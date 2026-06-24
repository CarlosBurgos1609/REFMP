# Mockup 9: Diálogos y Modales (Dialogs and Modals)

## 1. Diálogo de Compra de Objeto

### Modal Principal
- **Tipo**: Dialog/Modal
- **Tamaño**: 320x400
- **Color de fondo**: #FFFFFF
- **Border radius**: 20px
- **Sombra**: Yes

#### Contenido:
1. **Botón Cerrar**
   - **Tipo**: Icon Button
   - **Posición**: Esquina superior derecha
   - **Icono**: Close (X)
   - **Color**: #666666

2. **Imagen del Objeto**
   - **Tipo**: Image placeholder
   - **Posición**: Center X, Y: 40
   - **Tamaño**: 120x120
   - **Border radius**: 12px
   - **Texto**: "GOLDEN TRUMPET"

3. **Nombre del Objeto**
   - **Tipo**: Text
   - **Posición**: Center X, Y: 180
   - **Texto**: "Trompeta Dorada"
   - **Tamaño**: 20px, Bold
   - **Color**: #2196F3

4. **Descripción**
   - **Tipo**: Text Block
   - **Posición**: X: 24, Y: 210
   - **Tamaño**: 272x60
   - **Texto**: "Una hermosa trompeta dorada que te permitirá destacar en tus interpretaciones. Aumenta tu puntuación en un 10%."
   - **Tamaño**: 14px
   - **Color**: #666666
   - **Alineación**: Center

5. **Precio**
   - **Tipo**: Container
   - **Posición**: Center X, Y: 290

   - **Icono Moneda**
     - **Tamaño**: 24x24

   - **Cantidad**
     - **Texto**: "500"
     - **Tamaño**: 24px, Bold
     - **Color**: #2196F3

6. **Saldo Actual**
   - **Tipo**: Text
   - **Posición**: Center X, Y: 320
   - **Texto**: "Tu saldo: 1,250 monedas"
   - **Tamaño**: 12px
   - **Color**: #666666

7. **Botones de Acción**
   - **Posición**: Y: 350

   - **Botón Cancelar**
     - **Tipo**: Button
     - **Posición**: X: 40, Y: 350
     - **Tamaño**: 100x40
     - **Texto**: "Cancelar"
     - **Color de fondo**: Transparente
     - **Color de texto**: #F44336
     - **Border**: 1px solid #F44336

   - **Botón Comprar**
     - **Tipo**: Button
     - **Posición**: X: 180, Y: 350
     - **Tamaño**: 100x40
     - **Texto**: "Comprar"
     - **Color de fondo**: #4CAF50
     - **Color de texto**: #FFFFFF

## 2. Diálogo de Filtros (Música)

### Modal de Filtros
- **Tipo**: Dialog/Modal
- **Tamaño**: 300x200
- **Color de fondo**: #FFFFFF
- **Border radius**: 20px

#### Contenido:
1. **Título**
   - **Tipo**: Text
   - **Posición**: X: 24, Y: 20
   - **Texto**: "Filtrar Canciones"
   - **Tamaño**: 18px, Bold
   - **Color**: #2196F3

2. **Label Dificultad**
   - **Tipo**: Text
   - **Posición**: X: 24, Y: 60
   - **Texto**: "Dificultad:"
   - **Tamaño**: 14px
   - **Color**: #666666

3. **Dropdown Dificultad**
   - **Tipo**: Dropdown/Select
   - **Posición**: X: 24, Y: 85
   - **Tamaño**: 252x40
   - **Border**: 1px solid #E0E0E0
   - **Border radius**: 8px

   **Opciones:**
   - "Todas las dificultades"
   - "Principiante"
   - "Intermedio"
   - "Avanzado"
   - "Experto"

4. **Botones de Acción**
   - **Posición**: Y: 145

   - **Botón Cancelar**
     - **Tipo**: Button
     - **Posición**: X: 50, Y: 145
     - **Tamaño**: 80x35
     - **Texto**: "Cancelar"
     - **Color de fondo**: Transparente
     - **Color de texto**: #F44336

   - **Botón Aplicar**
     - **Tipo**: Button
     - **Posición**: X: 170, Y: 145
     - **Tamaño**: 80x35
     - **Texto**: "Aplicar"
     - **Color de fondo**: #2196F3
     - **Color de texto**: #FFFFFF

## 3. Diálogo de Confirmación de Salida

### Modal de Salida
- **Tipo**: Dialog/Modal
- **Tamaño**: 300x180
- **Color de fondo**: #FFFFFF
- **Border radius**: 20px

#### Contenido:
1. **Icono de Advertencia**
   - **Tipo**: Icon
   - **Posición**: Center X, Y: 20
   - **Icono**: Warning
   - **Color**: #FF9800
   - **Tamaño**: 48x48

2. **Título**
   - **Tipo**: Text
   - **Posición**: Center X, Y: 80
   - **Texto**: "¿Deseas salir de la aplicación?"
   - **Tamaño**: 16px, Bold
   - **Color**: #000000
   - **Alineación**: Center

3. **Botones de Acción**
   - **Posición**: Y: 120

   - **Botón Cancelar**
     - **Tipo**: Button
     - **Posición**: X: 50, Y: 120
     - **Tamaño**: 80x35
     - **Texto**: "Cancelar"
     - **Color de fondo**: Transparente
     - **Color de texto**: #666666

   - **Botón Salir**
     - **Tipo**: Button
     - **Posición**: X: 170, Y: 120
     - **Tamaño**: 80x35
     - **Texto**: "Salir"
     - **Color de fondo**: #F44336
     - **Color de texto**: #FFFFFF

## 4. Snackbar de Notificaciones

### Snackbar de Éxito
- **Tipo**: Rectangle
- **Posición**: X: 16, Y: 730 (bottom of screen)
- **Tamaño**: 343x50
- **Color de fondo**: #4CAF50
- **Border radius**: 8px

#### Contenido:
1. **Icono Éxito**
   - **Tipo**: Icon
   - **Posición**: X: 16, Y: center
   - **Icono**: Check circle
   - **Color**: #FFFFFF
   - **Tamaño**: 20x20

2. **Mensaje**
   - **Tipo**: Text
   - **Posición**: X: 48, Y: center
   - **Texto**: "¡Objeto comprado exitosamente!"
   - **Tamaño**: 14px
   - **Color**: #FFFFFF

3. **Botón Cerrar**
   - **Tipo**: Icon Button
   - **Posición**: X: 310, Y: center
   - **Icono**: Close
   - **Color**: #FFFFFF
   - **Tamaño**: 16x16

### Snackbar de Error
- **Tipo**: Rectangle
- **Posición**: X: 16, Y: 730
- **Tamaño**: 343x50
- **Color de fondo**: #F44336
- **Border radius**: 8px

#### Contenido similar pero con:
- **Icono**: Error icon
- **Mensaje**: "Error: No tienes suficientes monedas"

### Snackbar de Información
- **Tipo**: Rectangle
- **Posición**: X: 16, Y: 730
- **Tamaño**: 343x50
- **Color de fondo**: #2196F3
- **Border radius**: 8px

#### Contenido similar pero con:
- **Icono**: Info icon
- **Mensaje**: "Sincronizando datos..."

## 5. Bottom Sheet - Opciones de Objeto

### Bottom Sheet
- **Tipo**: Container
- **Posición**: X: 0, Y: 600 (slide up from bottom)
- **Tamaño**: 375x212
- **Color de fondo**: #FFFFFF
- **Border radius superior**: 20px

#### Contenido:
1. **Handle**
   - **Tipo**: Rectangle
   - **Posición**: Center X, Y: 8
   - **Tamaño**: 40x4
   - **Color**: #E0E0E0
   - **Border radius**: 2px

2. **Imagen y Nombre del Objeto**
   - **Posición**: X: 24, Y: 32

   - **Imagen**
     - **Tipo**: Image
     - **Tamaño**: 60x60
     - **Border radius**: 8px

   - **Nombre**
     - **Tipo**: Text
     - **Posición**: X: 100, Y: 40
     - **Texto**: "Trompeta Dorada"
     - **Tamaño**: 16px, Bold

   - **Estado**
     - **Tipo**: Text
     - **Posición**: X: 100, Y: 65
     - **Texto**: "Equipado"
     - **Tamaño**: 12px
     - **Color**: #4CAF50

3. **Opciones de Acción**
   - **Posición**: Y: 120

   - **Equipar/Desequipar**
     - **Tipo**: Button
     - **Tamaño**: 327x40
     - **Texto**: "Desequipar" / "Equipar"
     - **Color**: #2196F3

   - **Ver Detalles**
     - **Tipo**: Button
     - **Tamaño**: 327x40
     - **Texto**: "Ver Detalles"
     - **Color**: #666666

## Notas de Diseño:
- Todos los modales deben tener overlay semi-transparente
- Animaciones de entrada/salida suaves
- Los snackbars se auto-ocultan después de 3-4 segundos
- Los bottom sheets se pueden cerrar arrastrando hacia abajo
- Botones con estados de loading cuando es necesario
- Validaciones antes de acciones destructivas