# EcoSnap — recicla con inteligencia artificial

Proyecto del curso **Mobile Cloud Computing (IS0249 - 210)**, Ingeniería de Sistemas.

**Equipo:** Brandon Felipe Linares Viasus, Sariath Eyleen Xiomara Ariza Vargas y Adriana Lucia Carreño Medina.

**Docente:** `endijromero`

---

## Visión del proyecto

Queremos que separar bien los residuos deje de depender de que la gente se sepa las reglas de memoria. La idea es simple: si en el momento de botar algo tienes una duda, le tomas una foto y la app te responde. Un asesor de reciclaje en el bolsillo, disponible justo cuando se toma la decisión: parado frente a la caneca, con el residuo en la mano. Y para que la gente vuelva a usarla, reciclar suma puntos y hay un ranking entre estudiantes.

## Problema a resolver

En Colombia se aprovecha apenas un 17 % de los residuos que se generan. Una de las causas es muy cotidiana: nadie sabe con certeza en qué caneca va cada cosa. El código de colores existe desde 2021 (blanca para aprovechables, negra para no aprovechables, verde para orgánicos), pero en la práctica un vaso de café usado, un empaque de mecato o un icopor sucio generan duda, y ante la duda todo termina en la misma bolsa. En la universidad pasa lo mismo: hay puntos ecológicos, pero se usan mal.

La información para separar bien existe. El problema es que no está disponible cuando se necesita. Ahí es donde una app móvil conectada a la nube sí puede cambiar el comportamiento de la gente.

## Qué hace la app

1. El usuario le toma una foto al residuo desde la app.
2. La imagen se envía a nuestro backend en la nube, que consulta un modelo de visión por computador (Gemini). En segundos la app responde: qué es el objeto, en qué caneca va y cómo prepararlo (por ejemplo, enjuagar el envase antes de botarlo; si es una pila o un medicamento, indica el punto de recolección especial).
3. Cada clasificación suma eco-puntos. La app lleva la racha de días reciclando, las estadísticas personales y un ranking entre los usuarios.
4. El historial y los puntos quedan guardados en la nube, así que el usuario puede cambiar de celular sin perder nada.

### Por qué necesita ser móvil y en la nube

La decisión de reciclar ocurre en cualquier parte y necesita cámara y respuesta inmediata, así que tiene que ser una app de celular. Y la parte pesada no puede correr en el dispositivo: el modelo de IA se consulta en la nube, y la identidad de los usuarios, sus datos y el ranking viven en servicios administrados. El celular captura y muestra; la nube procesa y guarda.

## Stack tecnológico elegido

**Aplicación móvil:** React Native con Expo (TypeScript), bajo el patrón MVVM (View, ViewModel, Repository). Elegimos Expo porque el equipo trabaja en computadores distintos (Mac y Windows) y todos podemos probar la app en nuestros propios celulares, iPhone o Android, con Expo Go. El APK para la entrega del Sprint 3 se genera con EAS Build sin costo.

**Backend:** una API en Node.js con Express que expone la clasificación con IA y el ranking. La razón de tener backend propio es de seguridad: la llave de la API de Gemini queda en el servidor y no dentro del APK. Se despliega en Render, en su plan gratuito.

**Servicios en la nube (proveedor: Google):**

| Servicio | Modelo | Para qué lo usamos |
|---|---|---|
| Firebase Authentication | SaaS | Registro, inicio y cierre de sesión (Sprint 4) |
| Cloud Firestore | PaaS | Clasificaciones, puntos, rachas y ranking |
| Firebase Storage | PaaS | Fotos de residuos y de perfil |
| Gemini API | SaaS | Clasificación de la imagen del residuo |
| Google Cloud | IaaS | Infraestructura sobre la que corre todo lo anterior |

**Gestión del proyecto:** GitHub para el código y los Pull Requests, GitHub Projects para el tablero Kanban con el Product Backlog (18 historias de usuario, 6 por integrante), y Figma para el prototipo del Sprint 2 con Material Design 3.

Todo el stack se usa en capa gratuita. El costo del proyecto es $0.

## Funcionalidades del MVP

- Registro, inicio y cierre de sesión.
- Clasificación de residuos por foto: caneca correcta, explicación y preparación.
- Eco-puntos por clasificación y racha diaria.
- Historial personal con estadísticas.
- Ranking entre los usuarios.
- Guía del código de colores consultable sin conexión.

## Plan por sprints

| Sprint | Entregable |
|---|---|
| 1 | Product Backlog y este documento de pitch |
| 2 | Prototipo en Figma y diagrama de arquitectura (MVVM y servicios cloud) |
| 3 | Esqueleto de la app con navegación y APK instalable |
| 4 | Autenticación con Firebase Auth |

## Distribución del equipo

| Integrante | Módulo | Historias |
|---|---|---|
| Brandon | Autenticación y perfil | HU-01 a HU-06 |
| Sarihat | Clasificación con IA | HU-07 a HU-12 |
| Adriana | Gamificación y navegación | HU-13 a HU-18 |
