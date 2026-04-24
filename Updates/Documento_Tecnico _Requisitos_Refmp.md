# Documento Técnico de Requisitos

## Proyecto REFMP

### Red de Escuelas de Formación Musical de Pasto

**Aplicación:** REFMP  
**Versión:** 1.1.1+5  
**Autor:** Carlos Burgos  
**Institución Académica:** Universidad CESMAG  
**Contexto del Proyecto:** Red de Escuelas de Formación Musical de Pasto  
**Tecnología base:** Flutter, Firebase, Supabase y Hive

---

## 1. Introducción

El presente documento consolida la estructura técnica de requisitos de la aplicación REFMP, desarrollada como una solución móvil para apoyar la gestión, consulta y acompañamiento de los procesos de formación musical de la Red de Escuelas de Formación Musical de Pasto.

La aplicación integra módulos informativos, académicos, de comunicación, seguimiento, notificaciones, aprendizaje interactivo y sincronización offline. Este documento resume los objetivos, el alcance y los requisitos funcionales y no funcionales que justifican la implementación de la solución.

---

## 2. Propósito del documento

Definir de forma ordenada la estructura técnica de los requerimientos de la aplicación REFMP, tomando como referencia el documento de tesis y la implementación realizada en la carpeta `lib/` del proyecto.

Este documento sirve como soporte para:

- Describir el propósito general de la aplicación.
- Identificar los módulos funcionales implementados.
- Establecer los requisitos que guían el comportamiento del sistema.
- Dejar trazabilidad entre la documentación académica y la solución desarrollada.

---

## 3. Descripción general del sistema

REFMP es una aplicación móvil orientada a la comunidad de la Red de Escuelas de Formación Musical de Pasto. Su función principal es centralizar información institucional, facilitar el acceso a contenidos formativos, mostrar sedes, eventos, contactos y ubicaciones, y ofrecer una experiencia de aprendizaje con juegos, tips y niveles educativos.

La solución también incorpora autenticación, perfiles de usuario, gestión de notificaciones, actualización de versión, sincronización offline y almacenamiento local de información para mejorar la continuidad de uso.

---

## 4. Objetivo general

Diseñar e implementar una aplicación móvil para la Red de Escuelas de Formación Musical de Pasto que permita consultar información institucional, acceder a contenidos educativos y participar en experiencias interactivas de aprendizaje musical, con soporte para notificaciones, sincronización y funcionamiento offline.

---

## 5. Objetivos específicos

| OBJ 1 | Centralizar la información institucional de la red en una aplicación móvil de fácil acceso. |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Documento de tesis |
| **Descripción:** | Este objetivo busca agrupar y organizar toda la información relevante sobre las sedes, eventos, contactos y contenido fundamental de la Red de Escuelas de Formación Musical de Pasto en una plataforma unificada y fácil de navegar para la comunidad. |

<br>

| OBJ 2 | Permitir a los usuarios consultar sedes, eventos, contactos, ubicaciones e información general. |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Requisitos del usuario |
| **Descripción:** | Brindar herramientas para que la comunidad educativa acceda oportunamente a datos logísticos, ubicación en mapas y canales de comunicación directa de cada sede. |

<br>

| OBJ 3 | Incorporar un módulo de aprendizaje musical con niveles, subniveles, tips, preguntas y juego educativo. |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Análisis docente |
| **Descripción:** | Se implementan mecánicas gamificadas y académicas para apoyar el estudio de los instrumentos musicales, estimulando el aprendizaje a través de dinámicas que otorgan experiencia (XP), monedas y trofeos a los estudiantes. |

<br>

| OBJ 4 | Gestionar perfiles de usuario, categorías de usuarios y acceso a información personalizada. |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Administración de sistema |
| **Descripción:** | El sistema soporta diferentes roles (general, autenticado, invitados, etc.), con base en cuentas estructuradas, garantizando una visualización correcta de información personal. |

<br>

| OBJ 5 | Implementar un sistema de notificaciones push y locales para comunicar novedades y eventos. |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Integración técnica Firebase |
| **Descripción:** | Permite a la Red enviar alertas instantáneas a los dispositivos móviles para mantener informados a estudiantes y acudientes sobre cualquier actualización, evento de ensayo u otra eventualidad institucional. |

<br>

| OBJ 6 | Habilitar almacenamiento local y sincronización automática para uso sin conexión a internet. |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Requisitos no funcionales |
| **Descripción:** | Debido a que no siempre se cuenta con conexión estable a internet, la aplicación guarda en caché (usando Hive) el progreso musical, las imágenes y rutinas de juego para sincronizarse diferidamente cuando retorne la conexión. |

<br>

| OBJ 7 | Ofrecer un sistema de actualizaciones de versión para mantener la app vigente. |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Arquitectura de mantenimiento |
| **Descripción:** | La app incorpora un módulo interno para detectar si existe una versión descargable más reciente desde GitHub/Play Store, facilitando que el usuario goce de las correcciones de bugs inmediatamente. |

<br>

| OBJ 8 | Integrar servicios externos como Supabase, Firebase y almacenamiento local (Hive). |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Diseño de arquitectura |
| **Descripción:** | Se utilizan estas herramientas robustas para delegar la autenticación a Firebase y la persistencia de datos (como preguntas, bases de datos remotas y seguimiento de logros) a Supabase. |

---

## 6. Alcance

La aplicación REFMP cubre los siguientes ámbitos funcionales:

- Inicio y navegación general.
- Gestión de perfil.
- Consulta de sedes, instrumentos, eventos, contactos, ubicaciones, estudiantes, egresados y profesores.
- Sección de información institucional y autoría.
- Sección de aprendizaje y juego educativo.
- Sistema de notificaciones.
- Configuración y actualización de la aplicación.
- Modo offline con caché local y sincronización diferida.

No se considera dentro del alcance del sistema la administración académica completa de matrículas, notas, contabilidad o gestión interna avanzada, salvo la información que ya se consume desde los servicios integrados.

---

## 7. Actores del sistema

### 7.1 Usuario general
Persona que consulta información institucional, accede a contenidos educativos y utiliza las funciones principales de la app.

### 7.2 Usuario autenticado
Usuario que inicia sesión y puede acceder a funcionalidades personalizadas como perfil, sincronización, progreso, notificaciones y contenidos asociados.

### 7.3 Administrador o responsable de contenido
Rol encargado de alimentar o mantener la información que consume la aplicación desde los servicios backend.

---

## 8. Módulos funcionales de la aplicación

### 8.1 Inicio
Pantalla principal con acceso a sedes, juegos, información, perfil, notificaciones y contenidos destacados.

### 8.2 Perfil de usuario
Permite visualizar y administrar la información básica del usuario, incluyendo su imagen y datos asociados.

### 8.3 Sedes
Presenta la información de las sedes de la red con su contenido descriptivo y material visual.

### 8.4 Instrumentos
Muestra la información relacionada con los instrumentos musicales manejados por la red.

### 8.5 Eventos
Lista y consulta de eventos institucionales.

### 8.6 Contactos
Canal de consulta de información de contacto de la red.

### 8.7 Ubicaciones
Visualización de ubicaciones y apoyo geográfico para sedes o puntos de interés.

### 8.8 Estudiantes, egresados y profesores
Secciones de consulta para diferentes grupos de la comunidad educativa.

### 8.9 Información institucional
Incluye datos del proyecto, autoría, patrocinio y enlaces externos relacionados con la aplicación.

### 8.10 Aprende y juega
Módulo educativo interactivo con niveles, subniveles, tips, preguntas, juegos y recompensas.

### 8.11 Notificaciones
Gestión de notificaciones push y locales para informar al usuario sobre novedades relevantes.

### 8.12 Configuración y actualizaciones
Permite ajustar parámetros generales y verificar nuevas versiones de la aplicación.

### 8.13 Sincronización offline
Conserva datos en caché y sincroniza información pendiente cuando vuelve la conexión.

---

## 9. Requisitos funcionales

| RF-01 | Inicio de sesión y acceso al sistema |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Módulo de Autenticación |
| **Descripción:** | El sistema debe permitir el acceso a usuarios autenticados (con Firebase) y habilitar la navegación según el tipo (invitado o cuenta de estudiante, profesor o egresado). |

<br>

| RF-02 | Visualización de contenido institucional |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Módulo de Inicio |
| **Descripción:** | La aplicación debe presentar menús y pestañas para ver las redes e interfaces dedicadas a sedes, eventos, contactos y ubicación de la Red. |

<br>

| RF-03 | Aprendizaje musical interactivo |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Módulo 'Aprende y juega' |
| **Descripción:** | La aplicación debe contar con dinámicas gamificadas de trompeta o lecto-escritura con registro de Logros, XP (experiencia), niveles, subniveles y monedas de juego. |

<br>

| RF-04 | Funcionamiento offline y sincronización diferida |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Persistencia Offline (Hive) |
| **Descripción:** | Si no hay conexión de internet, el juego, subniveles y los logros operarán en caché local. Cuando se reestablece la línea de red, el historial se envía discretamente a Supabase. |

<br>

| RF-05 | Sistema de notificaciones en tiempo real |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Módulo de Notificaciones |
| **Descripción:** | La aplicación es capaz de recibir, mostrar en historial y alertar al usuario, incluso en segundo plano, frente a un anuncio nuevo proveniente de Firebase Cloud Messaging. |

<br>

| RF-06 | Actualización progresiva de la aplicación |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Módulo "Check for Updates" |
| **Descripción:** | La app alertará mediante un popup con el registro de cambios obligatorios u opcionales detectado en la nube y vinculará a la ruta de descarga directa del APK. |

---

## 10. Requisitos no funcionales

| RNF-01 | Usabilidad e Interfaz |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Usabilidad y UX |
| **Descripción:** | La estructura y el diseño gráfico de las redes, material lúdico e interfaces deben ser accesibles y predecibles (Flutter ThemeProvider). |

<br>

| RNF-02 | Compatibilidad Multiplataforma |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Compatibilidad base |
| **Descripción:** | REFMP estará compilada para Android (API vigente obligatoria), pero adaptada transversalmente para escalabilidad si se lleva a IOS o Web en el futuro con mínimo esfuerzo estructural. |

<br>

| RNF-03 | Rendimiento Móvil |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Control y testing |
| **Descripción:** | La carga y el juego deben procesar audio precargado, puntajes a cero-latencias, y uso estricto de paquetes como CachedNetworkImage para ahorrar consumos agresivos de datos celulares. |

<br>

| RNF-04 | Disponibilidad |
| :--- | :--- |
| **Versión:** | 1.0 (Noviembre 2024) |
| **Autores:** | Carlos Burgos |
| **Fuentes:** | Universidad CESMAG / Robustez offline |
| **Descripción:** | Gracias al almacén Hive, las funcionalidades elementales (lecturas, progresos pasados) no se limitan ni impiden la actividad central si la red de la Universidad o la de móviles cae temporalmente. |

---

## 11. Requisitos técnicos

### 11.1 Plataforma base
- Flutter como framework principal.
- Dart como lenguaje de desarrollo.
- Android como plataforma de despliegue principal.

### 11.2 Servicios externos
- Firebase para autenticación, mensajería y soporte de notificaciones.
- Supabase para almacenamiento de datos, consulta de contenido y control de versiones.
- Hive para caché local y persistencia offline.

### 11.3 Dependencias funcionales relevantes
- Manejo de imágenes en caché.
- Acceso a ubicación y mapas.
- Reproducción de audio y video.
- Gestión de archivos y descargas.
- Sincronización de datos y conectividad.

---

## 12. Requisitos de información

La aplicación debe trabajar con información como:

- Datos de usuarios.
- Información institucional.
- Sedes.
- Instrumentos.
- Eventos.
- Contactos.
- Ubicaciones.
- Estudiantes.
- Egresados.
- Profesores.
- Niveles y subniveles de aprendizaje.
- Tips y preguntas.
- Logros y progreso.
- Versiones de la aplicación.
- Datos de sincronización offline.

---

## 13. Documentos generados a partir de la aplicación

Esta sección deja constancia de los documentos elaborados para soportar el proyecto REFMP.

### 13.1 Documento de tesis
Documento académico principal donde se justifica el proyecto, su contexto, objetivos y resultados.

### 13.2 Ficha de catalogación
Documento de registro y referencia institucional del proyecto REFMP.

### 13.3 Manual de instalación
Documento orientado a explicar cómo instalar, configurar y ejecutar la aplicación.

### 13.4 Documento técnico de requisitos
Documento que organiza los objetivos, alcance y requerimientos funcionales y no funcionales de la solución.

### 13.5 Guías complementarias
Documentos de apoyo creados para actualización, publicación, pruebas y control de versiones.

---

## 14. Relación con la implementación en `lib/`

La estructura del proyecto evidencia los siguientes componentes principales:

- `interfaces/` para las pantallas de usuario.
- `games/` para el aprendizaje interactivo.
- `services/` para lógica de sincronización, notificaciones y manejo de datos.
- `models/` para estructuras de información.
- `routes/` para navegación.
- `widgets/` para componentes reutilizables.

Esto confirma que la solución está organizada por capas funcionales y que la documentación técnica debe reflejar dicha estructura.

---

## 15. Conclusión

REFMP se consolida como una aplicación móvil enfocada en la formación musical, la difusión institucional y el aprendizaje interactivo. La documentación técnica de requisitos debe reflejar tanto la visión académica del proyecto como la implementación real del sistema, por lo que este documento organiza de forma clara los elementos necesarios para describir su funcionamiento y sus necesidades técnicas.

---

## 16. Anexos sugeridos

- Documento de tesis.
- Ficha de catalogación.
- Manual de instalación.
- Guías de actualización y publicación.
- Scripts SQL de soporte.
- Capturas o evidencias de funcionamiento de la aplicación.
