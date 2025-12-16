# Mockup 7: Detalle de Sede (Headquarters Detail Screen)

## Componentes en Balsamiq:

### Container Principal
- **Tipo**: Rectangle
- **Tamaño**: 375x812
- **Color de fondo**: #F5F5F5

### App Bar
- **Tipo**: Rectangle
- **Posición**: X: 0, Y: 44
- **Tamaño**: 375x56
- **Color de fondo**: #2196F3

#### Contenido del App Bar:
1. **Botón Atrás**
   - **Tipo**: Icon Button
   - **Posición**: X: 8, Y: 52
   - **Icono**: Arrow back
   - **Color**: #FFFFFF

2. **Título**
   - **Tipo**: Text
   - **Posición**: Center X, Y: 52
   - **Texto**: "Sede Centro"
   - **Color**: #FFFFFF
   - **Tamaño**: 18px, Bold

### Imagen Principal de la Sede
- **Tipo**: Image placeholder
- **Posición**: X: 0, Y: 100
- **Tamaño**: 375x200
- **Texto**: "SEDE CENTRO IMAGE"
- **Fit**: Cover

### Información Principal
- **Tipo**: Card
- **Posición**: X: 16, Y: 320
- **Tamaño**: 343x120
- **Color de fondo**: #FFFFFF
- **Border radius**: 16px
- **Sombra**: Yes

#### Contenido de la Card:
1. **Nombre de la Sede**
   - **Tipo**: Text
   - **Posición**: X: 24, Y: 335
   - **Texto**: "Sede Centro"
   - **Tamaño**: 20px, Bold
   - **Color**: #2196F3

2. **Dirección**
   - **Tipo**: Container
   - **Posición**: X: 24, Y: 365

   - **Icono Ubicación**
     - **Tipo**: Icon
     - **Icono**: Location
     - **Color**: #2196F3
     - **Tamaño**: 18x18

   - **Texto Dirección**
     - **Tipo**: Text
     - **Posición**: X: 48, Y: 365
     - **Texto**: "Calle 20 #25-67, Centro, Pasto"
     - **Tamaño**: 14px
     - **Color**: #666666

3. **Teléfono**
   - **Tipo**: Container
   - **Posición**: X: 24, Y: 390

   - **Icono Teléfono**
     - **Tipo**: Icon
     - **Icono**: Phone
     - **Color**: #2196F3
     - **Tamaño**: 18x18

   - **Bandera y Código**
     - **Tipo**: Text
     - **Posición**: X: 48, Y: 390
     - **Texto**: "🇨🇴 +57 312 456 7890"
     - **Tamaño**: 14px
     - **Color**: #666666

4. **Botón Llamar**
   - **Tipo**: Button
   - **Posición**: X: 250, Y: 385
   - **Tamaño**: 80x30
   - **Texto**: "LLAMAR"
   - **Color de fondo**: #4CAF50
   - **Color de texto**: #FFFFFF
   - **Border radius**: 15px
   - **Tamaño de fuente**: 12px

### Descripción
- **Tipo**: Card
- **Posición**: X: 16, Y: 460
- **Tamaño**: 343x100
- **Color de fondo**: #FFFFFF
- **Border radius**: 16px

#### Contenido:
1. **Título**
   - **Tipo**: Text
   - **Posición**: X: 24, Y: 475
   - **Texto**: "Descripción"
   - **Tamaño**: 16px, Bold
   - **Color**: #2196F3

2. **Texto Descriptivo**
   - **Tipo**: Text Block
   - **Posición**: X: 24, Y: 500
   - **Tamaño**: 295x50
   - **Texto**: "La sede centro es el corazón de la red de escuelas de formación musical. Aquí ofrecemos clases de diversos instrumentos con profesores altamente calificados..."
   - **Tamaño**: 14px
   - **Color**: #666666
   - **Max lines**: 4
   - **Overflow**: Ellipsis

### Instrumentos Disponibles
- **Tipo**: Card
- **Posición**: X: 16, Y: 580
- **Tamaño**: 343x120
- **Color de fondo**: #FFFFFF
- **Border radius**: 16px

#### Contenido:
1. **Título**
   - **Tipo**: Text
   - **Posición**: X: 24, Y: 595
   - **Texto**: "| Instrumentos"
   - **Tamaño**: 14px, Bold
   - **Color**: #2196F3

2. **Lista Horizontal de Instrumentos**
   - **Tipo**: Horizontal Scrollable Container
   - **Posición**: X: 24, Y: 620
   - **Tamaño**: 295x60

#### Item de Instrumento
- **Tipo**: Container
- **Tamaño**: 60x60
- **Margin right**: 8px

**Contenido:**
1. **Imagen del Instrumento**
   - **Tipo**: Circle Image
   - **Tamaño**: 40x40
   - **Border**: 2px solid #2196F3
   - **Border radius**: 20px
   - **Placeholder**: "TRUMPET"

2. **Nombre del Instrumento**
   - **Tipo**: Text
   - **Posición**: Debajo de la imagen
   - **Texto**: "Trompeta"
   - **Tamaño**: 10px
   - **Color**: #666666
   - **Alineación**: Center

### Mapa/Ubicación
- **Tipo**: Card
- **Posición**: X: 16, Y: 720
- **Tamaño**: 343x80
- **Color de fondo**: #FFFFFF
- **Border radius**: 16px

#### Contenido:
1. **Título**
   - **Tipo**: Text
   - **Posición**: X: 24, Y: 735
   - **Texto**: "Ubicación"
   - **Tamaño**: 16px, Bold
   - **Color**: #2196F3

2. **Mini Mapa**
   - **Tipo**: Image placeholder
   - **Posición**: X: 24, Y: 755
   - **Tamaño**: 120x35
   - **Texto**: "MAP PREVIEW"
   - **Border radius**: 8px

3. **Botón Ver en Mapa**
   - **Tipo**: Button
   - **Posición**: X: 160, Y: 755
   - **Tamaño**: 140x35
   - **Texto**: "VER EN MAPA"
   - **Color de fondo**: #2196F3
   - **Color de texto**: #FFFFFF
   - **Border radius**: 8px
   - **Tamaño de fuente**: 12px

## Diálogo de Confirmación de Llamada

### Modal de Llamada
- **Tipo**: Dialog/Modal
- **Tamaño**: 300x200
- **Color de fondo**: #FFFFFF
- **Border radius**: 20px
- **Sombra**: Yes

#### Contenido del Modal:
1. **Icono Teléfono**
   - **Tipo**: Icon
   - **Posición**: Center X, Y: 20
   - **Icono**: Phone
   - **Color**: #4CAF50
   - **Tamaño**: 48x48

2. **Texto de Confirmación**
   - **Tipo**: Text
   - **Posición**: Center X, Y: 80
   - **Texto**: "¿Deseas llamar a la Sede Centro?"
   - **Tamaño**: 16px, Bold
   - **Color**: #000000

3. **Número a Llamar**
   - **Tipo**: Text
   - **Posición**: Center X, Y: 105
   - **Texto**: "+57 312 456 7890"
   - **Tamaño**: 14px
   - **Color**: #2196F3

4. **Botones de Acción**
   - **Posición**: Y: 140

   - **Botón Cancelar**
     - **Tipo**: Button
     - **Posición**: X: 50, Y: 140
     - **Tamaño**: 80x35
     - **Texto**: "Cancelar"
     - **Color de fondo**: Transparente
     - **Color de texto**: #F44336
     - **Border**: 1px solid #F44336

   - **Botón Llamar**
     - **Tipo**: Button
     - **Posición**: X: 170, Y: 140
     - **Tamaño**: 80x35
     - **Texto**: "Llamar"
     - **Color de fondo**: #4CAF50
     - **Color de texto**: #FFFFFF

## Notas de Diseño:
- La imagen principal debe ocupar un buen espacio para mostrar la sede
- Los instrumentos son clickeables y llevan a la página de detalle del instrumento
- El mapa muestra una preview y al hacer click abre la app de mapas
- El botón de llamar abre el dialer del teléfono
- Scroll vertical para todo el contenido
- Cards con sombras sutiles para separar secciones