# Mockup 10: Componentes Comunes y Elementos de UI

## 1. Bottom Navigation Bar (Aplicación Principal)

### Container del Navigation
- **Tipo**: Rectangle
- **Posición**: X: 0, Y: 762
- **Tamaño**: 375x50
- **Color de fondo**: #FFFFFF
- **Border top**: 1px solid #E0E0E0

#### Items de Navegación (5 items):
1. **Inicio**
   - **Posición**: X: 37.5, Y: center
   - **Icono**: Home
   - **Label**: "Inicio"
   - **Estado activo**: Color #2196F3
   - **Estado inactivo**: Color #9E9E9E

2. **Eventos**
   - **Posición**: X: 112.5, Y: center
   - **Icono**: Calendar
   - **Label**: "Eventos"

3. **Instrumentos**
   - **Posición**: X: 187.5, Y: center
   - **Icono**: Music note
   - **Label**: "Instrumentos"

4. **Sedes**
   - **Posición**: X: 262.5, Y: center
   - **Icono**: Building
   - **Label**: "Sedes"

5. **Perfil**
   - **Posición**: X: 337.5, Y: center
   - **Icono**: Person
   - **Label**: "Perfil"

## 2. Bottom Navigation Bar (Juegos)

### Container del Navigation
- **Tipo**: Rectangle
- **Posición**: X: 0, Y: 762
- **Tamaño**: 375x50
- **Color de fondo**: #2196F3

#### Items de Navegación (5 items):
1. **Aprender**
   - **Icono**: Book
   - **Color activo**: #FFD700
   - **Color inactivo**: #FFFFFF

2. **Música**
   - **Icono**: Music note
   - **Badge**: Número de canciones nuevas

3. **Torneo**
   - **Icono**: Trophy
   - **Badge**: Posición actual

4. **Objetos**
   - **Icono**: Star/Gift
   - **Badge**: Número de objetos nuevos

5. **Perfil**
   - **Icono**: Person

## 3. Cards de Contenido

### Card Básica
- **Tipo**: Rectangle
- **Tamaño**: Variable
- **Color de fondo**: #FFFFFF
- **Border radius**: 12px
- **Sombra**: box-shadow: 0 2px 8px rgba(0,0,0,0.1)
- **Padding**: 16px
- **Margin**: 8px

### Card de Sede
- **Tamaño**: 343x160
- **Layout**: Imagen izquierda + contenido derecha

#### Estructura:
1. **Imagen** (150x144)
2. **Contenido** (177x144)
   - Título (16px, Bold, #2196F3)
   - Dirección (14px, #666666)
   - Descripción (12px, #666666, 3 líneas max)
   - Teléfono (14px, #666666)

### Card de Instrumento
- **Tamaño**: 165x100
- **Layout**: Imagen izquierda + info derecha

#### Estructura:
1. **Imagen** (60x60)
2. **Info** (89x60)
   - Nombre (14px, Bold, #2196F3)
   - Descripción (12px, #666666)
   - Botón "JUGAR" (60x25, #4CAF50)

## 4. Elementos de Lista

### Item de Canción
- **Tipo**: Rectangle
- **Tamaño**: 327x80
- **Color de fondo**: #FFFFFF
- **Border radius**: 12px
- **Padding**: 8px

#### Estructura:
1. **Imagen** (64x64, border radius 8px)
2. **Info** (200x64)
   - Título (16px, Bold)
   - Badge dificultad (12px, coloreado)
   - Estrellas de rating
3. **Botón Play** (32x32, #4CAF50)

### Item de Participante (Torneo)
- **Tipo**: Rectangle
- **Tamaño**: 343x50
- **Border**: 1px solid #E0E0E0 (2px #2196F3 si es usuario actual)
- **Border radius**: 12px

#### Estructura:
1. **Ranking** (#4, 16px, Bold)
2. **Avatar** (30x30, circular)
3. **Nickname** (14px, con marquee si es necesario)
4. **Puntos** (14px, Bold, #2196F3)

## 5. Elementos de Input

### Text Field Estándar
- **Tipo**: Text Input
- **Tamaño**: 311x50
- **Border**: 2px solid #E0E0E0
- **Border radius**: 12px
- **Padding**: 16px
- **Font**: 16px

#### Estados:
- **Normal**: Border #E0E0E0
- **Focus**: Border #2196F3
- **Error**: Border #F44336
- **Disabled**: Background #F5F5F5, text #9E9E9E

### Search Field
- **Icono**: Search (izquierda)
- **Placeholder**: "Buscar..."
- **Clear button**: X (derecha, cuando hay texto)

### Dropdown/Select
- **Icono**: Arrow down (derecha)
- **Opciones**: Lista desplegable con border y sombra

## 6. Botones

### Botón Primario
- **Color de fondo**: #2196F3
- **Color de texto**: #FFFFFF
- **Border radius**: 12px
- **Padding**: 16px 32px
- **Font**: 16px, Bold
- **Sombra**: Sutil

### Botón Secundario
- **Color de fondo**: Transparente
- **Border**: 2px solid #2196F3
- **Color de texto**: #2196F3
- **Border radius**: 12px

### Botón de Peligro
- **Color de fondo**: #F44336
- **Color de texto**: #FFFFFF

### Botón de Éxito
- **Color de fondo**: #4CAF50
- **Color de texto**: #FFFFFF

### Icon Button
- **Tamaño**: 40x40 (o 32x32 para pequeños)
- **Background**: Circular con ripple effect
- **Icono**: 24x24 (o 16x16)

## 7. Badges y Chips

### Badge de Dificultad
- **Principiante**: #4CAF50 (verde)
- **Intermedio**: #FF9800 (naranja)
- **Avanzado**: #F44336 (rojo)
- **Experto**: #9C27B0 (púrpura)

### Badge de Notificación
- **Tamaño**: 20x20 (circular)
- **Color**: #F44336
- **Posición**: Esquina superior derecha del elemento padre
- **Texto**: Número (1-99, "99+" para más)

### Chip de Estado
- **Equipado**: #4CAF50
- **Disponible**: #2196F3
- **Bloqueado**: #9E9E9E

## 8. Progress Indicators

### Progress Bar Lineal
- **Altura**: 8px
- **Border radius**: 4px
- **Background**: #E0E0E0
- **Progreso**: #4CAF50
- **Con texto**: Porcentaje encima o al lado

### Circular Progress
- **Para loading**: #2196F3
- **Tamaño**: 40x40 (grande) o 20x20 (pequeño)

### Skeleton Loading
- **Color base**: #F0F0F0
- **Color highlight**: #E0E0E0
- **Animación**: Shimmer effect

## 9. Iconografía Sistemática

### Íconos de 24x24 (Material Design):
- **home**: Inicio
- **music_note**: Música
- **emoji_events**: Torneo/Trophy
- **star**: Objetos/Favoritos
- **person**: Perfil/Usuario
- **settings**: Configuración
- **phone**: Teléfono
- **location_on**: Ubicación
- **calendar_today**: Calendario/Eventos
- **school**: Aprendizaje
- **play_circle**: Reproducir
- **check_circle**: Completado/Éxito
- **error**: Error
- **info**: Información
- **warning**: Advertencia

### Colores de Íconos:
- **Activos**: #2196F3
- **Inactivos**: #9E9E9E
- **Éxito**: #4CAF50
- **Error**: #F44336
- **Advertencia**: #FF9800

## Notas de Diseño:
- Todos los elementos deben seguir Material Design guidelines
- Espaciado consistente: 8px, 16px, 24px, 32px
- Animaciones suaves (300ms para la mayoría)
- Respuesta táctil con ripple effects
- Accesibilidad: contraste mínimo 4.5:1
- Estados de hover para web (si aplica)