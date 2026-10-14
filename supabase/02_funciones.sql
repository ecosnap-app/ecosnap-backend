-- =====================================================================
-- EcoSnap · Base de datos en Supabase (PostgreSQL)
-- Archivo 2 de 3: funciones y triggers
--
-- Requiere haber ejecutado antes 01_tablas.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Crear el perfil automáticamente cuando alguien se registra (HU-01)
--
-- La app llama a supabase.auth.signUp({ email, password, options: { data: { nombre } } }).
-- Supabase inserta la cuenta en auth.users y este trigger crea la fila en
-- public.usuarios con el nombre que el usuario escribió.
-- ---------------------------------------------------------------------
create or replace function public.crear_perfil_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.usuarios (id, nombre)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'nombre'), ''), 'Estudiante')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists al_registrar_usuario on auth.users;
create trigger al_registrar_usuario
  after insert on auth.users
  for each row execute function public.crear_perfil_usuario();

-- ---------------------------------------------------------------------
-- 2. Registrar una clasificación (HU-10, HU-13, HU-14)
--
-- En una sola transacción:
--   a) guarda la clasificación en el historial,
--   b) suma los eco-puntos que corresponden a la caneca,
--   c) recalcula la racha diaria.
-- Si algo falla, no queda nada a medias.
--
-- Seguridad:
--   - Solo el propio usuario puede registrar a su nombre (p_usuario = auth.uid()).
--   - Los puntos los decide la base de datos según la caneca. El parámetro
--     p_puntos existe porque la app lo envía, pero se ignora: así nadie puede
--     sumarse puntos de más modificando la app.
--   - La racha usa la hora de Colombia (America/Bogota).
-- ---------------------------------------------------------------------
-- Si existe una versión anterior con otros parámetros, se borra primero.
-- Así nunca quedan dos funciones con el mismo nombre.
do $$
declare
  f regprocedure;
begin
  for f in
    select p.oid::regprocedure
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'registrar_clasificacion'
  loop
    execute 'drop function ' || f;
  end loop;
end;
$$;

create function public.registrar_clasificacion(
  p_usuario        uuid,
  p_foto           text,
  p_tipo           text,
  p_caneca         text,
  p_explicacion    text,
  p_instrucciones  text[],
  p_puntos         integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_puntos   smallint;
  v_hoy      date := (now() at time zone 'America/Bogota')::date;
  v_ultima   date;
  v_racha    integer;
  v_id       uuid;
begin
  if auth.uid() is null or p_usuario is distinct from auth.uid() then
    raise exception 'No autorizado: solo puedes registrar clasificaciones propias'
      using errcode = '42501';
  end if;

  select puntos into v_puntos from public.canecas where id = p_caneca;
  if v_puntos is null then
    raise exception 'Caneca inválida: %', p_caneca using errcode = '22023';
  end if;

  -- Bloquea la fila del usuario para que dos guardados simultáneos no
  -- calculen la racha con el mismo valor viejo
  select ultima_clasificacion, racha_actual
    into v_ultima, v_racha
    from public.usuarios
   where id = p_usuario
     for update;

  if not found then
    raise exception 'El perfil del usuario no existe' using errcode = 'P0002';
  end if;

  insert into public.clasificaciones
    (usuario_id, caneca, tipo_residuo, explicacion, instrucciones, foto_url, puntos)
  values
    (p_usuario, p_caneca, p_tipo, coalesce(p_explicacion, ''),
     coalesce(p_instrucciones, '{}'), coalesce(p_foto, ''), v_puntos)
  returning id into v_id;

  v_racha := case
    when v_ultima = v_hoy     then v_racha        -- ya clasificó hoy: no cambia
    when v_ultima = v_hoy - 1 then v_racha + 1    -- clasificó ayer: sigue la racha
    else 1                                        -- primera vez o la perdió
  end;

  update public.usuarios
     set eco_puntos           = eco_puntos + v_puntos,
         racha_actual         = v_racha,
         racha_mejor          = greatest(racha_mejor, v_racha),
         ultima_clasificacion = v_hoy
   where id = p_usuario;

  return v_id;
end;
$$;

comment on function public.registrar_clasificacion(uuid, text, text, text, text, text[], integer) is
  'Guarda una clasificación, suma puntos según la caneca y actualiza la racha, todo en una transacción.';
