# Diccionario de datos · EcoSnap

Base de datos PostgreSQL en Supabase, esquema `public`. Las definiciones exactas están en [`supabase/`](../../supabase).
Convenciones: PK = llave primaria, FK = llave foránea, UK = valor único. "Nulo: No" significa que el campo es obligatorio.

## 1. Tabla `usuarios`

Perfil del estudiante y acumulados de gamificación. Una fila por cada cuenta de Supabase Auth.

| Campo | Tipo | Nulo | Por defecto | Restricciones | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | No | — | PK · FK → `auth.users.id` (borrado en cascada) | Identificador del usuario. Es el mismo id de su cuenta. |
| `nombre` | `text` | No | `'Estudiante'` | Entre 1 y 80 caracteres | Nombre que muestra la app en Inicio, Perfil y Ranking. |
| `carrera` | `text` | Sí | `null` | Máximo 120 caracteres | Programa académico del estudiante. |
| `foto_url` | `text` | Sí | `null` | — | URL de la foto de perfil. |
| `eco_puntos` | `integer` | No | `0` | `>= 0` | Puntos acumulados. Solo los modifica `registrar_clasificacion()`. |
| `racha_actual` | `integer` | No | `0` | `>= 0` | Días seguidos con al menos una clasificación. |
| `racha_mejor` | `integer` | No | `0` | `>= 0` · `>= racha_actual` | La racha más larga que ha tenido. |
| `ultima_clasificacion` | `date` | Sí | `null` | — | Día (hora de Colombia) de la última clasificación. Sirve para calcular la racha. |
| `creado_en` | `timestamptz` | No | `now()` | — | Fecha y hora de registro. |

**Índices:** PK sobre `id`; `usuarios_eco_puntos_idx` sobre `eco_puntos desc` (ranking).
**Cómo se crea:** automáticamente con el trigger `al_registrar_usuario` cuando alguien se registra.

## 2. Tabla `canecas`

Catálogo del código de colores colombiano (Resolución 2184 de 2019). Tiene 4 filas fijas.

| Campo | Tipo | Nulo | Por defecto | Restricciones | Descripción |
|---|---|---|---|---|---|
| `id` | `text` | No | — | PK · solo `blanca`, `negra`, `verde` o `especial` | Código de la caneca. Es el mismo valor que devuelve la IA. |
| `nombre` | `text` | No | — | — | Nombre para mostrar, por ejemplo "Caneca blanca". |
| `color_hex` | `char(7)` | No | — | Formato `#RRGGBB` | Color con el que la app pinta la caneca. |
| `descripcion` | `text` | No | — | — | Qué tipo de residuos recibe. |
| `ejemplos` | `text[]` | No | `'{}'` | — | Lista de residuos de ejemplo para la guía. |
| `puntos` | `smallint` | No | — | `> 0` | Eco-puntos por clasificar un residuo de esta caneca. |
| `es_aprovechable` | `boolean` | No | — | — | Si el residuo se puede reciclar o compostar. |

**Datos cargados:**

| id | nombre | color_hex | puntos | es_aprovechable |
|---|---|---|---|---|
| `blanca` | Caneca blanca | `#E7E4DA` | 10 | Sí |
| `negra` | Caneca negra | `#33332F` | 10 | No |
| `verde` | Caneca verde | `#4F9A54` | 10 | Sí |
| `especial` | Punto de recolección especial | `#C96A34` | 15 | No |

## 3. Tabla `clasificaciones`

Historial: cada residuo que la IA identificó y el usuario guardó.

| Campo | Tipo | Nulo | Por defecto | Restricciones | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | No | `gen_random_uuid()` | PK | Identificador de la clasificación. |
| `usuario_id` | `uuid` | No | — | FK → `usuarios.id` (borrado en cascada) | Quién la registró. |
| `caneca` | `text` | No | — | FK → `canecas.id` | Caneca donde va el residuo. |
| `tipo_residuo` | `text` | No | — | Entre 1 y 120 caracteres | Lo que identificó la IA, por ejemplo "Botella PET". |
| `explicacion` | `text` | No | `''` | — | Por qué va en esa caneca. |
| `instrucciones` | `text[]` | No | `'{}'` | — | Pasos para preparar el residuo antes de botarlo. |
| `foto_url` | `text` | No | `''` | — | URL pública de la miniatura en Storage. Vacío si la foto no se pudo subir. |
| `puntos` | `smallint` | No | — | `>= 0` | Puntos otorgados, copiados de `canecas.puntos` al momento de guardar. |
| `creado_en` | `timestamptz` | No | `now()` | — | Fecha y hora de la clasificación. |

**Índices:** PK sobre `id`; `clasificaciones_usuario_fecha_idx` sobre `(usuario_id, creado_en desc)` para el historial; `clasificaciones_usuario_caneca_idx` sobre `(usuario_id, caneca)` para las estadísticas.
**Cómo se crea:** solo por medio de `registrar_clasificacion()`. La app no puede insertar directamente.

## 4. Tabla `auth.users` (de Supabase, no la creamos)

Solo se listan los campos que usa EcoSnap.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | `uuid` | PK de la cuenta. Es el mismo `usuarios.id`. |
| `email` | `text` | Correo con el que inicia sesión. Supabase garantiza que sea único. |
| `encrypted_password` | `text` | Contraseña cifrada por Supabase. La app nunca la ve. |
| `raw_user_meta_data` | `jsonb` | Datos enviados al registrarse. EcoSnap envía `{"nombre": "..."}`. |

## 5. Almacenamiento de fotos (Supabase Storage)

| Propiedad | Valor |
|---|---|
| Bucket | `residuos` |
| Acceso de lectura | Público, para mostrar la miniatura con su URL |
| Ruta de cada archivo | `<id del usuario>/<marca de tiempo>.jpg` |
| Tamaño máximo | 5 MB por archivo |
| Tipos permitidos | `image/jpeg`, `image/png` |

## 6. Funciones y triggers

| Nombre | Tipo | Qué hace |
|---|---|---|
| `crear_perfil_usuario()` | Función de trigger | Crea la fila en `usuarios` con el nombre enviado al registrarse, o "Estudiante" si llegó vacío. |
| `al_registrar_usuario` | Trigger `after insert` en `auth.users` | Llama a `crear_perfil_usuario()` por cada cuenta nueva. |
| `registrar_clasificacion(p_usuario, p_foto, p_tipo, p_caneca, p_explicacion, p_instrucciones, p_puntos)` | Función (RPC), devuelve `uuid` | En una transacción: verifica que `p_usuario` sea el usuario con sesión, guarda la clasificación, suma los puntos de la caneca y recalcula la racha. Ignora `p_puntos`: los puntos salen del catálogo. |

**Regla de la racha** (con la fecha de Colombia):

| Última clasificación | Nueva racha |
|---|---|
| Hoy | Igual |
| Ayer | Racha + 1 |
| Antes de ayer o nunca | 1 |

## 7. Reglas de seguridad (Row Level Security)

| Tabla | Sin sesión (`anon`) | Con sesión (`authenticated`) |
|---|---|---|
| `canecas` | Leer | Leer |
| `usuarios` | Nada | Leer todos los perfiles (para el ranking) · editar solo su `nombre`, `carrera` y `foto_url` |
| `clasificaciones` | Nada | Leer solo las propias · insertar solo con `registrar_clasificacion()` |
| Storage `residuos` | Ver archivos por URL pública | Subir, listar y borrar solo dentro de su carpeta |
