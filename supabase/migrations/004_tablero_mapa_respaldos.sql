-- =====================================================================
-- Tablero de KPIs, mapa, ficha de parcela, reportes, archivos,
-- bitácora, respaldos y sesión
-- =====================================================================
create or replace function app.campana(p int) returns int language sql stable as $$
  select coalesce(p, (select id from campanas where estado = 'abierta' order by fecha_inicio desc limit 1), (select id from campanas order by fecha_inicio desc limit 1))
$$;

-- KPIs por parcela para una campaña: base del tablero, mapa y rankings
create or replace function app.kpi_parcelas(p_camp int, p_finca int default null) returns jsonb language sql stable as $$
with c as (select extract(year from fecha_inicio)::int + 1 as anio from campanas where id = p_camp),
precios as (select variedad_id, avg(precio) p from tarifas where campana_id = p_camp and concepto = 'uva_kg' group by variedad_id),
base as (
  select p.id, p.codigo, p.nombre, p.superficie_ha, p.plantas_teoricas, p.validada, p.estado, p.malla_antigranizo, p.tipo_riego,
         l.finca_id, f.nombre as finca, sc.nombre as conduccion, mo.nombre as modalidad, pv.nombre as variedad, pv.id as variedad_id,
         (select (select anio from c) - min(pl.anio_plantacion) from plantaciones pl where pl.parcela_id = p.id and pl.origen = 'original') as edad,
         (select sum(vivas) from v_plantas_vigentes vp where vp.parcela_id = p.id and vp.campana_id = p_camp) as plantas_vivas,
         (select sum(productivas) from v_plantas_vigentes vp where vp.parcela_id = p.id and vp.campana_id = p_camp) as plantas_productivas,
         coalesce((select sum(kg_netos) from v_kg_parcela k where k.parcela_id = p.id and k.campana_id = p_camp), 0) as kg,
         coalesce((select sum(e.kg_estimados) from estimaciones e join plantaciones pl on pl.id = e.plantacion_id
                   where pl.parcela_id = p.id and e.campana_id = p_camp and e.id in (select max(id) from estimaciones group by plantacion_id, campana_id)), 0) as kg_estimados,
         coalesce((select sum(monto) from costos_parcela cp where cp.parcela_id = p.id and cp.campana_id = p_camp), 0) as gasto,
         (select max(a.fecha_fin_carencia) from aplicaciones a join ordenes_aplicacion oa on oa.id = a.orden_aplicacion_id where oa.parcela_id = p.id) as carencia_hasta
  from parcelas p join lotes l on l.id = p.lote_id join fincas f on f.id = l.finca_id
  left join sistemas_conduccion sc on sc.id = p.sistema_conduccion_id
  left join modalidades mo on mo.id = p.modalidad_id
  left join lateral (select v.id, v.nombre from plantaciones pl join variedades v on v.id = pl.variedad_id where pl.parcela_id = p.id order by pl.plantas_iniciales desc nulls last limit 1) pv on true
  where p_finca is null or l.finca_id = p_finca
),
x as (
  select b.*, coalesce(pr.p, (select p from precios where variedad_id is null), 10) as precio,
         coalesce(nullif(b.superficie_ha, 0), 1) as ha, coalesce(nullif(b.plantas_productivas, 0), b.plantas_vivas) as prod
  from base b left join precios pr on pr.variedad_id = b.variedad_id
)
select coalesce(jsonb_agg(jsonb_build_object(
  'id', id, 'codigo', codigo, 'nombre', nombre, 'superficie_ha', superficie_ha, 'plantas_teoricas', plantas_teoricas, 'validada', validada,
  'estado', estado, 'malla_antigranizo', malla_antigranizo, 'tipo_riego', tipo_riego, 'finca_id', finca_id, 'finca', finca, 'conduccion', conduccion,
  'modalidad', modalidad, 'variedad', variedad, 'variedad_id', variedad_id, 'edad', edad, 'plantas_vivas', plantas_vivas, 'plantas_productivas', plantas_productivas,
  'kg', kg, 'kg_estimados', kg_estimados, 'gasto', gasto, 'carencia_hasta', carencia_hasta, 'precio_kg', round(precio, 2),
  'kg_ha', round(kg / ha), 'kg_planta', case when prod > 0 then round(kg / prod, 2) end,
  'bs_kg', case when kg > 0 then round(gasto / kg, 2) end, 'bs_ha', round(gasto / ha),
  'bs_planta', case when plantas_vivas > 0 then round(gasto / plantas_vivas, 2) end,
  'ingreso', round(kg * precio), 'margen', round(kg * precio - gasto), 'margen_ha', round((kg * precio - gasto) / ha),
  'pct_fallas', case when plantas_vivas > 0 and plantas_teoricas > 0 then round((plantas_teoricas - plantas_vivas)::numeric / plantas_teoricas * 100, 1) end,
  'error_estimacion', case when kg_estimados > 0 and kg > 0 then round((kg - kg_estimados) / kg_estimados * 100, 1) end,
  'carencia_vigente', coalesce(carencia_hasta >= current_date, false)
) order by codigo), '[]') from x
$$;

create or replace function app.stock() returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(s order by s.producto), '[]') from (
    select p.id as producto_id, p.nombre_comercial as producto, p.unidad, m.lote_fabricante,
           sum(case when m.tipo in ('ingreso','devolucion') then m.cantidad when m.tipo = 'salida' then -m.cantidad else m.cantidad end) as stock,
           max(m.fecha) as ultimo_movimiento
    from almacen_movimientos m join productos p on p.id = m.producto_id
    group by p.id, p.nombre_comercial, p.unidad, m.lote_fabricante) s
$$;

create or replace function public.api_dashboard(p_camp int default null, p_finca int default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  camp int; k jsonb; ids int[]; t jsonb; ha numeric; kg numeric; gasto numeric; ingreso numeric; vivas numeric; presup numeric;
  cats jsonb; meses jsonb; vars jsonb; manejo jsonb; cosecha jsonb; alertas jsonb := '[]'; al jsonb;
begin
  perform app.require_user();
  camp := app.campana(p_camp);
  k := app.kpi_parcelas(camp, p_finca);
  select coalesce(array_agg((e->>'id')::int), '{0}') into ids from jsonb_array_elements(k) e;
  select coalesce(sum((e->>'superficie_ha')::numeric), 0), coalesce(sum((e->>'kg')::numeric), 0), coalesce(sum((e->>'gasto')::numeric), 0),
         coalesce(sum((e->>'ingreso')::numeric), 0), coalesce(nullif(sum((e->>'plantas_vivas')::numeric), 0), sum((e->>'plantas_teoricas')::numeric), 0)
    into ha, kg, gasto, ingreso, vivas from jsonb_array_elements(k) e;
  select coalesce(sum(monto_presupuestado), 0) into presup from presupuestos where campana_id = camp and (parcela_id is null or parcela_id = any(ids));

  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'categoria', categoria, 'monto', monto,
           'pct', case when gasto > 0 then round(monto / gasto * 100, 1) else 0 end,
           'bs_ha', case when ha > 0 then round(monto / ha) else 0 end, 'bs_planta', case when vivas > 0 then round(monto / vivas, 2) else 0 end,
           'bs_kg', case when kg > 0 then round(monto / kg, 2) else 0 end,
           'presupuesto', coalesce((select sum(monto_presupuestado) from presupuestos pr where pr.campana_id = camp and pr.categoria_id = q.id), 0)) order by monto desc), '[]')
    into cats from (
      select coalesce(cp.id, cg.id) as id, coalesce(cp.nombre, cg.nombre) as categoria, sum(c.monto) as monto
      from costos_parcela c join categorias_gasto cg on cg.id = c.categoria_id left join categorias_gasto cp on cp.id = cg.padre_id
      where c.campana_id = camp and c.parcela_id = any(ids) group by 1, 2) q;

  select coalesce(jsonb_agg(jsonb_build_object('mes', mes, 'monto', monto) order by mes), '[]') into meses
    from (select to_char(fecha, 'YYYY-MM') mes, sum(monto) monto from costos_parcela where campana_id = camp and parcela_id = any(ids) group by 1) q;

  select coalesce(jsonb_agg(jsonb_build_object('variedad', variedad, 'parcelas', n, 'ha', ha_, 'kg', kg_, 'gasto', g, 'ingreso', i, 'plantas', pl,
           'kg_ha', case when ha_ > 0 then round(kg_ / ha_) else 0 end, 'kg_planta', case when pl > 0 then round(kg_ / pl, 2) end,
           'bs_kg', case when kg_ > 0 then round(g / kg_, 2) end, 'margen_ha', case when ha_ > 0 then round((i - g) / ha_) else 0 end)
           order by case when ha_ > 0 then (i - g) / ha_ else 0 end desc), '[]') into vars
    from (select coalesce(e->>'variedad', 'Sin variedad') variedad, count(*) n, sum((e->>'superficie_ha')::numeric) ha_, sum((e->>'kg')::numeric) kg_,
                 sum((e->>'gasto')::numeric) g, sum((e->>'ingreso')::numeric) i,
                 sum(coalesce(nullif((e->>'plantas_productivas')::numeric, 0), (e->>'plantas_vivas')::numeric, 0)) pl
          from jsonb_array_elements(k) e group by 1) q;

  select coalesce(jsonb_agg(jsonb_build_object('manejo', manejo, 'parcelas', n, 'ha', ha_, 'kg', kg_, 'gasto', g, 'ingreso', i,
           'kg_ha', case when ha_ > 0 then round(kg_ / ha_) else 0 end, 'bs_kg', case when kg_ > 0 then round(g / kg_, 2) end,
           'margen_ha', case when ha_ > 0 then round((i - g) / ha_) else 0 end,
           'brix', (select round(avg(cr.brix), 1) from calidad_recepcion cr join viajes_camion v on v.id = cr.viaje_id join viaje_parcelas vp on vp.viaje_id = v.id
                    join parcelas p on p.id = vp.parcela_id left join sistemas_conduccion sc on sc.id = p.sistema_conduccion_id
                    where v.campana_id = camp and coalesce(sc.nombre, 'Sin definir') = q.manejo))), '[]') into manejo
    from (select coalesce(e->>'conduccion', 'Sin definir') manejo, count(*) n, sum((e->>'superficie_ha')::numeric) ha_, sum((e->>'kg')::numeric) kg_,
                 sum((e->>'gasto')::numeric) g, sum((e->>'ingreso')::numeric) i from jsonb_array_elements(k) e group by 1) q;

  select coalesce(jsonb_agg(jsonb_build_object('fecha', fecha, 'kg', kg_, 'viajes', n, 'kg_balde', kgb) order by fecha), '[]') into cosecha
    from (select fecha, sum(peso_neto_kg) kg_, count(*) n, round(sum(peso_neto_kg) / nullif(sum(total_baldes), 0), 2) kgb
          from viajes_camion where campana_id = camp group by fecha) q;

  for al in select * from jsonb_array_elements(k) loop
    if (al->>'carencia_vigente')::boolean then alertas := alertas || jsonb_build_object('nivel','alta','tipo','Carencia','parcela_id',al->'id','texto',format('%s: carencia vigente hasta %s', al->>'codigo', al->>'carencia_hasta')); end if;
    if not coalesce((al->>'validada')::boolean, false) then alertas := alertas || jsonb_build_object('nivel','media','tipo','Validación','parcela_id',al->'id','texto',format('%s: parcela sin validación aprobada', al->>'codigo')); end if;
    if (al->>'pct_fallas')::numeric > 5 then alertas := alertas || jsonb_build_object('nivel','media','tipo','Fallas','parcela_id',al->'id','texto',format('%s: %s %% de fallas (meta ≤ 5 %%)', al->>'codigo', al->>'pct_fallas')); end if;
  end loop;
  alertas := alertas || coalesce((select jsonb_agg(jsonb_build_object('nivel','media','tipo','Renovación','parcela_id',parcela_id,'texto',format('%s: llega al fin de su vida útil (%s)', codigo, fecha_fin_vida_estimada)))
    from plantaciones where estado <> 'arrancada' and fecha_fin_vida_estimada <= current_date + interval '1 year' and parcela_id = any(ids)), '[]');
  alertas := alertas || coalesce((select jsonb_agg(jsonb_build_object('nivel','alta','tipo','Mildio','parcela_id',null,'texto',format('%s: condición de los tres 10 el %s', f.nombre, m.fecha)))
    from v_alerta_mildio m join fincas f on f.id = m.finca_id where m.fecha >= current_date - 15), '[]');
  alertas := alertas || coalesce((select jsonb_agg(jsonb_build_object('nivel','alta','tipo','Almacén','parcela_id',null,'texto',format('%s lote %s: stock negativo', s->>'producto', s->>'lote_fabricante')))
    from jsonb_array_elements(app.stock()) s where (s->>'stock')::numeric < 0), '[]');

  t := jsonb_build_object(
    'gasto', round(gasto), 'presupuesto', round(presup), 'pct_presupuesto', case when presup > 0 then round(gasto / presup * 100, 1) end,
    'kg', round(kg), 'ha', round(ha, 2), 'plantas', vivas, 'ingreso', round(ingreso), 'margen', round(ingreso - gasto),
    'bs_ha', case when ha > 0 then round(gasto / ha) else 0 end, 'bs_planta', case when vivas > 0 then round(gasto / vivas, 2) else 0 end,
    'bs_kg', case when kg > 0 then round(gasto / kg, 2) end, 'kg_ha', case when ha > 0 then round(kg / ha) else 0 end,
    'kg_planta', case when vivas > 0 then round(kg / vivas, 2) else 0 end,
    'parcelas', jsonb_array_length(k), 'validadas', (select count(*) from jsonb_array_elements(k) e where (e->>'validada')::boolean));
  return jsonb_build_object('campana_id', camp, 'totales', t, 'categorias', cats, 'meses', meses, 'parcelas', k, 'variedades', vars,
                            'manejo', manejo, 'cosecha_dia', cosecha, 'alertas', alertas);
end $$;

create or replace function public.api_reporte(p_tipo text, p_camp int default null, p_parcela int default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare camp int; anio int; res jsonb;
begin
  perform app.require_user();
  camp := app.campana(p_camp);
  if p_tipo = 'stock' then return app.stock(); end if;
  if p_tipo = 'trazabilidad' then
    select coalesce(jsonb_agg(to_jsonb(v) order by v.fecha desc), '[]') into res from v_trazabilidad_planta v where v.campana_id = camp and (p_parcela is null or v.parcela_id = p_parcela);
    return res;
  end if;
  if p_tipo = 'productividad' then
    select coalesce(jsonb_agg(q order by q.fecha desc, q.kg desc), '[]') into res from (
      select pe.nombre, j.fecha, sum(b.cantidad_baldes) baldes, round(sum(b.cantidad_baldes * coalesce(v.kg_por_balde_real, 0)), 1) kg
      from cosecha_baldes b join cosecha_jornadas j on j.id = b.jornada_id join personal pe on pe.id = b.cosechador_id
      left join viajes_camion v on v.id = b.viaje_id where j.campana_id = camp group by pe.nombre, j.fecha) q;
    return res;
  end if;
  if p_tipo = 'rendimiento_edad' then
    select extract(year from fecha_inicio)::int + 1 into anio from campanas where id = camp;
    select coalesce(jsonb_agg(jsonb_build_object('variedad', variedad, 'edad', edad, 'plantas', plantas, 'kg', kg,
             'kg_planta', case when plantas > 0 then round(kg / plantas, 2) end, 'esperado', esp,
             'desvio', case when esp > 0 and plantas > 0 then round((kg / plantas - esp) / esp * 100, 1) end) order by variedad, edad), '[]') into res
    from (
      select v.nombre variedad, anio - pl.anio_plantacion edad,
             coalesce(sum((select sum(productivas) from v_plantas_vigentes vp where vp.plantacion_id = pl.id and vp.campana_id = camp)), 0) plantas,
             coalesce(sum((select sum(kg_netos) from v_kg_parcela kp where kp.plantacion_id = pl.id and kp.campana_id = camp)), 0) kg,
             (select kg_planta_esperado from curva_rendimiento_edad cu where cu.variedad_id is null and cu.edad_anios <= anio - pl.anio_plantacion order by edad_anios desc limit 1) esp
      from plantaciones pl join variedades v on v.id = pl.variedad_id group by v.nombre, pl.anio_plantacion) q;
    return res;
  end if;
  perform app.err('Reporte no existe', 'P0002');
end $$;

-- ---------------------------------------------------------------------
-- Mapa y planos
-- ---------------------------------------------------------------------
create or replace function public.api_mapa(p_finca int default null, p_camp int default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare finca int; k jsonb;
begin
  perform app.require_user();
  finca := coalesce(p_finca, (select min(id) from fincas));
  k := app.kpi_parcelas(app.campana(p_camp), finca);
  return jsonb_build_object(
    'finca', (select to_jsonb(f) from fincas f where id = finca),
    'planos', (select coalesce(jsonb_agg(to_jsonb(p) order by p.id), '[]') from planos p where finca_id = finca),
    'parcelas', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'codigo', p.codigo, 'nombre', p.nombre, 'superficie_ha', p.superficie_ha,
                   'geom', p.geom, 'geom_plano', p.geom_plano, 'plano_id', p.plano_id, 'color', p.color, 'estado', p.estado, 'validada', p.validada, 'lote_id', p.lote_id,
                   'kpi', (select e from jsonb_array_elements(k) e where (e->>'id')::int = p.id)) order by p.codigo), '[]')
                 from parcelas p join lotes l on l.id = p.lote_id where l.finca_id = finca),
    'elementos', (select coalesce(jsonb_agg(to_jsonb(e)), '[]') from mapa_elementos e where finca_id = finca));
end $$;

create or replace function public.api_mapa_parcela(p_id int, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare o parcelas; quien text; dibujo boolean;
begin
  perform app.can_write(app.recurso('parcelas'));
  select * into o from parcelas where id = p_id;
  if o.id is null then perform app.err('Parcela no encontrada', 'P0002'); end if;
  if p ? 'geom' then update parcelas set geom = nullif(p->'geom', 'null') where id = p_id; end if;
  if p ? 'geom_plano' then update parcelas set geom_plano = nullif(p->'geom_plano', 'null') where id = p_id; end if;
  if coalesce(p->>'plano_id', '') <> '' then update parcelas set plano_id = (p->>'plano_id')::int where id = p_id; end if;
  if coalesce((p->>'actualizar_superficie')::boolean, false) and coalesce(p->>'superficie_ha', '') <> '' then
    update parcelas set superficie_ha = round((p->>'superficie_ha')::numeric, 2) where id = p_id;
  end if;
  quien := case when p ? 'geom' then 'mapa satelital' else 'plano' end;
  dibujo := coalesce(nullif(p->'geom', 'null'), nullif(p->'geom_plano', 'null')) is not null;
  perform app.audit('mapa', 'parcelas', p_id, p_id, case when dibujo
    then format('Editó el polígono de %s en el %s%s', o.codigo, quien, case when coalesce(p->>'superficie_ha', '') <> '' then format(' (%s ha medidas)', round((p->>'superficie_ha')::numeric, 2)) else '' end)
    else format('Quitó el polígono de %s del %s', o.codigo, quien) end);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.api_mapa_elemento(p_id int, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare nid int;
begin
  perform app.can_write(app.recurso('mapa_elementos'));
  if p_id is null then
    insert into mapa_elementos (finca_id, plano_id, tipo, nombre, geom, color)
    values ((p->>'finca_id')::int, nullif(p->>'plano_id', '')::int, coalesce(nullif(p->>'tipo', ''), 'otro')::e_mapa_elementos_tipo, left(p->>'nombre', 120), p->'geom', coalesce(nullif(p->>'color', ''), '#444444'))
    returning id into nid;
  else
    update mapa_elementos set nombre = coalesce(left(p->>'nombre', 120), nombre), geom = coalesce(p->'geom', geom), color = coalesce(nullif(p->>'color', ''), color) where id = p_id;
    nid := p_id;
  end if;
  perform app.audit('mapa', 'mapa_elementos', nid, null, format('Guardó elemento de mapa ''%s'' %s', p->>'tipo', coalesce(p->>'nombre', '')));
  return jsonb_build_object('id', nid);
end $$;

create or replace function public.api_mapa_elemento_eliminar(p_id int) returns jsonb language plpgsql security definer set search_path = public as $$
declare o mapa_elementos;
begin
  perform app.can_write(app.recurso('mapa_elementos'));
  delete from mapa_elementos where id = p_id returning * into o;
  perform app.audit('mapa', 'mapa_elementos', p_id, null, format('Eliminó elemento de mapa ''%s'' %s', o.tipo, coalesce(o.nombre, '')));
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.api_plano_registrar(p_finca int, p_nombre text, p_ruta text, p_w int, p_h int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r planos;
begin
  perform app.can_write(app.recurso('planos'));
  insert into planos (finca_id, nombre, ruta, ancho_px, alto_px) values (p_finca, coalesce(nullif(p_nombre, ''), 'Plano'), p_ruta, p_w, p_h) returning * into r;
  perform app.audit('mapa', 'planos', r.id, null, format('Subió el plano «%s»', r.nombre));
  return to_jsonb(r);
end $$;

-- ---------------------------------------------------------------------
-- Archivos (los binarios viven en Supabase Storage, bucket "archivos")
-- ---------------------------------------------------------------------
create or replace function public.api_archivo_registrar(p_entidad text, p_entidad_id int, p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u perfiles := app.require_user(); row jsonb; par int; nid int;
begin
  if u.rol = 'consulta' then perform app.err('Su usuario es de solo consulta', '42501'); end if;
  perform app.recurso(p_entidad);
  execute format('select to_jsonb(t) from public.%I t where id = $1', p_entidad) into row using p_entidad_id;
  if row is null then perform app.err('Registro no encontrado', 'P0002'); end if;
  par := app.parcela_of(p_entidad, row);
  insert into archivos (entidad, entidad_id, parcela_id, nombre_original, ruta, mime, tamano_bytes, descripcion, created_by)
  values (p_entidad, p_entidad_id, par, left(p->>'nombre', 250), p->>'ruta', p->>'mime', (p->>'size')::int, nullif(p->>'descripcion', ''), u.id)
  returning id into nid;
  perform app.audit('subir_archivo', p_entidad, p_entidad_id, par, format('Adjuntó «%s» a %s #%s', p->>'nombre', replace(p_entidad, '_', ' '), p_entidad_id));
  return jsonb_build_object('id', nid);
end $$;

create or replace function public.api_archivos(p jsonb default '{}') returns jsonb language plpgsql stable security definer set search_path = public as $$
declare res jsonb;
begin
  perform app.require_user();
  select coalesce(jsonb_agg(to_jsonb(a) || jsonb_build_object('usuario', pf.nombre, 'parcela', pa.codigo) order by a.created_at desc), '[]') into res
  from (select * from archivos a
        where (coalesce(p->>'entidad', '') = '' or a.entidad = p->>'entidad')
          and (coalesce(p->>'entidad_id', '') = '' or a.entidad_id = (p->>'entidad_id')::int)
          and (coalesce(p->>'parcela_id', '') = '' or a.parcela_id = (p->>'parcela_id')::int)
          and (coalesce(p->>'solo_imagenes', '') = '' or a.mime like 'image/%')
        order by a.created_at desc limit 300) a
  left join perfiles pf on pf.id = a.created_by left join parcelas pa on pa.id = a.parcela_id;
  return res;
end $$;

create or replace function public.api_archivo_eliminar(p_id int) returns jsonb language plpgsql security definer set search_path = public as $$
declare u perfiles := app.require_user(); a archivos;
begin
  if u.rol = 'consulta' then perform app.err('Su usuario es de solo consulta', '42501'); end if;
  delete from archivos where id = p_id returning * into a;
  if a.id is null then perform app.err('Archivo no encontrado', 'P0002'); end if;
  perform app.audit('eliminar', a.entidad, a.entidad_id, a.parcela_id, format('Eliminó el adjunto «%s»', a.nombre_original));
  return jsonb_build_object('ok', true, 'ruta', a.ruta);
end $$;

-- ---------------------------------------------------------------------
-- Ficha de parcela y bitácora
-- ---------------------------------------------------------------------
create or replace function public.api_parcela_resumen(p_id int, p_camp int default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p jsonb; anio int; kpis jsonb := '[]'; c record; e jsonb;
begin
  perform app.require_user();
  select to_jsonb(x) - 'geom_plano' into p from (
    select pa.*, l.codigo lote, l.finca_id, f.nombre finca, f.zona, pr.nombre propietario, m.nombre modalidad, sc.nombre conduccion
    from parcelas pa join lotes l on l.id = pa.lote_id join fincas f on f.id = l.finca_id
    left join propietarios pr on pr.id = pa.propietario_id left join modalidades m on m.id = pa.modalidad_id
    left join sistemas_conduccion sc on sc.id = pa.sistema_conduccion_id where pa.id = p_id) x;
  if p is null then perform app.err('Parcela no encontrada', 'P0002'); end if;
  select extract(year from fecha_inicio)::int + 1 into anio from campanas where id = app.campana(p_camp);
  for c in select id, nombre from campanas order by fecha_inicio loop
    select e2 into e from jsonb_array_elements(app.kpi_parcelas(c.id, (p->>'finca_id')::int)) e2 where (e2->>'id')::int = p_id;
    if e is not null then kpis := kpis || (jsonb_build_object('campana', c.nombre) || e); end if;
  end loop;
  return jsonb_build_object(
    'parcela', p,
    'plantaciones', (select coalesce(jsonb_agg(to_jsonb(pl) || jsonb_build_object('variedad', v.nombre, 'edad', anio - pl.anio_plantacion) order by pl.anio_plantacion), '[]')
                     from plantaciones pl join variedades v on v.id = pl.variedad_id where pl.parcela_id = p_id),
    'kpis', kpis,
    'trazabilidad', (select coalesce(jsonb_agg(to_jsonb(t) order by t.fecha desc), '[]') from (select * from v_trazabilidad_planta where parcela_id = p_id order by fecha desc limit 30) t),
    'actividad', (select coalesce(jsonb_agg(to_jsonb(b) order by b.id desc), '[]') from (select * from bitacora where parcela_id = p_id order by id desc limit 60) b),
    'archivos', public.api_archivos(jsonb_build_object('parcela_id', p_id)));
end $$;

create or replace function public.api_bitacora(p jsonb default '{}') returns jsonb language plpgsql stable security definer set search_path = public as $$
declare total int; rows jsonb; lim int := least(500, greatest(1, coalesce((p->>'limit')::int, 100))); off int := greatest(0, coalesce((p->>'offset')::int, 0));
begin
  perform app.require_user();
  select count(*) into total from bitacora b
   where (coalesce(p->>'entidad','') = '' or b.entidad = p->>'entidad') and (coalesce(p->>'accion','') = '' or b.accion = p->>'accion')
     and (coalesce(p->>'entidad_id','') = '' or b.entidad_id = (p->>'entidad_id')::int) and (coalesce(p->>'parcela_id','') = '' or b.parcela_id = (p->>'parcela_id')::int)
     and (coalesce(p->>'desde','') = '' or b.created_at >= (p->>'desde')::date) and (coalesce(p->>'hasta','') = '' or b.created_at < (p->>'hasta')::date + 1)
     and (coalesce(p->>'q','') = '' or b.descripcion ilike '%' || (p->>'q') || '%' or b.usuario_nombre ilike '%' || (p->>'q') || '%');
  select coalesce(jsonb_agg(to_jsonb(b) || jsonb_build_object('parcela', pa.codigo) order by b.id desc), '[]') into rows from (
    select * from bitacora b
     where (coalesce(p->>'entidad','') = '' or b.entidad = p->>'entidad') and (coalesce(p->>'accion','') = '' or b.accion = p->>'accion')
       and (coalesce(p->>'entidad_id','') = '' or b.entidad_id = (p->>'entidad_id')::int) and (coalesce(p->>'parcela_id','') = '' or b.parcela_id = (p->>'parcela_id')::int)
       and (coalesce(p->>'desde','') = '' or b.created_at >= (p->>'desde')::date) and (coalesce(p->>'hasta','') = '' or b.created_at < (p->>'hasta')::date + 1)
       and (coalesce(p->>'q','') = '' or b.descripcion ilike '%' || (p->>'q') || '%' or b.usuario_nombre ilike '%' || (p->>'q') || '%')
     order by b.id desc limit lim offset off) b left join parcelas pa on pa.id = b.parcela_id;
  return jsonb_build_object('total', total, 'rows', rows);
end $$;

-- ---------------------------------------------------------------------
-- Sesión
-- ---------------------------------------------------------------------
create or replace function public.api_me(p_login boolean default false) returns jsonb language plpgsql security definer set search_path = public as $$
declare u perfiles := app.require_user();
begin
  if p_login then
    update perfiles set ultimo_acceso = now() where id = u.id;
    perform app.audit('login', 'perfiles', null, null, 'Inicio de sesión');
  end if;
  return jsonb_build_object('user', jsonb_build_object('id', u.id, 'nombre', u.nombre, 'email', u.email, 'rol', u.rol));
end $$;

-- ---------------------------------------------------------------------
-- Respaldos: exportación/importación JSON de todas las tablas
-- (los archivos de fotos quedan en Storage y no se borran al restaurar)
-- ---------------------------------------------------------------------
create or replace function app.tablas_respaldo() returns text[] language sql stable as $$
  -- orden de dependencias: padres primero
  with recursive deps as (
    select c.relname::text t, 0 nivel from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relname not in ('perfiles','respaldos')
  ), fk as (
    select tc.relname::text t, rc.relname::text r from pg_constraint k join pg_class tc on tc.oid = k.conrelid join pg_class rc on rc.oid = k.confrelid
    join pg_namespace n on n.oid = tc.relnamespace where k.contype = 'f' and n.nspname = 'public' and tc.relname <> rc.relname
  ), lvl as (
    select t, 0 as l from deps
    union all
    select fk.t, lvl.l + 1 from lvl join fk on fk.r = lvl.t where lvl.l < 20
  )
  select array_agg(t order by l, t) from (select t, max(l) l from lvl where t in (select t from deps) group by t) x
$$;

create or replace function public.api_respaldo_exportar() returns jsonb language plpgsql stable security definer set search_path = public as $$
declare res jsonb := '{}'; t text; data jsonb;
begin
  perform app.require_role(array['gerencia']);
  foreach t in array app.tablas_respaldo() loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x) order by x.id), ''[]'') from public.%I x', t) into data;
    res := res || jsonb_build_object(t, data);
  end loop;
  return jsonb_build_object('version', 1, 'sistema', 'control-vinedo', 'fecha', now(), 'tablas', res);
end $$;

create or replace function public.api_respaldo_registrar(p_archivo text, p_size bigint, p_nota text) returns jsonb language plpgsql security definer set search_path = public as $$
declare nid int;
begin
  perform app.require_role(array[]::text[]);
  insert into respaldos (archivo, tamano_bytes, incluye_archivos, nota, created_by) values (p_archivo, p_size, false, p_nota, auth.uid()) returning id into nid;
  perform app.audit('respaldo', 'respaldos', nid, null, format('Generó el respaldo %s (%s KB)', p_archivo, round(p_size / 1024.0)));
  return jsonb_build_object('id', nid);
end $$;

create or replace function public.api_respaldos() returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform app.require_role(array['gerencia']);
  return jsonb_build_object(
    'rows', (select coalesce(jsonb_agg(to_jsonb(r) || jsonb_build_object('usuario', p.nombre, 'existe', true) order by r.id desc), '[]') from respaldos r left join perfiles p on p.id = r.created_by),
    'tablas', (select coalesce(jsonb_agg(jsonb_build_object('tabla', c.relname, 'filas', greatest(c.reltuples, 0)::bigint, 'kb', pg_total_relation_size(c.oid) / 1024) order by c.relname), '[]')
               from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r'));
end $$;

create or replace function public.api_respaldo_eliminar(p_id int) returns jsonb language plpgsql security definer set search_path = public as $$
declare r respaldos;
begin
  perform app.require_role(array[]::text[]);
  delete from respaldos where id = p_id returning * into r;
  perform app.audit('eliminar', 'respaldos', p_id, null, format('Eliminó el respaldo %s', r.archivo));
  return jsonb_build_object('ok', true, 'archivo', r.archivo);
end $$;

create or replace function public.api_respaldo_importar(p_data jsonb, p_nombre text) returns jsonb language plpgsql security definer set search_path = public as $$
declare t text; tablas text[] := app.tablas_respaldo(); lista text;
begin
  perform app.require_role(array[]::text[]);
  if p_data->>'sistema' is distinct from 'control-vinedo' then perform app.err('El archivo no es un respaldo de este sistema'); end if;
  select string_agg(format('public.%I', x), ', ') into lista from unnest(tablas) x;
  execute 'truncate ' || lista || ' restart identity cascade';
  foreach t in array tablas loop
    if p_data->'tablas' ? t then
      execute format('insert into public.%I select * from jsonb_populate_recordset(null::public.%I, $1)', t, t) using p_data->'tablas'->t;
      execute format('select setval(pg_get_serial_sequence(%L, ''id''), coalesce((select max(id) from public.%I), 1))', 'public.' || t, t);
    end if;
  end loop;
  perform app.audit('respaldo', 'respaldos', null, null, format('Restauró la base de datos desde %s', p_nombre));
  return jsonb_build_object('ok', true);
end $$;
