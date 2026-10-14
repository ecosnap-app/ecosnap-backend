-- =====================================================================
-- EcoSnap · Base de datos en Supabase (PostgreSQL)
-- Archivo 1 de 3: tablas, catálogo de canecas e índices
--
-- Cómo se ejecuta: Supabase → SQL Editor → New query → pegar todo → Run.
-- Orden obligatorio: 01_tablas.sql → 02_funciones.sql → 03_seguridad.sql
--
-- Las cuentas de usuario (correo y contraseña) no se guardan aquí: las
-- maneja Supabase Auth en la tabla auth.users. Este esquema guarda el
-- perfil y la actividad de cada usuario y se enlaza con auth.users por id.
-- =====================================================================

-- ---------------------------------------------------------------------
-- canecas: catálogo del código de colores (Resolución 2184 de 2019)
-- Es la única fuente de verdad de cuántos puntos da cada tipo de residuo.
-- ---------------------------------------------------------------------
create table if not exists public.canecas (
  id              text        primary key
                              check (id in ('blanca', 'negra', 'verde', 'especial')),
  nombre          text        not null,
  color_hex       char(7)     not null check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  descripcion     text        not null,
  ejemplos        text[]      not null default '{}',
  puntos          smallint    not null check (puntos > 0),
  es_aprovechable boolean     not null
);

comment on table public.canecas is
  'Catálogo de canecas del código de colores colombiano. Define los puntos por tipo de residuo.';

insert into public.canecas (id, nombre, color_hex, descripcion, ejemplos, puntos, es_aprovechable)
values
  ('blanca',   'Caneca blanca',                 '#E7E4DA',
   'Residuos aprovechables, limpios y secos.',
   array['Botellas PET', 'Latas', 'Cartón', 'Vidrio', 'Papel'], 10, true),
  ('negra',    'Caneca negra',                  '#33332F',
   'Residuos no aprovechables o sucios.',
   array['Servilletas usadas', 'Papel higiénico', 'Icopor contaminado', 'Empaques metalizados'], 10, false),
  ('verde',    'Caneca verde',                  '#4F9A54',
   'Residuos orgánicos aprovechables.',
   array['Cáscaras de fruta', 'Restos de comida', 'Residuos de jardín'], 10, true),
  ('especial', 'Punto de recolección especial', '#C96A34',
   'Residuos peligrosos que no van en ninguna caneca común.',
   array['Pilas', 'Medicamentos vencidos', 'Bombillos', 'Aparatos electrónicos'], 15, false)
on conflict (id) do update
  set nombre          = excluded.nombre,
      color_hex       = excluded.color_hex,
      descripcion     = excluded.descripcion,
      ejemplos        = excluded.ejemplos,
      puntos          = excluded.puntos,
      es_aprovechable = excluded.es_aprovechable;

-- ---------------------------------------------------------------------
-- usuarios: perfil público y acumulados de gamificación (1 a 1 con auth.users)
-- ---------------------------------------------------------------------
create table if not exists public.usuarios (
  id                   uuid        primary key
                                   references auth.users (id) on delete cascade,
  nombre               text        not null default 'Estudiante'
                                   check (char_length(nombre) between 1 and 80),
  carrera              text        check (char_length(carrera) <= 120),
  foto_url             text,
  eco_puntos           integer     not null default 0 check (eco_puntos >= 0),
  racha_actual         integer     not null default 0 check (racha_actual >= 0),
  racha_mejor          integer     not null default 0 check (racha_mejor >= 0),
  ultima_clasificacion date,
  creado_en            timestamptz not null default now(),
  constraint racha_mejor_cubre_actual check (racha_mejor >= racha_actual)
);

comment on table public.usuarios is
  'Perfil de cada estudiante. Se crea solo al registrarse (trigger en auth.users).';

-- El ranking ordena por puntos y cuenta cuántos tienen más que uno
create index if not exists usuarios_eco_puntos_idx
  on public.usuarios (eco_puntos desc);

-- ---------------------------------------------------------------------
-- clasificaciones: cada residuo que la IA identificó y el usuario guardó
-- ---------------------------------------------------------------------
create table if not exists public.clasificaciones (
  id            uuid        primary key default gen_random_uuid(),
  usuario_id    uuid        not null
                            references public.usuarios (id) on delete cascade,
  caneca        text        not null
                            references public.canecas (id),
  tipo_residuo  text        not null check (char_length(tipo_residuo) between 1 and 120),
  explicacion   text        not null default '',
  instrucciones text[]      not null default '{}',
  foto_url      text        not null default '',
  puntos        smallint    not null check (puntos >= 0),
  creado_en     timestamptz not null default now()
);

comment on table public.clasificaciones is
  'Historial de clasificaciones. Solo se inserta por medio de registrar_clasificacion().';

-- El historial pide las de un usuario, de la más reciente a la más antigua
create index if not exists clasificaciones_usuario_fecha_idx
  on public.clasificaciones (usuario_id, creado_en desc);

-- Las estadísticas de impacto cuentan por caneca
create index if not exists clasificaciones_usuario_caneca_idx
  on public.clasificaciones (usuario_id, caneca);
