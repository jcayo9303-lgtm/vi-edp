-- =====================================================================
-- Seguridad: RLS, permisos y Storage
-- Lectura: cualquier usuario activo. Escritura: SOLO a través de las
-- funciones public.api_* (que validan rol, reglas y registran la bitácora).
-- =====================================================================
do $$
declare t text;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r' loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists lectura on public.%I', t);
    if t = 'respaldos' then
      execute format('create policy lectura on public.%I for select to authenticated using (app.rol_actual() in (''admin'',''gerencia''))', t);
    else
      execute format('create policy lectura on public.%I for select to authenticated using (app.rol_actual() is not null)', t);
    end if;
    execute format('revoke insert, update, delete, truncate on public.%I from anon, authenticated', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end $$;

revoke all on all sequences in schema public from anon;

-- Funciones: nada para anónimos; solo api_* para usuarios autenticados
revoke execute on all functions in schema public from public, anon;
revoke execute on all functions in schema app from public, anon;
grant execute on function app.rol_actual() to authenticated;
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like 'api\_%' loop
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;
alter default privileges in schema public revoke execute on functions from public, anon;

-- ---------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('archivos', 'archivos', false, 15728640, array['image/jpeg','image/png','image/webp','image/gif','application/pdf',
     'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.openxmlformats-officedocument.wordprocessingml.document','text/csv','text/plain']),
  ('respaldos', 'respaldos', false, 52428800, array['application/json'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "archivos lectura" on storage.objects;
drop policy if exists "archivos subir" on storage.objects;
drop policy if exists "archivos borrar" on storage.objects;
drop policy if exists "respaldos lectura" on storage.objects;
drop policy if exists "respaldos subir" on storage.objects;
drop policy if exists "respaldos borrar" on storage.objects;

create policy "archivos lectura" on storage.objects for select to authenticated
  using (bucket_id = 'archivos' and app.rol_actual() is not null);
create policy "archivos subir" on storage.objects for insert to authenticated
  with check (bucket_id = 'archivos' and app.rol_actual() is not null and app.rol_actual() <> 'consulta');
create policy "archivos borrar" on storage.objects for delete to authenticated
  using (bucket_id = 'archivos' and app.rol_actual() is not null and app.rol_actual() <> 'consulta');

create policy "respaldos lectura" on storage.objects for select to authenticated
  using (bucket_id = 'respaldos' and app.rol_actual() in ('admin','gerencia'));
create policy "respaldos subir" on storage.objects for insert to authenticated
  with check (bucket_id = 'respaldos' and app.rol_actual() = 'admin');
create policy "respaldos borrar" on storage.objects for delete to authenticated
  using (bucket_id = 'respaldos' and app.rol_actual() = 'admin');
