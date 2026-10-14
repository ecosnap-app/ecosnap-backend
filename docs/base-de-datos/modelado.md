# Modelado de la base de datos · EcoSnap

**Plataforma:** Supabase (PostgreSQL 15+ administrado en la nube, sobre AWS).
**Scripts:** carpeta [`supabase/`](../../supabase) de este repositorio, ejecutados en orden `01` → `02` → `03`.

## Qué necesita guardar la app

EcoSnap identifica un residuo con IA a partir de una foto, dice en qué caneca va y premia al estudiante con puntos, rachas y un ranking. De las 18 historias de usuario salen estas necesidades de datos:

| Necesidad | Historias | Dónde queda |
|---|---|---|
| Cuentas con correo y contraseña, sesión persistente y recuperación | HU-01 a HU-05 | Supabase Auth (`auth.users`) |
| Perfil con nombre, carrera y foto | HU-06 | `usuarios` |
| Guardar cada clasificación con su foto, tipo, caneca y explicación | HU-08 a HU-10 | `clasificaciones` + Storage |
| Código de colores con ejemplos | HU-09, HU-11 | `canecas` |
| Eco-puntos, racha diaria e historial | HU-13 a HU-15 | `usuarios` + `clasificaciones` |
| Estadísticas por caneca y ranking | HU-16, HU-17 | consultas sobre `clasificaciones` y `usuarios` |

## Entidades

**Usuario (`usuarios`).** El perfil del estudiante y sus acumulados de gamificación. Se enlaza 1 a 1 con la cuenta de Supabase Auth usando el mismo `id`. Guardar los puntos y la racha aquí, en lugar de calcularlos cada vez, permite que el ranking sea una sola consulta ordenada.

**Caneca (`canecas`).** Catálogo fijo de las cuatro categorías de la Resolución 2184 de 2019: blanca (aprovechables), negra (no aprovechables), verde (orgánicos) y el punto de recolección especial (peligrosos). Define cuántos puntos vale cada una: 10, y 15 para los especiales, porque llevarlos a un punto de recolección cuesta más esfuerzo.

**Clasificación (`clasificaciones`).** Cada residuo que la IA identificó y el usuario decidió guardar. Es el historial y la fuente de las estadísticas.

**Cuenta (`auth.users`).** No la creamos nosotros: es la tabla de Supabase Auth donde quedan el correo y la contraseña cifrada. Nuestro esquema solo se enlaza a ella.

**Foto del residuo (Storage).** Las imágenes no van dentro de la base de datos. Se guardan en el bucket `residuos` de Supabase Storage, en la ruta `<id del usuario>/<fecha>.jpg`, y la clasificación guarda su URL.

## Relaciones

- Una cuenta tiene **un** perfil (1:1). Al borrar la cuenta se borra el perfil, y con él su historial (cascada).
- Un usuario registra **muchas** clasificaciones (1:N).
- Una caneca recibe **muchas** clasificaciones (1:N). La caneca no se puede borrar mientras tenga clasificaciones.
- Un usuario sube **muchas** fotos a su carpeta de Storage (1:N).

## Decisiones de diseño

1. **Relacional y no NoSQL.** Los datos tienen relaciones claras (usuario → clasificaciones → caneca) y el ranking necesita ordenar y contar. PostgreSQL lo resuelve con llaves foráneas, índices y una consulta; en Firestore habría que duplicar datos y mantenerlos sincronizados a mano.
2. **Los puntos los decide la base de datos.** La función `registrar_clasificacion()` toma los puntos del catálogo de canecas e ignora lo que mande la app. Así nadie puede darse puntos de más modificando el APK.
3. **Una sola transacción por clasificación.** Guardar el historial, sumar los puntos y recalcular la racha ocurren juntos: o se hace todo o no se hace nada.
4. **Seguridad por fila (RLS).** Cada usuario solo ve su propio historial y solo edita su nombre, carrera y foto. Los perfiles son visibles para usuarios con sesión porque el ranking los necesita.
5. **La racha usa la hora de Colombia** (`America/Bogota`), para que una clasificación a las 11 p. m. cuente para ese día y no para el siguiente.
6. **Índices pensados para las pantallas.** `usuarios(eco_puntos desc)` para el ranking, `clasificaciones(usuario_id, creado_en desc)` para el historial paginado y `clasificaciones(usuario_id, caneca)` para las estadísticas.
