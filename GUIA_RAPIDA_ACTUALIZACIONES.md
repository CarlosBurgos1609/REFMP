# ⚡ Guía Rápida - Sistema de Actualizaciones

## 📥 Instalación (5 minutos)

### 1. Instalar dependencias

```bash
flutter pub add dio install_plugin device_info_plus
flutter pub get
```

### 2. Configurar Android

Abre `android/app/src/main/AndroidManifest.xml` y agrega DENTRO de `<manifest>`:

```xml
<!-- PERMISOS -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

Dentro de `<application>`, agrega:

```xml
<!-- FILE PROVIDER -->
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

El archivo `file_paths.xml` ya está creado en:
`android/app/src/main/res/xml/file_paths.xml`

### 3. Crear tabla en Supabase

Copia y ejecuta en **Supabase SQL Editor**:

```bash
sql_triggers/app_version_table.sql
```

✅ ¡Listo! Ya está configurado.

---

## 🚀 Uso - Publicar Nueva Versión

### Paso 1: Compilar APK

```bash
flutter build apk --release
```

### Paso 2: Subir a GitHub

1. Ve a tu repositorio → **Releases** → **Create a new release**
2. Tag: `v1.0.1`
3. Título: `Versión 1.0.1`
4. **Arrastra el APK** desde: `build/app/outputs/flutter-apk/app-release.apk`
5. Click **Publish release**

### Paso 3: Copiar URL del APK

Después de publicar, **click derecho** en el APK → **Copiar enlace**

Ejemplo:
```
https://github.com/usuario/repo/releases/download/v1.0.1/app-release.apk
```

### Paso 4: Registrar en Supabase

Ejecuta en **Supabase SQL Editor** (reemplaza los valores):

```sql
INSERT INTO app_version (version, build_number, required, release_notes, android_url)
VALUES (
    '1.0.1',                    -- Nueva versión
    2,                          -- Build number (incrementar)
    false,                      -- true = obligatoria
    '- Corrección de errores
- Nuevas funcionalidades
- Mejoras de rendimiento',
    'URL_DEL_APK_DE_GITHUB'     -- URL copiada en paso 3
);
```

✅ **¡Listo!** Los usuarios verán la actualización en **Ajustes → Buscar actualizaciones**

---

## 🔥 Tips Rápidos

### 💡 Build Number
Incrementa el número después del `+` en `pubspec.yaml`:

```yaml
version: 1.0.1+2  # ← Este número
```

### 💡 Actualización Obligatoria
Cambia `required` a `true` en el SQL:

```sql
required: true  -- Usuarios no pueden omitir
```

### 💡 Verificar Versión Actual
En la app:
**Ajustes → Buscar actualizaciones → Ver versión actual**

### 💡 Automatizar
Usa el script:

```bash
chmod +x create_release.sh
./create_release.sh 1.0.1 2
```

---

## 🐛 Problemas Comunes

| Error | Solución |
|-------|----------|
| "Tabla app_version no existe" | Ejecutar `sql_triggers/app_version_table.sql` |
| "Error al instalar APK" | Verificar permisos en AndroidManifest.xml |
| "No puede descargar" | Verificar que URL termine en `.apk` |
| APK no instala | Verificar FileProvider configurado |

---

## 📚 Más Info

- 📖 Guía completa: `SISTEMA_ACTUALIZACIONES_APK.md`
- 🔧 Código: `lib/interfaces/menu/settings.dart`
- 🗄️ SQL: `sql_triggers/app_version_table.sql`

---

**¿Necesitas ayuda?** Lee la documentación completa en `SISTEMA_ACTUALIZACIONES_APK.md`
