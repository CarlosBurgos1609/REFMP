# Guía de Mockups para Balsamiq - REFMP

Esta guía contiene los mockups diseñados para la aplicación REFMP (Red de Escuelas de Formación Musical de Pasto) que pueden ser importados y utilizados en Balsamiq Mockups.

## Archivos de Mockups Incluidos

### 1. `01_welcome_screen.bmml` - Pantalla de Bienvenida
**Descripción:** Pantalla inicial de la aplicación que presenta la institución.
**Elementos principales:**
- Logo REFMP centrado
- Texto descriptivo de la institución
- Botón "Ir al Inicio de Sesión"
- Círculo decorativo azul en la esquina superior

**Dimensiones:** 375x812 (iPhone X/11/12 format)

### 2. `02_login_screen.bmml` - Pantalla de Inicio de Sesión
**Descripción:** Formulario de autenticación para usuarios.
**Elementos principales:**
- Logo pequeño centrado
- Campos de correo electrónico y contraseña
- Checkbox "Recordarme"
- Botón de inicio de sesión
- Enlaces para registro y recuperación de contraseña
- Botón de retroceso

### 3. `03_home_screen.bmml` - Pantalla Principal
**Descripción:** Pantalla principal después del login mostrando sedes y juegos.
**Elementos principales:**
- Header con logo y navegación
- Sección "Sedes" con carrusel de tarjetas
- Indicadores de páginas para carrusel
- Sección "Aprende y Juega" con tarjetas de juegos
- Iconos de perfil y menú hamburguesa

### 4. `04_navigation_drawer.bmml` - Menú de Navegación Lateral
**Descripción:** Menú deslizable lateral con todas las opciones de navegación.
**Elementos principales:**
- Header con información del usuario
- Menú principal: Inicio, Perfil, Sedes, Notificaciones, etc.
- Sección de estudiantes y profesores
- Configuración
- Enlaces a redes sociales (Facebook, WhatsApp, Instagram, YouTube)

### 5. `05_game_interface.bmml` - Interfaz de Juego
**Descripción:** Pantalla principal del módulo de aprendizaje musical.
**Elementos principales:**
- Header con título del instrumento
- Imagen de fondo del instrumento
- Barra de progreso de nivel
- Estadísticas (monedas, trofeos, días seguidos)
- Modos de juego: Práctica, Torneo, Música
- Navegación inferior con 5 pestañas

### 6. `06_headquarters_detail.bmml` - Detalle de Sede
**Descripción:** Vista detallada de una sede específica.
**Elementos principales:**
- Imagen de encabezado de la sede
- Información de contacto (dirección, teléfono)
- Tipo de sede y descripción
- Grid de instrumentos disponibles
- Información de profesores
- Botones de acción (favorito, etc.)

## Cómo Usar en Balsamiq

### Importar los Mockups:
1. Abre Balsamiq Mockups
2. Ve a `Proyecto > Importar > Mockup...`
3. Selecciona los archivos `.bmml` uno por uno
4. Los mockups aparecerán en tu proyecto

### Personalización Sugerida:
- **Colores:** El color azul principal es #2196F3 (RGB: 33, 150, 243)
- **Tipografía:** Utiliza Balsamiq Sans o una fuente similar
- **Iconos:** Puedes reemplazar los iconos por los específicos de tu design system

### Flujo de Navegación Sugerido:
```
Bienvenida → Login → Home → [Menú Lateral | Detalle Sede | Juegos]
                        ↓
                   Game Interface
```

## Elementos de Diseño Clave

### Paleta de Colores:
- **Azul principal:** #2196F3 (usado en botones, headers, enlaces)
- **Blanco:** #FFFFFF (fondos principales)
- **Gris claro:** #F5F5F5 (fondos secundarios)
- **Gris medio:** #9E9E9E (textos secundarios)
- **Verde:** #4CAF50 (elementos de éxito)
- **Dorado:** #FFD700 (elementos de logros)

### Espaciado:
- **Márgenes:** 20px en los bordes
- **Espaciado entre elementos:** 10-20px
- **Padding en botones:** 15px vertical, 80px horizontal

### Tipografía:
- **Títulos:** 18-24px, negrita
- **Subtítulos:** 14-16px, negrita
- **Texto normal:** 12-14px
- **Texto pequeño:** 10-12px

## Componentes Reutilizables

### Tarjetas:
- Bordes redondeados
- Sombra sutil
- Padding interno de 15px
- Imágenes con aspecto ratio 16:9

### Botones:
- Bordes redondeados (radius: 12px)
- Color azul para acciones principales
- Texto blanco sobre fondo azul
- Iconos opcionales a la izquierda del texto

### Navegación:
- Bottom navigation con 5 pestañas máximo
- Drawer navigation para opciones secundarias
- Breadcrumbs para navegación jerárquica

## Notas de Implementación

### Responsive Design:
- Los mockups están diseñados para móviles (375px ancho)
- Para tablet/desktop, considera un layout de 2-3 columnas
- Mantén los elementos principales centrados

### Accesibilidad:
- Contraste mínimo de 4.5:1 entre texto y fondo
- Área mínima de toque de 44px para elementos interactivos
- Etiquetas descriptivas para todos los elementos

### Performance:
- Optimiza las imágenes para web (WebP preferido)
- Usa lazy loading para imágenes de carrusel
- Implementa cache para elementos repetitivos

## Extensiones Futuras

### Pantallas Adicionales Sugeridas:
- Registro de usuario
- Perfil de usuario
- Lista de instrumentos
- Detalle de instrumento
- Lista de eventos
- Detalle de evento
- Configuraciones
- Sobre nosotros

### Funcionalidades Avanzadas:
- Modo oscuro/claro
- Notificaciones push
- Búsqueda global
- Filtros y ordenamiento
- Compartir en redes sociales
- Chat/mensajería

¡Estos mockups proporcionan una base sólida para el desarrollo de la aplicación REFMP manteniendo consistencia visual y experiencia de usuario optimizada!