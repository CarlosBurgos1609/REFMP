# Mockup 4: Pantalla de Torneo (Tournament Screen)

## Componentes en Balsamiq:

### Container Principal
- **Tipo**: Rectangle
- **Tamaño**: 375x812
- **Color de fondo**: #F5F5F5

### Sliver App Bar (Expandible)
- **Tipo**: Expandable Header
- **Altura expandida**: 350px
- **Altura colapsada**: 100px

#### Background Image
- **Tipo**: Image placeholder
- **Tamaño**: 375x350
- **Texto**: "TOURNAMENT BACKGROUND"
- **Fit**: Cover
- **Overlay**: Semi-transparente

#### Contenido del Header:
1. **Botón Atrás**
   - **Tipo**: Icon Button
   - **Posición**: X: 8, Y: 52
   - **Icono**: Arrow back
   - **Color**: #FFFFFF
   - **Sombra**: Yes

2. **Título "Torneo"**
   - **Tipo**: Text
   - **Posición**: Center X, Y: 280 (cuando expandido)
   - **Texto**: "Torneo"
   - **Color**: #FFFFFF
   - **Tamaño**: 18px, Bold
   - **Sombra**: Yes

### Sección de Información
- **Tipo**: Container
- **Posición**: X: 16, Y: 370
- **Tamaño**: 343x100

#### Mi Posición
- **Tipo**: Card
- **Tamaño**: 343x45
- **Color de fondo**: #E3F2FD
- **Border**: 2px solid #2196F3
- **Border radius**: 12px

**Contenido:**
1. **Ranking**
   - **Tipo**: Text
   - **Posición**: X: 16, Y: center
   - **Texto**: "#5"
   - **Tamaño**: 18px, Bold
   - **Color**: #2196F3

2. **Avatar**
   - **Tipo**: Circle Image
   - **Posición**: X: 50, Y: center
   - **Tamaño**: 30x30
   - **Border**: 2px solid #2196F3

3. **Nickname**
   - **Tipo**: Text
   - **Posición**: X: 90, Y: center
   - **Texto**: "Mi Usuario"
   - **Tamaño**: 16px, Bold
   - **Color**: #2196F3

4. **Puntos**
   - **Tipo**: Text
   - **Posición**: X: 280, Y: center
   - **Texto**: "1,250 pts"
   - **Tamaño**: 16px, Bold
   - **Color**: #2196F3

### Sección Top 3
- **Tipo**: Container
- **Posición**: X: 16, Y: 485
- **Tamaño**: 343x120

#### Podio Visual
1. **Primer Lugar** (Centro)
   - **Tipo**: Container
   - **Posición**: X: center, Y: 485
   - **Tamaño**: 100x120

   - **Trophy Icon**
     - **Tipo**: Icon
     - **Icono**: Trophy
     - **Color**: #FFD700 (dorado)
     - **Tamaño**: 32x32

   - **Posición "1°"**
     - **Tipo**: Text
     - **Texto**: "1°"
     - **Tamaño**: 18px, Bold
     - **Color**: #FFD700

   - **Avatar**
     - **Tipo**: Circle Image
     - **Tamaño**: 40x40
     - **Border**: 2px solid #FFD700

   - **Object Preview**
     - **Tipo**: Small Image
     - **Tamaño**: 30x30
     - **Border radius**: 8px

2. **Segundo Lugar** (Izquierda)
   - **Similar al primero pero:**
   - **Color**: #C0C0C0 (plata)
   - **Posición**: Izquierda del centro

3. **Tercer Lugar** (Derecha)
   - **Similar al primero pero:**
   - **Color**: #CD7F32 (bronce)
   - **Posición**: Derecha del centro

### Lista de Participantes
- **Tipo**: Scrollable List
- **Posición**: X: 16, Y: 620
- **Tamaño**: 343x120

#### Item de Participante
- **Tipo**: Rectangle
- **Tamaño**: 343x50
- **Color de fondo**: #FFFFFF
- **Border**: 1px solid #E0E0E0 (normal) / 2px solid #2196F3 (usuario actual)
- **Border radius**: 12px
- **Margin bottom**: 4px

**Contenido:**
1. **Ranking**
   - **Tipo**: Text
   - **Posición**: X: 16, Y: center
   - **Texto**: "#4"
   - **Tamaño**: 16px, Bold
   - **Color**: #666666

2. **Avatar**
   - **Tipo**: Circle Image
   - **Posición**: X: 50, Y: center
   - **Tamaño**: 30x30

3. **Nickname**
   - **Tipo**: Text (con Marquee si es muy largo)
   - **Posición**: X: 90, Y: center
   - **Texto**: "Usuario123"
   - **Tamaño**: 14px
   - **Color**: #000000

4. **Puntos**
   - **Tipo**: Text
   - **Posición**: X: 280, Y: center
   - **Texto**: "980 pts"
   - **Tamaño**: 14px, Bold
   - **Color**: #2196F3

### Bottom Navigation (Game)
- **Tipo**: Bottom Navigation Bar
- **Posición**: X: 0, Y: 762
- **Tamaño**: 375x50
- **Color de fondo**: #2196F3

#### Items:
1. **Aprender** - Inactivo
2. **Música** - Inactivo
3. **Torneo** - Activo (#FFD700)
4. **Objetos** - Inactivo
5. **Perfil** - Inactivo

## Notas de Diseño:
- Pull-to-refresh para actualizar rankings
- Scroll infinito si hay muchos participantes
- Animaciones al cambiar posiciones
- El header se colapsa al hacer scroll
- Destacar visualmente al usuario actual
- Los objetos del top 3 son los premios que recibirán
- Nicknames largos usan animación marquee