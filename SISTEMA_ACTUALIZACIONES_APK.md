# 🔄 Sistema de Actualización Automática

Sistema completo de actualizaciones automáticas con descarga e instalación de APK desde GitHub Releases.

## 📦 Dependencias Requeridas

Agrega estas dependencias en `pubspec.yaml`:

```yaml
dependencies:
  # Ya instaladas
  supabase_flutter: ^2.0.0
  package_info_plus: ^5.0.0
  url_launcher: ^6.2.0
  path_provider: ^2.1.0
  permission_handler: ^11.0.0

  # NUEVAS - Instalar con: flutter pub add <nombre>
  dio: ^5.4.0                    # Descarga de archivos con progreso
  install_plugin: ^2.1.0         # Instalación de APK en Android
  device_info_plus: ^9.1.0       # Info del dispositivo Android
```

Ejecuta:
```bash
flutter pub add dio install_plugin device_info_plus
flutter pub get
```

## ⚙️ Configuración de Android

### 1. Permisos en `android/app/src/main/AndroidManifest.xml`

Agrega estos permisos dentro de `<manifest>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Permisos para descarga e instalación de APK -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />

    <application
        ...
    >
        ...
    </application>
</manifest>
```

### 2. FileProvider en `android/app/src/main/AndroidManifest.xml`

Dentro de `<application>`, agrega:

```xml
<application>
    ...
    
    <!-- FileProvider para compartir archivos APK -->
    <provider
        android:name="androidx.core.content.FileProvider"
        android:authorities="${applicationId}.fileprovider"
        android:exported="false"
        android:grantUriPermissions="true">
        <meta-data
            android:name="android.support.FILE_PROVIDER_PATHS"
            android:resource="@xml/file_paths" />
    </provider>
    
</application>
```

### 3. Crear archivo `android/app/src/main/res/xml/file_paths.xml`

Crea el directorio `xml` si no existe y agrega:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-path name="external_files" path="." />
    <cache-path name="cache" path="." />
    <external-cache-path name="external_cache" path="." />
</paths>
```

### 4. Gradle (opcional - si tienes problemas de compilación)

En `android/app/build.gradle`, verifica:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

## 🗄️ Configuración de Base de Datos

### 1. Ejecutar script SQL

Ejecuta en Supabase SQL Editor:
```sql
-- Copiar contenido de: sql_triggers/app_version_table.sql
```

### 2. Insertar primera versión

```sql
INSERT INTO app_version (version, build_number, required, release_notes, android_url)
VALUES (
    '1.0.0',
    1,
    false,
    'Versión inicial de la aplicación',
    'https://github.com/usuario/repo/releases/download/v1.0.0/app-release.apk'
);
```

## 📤 Publicar Nueva Versión en GitHub

### 1. Compilar APK de Release

```bash
flutter build apk --release
```

El APK estará en: `build/app/outputs/flutter-apk/app-release.apk`

### 2. Crear Release en GitHub

1. Ve a tu repositorio en GitHub
2. Click en "Releases" → "Create a new release"
3. Tag: `v1.0.1` (nueva versión)
4. Título: `Versión 1.0.1`
5. Descripción: Changelog de la versión
6. **Arrastra el archivo `app-release.apk`**
7. Click en "Publish release"

### 3. Obtener URL del APK

Después de publicar, haz click derecho en el APK y copia la URL:
```
https://github.com/usuario/repo/releases/download/v1.0.1/app-release.apk
```

### 4. Registrar en Supabase

```sql
INSERT INTO app_version (version, build_number, required, release_notes, android_url)
VALUES (
    '1.0.1',
    2, -- Incrementar build_number
    false, -- O true si es obligatoria
    '- Corrección de errores\n- Sistema de logros\n- Mejoras de rendimiento',
    'https://github.com/usuario/repo/releases/download/v1.0.1/app-release.apk'
);
```

## 🎯 Flujo de Actualización

```
Usuario abre ajustes
    ↓
Toca "Buscar actualizaciones"
    ↓
App consulta tabla app_version en Supabase
    ↓
Compara build_number actual vs disponible
    ↓
Si hay nueva versión:
    ↓
Muestra diálogo con changelog
    ↓
Usuario acepta actualizar
    ↓
Detecta si es APK directo (.apk) o tienda
    ↓
Si es APK directo:
  → Descarga con progreso (Dio)
  → Solicita permiso de instalación
  → Instala automáticamente (InstallPlugin)
    ↓
Si es tienda:
  → Abre Google Play/App Store
```

## 🔒 Actualizaciones Obligatorias

Para forzar una actualización:

```sql
UPDATE app_version 
SET required = true 
WHERE build_number = 2;
```

En actualización obligatoria:
- ❌ No se puede cerrar el diálogo
- ❌ No hay botón "Más tarde"
- ⚠️ Mensaje de advertencia naranja

## 📱 Permisos en Tiempo Real

El sistema maneja automáticamente:
- ✅ Permiso de instalación (Android 8.0+)
- ✅ Permisos de almacenamiento
- ✅ Abre configuración si está denegado permanentemente

## 🐛 Debugging

Logs útiles en consola:
```
📱 Versión actual: 1.0.0+1
☁️ Versión disponible: 1.0.1+2
📥 Descargando APK desde: https://...
💾 Guardando en: /storage/...
📊 Progreso: 45%
✅ Descarga completada
📦 Tamaño del archivo: 25.3 MB
📲 Instalando APK
✅ Instalación iniciada
```

## 🚨 Solución de Problemas

### Error: "La tabla app_version no existe"
```bash
# Ejecutar script SQL en Supabase
sql_triggers/app_version_table.sql
```

### Error: "Sin permisos RLS"
```sql
-- Habilitar Row Level Security en Supabase
ALTER TABLE app_version ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read app versions"
ON app_version FOR SELECT
USING (true);
```

### Error al instalar APK
- Verifica permisos en AndroidManifest.xml
- Verifica FileProvider configurado
- Verifica que el APK está completo (tamaño correcto)

### APK no descarga
- Verifica que la URL es pública (GitHub Release)
- Verifica conexión a internet
- Verifica que el enlace termina en `.apk`

## 📊 Incrementar Build Number

En `pubspec.yaml`, incrementa el número después del `+`:

```yaml
version: 1.0.1+2  # ← Incrementar este número
```

Luego:
```bash
flutter clean
flutter build apk --release
```

## 🔐 Seguridad

### Verificación de integridad (opcional)

Para mayor seguridad, puedes agregar hash SHA-256:

```sql
ALTER TABLE app_version ADD COLUMN apk_sha256 text;

-- Al insertar
INSERT INTO app_version (version, build_number, android_url, apk_sha256)
VALUES ('1.0.1', 2, 'URL', 'hash_sha256_del_apk');
```

## 📚 Recursos

- **Código:** `lib/interfaces/menu/settings.dart`
- **SQL:** `sql_triggers/app_version_table.sql`
- **Tabla:** `public.app_version`
- **Permisos:** `android/app/src/main/AndroidManifest.xml`

## ✅ Checklist de Implementación

- [ ] Instalar dependencias: `dio`, `install_plugin`, `device_info_plus`
- [ ] Configurar permisos en AndroidManifest.xml
- [ ] Crear FileProvider y file_paths.xml
- [ ] Ejecutar script SQL en Supabase
- [ ] Crear primer release en GitHub
- [ ] Registrar versión en app_version
- [ ] Probar actualización en dispositivo real
- [ ] Incrementar build_number antes de cada release

---

**Última actualización:** 10 de marzo de 2026  
**Versión del sistema:** 1.0.0
