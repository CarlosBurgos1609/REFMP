# Mockup 5: Pantalla de Objetos (Objects Collection Screen)

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
   - **Texto**: "Colección - Trompeta"
   - **Color**: #FFFFFF
   - **Tamaño**: 18px, Bold

### Tabs de Categorías
- **Tipo**: Horizontal Scrollable Tab Bar
- **Posición**: X: 0, Y: 100
- **Tamaño**: 375x60
- **Color de fondo**: #FFFFFF

#### Tabs individuales:
1. **TROMPETAS** (Activo)
   - **Color de fondo**: #2196F3
   - **Color de texto**: #FFFFFF

2. **AVATARES**
   - **Color de fondo**: Transparente
   - **Color de texto**: #2196F3

3. **FONDOS**
   - **Color de fondo**: Transparente
   - **Color de texto**: #2196F3

4. **LOGROS**
   - **Color de fondo**: Transparente
   - **Color de texto**: #2196F3

5. **CANCIONES**
   - **Color de fondo**: Transparente
   - **Color de texto**: #2196F3

### Sección de Información
- **Tipo**: Container
- **Posición**: X: 16, Y: 180
- **Tamaño**: 343x80

#### Título de Categoría
- **Tipo**: Text
- **Posición**: X: center, Y: 180
- **Texto**: "TROMPETAS"
- **Tamaño**: 24px, Bold
- **Color**: #2196F3

#### Contador de Monedas
- **Tipo**: Container
- **Posición**: X: center, Y: 210

1. **Texto "Mis monedas"**
   - **Tamaño**: 18px, Bold
   - **Color**: #2196F3

2. **Icono Moneda**
   - **Tamaño**: 20x20

3. **Cantidad**
   - **Texto**: "1,250"
   - **Tamaño**: 18px, Bold
   - **Color**: #2196F3

### Grid de Objetos
- **Tipo**: Grid Container
- **Posición**: X: 16, Y: 280
- **Tamaño**: 343x400
- **Columnas**: 3
- **Spacing**: 12px
- **Scrollable**: Yes

#### Item de Objeto (Card)
- **Tipo**: Rectangle
- **Tamaño**: 105x140
- **Color de fondo**: #FFFFFF
- **Border radius**: 12px
- **Border**: 2px solid #E0E0E0 (no obtenido) / #4CAF50 (obtenido)
- **Sombra**: Sutil

**Contenido del item:**

1. **Imagen del Objeto**
   - **Tipo**: Image placeholder
   - **Posición**: X: center, Y: 8
   - **Tamaño**: 80x80 (trompetas) / 80x80 (avatares - círculo) / 80x60 (fondos)
   - **Border radius**: 8px (trompetas/fondos) / circular (avatares)
   - **Texto**: "TRUMPET" / "AVATAR" / "BACKGROUND"

2. **Indicador de Estado** (si está obtenido)
   - **Tipo**: Icon
   - **Posición**: Esquina superior derecha
   - **Icono**: Check circle
   - **Color**: #4CAF50
   - **Tamaño**: 20x20

3. **Nombre del Objeto**
   - **Tipo**: Text
   - **Posición**: X: center, Y: 100
   - **Texto**: "Trompeta Dorada"
   - **Tamaño**: 10px, Bold
   - **Color**: #000000 / #666666 (si no está obtenido)
   - **Max lines**: 2
   - **Overflow**: Ellipsis

4. **Precio** (si no está obtenido)
   - **Tipo**: Container
   - **Posición**: X: center, Y: 120

   - **Icono Moneda**
     - **Tamaño**: 12x12

   - **Cantidad**
     - **Tipo**: Text
     - **Texto**: "500"
     - **Tamaño**: 10px, Bold
     - **Color**: #2196F3

### Botón "Ver Todos" (si hay más de 6 items)
- **Tipo**: Button
- **Posición**: X: 16, Y: 690
- **Tamaño**: 343x40
- **Texto**: "TODOS LAS TROMPETAS (15)"
- **Color de fondo**: #2196F3
- **Color de texto**: #FFFFFF
- **Border radius**: 12px
- **Tamaño de fuente**: 12px, Bold

### Divider
- **Tipo**: Line
- **Posición**: Y: 740
- **Tamaño**: 343x1
- **Color**: #E0E0E0

### Bottom Navigation (Game)
- **Tipo**: Bottom Navigation Bar
- **Posición**: X: 0, Y: 762
- **Tamaño**: 375x50
- **Color de fondo**: #2196F3

#### Items:
1. **Aprender** - Inactivo
2. **Música** - Inactivo
3. **Torneo** - Inactivo
4. **Objetos** - Activo (#FFD700)
5. **Perfil** - Inactivo

## Estados Visuales:

### Objeto No Obtenido:
- Border gris (#E0E0E0)
- Imagen en escala de grises o con opacidad reducida
- Muestra precio
- No tiene check icon

### Objeto Obtenido:
- Border verde (#4CAF50)
- Imagen a color completo
- Check icon verde en esquina
- No muestra precio

### Objeto Equipado (para avatares/fondos):
- Border azul doble (#2196F3)
- Badge "EQUIPADO" pequeño

## Notas de Diseño:
- Tap en objeto no obtenido → Diálogo de compra
- Tap en objeto obtenido → Diálogo de información/equipar
- Scroll horizontal para cambiar categorías
- Grid adaptativo según categoría (avatares más altos, fondos más anchos)
- Animaciones al obtener nuevo objeto
- Pull-to-refresh para sincronizar