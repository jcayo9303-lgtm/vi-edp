# Control de Producción de Viñedo

Sistema basado en `Propuesta_Control_Produccion_Vinedo.md`.

| Capa | Tecnología | Carpeta |
|---|---|---|
| Base de datos y lógica | **Supabase** (PostgreSQL 17): 59 tablas, 6 vistas, funciones `api_*`, RLS, Storage | `supabase/migrations/` |
| Frontend | Next.js 15 + React 19 + TypeScript + CSS vanilla, exportado como sitio estático | `web/` |
| Publicación | **Netlify** (estático) | `netlify.toml` |
| Alternativa local | API PHP 8 + MySQL (XAMPP), misma interfaz | `api/` |

## Cómo funciona

El navegador habla directo con Supabase:
- **Auth**: correo y contraseña (Supabase Auth). Cada usuario tiene un perfil con rol en `perfiles`.
- **Lectura**: cualquier usuario activo puede leer (RLS). Sin sesión no se lee nada.
- **Escritura**: solo a través de funciones `public.api_*` que validan el rol, aplican las reglas del documento (carencia, bruto − tara, lote de fabricante, campaña cerrada, etc.) y registran todo en la **bitácora**. Las tablas no aceptan escrituras directas.
- **Fotos, planos y respaldos**: Supabase Storage (buckets privados `archivos` y `respaldos`, con URLs firmadas).

## Desarrollo local

```bash
cd web
npm install
npm run dev
```
Requiere `web/.env.local` con:
```
NEXT_PUBLIC_SUPABASE_URL=https://<proyecto>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<publishable key>
```
Usuarios iniciales: ver `CREDENCIALES-SUPABASE.txt` (archivo local, no se sube a GitHub). Cambiar las contraseñas al entregar.

## Crear la base en otro proyecto Supabase

Ejecutar en el SQL Editor, en orden: `001_esquema.sql`, `002_vistas_y_nucleo.sql`, `003_reglas_y_guardado.sql`, `004_tablero_mapa_respaldos.sql`, `005_seguridad_storage.sql` y (opcional) `006_datos_ejemplo.sql`.
Luego `alter database postgres set timezone to 'America/La_Paz';` y crear el primer administrador:
```sql
select app.crear_usuario('admin@empresa.com', '<contraseña segura>', 'Administrador', 'admin');
```

## Publicar

1. **GitHub**: subir esta carpeta (`vinedo-control`) como repositorio.
2. **Netlify** → *Add new site* → *Import from Git* → elegir el repositorio. La configuración se toma de `netlify.toml` (base `web`, comando `npm run build`, carpeta `out`).
3. En Supabase → *Authentication → URL Configuration*, poner la URL de Netlify como *Site URL*.
