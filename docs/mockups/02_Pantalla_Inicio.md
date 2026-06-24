# Mockup 2: Pantalla de Inicio (Home Screen)

## Componentes en Balsamiq:

### Container Principal
- **Tipo**: Rectangle
- **Tamaño**: 375x812
- **Color de fondo**: #F5F5F5 (gris muy claro)

### Header con Logo
- **Tipo**: Image placeholder
- **Posición**: X: 0, Y: 44 (debajo del status bar)
- **Tamaño**: 375x80
- **Texto del placeholder**: "HEADER LOGO REFMP"
- **Border radius inferior**: 16px

### Divider
- **Tipo**: Line
- **Posición**: Y: 134
- **Tamaño**: 375x2
- **Color**: #E0E0E0

### Título "Sedes"
- **Tipo**: Text
- **Posición**: X: 16, Y: 150
- **Texto**: "Sedes"
- **Tamaño de fuente**: 25px
- **Color**: #2196F3
- **Font weight**: Bold
- **Alineación**: Center (en toda la pantalla)

### Carousel de Sedes
- **Tipo**: Container con cards
- **Posición**: X: 16, Y: 190
- **Tamaño**: 343x340

#### Card de Sede (repetir 3 veces con indicadores)
- **Tipo**: Rectangle
- **Tamaño**: 343x320
- **Color de fondo**: #FFFFFF
- **Border radius**: 16px
- **Sombra**: Yes

**Contenido de cada card:**

1. **Imagen de Sede**
   - **Tipo**: Image placeholder
   - **Posición**: X: 8, Y: 8 (relativo al card)
   - **Tamaño**: 150x200
   - **Border radius**: 10px
   - **Texto**: "SEDE IMAGE"

2. **Información de Sede**
   - **Posición**: X: 170, Y: 8 (al lado de la imagen)
   - **Tamaño**: 165x200

   - **Nombre de Sede**
     - **Tipo**: Text
     - **Texto**: "Sede Centro"
     - **Tamaño**: 16px, Bold
     - **Color**: #2196F3

   - **Dirección**
     - **Tipo**: Text con Icon
     - **Icono**: Location icon
     - **Texto**: "Calle 20 #25-67"
     - **Tamaño**: 14px
     - **Color**: #666666

   - **Descripción**
     - **Tipo**: Text Block
     - **Texto**: "Descripción breve de la sede..."
     - **Tamaño**: 12px
     - **Max lines**: 5

   - **Teléfono**
     - **Tipo**: Text con Icon
     - **Icono**: Phone icon
     - **Texto**: "🇨🇴 +57 312 456 7890"
     - **Tamaño**: 14px

### Indicadores del Carousel
- **Tipo**: Dots (3 círculos)
- **Posición**: X: center, Y: 540
- **Círculo activo**: #2196F3
- **Círculos inactivos**: #E0E0E0

### Título "Juegos"
- **Tipo**: Text
- **Posición**: X: 16, Y: 580
- **Texto**: "Juegos"
- **Tamaño de fuente**: 25px
- **Color**: #2196F3
- **Font weight**: Bold
- **Alineación**: Center

### Grid de Juegos
- **Tipo**: Grid Container
- **Posición**: X: 16, Y: 620
- **Tamaño**: 343x120
- **Columnas**: 2
- **Spacing**: 12px

#### Card de Juego (2 cards en fila)
- **Tipo**: Rectangle
- **Tamaño**: 165x100
- **Color de fondo**: #FFFFFF
- **Border radius**: 12px
- **Sombra**: Yes

**Contenido de cada card:**

1. **Imagen del Instrumento**
   - **Tipo**: Image placeholder
   - **Posición**: X: 8, Y: 8
   - **Tamaño**: 60x60
   - **Border radius**: 8px
   - **Texto**: "TRUMPET"

2. **Información**
   - **Posición**: X: 76, Y: 8

   - **Nombre**
     - **Tipo**: Text
     - **Texto**: "Trompeta"
     - **Tamaño**: 14px, Bold
     - **Color**: #2196F3

   - **Descripción**
     - **Tipo**: Text
     - **Texto**: "Aprende a tocar"
     - **Tamaño**: 12px
     - **Color**: #666666

   - **Botón Play**
     - **Tipo**: Button (pequeño)
     - **Posición**: X: 76, Y: 50
     - **Tamaño**: 60x25
     - **Texto**: "JUGAR"
     - **Color**: #4CAF50
     - **Tamaño de fuente**: 10px

### Bottom Navigation Bar
- **Tipo**: Container
- **Posición**: X: 0, Y: 762
- **Tamaño**: 375x50
- **Color de fondo**: #FFFFFF

#### Íconos de navegación (5 items)
- **Inicio**: Home icon (activo - #2196F3)
- **Eventos**: Calendar icon
- **Instrumentos**: Music note icon
- **Sedes**: Building icon
- **Perfil**: Person icon

## Notas de Diseño:
- El carousel debe tener swipe indicators
- Las cards deben tener sombra sutil
- El bottom navigation debe mostrar el item activo
- Usar RefreshIndicator implícito para pull-to-refresh