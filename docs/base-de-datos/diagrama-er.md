# Diagrama entidad-relación · EcoSnap

Modelo conceptual de la base de datos de EcoSnap, implementada en Supabase (PostgreSQL).
GitHub dibuja este diagrama automáticamente; la imagen `diagrama-er.png` es la misma versión exportada para el documento PDF.

```mermaid
erDiagram
    AUTH_USERS ||--|| USUARIOS : "tiene un perfil"
    USUARIOS ||--o{ CLASIFICACIONES : "registra"
    CANECAS ||--o{ CLASIFICACIONES : "clasifica en"
    USUARIOS ||--o{ FOTOS_RESIDUOS : "sube a su carpeta"
    CLASIFICACIONES |o..o| FOTOS_RESIDUOS : "foto_url apunta a"

    AUTH_USERS {
        uuid id PK "Supabase Auth"
        text email UK "correo de acceso"
        jsonb raw_user_meta_data "trae el nombre al registrarse"
    }

    USUARIOS {
        uuid id PK, FK "= auth.users.id"
        text nombre "1 a 80 caracteres"
        text carrera "opcional"
        text foto_url "opcional"
        integer eco_puntos ">= 0"
        integer racha_actual ">= 0"
        integer racha_mejor ">= racha_actual"
        date ultima_clasificacion "para calcular la racha"
        timestamptz creado_en
    }

    CANECAS {
        text id PK "blanca, negra, verde, especial"
        text nombre
        char color_hex "#RRGGBB"
        text descripcion
        text_array ejemplos
        smallint puntos "10 o 15"
        boolean es_aprovechable
    }

    CLASIFICACIONES {
        uuid id PK
        uuid usuario_id FK "usuarios.id"
        text caneca FK "canecas.id"
        text tipo_residuo "lo que identificó la IA"
        text explicacion
        text_array instrucciones "pasos de preparación"
        text foto_url "miniatura en Storage"
        smallint puntos "copiado de la caneca"
        timestamptz creado_en
    }

    FOTOS_RESIDUOS {
        text bucket_id "residuos"
        text name "usuario_id/fecha.jpg"
    }
```

## Cómo leerlo

| Relación | Cardinalidad | Qué significa |
|---|---|---|
| `auth.users` → `usuarios` | 1 a 1 | Cada cuenta de Supabase Auth tiene exactamente un perfil. Un trigger lo crea al registrarse y se borra en cascada con la cuenta. |
| `usuarios` → `clasificaciones` | 1 a muchos | Un estudiante registra cero o muchas clasificaciones; cada clasificación pertenece a un solo estudiante. |
| `canecas` → `clasificaciones` | 1 a muchos | Cada clasificación cae en exactamente una caneca del catálogo; una caneca aparece en muchas clasificaciones. |
| `usuarios` → fotos (Storage) | 1 a muchos | Las fotos se guardan en el bucket `residuos`, dentro de una carpeta con el id del usuario. |
| `clasificaciones` → fotos (Storage) | 0..1 a 0..1 | `foto_url` guarda la URL pública de la miniatura. Es opcional: si la foto no se pudo subir, la clasificación se guarda igual con `foto_url` vacío. No es una llave foránea porque Storage es un servicio aparte. |

La línea punteada indica una relación que no es una llave foránea de la base de datos.
