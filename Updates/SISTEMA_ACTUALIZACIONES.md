# Sistema de Actualización de la Aplicación

Este sistema permite verificar y notificar a los usuarios cuando hay una nueva versión de la aplicación disponible.

## 📋 Configuración Inicial

### 1. Crear la tabla en Supabase

Ejecuta el script SQL ubicado en: `sql_triggers/app_version_table.sql`

Este script creará:
- Tabla `app_version` con la estructura necesaria
- Índices para búsquedas eficientes
- Trigger para actualizar timestamps automáticamente
- Un registro inicial de ejemplo

### 2. Configurar URLs de las tiendas

#### Para Android (Google Play Store):
```
https://play.google.com/store/apps/details?id=TU_PACKAGE_NAME
```
Reemplaza `TU_PACKAGE_NAME` con el nombre de tu paquete (ej: `com.refmp.app`)

#### Para iOS (App Store):
```
https://apps.apple.com/app/idTU_APP_ID
```
Reemplaza `TU_APP_ID` con el ID de tu app en App Store

### 3. Permisos en Supabase

Asegúrate de que la tabla `app_version` tenga permisos de lectura para usuarios autenticados:

```sql
-- Política de lectura para usuarios autenticados
CREATE POLICY "Usuarios pueden leer versiones"
ON app_version
FOR SELECT
TO authenticated
USING (true);
```

## 🚀 Cómo Publicar una Nueva Versión

### 1. Actualizar version en pubspec.yaml

```yaml
version: 1.0.1+2  # versión+buildNumber
```

- **version**: Versión semántica (1.0.1)
- **buildNumber**: Número incremental único (2, 3, 4...)

### 2. Insertar nueva versión en Supabase

```sql
INSERT INTO app_version (
    version, 
    build_number, 
    required, 
    release_notes, 
    android_url, 
    ios_url
)
VALUES (
    '1.0.1',  -- Nueva versión
    2,         -- Nuevo build number (debe ser mayor que el anterior)
    false,     -- true si es actualización obligatoria
    '- Corrección de errores
- Mejoras de rendimiento
- Nueva funcionalidad X',
    'https://play.google.com/store/apps/details?id=tu.paquete.app',
    'https://apps.apple.com/app/idTU_APP_ID'
);
```

### 3. Compilar y publicar la app

```bash
# Para Android
flutter build apk --release
# o
flutter build appbundle --release

# Para iOS
flutter build ios --release
```

## 📱 Cómo Funciona

### Para el Usuario:

1. El usuario va a **Configuración** → **Buscar actualizaciones**
2. La app verifica en Supabase si hay una versión más reciente
3. Si hay actualización disponible:
   - Muestra un diálogo con detalles de la nueva versión
   - Permite actualizar o recordar más tarde
   - Si es **obligatoria**, no se puede cerrar el diálogo
4. Al tocar "Actualizar", abre la tienda correspondiente (Play Store o App Store)

### Verificación Automática (Opcional):

Puedes agregar verificación automática al iniciar la app:

```dart
// En tu init.dart o main.dart
@override
void initState() {
  super.initState();
  // Verificar actualizaciones al iniciar (sin mostrar diálogo si está actualizado)
  _checkForUpdatesOnStartup();
}

Future<void> _checkForUpdatesOnStartup() async {
  // Esperar un poco para no interferir con la carga inicial
  await Future.delayed(Duration(seconds: 3));
  // Verificar sin mostrar diálogo de "ya está actualizado"
  _checkForUpdates(showNoUpdateDialog: false);
}
```

## 🔧 Tipos de Actualización

### Actualización Opcional (recommended: false)
- El usuario puede elegir "Más tarde"
- Puede seguir usando la app sin actualizar
- Útil para mejoras menores o nuevas características

### Actualización Obligatoria (recommended: true)
- El usuario NO puede cerrar el diálogo
- Debe actualizar para continuar usando la app
- Útil para correcciones críticas de seguridad o cambios importantes

## 📊 Estructura de la Tabla

```sql
CREATE TABLE app_version (
    id UUID PRIMARY KEY,
    version VARCHAR(20),           -- "1.0.1"
    build_number INTEGER UNIQUE,   -- 2, 3, 4...
    required BOOLEAN,              -- true/false
    release_notes TEXT,            -- Changelog
    android_url TEXT,              -- URL Play Store
    ios_url TEXT,                  -- URL App Store
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

## 🎯 Ejemplos de Release Notes

```text
Versión 1.0.1:
- Corrección de bugs en el juego educativo
- Mejoras de rendimiento en la carga de partituras
- Nuevos ejercicios de trompeta
- Corrección del sistema de notificaciones

Versión 1.1.0:
- ¡Nueva sección de estadísticas!
- Modo oscuro mejorado
- Sincronización más rápida
- Correcciones menores
```

## 🔐 Seguridad

- Solo usuarios autenticados pueden leer la tabla `app_version`
- Las URLs de las tiendas son públicas (no contienen información sensible)
- El sistema solo lee datos, no modifica nada en el cliente

## 📝 Notas Importantes

1. **Build Number**: Siempre debe ser incremental y único
2. **Versión en pubspec.yaml**: Debe coincidir con la versión en Supabase
3. **URLs**: Actualiza las URLs con los IDs reales de tu app
4. **Testing**: Prueba con una versión de prueba antes de publicar

## 🐛 Troubleshooting

### "No se puede abrir la tienda"
- Verifica que las URLs sean correctas
- Asegúrate de que el package `url_launcher` esté instalado
- Revisa los permisos de Internet en AndroidManifest.xml

### "Error al verificar actualizaciones"
- Verifica la conexión a Internet
- Confirma que la tabla exista en Supabase
- Revisa los permisos de lectura en Supabase

### La app no detecta la actualización
- Verifica que el `build_number` en Supabase sea mayor
- Confirma que la versión en pubspec.yaml sea correcta
- Limpia y reconstruye la app: `flutter clean && flutter pub get`

## 🔄 Flujo Completo

```
1. Desarrollador actualiza código
   ↓
2. Incrementa version en pubspec.yaml (1.0.1+2)
   ↓
3. Compila nueva versión de la app
   ↓
4. Publica en Play Store / App Store
   ↓
5. Inserta nuevo registro en tabla app_version
   ↓
6. Usuario abre la app
   ↓
7. Usuario busca actualizaciones en Configuración
   ↓
8. Sistema compara build_number local vs remoto
   ↓
9. Si hay nueva versión, muestra diálogo
   ↓
10. Usuario toca "Actualizar"
   ↓
11. Se abre la tienda correspondiente
   ↓
12. Usuario descarga e instala actualización
```

## 📦 Dependencias Requeridas

```yaml
dependencies:
  package_info_plus: ^8.1.2  # Obtener versión actual
  url_launcher: ^6.3.1       # Abrir tiendas
  supabase_flutter: ^2.8.3   # Consultar actualizaciones
```

---

¿Necesitas ayuda? Revisa los logs en debug para más información sobre el proceso de actualización.
