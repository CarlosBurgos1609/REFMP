# Mockup 3: Pantalla de Juego - Música (Music Game Screen)

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
   - **Texto**: "Música - Trompeta"
   - **Color**: #FFFFFF
   - **Tamaño**: 18px, Bold

3. **Botón Filtro**
   - **Tipo**: Icon Button
   - **Posición**: X: 330, Y: 52
   - **Icono**: Filter icon
   - **Color**: #FFFFFF

### Sección de Monedas
- **Tipo**: Container
- **Posición**: X: 16, Y: 120
- **Tamaño**: 343x40
- **Color de fondo**: Transparente

#### Contenido:
1. **Texto "Mis monedas"**
   - **Tipo**: Text
   - **Posición**: X: 16, Y: 125
   - **Texto**: "Mis monedas"
   - **Tamaño**: 18px, Bold
   - **Color**: #2196F3

2. **Icono Moneda**
   - **Tipo**: Image
   - **Posición**: X: 120, Y: 128
   - **Tamaño**: 20x20
   - **Texto**: "COIN"

3. **Cantidad**
   - **Tipo**: Text
   - **Posición**: X: 148, Y: 125
   - **Texto**: "1,250"
   - **Tamaño**: 18px, Bold
   - **Color**: #2196F3

### Lista de Canciones por Letras
- **Tipo**: Accordion/Expandable List
- **Posición**: X: 16, Y: 180
- **Tamaño**: 343x550

#### Grupo de Letra (Ejemplo: "A")
- **Tipo**: Container
- **Tamaño**: 343x50 (header) + variable (contenido)

1. **Header de Letra**
   - **Tipo**: Rectangle
   - **Tamaño**: 343x50
   - **Color de fondo**: #E3F2FD (azul claro)
   - **Border radius**: 8px

   - **Letra**
     - **Tipo**: Text
     - **Posición**: X: 16, Y: center
     - **Texto**: "A"
     - **Tamaño**: 24px, Bold
     - **Color**: #2196F3

   - **Contador**
     - **Tipo**: Text
     - **Posición**: X: 300, Y: center
     - **Texto**: "(3)"
     - **Tamaño**: 16px
     - **Color**: #666666

   - **Icono Expandir**
     - **Tipo**: Icon
     - **Posición**: X: 320, Y: center
     - **Icono**: Expand arrow
     - **Color**: #2196F3

2. **Lista de Canciones** (cuando está expandido)
   - **Tipo**: List

#### Item de Canción
- **Tipo**: Rectangle
- **Tamaño**: 327x80
- **Color de fondo**: #FFFFFF
- **Border radius**: 12px
- **Sombra**: Sutil
- **Margin bottom**: 8px

**Contenido del item:**

1. **Imagen de Canción**
   - **Tipo**: Image placeholder
   - **Posición**: X: 8, Y: 8
   - **Tamaño**: 64x64
   - **Border radius**: 8px
   - **Texto**: "SONG IMG"

2. **Información de Canción**
   - **Posición**: X: 80, Y: 8

   - **Título**
     - **Tipo**: Text
     - **Texto**: "Adiós Nonino"
     - **Tamaño**: 16px, Bold
     - **Color**: #000000

   - **Dificultad**
     - **Tipo**: Badge/Chip
     - **Texto**: "Intermedio"
     - **Color de fondo**: #FF9800 (naranja)
     - **Color de texto**: #FFFFFF
     - **Tamaño**: 12px
     - **Border radius**: 12px

   - **Puntuación**
     - **Tipo**: Text con Icon
     - **Icono**: Star icon
     - **Texto**: "★★★☆☆"
     - **Color**: #FFD700 (dorado)

3. **Botón Reproducir**
   - **Tipo**: Icon Button
   - **Posición**: X: 280, Y: 24
   - **Tamaño**: 32x32
   - **Icono**: Play circle
   - **Color**: #4CAF50

### Bottom Navigation (Game)
- **Tipo**: Bottom Navigation Bar
- **Posición**: X: 0, Y: 762
- **Tamaño**: 375x50
- **Color de fondo**: #2196F3

#### Items (4 tabs):
1. **Aprender**
   - **Icono**: Book icon
   - **Color**: #FFFFFF (inactivo)

2. **Música**
   - **Icono**: Music note icon
   - **Color**: #FFD700 (activo)

3. **Torneo**
   - **Icono**: Trophy icon
   - **Color**: #FFFFFF (inactivo)

4. **Objetos**
   - **Icono**: Star icon
   - **Color**: #FFFFFF (inactivo)

5. **Perfil**
   - **Icono**: Person icon
   - **Color**: #FFFFFF (inactivo)

## Notas de Diseño:
- La lista debe ser scrolleable
- Los grupos de letras son expandibles/colapsables
- Mostrar solo letras que tienen canciones
- El botón de filtro abre un diálogo para filtrar por dificultad
- Animaciones de expansión para los acordeones
- Audio preview al hacer tap en el botón play