-- =====================================================================
-- Guardado / eliminación genéricos + reglas de negocio (sección 6)
-- =====================================================================
create or replace function app.n(v jsonb) returns numeric language sql immutable as $$
  select coalesce(nullif(v #>> '{}', '')::numeric, 0)
$$;

create or replace function app.check_campana(p jsonb) returns void language plpgsql stable as $$
begin
  if coalesce(p->>'campana_id', '') <> '' and (select estado from campanas where id = (p->>'campana_id')::int) = 'cerrada' then
    perform app.err('La campaña está cerrada: ya no se puede modificar (P-16)');
  end if;
end $$;

create or replace function app.parcela_of(p_res text, p jsonb) returns int language sql stable as $$
  select case
    when coalesce(p->>'parcela_id', '') <> '' then (p->>'parcela_id')::int
    when p_res = 'parcelas' then (p->>'id')::int
    when coalesce(p->>'plantacion_id', '') <> '' then (select parcela_id from plantaciones where id = (p->>'plantacion_id')::int)
  end
$$;

-- ---------------------------------------------------------------------
-- Costos automáticos y recálculos
-- ---------------------------------------------------------------------
create or replace function app.sync_costo(p_origen text, p_ref int, p_camp int, p_parcela int, p_fecha date, p_cat int, p_monto numeric, p_desc text)
returns void language plpgsql as $$
begin
  delete from costos_parcela where origen = p_origen::e_costos_parcela_origen and referencia_id = p_ref;
  if p_monto > 0 then
    insert into costos_parcela (campana_id, parcela_id, fecha, tipo, categoria_id, descripcion, origen, referencia_id, monto)
    values (p_camp, p_parcela, p_fecha, 'variable', p_cat, p_desc, p_origen::e_costos_parcela_origen, p_ref, round(p_monto, 2));
  end if;
end $$;

-- Bruto − tara = neto; reparte el neto por parcela según baldes y calcula kg/balde real
create or replace function app.recompute_viaje(p_viaje int) returns void language plpgsql as $$
declare v viajes_camion; baldes int; kgb numeric;
begin
  select * into v from viajes_camion where id = p_viaje;
  if v.id is null then return; end if;
  select coalesce(sum(vp.baldes), 0) into baldes from viaje_parcelas vp where viaje_id = p_viaje;
  if baldes = 0 then select coalesce(sum(cantidad_baldes), 0) into baldes from cosecha_baldes where viaje_id = p_viaje; end if;
  kgb := case when baldes > 0 then round(coalesce(v.peso_neto_kg, 0) / baldes, 3) else 0 end;
  update viajes_camion set total_baldes = baldes, kg_por_balde_real = kgb where id = p_viaje;
  update viaje_parcelas set kg_asignados = round(viaje_parcelas.baldes * kgb, 2) where viaje_id = p_viaje;
  if baldes > 0 and (kgb < 14 or kgb > 22) then
    perform app.warn(format('Kg por balde fuera de rango: %s kg (esperado 14–22)', kgb));
  end if;
end $$;

-- Dosis por ha y por planta, fin de carencia y reingreso, costo de agroquímicos
create or replace function app.recompute_aplicacion(p_aid int) returns void language plpgsql as $$
declare a record; sup numeric; pl numeric; car int; rei int; monto numeric;
begin
  select ap.*, oa.parcela_id, oa.campana_id into a from aplicaciones ap join ordenes_aplicacion oa on oa.id = ap.orden_aplicacion_id where ap.id = p_aid;
  if a.id is null then return; end if;
  sup := coalesce(nullif(a.superficie_aplicada_ha, 0), 1);
  pl := coalesce(nullif(a.plantas_tratadas, 0), 1);
  update aplicacion_productos set cantidad_por_ha = round(cantidad_aplicada / sup, 4), cantidad_por_planta = round(cantidad_aplicada * 1000 / pl, 6) where aplicacion_id = p_aid;
  select coalesce(max(p.carencia_dias), 0), coalesce(max(p.reingreso_horas), 0) into car, rei
  from aplicacion_productos x join productos p on p.id = x.producto_id where x.aplicacion_id = p_aid;
  update aplicaciones set fecha_fin_carencia = fecha + car,
         fecha_reingreso = (fecha + coalesce(hora_fin, time '18:00'))::timestamp at time zone 'America/La_Paz' + make_interval(hours => rei)
  where id = p_aid;
  select coalesce(sum(x.cantidad_aplicada * coalesce((select avg(m.costo_unitario) from almacen_movimientos m where m.producto_id = x.producto_id and m.tipo = 'ingreso'), 0)), 0)
    into monto from aplicacion_productos x where x.aplicacion_id = p_aid;
  perform app.sync_costo('aplicacion', p_aid, a.campana_id, a.parcela_id, a.fecha, 13, monto, 'Aplicación de agroquímicos');
end $$;

-- ---------------------------------------------------------------------
-- Reglas ANTES de guardar: devuelve los datos ajustados
-- ---------------------------------------------------------------------
create or replace function app.hook_before(p_res text, d jsonb, o jsonb) returns jsonb language plpgsql as $$
declare
  m jsonb := coalesce(o, '{}') || d;
  x numeric; y numeric; i int; t text; car date; p parcelas; oa ordenes_aplicacion;
begin
  case p_res
  when 'parcelas' then
    if coalesce(m->>'plantas_teoricas', '') = '' and app.n(m->'superficie_ha') > 0 and app.n(m->'marco_entre_hileras_m') > 0 and app.n(m->'marco_entre_plantas_m') > 0 then
      d := d || jsonb_build_object('plantas_teoricas', round(app.n(m->'superficie_ha') * 10000 / (app.n(m->'marco_entre_hileras_m') * app.n(m->'marco_entre_plantas_m'))));
    end if;
  when 'plantaciones' then
    if coalesce(m->>'anio_plantacion', '') <> '' and coalesce(m->>'variedad_id', '') <> '' then
      select vida_util_anios into i from variedades where id = (m->>'variedad_id')::int;
      if i is not null then d := d || jsonb_build_object('fecha_fin_vida_estimada', make_date((m->>'anio_plantacion')::int + i, 6, 30)); end if;
    end if;
  when 'seguimiento_formacion' then
    select plantas_iniciales into i from plantaciones where id = (m->>'plantacion_id')::int;
    if coalesce(i, 0) > 0 and coalesce(m->>'plantas_vivas', '') <> '' then
      x := round(app.n(m->'plantas_vivas') / i * 100, 2);
      d := d || jsonb_build_object('pct_prendimiento', x);
      if x < 95 then perform app.warn('Prendimiento bajo la meta de 95 %'); end if;
    end if;
  when 'ordenes_trabajo' then
    if o is null and coalesce(d->>'numero', '') = '' then
      t := to_char(current_date, 'YYYY');
      select count(*) + 1 into i from ordenes_trabajo where numero like 'OT-' || t || '-%';
      d := d || jsonb_build_object('numero', format('OT-%s-%s', t, lpad(i::text, 4, '0')));
    end if;
  when 'poda_registros' then
    d := d || jsonb_build_object('importe', round(app.n(m->'plantas_podadas') * app.n(m->'tarifa_planta'), 2));
    select sum(vivas) into x from v_plantas_vigentes where parcela_id = (m->>'parcela_id')::int and campana_id = (m->>'campana_id')::int;
    select coalesce(sum(plantas_podadas), 0) into y from poda_registros where parcela_id = (m->>'parcela_id')::int and campana_id = (m->>'campana_id')::int and id::text <> coalesce(o->>'id', '0');
    if x is not null and y + app.n(m->'plantas_podadas') > x then perform app.warn('Plantas podadas superan las plantas del censo'); end if;
  when 'cosecha_jornadas' then
    select max(a.fecha_fin_carencia) into car from aplicaciones a join ordenes_aplicacion oa2 on oa2.id = a.orden_aplicacion_id where oa2.parcela_id = (m->>'parcela_id')::int;
    if car is not null and car > coalesce((m->>'fecha')::date, current_date) then
      perform app.err(format('Parcela con carencia vigente hasta %s: no se puede cosechar (regla 1)', car));
    end if;
    if not exists (select 1 from muestreos_madurez mm join plantaciones pl on pl.id = mm.plantacion_id
                   where pl.parcela_id = (m->>'parcela_id')::int and mm.campana_id = (m->>'campana_id')::int and mm.apta_cosecha) then
      perform app.warn('Sin control de madurez apto registrado para esta parcela (regla 12)');
    end if;
  when 'viajes_camion' then
    if coalesce(m->>'tara_kg', '') = '' and coalesce(m->>'vehiculo_id', '') <> '' then
      select tara_kg into x from vehiculos where id = (m->>'vehiculo_id')::int;
      d := d || jsonb_build_object('tara_kg', x);
      m := m || jsonb_build_object('tara_kg', x);
    end if;
    d := d || jsonb_build_object('peso_neto_kg', greatest(0, app.n(m->'peso_bruto_kg') - app.n(m->'tara_kg')));
  when 'aplicaciones' then
    select * into oa from ordenes_aplicacion where id = (m->>'orden_aplicacion_id')::int;
    if oa.id is null then perform app.err('No se aplica sin orden de aplicación emitida (regla 2)'); end if;
    if coalesce(m->>'plantas_tratadas', '') = '' then
      select sum(vivas) into x from v_plantas_vigentes where parcela_id = oa.parcela_id and campana_id = oa.campana_id;
      if x is null then select plantas_teoricas into x from parcelas where id = oa.parcela_id; end if;
      d := d || jsonb_build_object('plantas_tratadas', x);
    end if;
  when 'aplicacion_productos' then
    if coalesce(m->>'lote_fabricante', '') = '' then perform app.err('Todo producto aplicado lleva lote de fabricante (regla 3)'); end if;
  when 'estimaciones' then
    if coalesce(m->>'plantas_productivas', '') = '' then
      select sum(productivas) into x from v_plantas_vigentes where plantacion_id = (m->>'plantacion_id')::int and campana_id = (m->>'campana_id')::int;
      d := d || jsonb_build_object('plantas_productivas', x);
      m := m || jsonb_build_object('plantas_productivas', x);
    end if;
    d := d || jsonb_build_object('kg_estimados', round(app.n(m->'plantas_productivas') * app.n(m->'racimos_por_planta') * app.n(m->'peso_racimo_kg') * (1 - app.n(m->'ajuste_dano_pct') / 100), 2));
  when 'conteo_yemas' then
    if app.n(m->'yemas_dejadas_poda') > 0 then
      d := d || jsonb_build_object(
        'pct_desborre', round(app.n(m->'yemas_brotadas') / app.n(m->'yemas_dejadas_poda') * 100, 2),
        'fertilidad_practica', round(app.n(m->'inflorescencias') / app.n(m->'yemas_dejadas_poda'), 2),
        'ventanas', greatest(0, app.n(m->'yemas_dejadas_poda') - app.n(m->'yemas_brotadas')));
    end if;
    if app.n(m->'yemas_brotadas') > 0 then d := d || jsonb_build_object('fertilidad_potencial', round(app.n(m->'inflorescencias') / app.n(m->'yemas_brotadas'), 2)); end if;
  when 'analisis_suelo' then
    if coalesce(m->>'n_recomendado_kg_ha', '') <> '' and app.n(m->'n_recomendado_kg_ha') not between 80 and 120 then perform app.warn('N fuera del rango 80–120 kg/ha (regla 11)'); end if;
    if coalesce(m->>'p2o5_recomendado_kg_ha', '') <> '' and app.n(m->'p2o5_recomendado_kg_ha') not between 30 and 50 then perform app.warn('P₂O₅ fuera del rango 30–50 kg/ha (regla 11)'); end if;
    if coalesce(m->>'k2o_recomendado_kg_ha', '') <> '' and app.n(m->'k2o_recomendado_kg_ha') not between 100 and 180 then perform app.warn('K₂O fuera del rango 100–180 kg/ha (regla 11)'); end if;
  when 'validaciones_parcela' then
    select * into p from parcelas where id = (m->>'parcela_id')::int;
    if p.id is not null then
      if coalesce(m->>'plantas_teoricas', '') = '' then d := d || jsonb_build_object('plantas_teoricas', p.plantas_teoricas); m := m || jsonb_build_object('plantas_teoricas', p.plantas_teoricas); end if;
      if coalesce(m->>'plantas_censadas', '') = '' then
        select sum(vivas) into x from v_plantas_vigentes where parcela_id = p.id and campana_id = (m->>'campana_id')::int;
        d := d || jsonb_build_object('plantas_censadas', x); m := m || jsonb_build_object('plantas_censadas', x);
      end if;
      if app.n(m->'plantas_teoricas') > 0 then
        x := round((app.n(m->'plantas_teoricas') - app.n(m->'plantas_censadas')) / app.n(m->'plantas_teoricas') * 100, 2);
        d := d || jsonb_build_object('pct_fallas', x);
        if x > 10 then perform app.warn('Diferencia de densidad mayor a 10 %: revisar censo (regla 10)'); end if;
      end if;
      if app.n(m->'superficie_medida_ha') > 0 and coalesce(p.superficie_ha, 0) > 0 and abs(app.n(m->'superficie_medida_ha') - p.superficie_ha) / p.superficie_ha > 0.05 then
        perform app.warn('Superficie medida difiere más de 5 % de la declarada (P-01)');
      end if;
    end if;
  when 'liquidacion_personal' then
    d := d || jsonb_build_object('importe_neto', round(app.n(m->'importe_bruto') - app.n(m->'anticipos'), 2));
    if o is not null and d ? 'estado' and d->>'estado' <> o->>'estado' and d->>'estado' <> 'borrador' then
      if o->>'estado' = 'pagada' then perform app.err('Una liquidación pagada no se puede modificar'); end if;
      d := d || jsonb_build_object('fecha_aprobacion', now());
    end if;
  when 'liquidacion_produccion' then
    select * into p from parcelas where id = (m->>'parcela_id')::int;
    if p.id is not null and not coalesce(p.validada, false) then perform app.err('Solo se liquidan parcelas validadas (regla 8)'); end if;
    if coalesce(m->>'kg_netos', '') = '' or app.n(m->'kg_netos') = 0 then
      select coalesce(sum(kg_netos), 0) into x from v_kg_parcela where parcela_id = p.id and campana_id = (m->>'campana_id')::int;
      d := d || jsonb_build_object('kg_netos', x); m := m || jsonb_build_object('kg_netos', x);
    end if;
    if coalesce(m->>'plantas_productivas', '') = '' then
      select sum(productivas) into x from v_plantas_vigentes where parcela_id = p.id and campana_id = (m->>'campana_id')::int;
      d := d || jsonb_build_object('plantas_productivas', x); m := m || jsonb_build_object('plantas_productivas', x);
    end if;
    if app.n(m->'plantas_productivas') > 0 then d := d || jsonb_build_object('kg_por_planta', round(app.n(m->'kg_netos') / app.n(m->'plantas_productivas'), 3)); end if;
    if coalesce(p.superficie_ha, 0) > 0 then d := d || jsonb_build_object('kg_por_ha', round(app.n(m->'kg_netos') / p.superficie_ha, 2)); end if;
    d := d || jsonb_build_object('importe_liquidar', round(app.n(m->'kg_netos') * app.n(m->'precio_kg') - app.n(m->'descuentos_calidad') - app.n(m->'costos_descontables'), 2));
  when 'costos_parcela' then
    if app.n(m->'monto') = 0 and app.n(m->'cantidad') > 0 then d := d || jsonb_build_object('monto', round(app.n(m->'cantidad') * app.n(m->'costo_unitario'), 2)); end if;
  when 'ventas_uva' then
    d := d || jsonb_build_object('importe', round(app.n(m->'kg') * app.n(m->'precio_kg'), 2));
  else null;
  end case;
  return d;
end $$;

-- Reglas DESPUÉS de guardar
create or replace function app.hook_after(p_res text, p_id int) returns void language plpgsql as $$
declare r record;
begin
  case p_res
  when 'poda_registros' then
    select * into r from poda_registros where id = p_id;
    perform app.sync_costo('poda', p_id, r.campana_id, r.parcela_id, r.fecha, 10, coalesce(r.importe, 0), format('Poda: %s plantas', r.plantas_podadas));
  when 'labores' then
    select * into r from labores where id = p_id;
    perform app.sync_costo('labor', p_id, r.campana_id, r.parcela_id, r.fecha, case when r.tipo = 'riego' then 18 else 11 end, coalesce(r.costo, 0), 'Labor: ' || r.tipo);
  when 'viajes_camion' then perform app.recompute_viaje(p_id);
  when 'viaje_parcelas' then perform app.recompute_viaje((select viaje_id from viaje_parcelas where id = p_id));
  when 'aplicaciones' then
    perform app.recompute_aplicacion(p_id);
    update ordenes_aplicacion set estado = 'aplicada' where id = (select orden_aplicacion_id from aplicaciones where id = p_id);
  when 'aplicacion_productos' then perform app.recompute_aplicacion((select aplicacion_id from aplicacion_productos where id = p_id));
  when 'validaciones_parcela' then
    select * into r from validaciones_parcela where id = p_id;
    update parcelas set validada = (r.resultado = 'aprobada'), fecha_ultima_validacion = r.fecha where id = r.parcela_id;
  else null;
  end case;
end $$;

-- ---------------------------------------------------------------------
-- Usuarios (Supabase Auth)
-- ---------------------------------------------------------------------
create or replace function app.crear_usuario(p_email text, p_password text, p_nombre text, p_rol text) returns uuid
language plpgsql security definer set search_path = public, auth, extensions as $$
declare uid uuid := gen_random_uuid();
begin
  if exists (select 1 from auth.users where lower(email) = lower(p_email)) then perform app.err('Ya existe un usuario con ese correo'); end if;
  if length(coalesce(p_password, '')) < 8 then perform app.err('La contraseña debe tener al menos 8 caracteres'); end if;
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                          created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', lower(p_email), extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
          '{"provider":"email","providers":["email"]}', jsonb_build_object('nombre', p_nombre, 'rol', p_rol), now(), now(), '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), uid, uid::text, jsonb_build_object('sub', uid::text, 'email', lower(p_email), 'email_verified', true), 'email', now(), now(), now());
  return uid;
end $$;

-- Perfil automático para usuarios creados desde el panel de Supabase
create or replace function app.on_auth_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, nombre, email, rol)
  values (new.id, coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email, '@', 1)), new.email,
          coalesce(nullif(new.raw_user_meta_data->>'rol', ''), 'consulta')::e_perfiles_rol)
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function app.on_auth_user();

-- ---------------------------------------------------------------------
-- API: guardar y eliminar
-- ---------------------------------------------------------------------
create or replace function public.api_save(p_res text, p_id text, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r app.recursos := app.recurso(p_res);
  u public.perfiles;
  o jsonb; d jsonb := '{}'; nw jsonb; k text; v jsonb; f jsonb; flds jsonb := app.fields(p_res);
  cols text; sets text; new_id text; warnings jsonb; uid uuid;
begin
  perform set_config('app.warnings', '[]', true);
  u := app.can_write(r);
  if p_id is not null and p_id <> '' then
    execute format('select to_jsonb(t) from public.%I t where id::text = $1', p_res) into o using p_id;
    if o is null then perform app.err('Registro no encontrado', 'P0002'); end if;
  else p_id := null;
  end if;
  -- limpiar: solo columnas editables, '' → null
  for k, v in select * from jsonb_each(coalesce(p_data, '{}')) loop
    if exists (select 1 from jsonb_array_elements(flds) e where e->>'name' = k) then
      d := d || jsonb_build_object(k, case when v = '""'::jsonb then 'null'::jsonb else v end);
    end if;
  end loop;

  -- Usuarios: altas y contraseñas vía Supabase Auth
  if p_res = 'perfiles' then
    if p_id is null then
      uid := app.crear_usuario(d->>'email', p_data->>'password', coalesce(d->>'nombre', d->>'email'), coalesce(d->>'rol', 'consulta'));
      p_id := uid::text;
      o := (select to_jsonb(t) from perfiles t where id = uid);
    elsif coalesce(p_data->>'password', '') <> '' then
      if length(p_data->>'password') < 8 then perform app.err('La contraseña debe tener al menos 8 caracteres'); end if;
      update auth.users set encrypted_password = extensions.crypt(p_data->>'password', extensions.gen_salt('bf')), updated_at = now() where id = p_id::uuid;
    end if;
    d := d - 'email';
  end if;

  if p_res <> 'campanas' then
    if o is not null then perform app.check_campana(o); end if;
    perform app.check_campana(coalesce(o, '{}') || d);
  end if;
  d := app.hook_before(p_res, d, o);
  -- obligatorios
  for f in select * from jsonb_array_elements(flds) loop
    if (f->>'required')::boolean and coalesce((coalesce(o, '{}') || d)->>(f->>'name'), '') = '' then
      perform app.err('Falta completar: ' || replace(f->>'name', '_', ' '));
    end if;
  end loop;
  if d = '{}'::jsonb and o is null then perform app.err('No hay datos para guardar'); end if;

  if d <> '{}'::jsonb then
    select string_agg(format('%I', key), ', '), string_agg(format('%I = r.%I', key, key), ', ') into cols, sets from jsonb_object_keys(d) key;
    if p_id is null then
      execute format('insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I, $1) returning id::text', p_res, cols, cols, p_res) into new_id using d;
      p_id := new_id;
    else
      execute format('update public.%I t set %s from jsonb_populate_record(null::public.%I, $1) r where t.id::text = $2', p_res, sets, p_res) using d, p_id;
    end if;
  end if;
  if p_res <> 'perfiles' then perform app.hook_after(p_res, p_id::int); end if;
  execute format('select to_jsonb(t) from public.%I t where id::text = $1', p_res) into nw using p_id;
  warnings := coalesce(nullif(current_setting('app.warnings', true), '')::jsonb, '[]');
  perform app.audit(case when o is null then 'crear' else 'editar' end, p_res, case when p_res = 'perfiles' then null else p_id::int end, app.parcela_of(p_res, nw),
    format('%s %s #%s%s', case when o is null then 'Creó' else 'Editó' end, replace(p_res, '_', ' '), case when p_res = 'perfiles' then nw->>'email' else p_id end,
           case when jsonb_array_length(warnings) > 0 then ' · ' || (select string_agg(x, '; ') from jsonb_array_elements_text(warnings) x) else '' end),
    case when o is null then null else (select jsonb_object_agg(key, o->key) from jsonb_object_keys(d) key) end,
    case when o is null then nw else (select jsonb_object_agg(key, nw->key) from jsonb_object_keys(d) key) end);
  return jsonb_build_object('row', nw, 'warnings', warnings);
end $$;

create or replace function public.api_delete(p_res text, p_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r app.recursos := app.recurso(p_res); o jsonb; rutas jsonb;
begin
  perform app.can_write(r);
  execute format('select to_jsonb(t) from public.%I t where id::text = $1', p_res) into o using p_id;
  if o is null then perform app.err('Registro no encontrado', 'P0002'); end if;
  if p_res <> 'campanas' then perform app.check_campana(o); end if;
  if p_res = 'perfiles' then
    if p_id::uuid = auth.uid() then perform app.err('No puede eliminar su propio usuario'); end if;
    delete from auth.users where id = p_id::uuid;
  else
    begin
      execute format('delete from public.%I where id::text = $1', p_res) using p_id;
    exception when foreign_key_violation then
      perform app.err('No se puede eliminar: hay otros registros que dependen de este', '23503');
    end;
  end if;
  if p_res = 'viaje_parcelas' then perform app.recompute_viaje((o->>'viaje_id')::int); end if;
  if p_res = 'aplicacion_productos' then perform app.recompute_aplicacion((o->>'aplicacion_id')::int); end if;
  if p_res in ('poda_registros','labores') then delete from costos_parcela where origen::text = case when p_res = 'poda_registros' then 'poda' else 'labor' end and referencia_id = p_id::int; end if;
  select coalesce(jsonb_agg(ruta), '[]') into rutas from archivos where entidad = p_res and entidad_id::text = p_id;
  delete from archivos where entidad = p_res and entidad_id::text = p_id;
  perform app.audit('eliminar', p_res, case when p_res = 'perfiles' then null else p_id::int end, app.parcela_of(p_res, o),
    format('Eliminó %s #%s', replace(p_res, '_', ' '), coalesce(o->>'email', p_id)), o, null);
  return jsonb_build_object('ok', true, 'rutas', rutas);   -- el cliente borra esos archivos del Storage
end $$;
