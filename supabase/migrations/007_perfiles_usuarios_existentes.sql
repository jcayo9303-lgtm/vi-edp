-- Recupera los perfiles de usuarios que ya existen en Supabase Auth
-- (útil si el esquema public fue reinstalado y auth.users se conservó)
insert into public.perfiles (id, nombre, email, rol)
select u.id, coalesce(u.raw_user_meta_data->>'nombre', split_part(u.email, '@', 1)), u.email,
       coalesce(nullif(u.raw_user_meta_data->>'rol', ''), 'consulta')::e_perfiles_rol
from auth.users u
on conflict (id) do nothing;
