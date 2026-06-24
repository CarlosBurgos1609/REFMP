# Mockup 6: Pantalla de Perfil del Juego (Game Profile Screen)

## Componentes en Balsamiq:

### Container Principal
- **Tipo**: Rectangle
- **Tamaño**: 375x812
- **Color de fondo**: Con wallpaper personalizado (si está configurado) o #F5F5F5

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
   - **Texto**: "Perfil - Trompeta"
   - **Color**: #FFFFFF
   - **Tamaño**: 18px, Bold

3. **Botón Configuración**
   - **Tipo**: Icon Button
   - **Posición**: X: 330, Y: 52
   - **Icono**: Settings
   - **Color**: #FFFFFF

### Información del Usuario
- **Tipo**: Card
- **Posición**: X: 16, Y: 120
- **Tamaño**: 343x120
- **Color de fondo**: #FFFFFF
- **Border radius**: 16px
- **Sombra**: Yes

#### Contenido de la Card:
1. **Avatar del Usuario**
   - **Tipo**: Circle Image
   - **Posición**: X: 24, Y: 135
   - **Tamaño**: 80x80
   - **Border**: 3px solid #2196F3
   - **Placeholder**: "USER AVATAR"

2. **Información Personal**
   - **Posición**: X: 120, Y: 135

   - **Nombre**
     - **Tipo**: Text
     - **Texto**: "Carlos Burgos"
     - **Tamaño**: 18px, Bold
     - **Color**: #000000

   - **Email**
     - **Tipo**: Text
     - **Texto**: "carlos@example.com"
     - **Tamaño**: 14px
     - **Color**: #666666

   - **Nickname**
     - **Tipo**: Text
     - **Texto**: "@carlosburgos"
     - **Tamaño**: 14px
     - **Color**: #2196F3

3. **Estadísticas Rápidas**
   - **Posición**: X: 120, Y: 190

   - **Puntos Totales**
     - **Tipo**: Text con Icon
     - **Icono**: Star
     - **Texto**: "2,450 pts"
     - **Tamaño**: 12px, Bold
     - **Color**: #FFD700

   - **Ranking**
     - **Tipo**: Text con Icon
     - **Icono**: Trophy
     - **Texto**: "Posición #5"
     - **Tamaño**: 12px, Bold
     - **Color**: #2196F3

### Progreso del Instrumento
- **Tipo**: Card
- **Posición**: X: 16, Y: 260
- **Tamaño**: 343x100
- **Color de fondo**: #FFFFFF
- **Border radius**: 16px

#### Contenido:
1. **Título**
   - **Tipo**: Text
   - **Posición**: X: 24, Y: 275
   - **Texto**: "Progreso en Trompeta"
   - **Tamaño**: 16px, Bold
   - **Color**: #2196F3

2. **Barra de Progreso**
   - **Tipo**: Progress Bar
   - **Posición**: X: 24, Y: 300
   - **Tamaño**: 295x8
   - **Progreso**: 65%
   - **Color de fondo**: #E0E0E0
   - **Color de progreso**: #4CAF50

3. **Texto de Progreso**
   - **Tipo**: Text
   - **Posición**: X: 24, Y: 320
   - **Texto**: "65% completado - Nivel Intermedio"
   - **Tamaño**: 12px
   - **Color**: #666666

4. **Canciones Completadas**
   - **Tipo**: Text
   - **Posición**: X: 24, Y: 335
   - **Texto**: "13 de 20 canciones dominadas"
   - **Tamaño**: 12px
   - **Color**: #4CAF50

### Estadísticas Detalladas
- **Tipo**: Grid Container
- **Posición**: X: 16, Y: 380
- **Tamaño**: 343x120
- **Columnas**: 2
- **Spacing**: 12px

#### Stat Card 1 - Tiempo de Juego
- **Tipo**: Rectangle
- **Tamaño**: 165x50
- **Color de fondo**: #E3F2FD
- **Border radius**: 12px

**Contenido:**
- **Icono**: Clock
- **Título**: "Tiempo Total"
- **Valor**: "24h 30m"
- **Color del valor**: #2196F3

#### Stat Card 2 - Sesiones
- **Tipo**: Rectangle
- **Tamaño**: 165x50
- **Color de fondo**: #E8F5E8
- **Border radius**: 12px

**Contenido:**
- **Icono**: Play circle
- **Título**: "Sesiones"
- **Valor**: "127"
- **Color del valor**: #4CAF50

#### Stat Card 3 - Racha
- **Tipo**: Rectangle
- **Tamaño**: 165x50
- **Color de fondo**: #FFF3E0
- **Border radius**: 12px

**Contenido:**
- **Icono**: Fire
- **Título**: "Racha Actual"
- **Valor**: "7 días"
- **Color del valor**: #FF9800

#### Stat Card 4 - Precisión
- **Tipo**: Rectangle
- **Tamaño**: 165x50
- **Color de fondo**: #F3E5F5
- **Border radius**: 12px

**Contenido:**
- **Icono**: Target
- **Título**: "Precisión Media"
- **Valor**: "87%"
- **Color del valor**: #9C27B0

### Acciones Rápidas
- **Tipo**: Container
- **Posición**: X: 16, Y: 520
- **Tamaño**: 343x80

#### Botones de Acción (2 en fila)
1. **Ver Mi Colección**
   - **Tipo**: Button
   - **Posición**: X: 16, Y: 520
   - **Tamaño**: 165x35
   - **Texto**: "Mi Colección"
   - **Color de fondo**: #2196F3
   - **Color de texto**: #FFFFFF
   - **Border radius**: 8px

2. **Cambiar Avatar**
   - **Tipo**: Button
   - **Posición**: X: 194, Y: 520
   - **Tamaño**: 165x35
   - **Texto**: "Cambiar Avatar"
   - **Color de fondo**: #4CAF50
   - **Color de texto**: #FFFFFF
   - **Border radius**: 8px

3. **Configurar Wallpaper**
   - **Tipo**: Button
   - **Posición**: X: 16, Y: 565
   - **Tamaño**: 165x35
   - **Texto**: "Wallpaper"
   - **Color de fondo**: #FF9800
   - **Color de texto**: #FFFFFF
   - **Border radius**: 8px

4. **Ver Logros**
   - **Tipo**: Button
   - **Posición**: X: 194, Y: 565
   - **Tamaño**: 165x35
   - **Texto**: "Mis Logros"
   - **Color de fondo**: #9C27B0
   - **Color de texto**: #FFFFFF
   - **Border radius**: 8px

### Últimos Logros
- **Tipo**: Container
- **Posición**: X: 16, Y: 620
- **Tamaño**: 343x100

#### Título
- **Tipo**: Text
- **Posición**: X: 16, Y: 620
- **Texto**: "Últimos Logros"
- **Tamaño**: 16px, Bold
- **Color**: #2196F3

#### Lista Horizontal de Logros
- **Tipo**: Horizontal Scrollable List
- **Posición**: X: 16, Y: 650
- **Tamaño**: 343x60

##### Item de Logro
- **Tipo**: Container
- **Tamaño**: 80x60
- **Margin right**: 8px

**Contenido:**
- **Badge del Logro**
  - **Tipo**: Circle Image
  - **Tamaño**: 40x40
  - **Border**: 2px solid #FFD700
  - **Placeholder**: "BADGE"

- **Nombre**
  - **Tipo**: Text
  - **Tamaño**: 10px
  - **Color**: #666666
  - **Max lines**: 2

### Bottom Navigation (Game)
- **Tipo**: Bottom Navigation Bar
- **Posición**: X: 0, Y: 762
- **Tamaño**: 375x50
- **Color de fondo**: #2196F3

#### Items:
1. **Aprender** - Inactivo
2. **Música** - Inactivo
3. **Torneo** - Inactivo
4. **Objetos** - Inactivo
5. **Perfil** - Activo (#FFD700)

## Notas de Diseño:
- El fondo puede cambiar según el wallpaper equipado
- Avatar circular con border del color del instrumento
- Estadísticas con iconos coloridos para mejor UX
- Botones de acción rápida para funciones frecuentes
- Scroll horizontal para ver más logros
- Pull-to-refresh para actualizar estadísticas