-- =====================================================================
-- Vistas de control, configuración de recursos y núcleo CRUD seguro
-- El esquema "app" no se expone por la API; solo las funciones public.api_*
-- =====================================================================
create schema if not exists app;
grant usage on schema app to authenticated;

-- ---------------------------------------------------------------------
-- Vistas (sección 5 del documento)
-- ---------------------------------------------------------------------
create or replace view public.v_plantas_vigentes with (security_invoker = on) as
select c.campana_id, c.parcela_id, d.plantacion_id,
       sum(d.plantas_vivas_productivas) as productivas,
       sum(d.plantas_vivas_improductivas) as improductivas,
       sum(d.plantas_vivas_productivas + d.plantas_vivas_improductivas) as vivas,
       sum(d.plantas_muertas) as muertas, sum(d.fallas) as fallas
from censos c join censo_detalle d on d.censo_id = c.id
where c.estado = 'validado'
group by c.campana_id, c.parcela_id, d.plantacion_id;

create or replace view public.v_kg_parcela with (security_invoker = on) as
select v.campana_id, vp.parcela_id, vp.plantacion_id, sum(vp.kg_asignados) as kg_netos, sum(vp.baldes) as baldes
from viaje_parcelas vp join viajes_camion v on v.id = vp.viaje_id
group by v.campana_id, vp.parcela_id, vp.plantacion_id;

create or replace view public.v_gasto_por_categoria with (security_invoker = on) as
select cp.campana_id, cp.parcela_id, cg.id as categoria_id, coalesce(cgp.nombre, cg.nombre) as categoria, sum(cp.monto) as monto
from costos_parcela cp join categorias_gasto cg on cg.id = cp.categoria_id left join categorias_gasto cgp on cgp.id = cg.padre_id
group by cp.campana_id, cp.parcela_id, cg.id, coalesce(cgp.nombre, cg.nombre);

create or replace view public.v_alerta_carencia with (security_invoker = on) as
select oa.campana_id, oa.parcela_id, p.codigo as parcela, max(a.fecha_fin_carencia) as carencia_hasta
from aplicaciones a join ordenes_aplicacion oa on oa.id = a.orden_aplicacion_id join parcelas p on p.id = oa.parcela_id
group by oa.campana_id, oa.parcela_id, p.codigo
having max(a.fecha_fin_carencia) >= current_date;

create or replace view public.v_trazabilidad_planta with (security_invoker = on) as
select oa.campana_id, oa.parcela_id, p.codigo as parcela, a.fecha, pr.nombre_comercial as producto, pr.ingrediente_activo,
       ap.lote_fabricante, ap.cantidad_aplicada, pr.unidad, ap.cantidad_por_planta, a.plantas_tratadas, a.fecha_fin_carencia
from aplicacion_productos ap join aplicaciones a on a.id = ap.aplicacion_id
join ordenes_aplicacion oa on oa.id = a.orden_aplicacion_id join parcelas p on p.id = oa.parcela_id
join productos pr on pr.id = ap.producto_id;

create or replace view public.v_alerta_mildio with (security_invoker = on) as
select cl.finca_id, cl.fecha, cl.temp_media, cl.lluvia_mm, max(f.longitud_brote_cm) as brote_cm
from clima_diario cl
join lotes l on l.finca_id = cl.finca_id join parcelas p on p.lote_id = l.id
join plantaciones pl on pl.parcela_id = p.id
join fenologia_registros f on f.plantacion_id = pl.id and f.fecha <= cl.fecha
where cl.temp_media >= 10 and cl.lluvia_mm >= 10
group by cl.finca_id, cl.fecha, cl.temp_media, cl.lluvia_mm
having max(f.longitud_brote_cm) >= 10;

-- ---------------------------------------------------------------------
-- Usuario actual y permisos
-- ---------------------------------------------------------------------
create or replace function app.perfil() returns public.perfiles
language sql stable security definer set search_path = public as $$
  select * from public.perfiles where id = auth.uid() and activo
$$;

create or replace function app.rol_actual() returns text
language sql stable security definer set search_path = public as $$
  select rol::text from public.perfiles where id = auth.uid() and activo
$$;
grant execute on function app.rol_actual() to authenticated;

create or replace function app.err(p_msg text, p_code text default 'P0001') returns void language plpgsql as $$
begin raise exception using message = p_msg, errcode = p_code; end $$;

create or replace function app.require_user() returns public.perfiles language plpgsql stable security definer set search_path = public as $$
declare u public.perfiles;
begin
  select * into u from public.perfiles where id = auth.uid() and activo;
  if u.id is null then perform app.err('Sesión no válida o usuario inactivo', '28000'); end if;
  return u;
end $$;

create or replace function app.require_role(p_roles text[]) returns public.perfiles language plpgsql stable security definer set search_path = public as $$
declare u public.perfiles := app.require_user();
begin
  if u.rol <> 'admin' and not (u.rol::text = any(p_roles)) then perform app.err('No tiene permiso para esta acción', '42501'); end if;
  return u;
end $$;

-- Advertencias no bloqueantes acumuladas durante una operación
create or replace function app.warn(p text) returns void language plpgsql as $$
declare cur jsonb := coalesce(nullif(current_setting('app.warnings', true), '')::jsonb, '[]'::jsonb);
begin perform set_config('app.warnings', (cur || to_jsonb(p))::text, true); end $$;

create or replace function app.audit(p_accion text, p_entidad text, p_id int, p_parcela int, p_desc text, p_antes jsonb default null, p_despues jsonb default null)
returns void language plpgsql security definer set search_path = public as $$
declare u public.perfiles := app.perfil();
begin
  insert into bitacora (usuario_id, usuario_nombre, accion, entidad, entidad_id, parcela_id, descripcion, datos_antes, datos_despues)
  values (u.id, u.nombre, p_accion, p_entidad, p_id, p_parcela, left(p_desc, 500),
          p_antes - array['geom','geom_plano'], p_despues - array['geom','geom_plano']);
end $$;

-- ---------------------------------------------------------------------
-- Configuración de recursos (etiqueta, búsqueda, orden, permisos)
-- {a} = alias de la tabla
-- ---------------------------------------------------------------------
create table app.recursos (
  nombre text primary key,
  etiqueta text not null,
  busqueda text[] default '{}',
  orden text default 'id desc',
  escritura text[],          -- null = todos menos consulta
  lectura text[]             -- null = cualquier usuario activo
);

insert into app.recursos (nombre, etiqueta, busqueda, orden, escritura, lectura) values
('campanas', '{a}.nombre', '{nombre}', 'fecha_inicio desc', '{gerencia,administracion}', null),
('modalidades', '{a}.nombre', '{nombre}', 'id', '{gerencia,administracion,agronomo}', null),
('propietarios', '{a}.nombre', '{nombre,nit_ci}', 'nombre', '{gerencia,administracion,agronomo}', null),
('variedades', '{a}.nombre', '{nombre,grupo}', 'nombre', '{gerencia,administracion,agronomo}', null),
('sistemas_conduccion', '{a}.nombre', '{nombre}', 'id', '{gerencia,administracion,agronomo}', null),
('curva_rendimiento_edad', 'concat(''Edad '', {a}.edad_anios)', '{}', 'edad_anios', '{gerencia,administracion,agronomo}', null),
('productos', '{a}.nombre_comercial', '{nombre_comercial,ingrediente_activo}', 'nombre_comercial', '{gerencia,administracion,agronomo}', null),
('plagas_enfermedades', '{a}.nombre', '{nombre}', 'nombre', '{gerencia,administracion,agronomo}', null),
('cuadrillas', '{a}.nombre', '{nombre}', 'nombre', '{gerencia,administracion,agronomo}', null),
('personal', '{a}.nombre', '{nombre,ci}', 'nombre', '{gerencia,administracion,agronomo}', null),
('vehiculos', 'concat({a}.placa, '' · '', {a}.tipo)', '{placa}', 'placa', '{gerencia,administracion,agronomo}', null),
('tipos_envase', '{a}.nombre', '{nombre}', 'id', '{gerencia,administracion,agronomo}', null),
('categorias_gasto', 'concat({a}.codigo, '' '', {a}.nombre)', '{nombre,codigo}', 'codigo', '{gerencia,administracion,agronomo}', null),
('tarifas', 'concat({a}.concepto, '' '', {a}.precio)', '{}', 'id desc', '{administracion,gerencia}', null),
('fincas', '{a}.nombre', '{nombre,comunidad}', 'nombre', '{gerencia,administracion,agronomo}', null),
('lotes', 'concat({a}.codigo, '' · '', {a}.nombre)', '{codigo,nombre}', 'codigo', '{gerencia,administracion,agronomo}', null),
('parcelas', 'concat({a}.codigo, '' · '', coalesce({a}.nombre, ''''))', '{codigo,nombre}', 'codigo', '{gerencia,administracion,agronomo,tecnico}', null),
('hileras', 'concat(''H-'', {a}.numero)', '{}', 'parcela_id, numero', null, null),
('plantaciones', '{a}.codigo', '{codigo,portainjerto}', 'codigo', null, null),
('plantines_lotes', '{a}.codigo_lote', '{codigo_lote,proveedor}', 'id desc', null, null),
('implantaciones', 'concat(''Implantación '', {a}.id)', '{}', 'id desc', null, null),
('seguimiento_formacion', '{a}.fecha::text', '{}', 'fecha desc', null, null),
('plantas', '{a}.codigo', '{codigo}', 'id desc', null, null),
('planos', '{a}.nombre', '{nombre}', 'id', null, null),
('mapa_elementos', 'coalesce({a}.nombre, {a}.tipo::text)', '{nombre}', 'id', null, null),
('censos', 'concat(''Censo '', {a}.fecha)', '{}', 'fecha desc', null, null),
('censo_detalle', 'concat(''Detalle '', {a}.id)', '{}', 'id', null, null),
('validaciones_parcela', 'concat(''Validación '', {a}.fecha)', '{}', 'fecha desc', '{administracion,tecnico,gerencia}', null),
('replantes', 'concat(''Replante '', {a}.fecha)', '{}', 'fecha desc', null, null),
('ordenes_trabajo', 'concat({a}.numero, '' · '', {a}.tipo)', '{numero,descripcion}', 'fecha_programada desc', null, null),
('poda_registros', 'concat(''Poda '', {a}.fecha)', '{}', 'fecha desc', null, null),
('labores', 'concat({a}.tipo, '' '', {a}.fecha)', '{observaciones}', 'fecha desc', null, null),
('fenologia_registros', 'concat({a}.etapa, '' '', {a}.fecha)', '{observaciones}', 'fecha desc', null, null),
('conteo_yemas', 'concat(''Conteo '', {a}.fecha)', '{}', 'fecha desc', null, null),
('analisis_suelo', 'concat(''Análisis '', {a}.fecha_muestreo)', '{laboratorio}', 'fecha_muestreo desc', null, null),
('clima_diario', '{a}.fecha::text', '{}', 'fecha desc', null, null),
('monitoreos', 'concat(''Monitoreo '', {a}.fecha)', '{observaciones}', 'fecha desc', null, null),
('ordenes_aplicacion', 'concat(''OA-'', lpad({a}.id::text, 4, ''0''), '' · '', {a}.fecha_programada)', '{}', 'fecha_programada desc', '{agronomo,tecnico,almacenero}', null),
('orden_aplicacion_productos', 'concat(''Ítem '', {a}.id)', '{}', 'id', null, null),
('aplicaciones', 'concat(''Aplicación '', {a}.fecha)', '{clima}', 'fecha desc', null, null),
('aplicacion_productos', '{a}.lote_fabricante', '{lote_fabricante}', 'id', null, null),
('almacen_movimientos', 'concat({a}.tipo, '' '', {a}.fecha)', '{lote_fabricante,nro_factura,proveedor}', 'fecha desc', '{almacenero,agronomo,administracion}', null),
('estimaciones', 'concat(''Estimación '', {a}.fecha)', '{}', 'fecha desc', null, null),
('muestreos_madurez', 'concat(''Madurez '', {a}.fecha)', '{estado_sanitario}', 'fecha desc', null, null),
('cosecha_jornadas', 'concat(''Jornada '', {a}.fecha)', '{}', 'fecha desc', null, null),
('cosecha_baldes', 'concat({a}.cantidad_baldes, '' baldes'')', '{}', 'id', null, null),
('viajes_camion', 'concat(''Ticket '', coalesce({a}.nro_ticket, {a}.id::text), '' · '', {a}.fecha)', '{nro_ticket,destino}', 'fecha desc, id desc', null, null),
('viaje_parcelas', 'concat(''Reparto '', {a}.id)', '{}', 'id', null, null),
('calidad_recepcion', 'concat(''Calidad '', {a}.clasificacion)', '{lote_bodega}', 'id', null, null),
('liquidacion_personal', 'concat(''Liq. '', {a}.periodo_desde)', '{}', 'periodo_desde desc', '{administracion,gerencia}', null),
('liquidacion_produccion', 'concat(''Liq. '', {a}.id)', '{}', 'id desc', '{administracion,gerencia}', null),
('presupuestos', 'concat(''Presupuesto '', {a}.id)', '{}', 'id', '{administracion,gerencia}', null),
('manejo_parcela', 'concat(''Manejo '', {a}.id)', '{observaciones}', 'id', null, null),
('costos_parcela', 'coalesce({a}.descripcion, '''')', '{descripcion}', 'fecha desc', '{administracion,gerencia,agronomo}', null),
('ventas_uva', 'concat({a}.cliente, '' '', {a}.fecha)', '{cliente}', 'fecha desc', '{administracion,gerencia}', null),
('perfiles', '{a}.nombre', '{nombre,email}', 'nombre', '{}', '{}');

create or replace function app.recurso(p_res text) returns app.recursos language plpgsql stable as $$
declare r app.recursos;
begin
  select * into r from app.recursos where nombre = p_res;
  if r.nombre is null then perform app.err(format('Recurso ''%s'' no existe', p_res), 'P0002'); end if;
  return r;
end $$;

create or replace function app.can_read(r app.recursos) returns public.perfiles language plpgsql stable as $$
begin
  if r.lectura is not null then return app.require_role(r.lectura); end if;
  return app.require_user();
end $$;

create or replace function app.can_write(r app.recursos) returns public.perfiles language plpgsql stable as $$
declare u public.perfiles := app.require_user();
begin
  if u.rol = 'consulta' then perform app.err('Su usuario es de solo consulta', '42501'); end if;
  if r.escritura is not null then return app.require_role(r.escritura); end if;
  return u;
end $$;

-- ---------------------------------------------------------------------
-- Introspección (mismo formato que entregaba la API PHP)
-- ---------------------------------------------------------------------
create or replace function app.fk_map(p_table text) returns jsonb language sql stable as $$
  with reales as (
    select a.attname::text col, cf.relname::text ref
    from pg_constraint c join pg_class t on t.oid = c.conrelid join pg_namespace n on n.oid = t.relnamespace
    join pg_class cf on cf.oid = c.confrelid join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where c.contype = 'f' and n.nspname = 'public' and t.relname = p_table
  ),
  logicas(col, ref) as (values ('capataz_id','personal'),('aprobado_por','personal'),('validador_id','personal'),('balancero_id','personal'),
    ('conductor_id','personal'),('propietario_id','propietarios'),('modalidad_id','modalidades'),('variedad_id','variedades'),('tecnico_id','personal'),
    ('parcela_id','parcelas'),('plano_id','planos'),('hilera_id','hileras'),('finca_id','fincas'))
  select coalesce(jsonb_object_agg(col, ref), '{}') from (
    select col, ref from reales where ref <> 'users'
    union
    select l.col, l.ref from logicas l
    where exists (select 1 from information_schema.columns ic where ic.table_schema='public' and ic.table_name=p_table and ic.column_name=l.col)
      and not exists (select 1 from reales r where r.col = l.col)
  ) x
$$;

create or replace function app.fields(p_table text) returns jsonb language sql stable as $$
  with fk as (select app.fk_map(p_table) m)
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
    'name', c.column_name,
    'type', case
      when c.data_type = 'USER-DEFINED' then 'enum'
      when c.data_type = 'integer' then 'int'
      when c.data_type = 'bigint' then 'bigint'
      when c.data_type = 'numeric' then 'decimal'
      when c.data_type = 'boolean' then 'bool'
      when c.data_type = 'date' then 'date'
      when c.data_type like 'time without%' then 'time'
      when c.data_type like 'timestamp%' then 'datetime'
      when c.data_type = 'jsonb' then 'json'
      when c.data_type = 'text' then 'text'
      else 'varchar' end,
    'required', c.is_nullable = 'NO' and c.column_default is null and c.is_identity = 'NO',
    'options', case when c.data_type = 'USER-DEFINED' then (select jsonb_agg(e.enumlabel order by e.enumsortorder) from pg_type ty join pg_enum e on e.enumtypid = ty.oid where ty.typname = c.udt_name) end,
    'fk', (select m->>c.column_name from fk)
  )) order by c.ordinal_position), '[]')
  from information_schema.columns c
  where c.table_schema = 'public' and c.table_name = p_table
    and c.column_name not in ('id','created_at','updated_at','created_by','geom','geom_plano','ultimo_acceso')
$$;

create or replace function public.api_schema(p_res text) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r app.recursos := app.recurso(p_res); f jsonb;
begin
  perform app.can_read(r);
  f := app.fields(p_res);
  if p_res = 'perfiles' then f := f || '[{"name":"password","type":"password","required":false}]'::jsonb; end if;
  return jsonb_build_object('resource', p_res, 'fields', f);
end $$;

create or replace function app.order_sql(p_order text) returns text language sql immutable as $$
  select string_agg('t.' || trim(x), ', ') from unnest(string_to_array(p_order, ',')) x
$$;

create or replace function public.api_options(p_res text, p_filters jsonb default '{}') returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r app.recursos := app.recurso(p_res); w text := ''; k text; v text; res jsonb; cols jsonb := app.fields(p_res);
begin
  perform app.require_user();
  for k, v in select * from jsonb_each_text(coalesce(p_filters, '{}')) loop
    if v is not null and v <> '' and exists (select 1 from information_schema.columns where table_schema='public' and table_name=p_res and column_name=k) then
      w := w || case when w = '' then ' where ' else ' and ' end || format('t.%I::text = %L', k, v);
    end if;
  end loop;
  execute format('select coalesce(jsonb_agg(jsonb_build_object(''value'', t.id, ''label'', %s) order by %s), ''[]'') from (select * from public.%I t %s limit 2000) t',
    replace(r.etiqueta, '{a}', 't'), app.order_sql(r.orden), p_res, w) into res;
  return res;
end $$;

-- Listado genérico con etiquetas de llaves foráneas y conteo de adjuntos
create or replace function public.api_list(p_res text, p jsonb default '{}') returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  r app.recursos := app.recurso(p_res);
  fk jsonb := app.fk_map(p_res);
  sel text := 'to_jsonb(t.*)';
  joins text := '';
  w text[] := '{}';
  k text; v text; i int := 0; col text; ref text;
  ord text; lim int; off int; total int; rows jsonb; s text;
begin
  perform app.can_read(r);
  for col, ref in select * from jsonb_each_text(fk) loop
    if exists (select 1 from app.recursos where nombre = ref) then
      i := i + 1;
      sel := sel || format(' || jsonb_build_object(%L, %s)', col || '__label', replace((select etiqueta from app.recursos where nombre = ref), '{a}', 'j' || i));
      joins := joins || format(' left join public.%I j%s on j%s.id = t.%I', ref, i, i, col);
    end if;
  end loop;
  for k, v in select * from jsonb_each_text(p) loop
    if k in ('q','sort','limit','offset','finca_id') or v is null or v = '' then continue; end if;
    if exists (select 1 from information_schema.columns where table_schema='public' and table_name=p_res and column_name=k) then
      w := w || format('t.%I::text = %L', k, v);
    end if;
  end loop;
  if coalesce(p->>'finca_id', '') <> '' and not exists (select 1 from information_schema.columns where table_schema='public' and table_name=p_res and column_name='finca_id') then
    if exists (select 1 from information_schema.columns where table_schema='public' and table_name=p_res and column_name='parcela_id') then
      w := w || format('t.parcela_id in (select pa.id from parcelas pa join lotes lo on lo.id = pa.lote_id where lo.finca_id = %s)', (p->>'finca_id')::int);
    elsif p_res = 'parcelas' then
      w := w || format('t.lote_id in (select id from lotes where finca_id = %s)', (p->>'finca_id')::int);
    end if;
  end if;
  if coalesce(p->>'q', '') <> '' and cardinality(r.busqueda) > 0 then
    w := w || ('(' || (select string_agg(format('t.%I::text ilike %L', b, '%' || (p->>'q') || '%'), ' or ') from unnest(r.busqueda) b) || ')');
  end if;
  ord := app.order_sql(r.orden);
  s := coalesce(p->>'sort', '');
  if s <> '' and exists (select 1 from information_schema.columns where table_schema='public' and table_name=p_res and column_name=ltrim(s, '-')) then
    ord := format('t.%I %s', ltrim(s, '-'), case when left(s, 1) = '-' then 'desc' else 'asc' end) || ', t.id desc';
  end if;
  lim := least(500, greatest(1, coalesce((p->>'limit')::int, 50)));
  off := greatest(0, coalesce((p->>'offset')::int, 0));
  execute format('select count(*) from public.%I t %s', p_res, case when cardinality(w) > 0 then 'where ' || array_to_string(w, ' and ') else '' end) into total;
  execute format('select coalesce(jsonb_agg(x), ''[]'') from (select %s as x from public.%I t %s %s order by %s limit %s offset %s) q',
    sel, p_res, joins, case when cardinality(w) > 0 then 'where ' || array_to_string(w, ' and ') else '' end, ord, lim, off) into rows;
  -- quitar geometrías pesadas y agregar conteo de adjuntos
  select coalesce(jsonb_agg(
    (e - 'geom' - 'geom_plano')
    || case when e ? 'geom' then jsonb_build_object('tiene_geom', (e->'geom') is not null and e->'geom' <> 'null') else '{}' end
    || jsonb_build_object('_adjuntos', (select count(*) from archivos a where a.entidad = p_res and a.entidad_id::text = e->>'id'))
  ), '[]') into rows from jsonb_array_elements(rows) e;
  return jsonb_build_object('rows', rows, 'total', total);
end $$;

create or replace function public.api_get(p_res text, p_id text) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r app.recursos := app.recurso(p_res); res jsonb;
begin
  perform app.can_read(r);
  execute format('select to_jsonb(t) from public.%I t where id::text = $1', p_res) into res using p_id;
  if res is null then perform app.err('Registro no encontrado', 'P0002'); end if;
  return res;
end $$;
