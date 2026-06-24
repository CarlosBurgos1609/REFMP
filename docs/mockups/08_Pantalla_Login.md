# Mockup 8: Pantalla de Login (Login Screen)

## Componentes en Balsamiq:

### Container Principal
- **Tipo**: Rectangle
- **Tamaño**: 375x812
- **Color de fondo**: #FFFFFF

### Elemento Decorativo Superior
- **Tipo**: Circle
- **Posición**: Esquina superior izquierda (parcialmente fuera)
- **Tamaño**: 300x300
- **Color**: #2196F3
- **Posición X**: -100
- **Posición Y**: -80

### Logo
- **Tipo**: Image placeholder
- **Posición**: Center X, Y: 120
- **Tamaño**: 200x80
- **Texto**: "LOGO REFMP"
- **Border radius**: 12px

### Título
- **Tipo**: Text
- **Posición**: Center X, Y: 220
- **Texto**: "Iniciar Sesión"
- **Tamaño**: 28px, Bold
- **Color**: #2196F3

### Formulario de Login
- **Tipo**: Container
- **Posición**: X: 32, Y: 280
- **Tamaño**: 311x200

#### Campo Email
- **Tipo**: Text Input
- **Posición**: X: 32, Y: 280
- **Tamaño**: 311x50
- **Placeholder**: "Correo electrónico"
- **Border**: 2px solid #E0E0E0
- **Border radius**: 12px
- **Icono izquierdo**: Email icon

#### Campo Contraseña
- **Tipo**: Text Input
- **Posición**: X: 32, Y: 345
- **Tamaño**: 311x50
- **Placeholder**: "Contraseña"
- **Type**: Password
- **Border**: 2px solid #E0E0E0
- **Border radius**: 12px
- **Icono izquierdo**: Lock icon
- **Icono derecho**: Eye icon (mostrar/ocultar)

#### Checkbox "Recordarme"
- **Tipo**: Checkbox
- **Posición**: X: 32, Y: 410
- **Texto**: "Recordarme"
- **Tamaño**: 14px
- **Color**: #666666

#### Link "¿Olvidaste tu contraseña?"
- **Tipo**: Link
- **Posición**: X: 200, Y: 410
- **Texto**: "¿Olvidaste tu contraseña?"
- **Tamaño**: 12px
- **Color**: #2196F3
- **Underline**: Yes

### Botón de Login
- **Tipo**: Button
- **Posición**: X: 32, Y: 450
- **Tamaño**: 311x50
- **Texto**: "INICIAR SESIÓN"
- **Color de fondo**: #2196F3
- **Color de texto**: #FFFFFF
- **Border radius**: 12px
- **Tamaño de fuente**: 16px, Bold

### Divider con Texto
- **Tipo**: Container
- **Posición**: X: 32, Y: 520
- **Tamaño**: 311x30

#### Líneas y Texto "O"
1. **Línea Izquierda**
   - **Tipo**: Line
   - **Posición**: X: 32, Y: 535
   - **Tamaño**: 130x1
   - **Color**: #E0E0E0

2. **Texto "O"**
   - **Tipo**: Text
   - **Posición**: Center X, Y: 530
   - **Texto**: "O"
   - **Tamaño**: 14px
   - **Color**: #666666
   - **Background**: #FFFFFF (para cubrir la línea)

3. **Línea Derecha**
   - **Tipo**: Line
   - **Posición**: X: 213, Y: 535
   - **Tamaño**: 130x1
   - **Color**: #E0E0E0

### Botones de Login Social
- **Tipo**: Container
- **Posición**: X: 32, Y: 570
- **Tamaño**: 311x110

#### Botón Google
- **Tipo**: Button
- **Posición**: X: 32, Y: 570
- **Tamaño**: 311x45
- **Color de fondo**: #FFFFFF
- **Border**: 2px solid #E0E0E0
- **Border radius**: 12px

**Contenido:**
- **Icono Google**
  - **Posición**: X: 50, Y: center
  - **Tamaño**: 24x24

- **Texto**
  - **Posición**: Center X, Y: center
  - **Texto**: "Continuar con Google"
  - **Tamaño**: 14px
  - **Color**: #666666

#### Botón Facebook
- **Tipo**: Button
- **Posición**: X: 32, Y: 625
- **Tamaño**: 311x45
- **Color de fondo**: #4267B2
- **Border radius**: 12px

**Contenido:**
- **Icono Facebook**
  - **Posición**: X: 50, Y: center
  - **Tamaño**: 24x24
  - **Color**: #FFFFFF

- **Texto**
  - **Posición**: Center X, Y: center
  - **Texto**: "Continuar con Facebook"
  - **Tamaño**: 14px
  - **Color**: #FFFFFF

### Footer
- **Tipo**: Container
- **Posición**: X: 32, Y: 720
- **Tamaño**: 311x50

#### Texto de Registro
- **Tipo**: Text
- **Posición**: Center X, Y: 730
- **Texto**: "¿No tienes cuenta?"
- **Tamaño**: 14px
- **Color**: #666666

#### Link de Registro
- **Tipo**: Link
- **Posición**: Center X, Y: 750
- **Texto**: "Regístrate aquí"
- **Tamaño**: 14px, Bold
- **Color**: #2196F3
- **Underline**: Yes

## Estados del Formulario:

### Estado Normal:
- Campos con border gris claro
- Botón de login azul habilitado

### Estado de Error:
- Campo con error: border rojo (#F44336)
- Mensaje de error debajo del campo en rojo
- Ejemplo: "El correo electrónico no es válido"

### Estado de Loading:
- Botón de login con spinner
- Texto: "INICIANDO SESIÓN..."
- Campos deshabilitados

### Estado de Éxito:
- Transición a la pantalla de inicio
- Animación de fade out

## Notas de Diseño:
- El círculo azul debe estar parcialmente cortado
- Campos de texto con iconos para mejor UX
- Validación en tiempo real de campos
- Animaciones suaves al cambiar estados
- Responsive para diferentes tamaños de pantalla
- El campo de contraseña debe tener toggle para mostrar/ocultar
- Auto-focus en el primer campo al cargar la pantalla