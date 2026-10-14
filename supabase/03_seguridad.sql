-- =====================================================================
-- EcoSnap · Base de datos en Supabase (PostgreSQL)
-- Archivo 3 de 3: seguridad (RLS, permisos y almacenamiento de fotos)
--
-- Requiere haber ejecutado antes 01_tablas.sql y 02_funciones.sql.
--
-- Supabase expone las tablas por una API pública protegida con la llave
-- anon. Sin estas reglas, cualquiera con la app podría leer o modificar
-- datos ajenos. Aquí se define qué puede hacer cada rol:
--   anon          → usuario sin sesión
--   authenticated → usuario con sesión iniciada (auth.uid() = su id)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Activar Row Level Security en las tres tablas
-- ---------------------------------------------------------------------
alter table public.canecas         enable row level security;
alter table public.usuarios        enable row level security;
alter table public.clasificaciones enable row level security;

-- ---------------------------------------------------------------------
-- 2. canecas: catálogo de solo lectura para todos
-- ---------------------------------------------------------------------
revoke all on public.canecas from anon, authenticated;
grant select on public.canecas to anon, authenticated;

drop policy if exists "canecas: lectura publica" on public.canecas;
create policy "canecas: lectura publica"
  on public.canecas for select
  to anon, authenticated
  using (true);

-- ---------------------------------------------------------------------
-- 3. usuarios
--    - Cualquier usuario con sesión ve los perfiles (lo necesita el ranking).
--    - Cada uno solo edita su nombre, carrera y foto. Los puntos y la racha
--      solo los cambia registrar_clasificacion().
--    - Nadie inserta ni borra por la API: el perfil lo crea el trigger y se
--      borra en cascada al eliminar la cuenta.
-- ---------------------------------------------------------------------
revoke all on public.usuarios from anon, authenticated;
grant select on public.usuarios to authenticated;
grant update (nombre, carrera, foto_url) on public.usuarios to authenticated;

drop policy if exists "usuarios: lectura con sesion" on public.usuarios;
create policy "usuarios: lectura con sesion"
  on public.usuarios for select
  to authenticated
  using (true);

drop policy if exists "usuarios: editar el propio perfil" on public.usuarios;
create policy "usuarios: editar el propio perfil"
  on public.usuarios for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------
-- 4. clasificaciones
--    - Cada usuario solo ve su propio historial.
--    - No se puede insertar, editar ni borrar directo: solo por la función.
-- ---------------------------------------------------------------------
revoke all on public.clasificaciones from anon, authenticated;
grant select on public.clasificaciones to authenticated;

drop policy if exists "clasificaciones: ver solo las propias" on public.clasificaciones;
create policy "clasificaciones: ver solo las propias"
  on public.clasificaciones for select
  to authenticated
  using (usuario_id = auth.uid());

-- ---------------------------------------------------------------------
-- 5. Funciones: solo usuarios con sesión pueden registrar clasificaciones
-- ---------------------------------------------------------------------
revoke all on function public.registrar_clasificacion(uuid, text, text, text, text, text[], integer)
  from public, anon;
grant execute on function public.registrar_clasificacion(uuid, text, text, text, text, text[], integer)
  to authenticated;

revoke all on function public.crear_perfil_usuario() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. Storage: bucket "residuos" para las fotos (HU-10)
--    - Público para lectura: la app muestra la miniatura con getPublicUrl().
--    - Cada usuario solo sube y borra dentro de su carpeta: <su id>/<archivo>.jpg
--    - Máximo 5 MB por foto y solo imágenes JPEG o PNG.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('residuos', 'residuos', true, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "residuos: subir a la carpeta propia" on storage.objects;
create policy "residuos: subir a la carpeta propia"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'residuos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "residuos: ver las propias" on storage.objects;
create policy "residuos: ver las propias"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'residuos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "residuos: borrar las propias" on storage.objects;
create policy "residuos: borrar las propias"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'residuos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
