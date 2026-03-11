# ✅ Checklist de Verificación - Sistema de Actualizaciones

## 📋 Antes de la Primera Actualización

### Configuración Inicial

- [ ] **Dependencias instaladas**
  ```bash
  flutter pub add dio install_plugin device_info_plus
  flutter pub get
  ```

- [ ] **AndroidManifest.xml configurado**
  - [ ] Permisos agregados (INTERNET, STORAGE, REQUEST_INSTALL_PACKAGES)
  - [ ] FileProvider agregado dentro de `<application>`
  - [ ] Autoridad correcta: `${applicationId}.fileprovider`

- [ ] **file_paths.xml creado**
  - [ ] Ubicación: `android/app/src/main/res/xml/file_paths.xml`
  - [ ] Contiene paths: external-path, cache-path, external-cache-path

- [ ] **Tabla en Supabase**
  - [ ] Script SQL ejecutado: `sql_triggers/app_version_table.sql`
  - [ ] Tabla `app_version` existe y es accesible
  - [ ] RLS configurado (lectura pública habilitada)

- [ ] **Versión inicial registrada**
  ```sql
  SELECT * FROM app_version;
  -- Debe haber al menos 1 registro
  ```

---

## 🚀 Checklist por Cada Nueva Versión

### Antes de Compilar

- [ ] **Versión actualizada en pubspec.yaml**
  ```yaml
  version: 1.0.X+Y  # X = versión, Y = build_number
  ```

- [ ] **Build number incrementado**
  - Ejemplo: `1.0.0+1` → `1.0.1+2`
  - El número después del `+` DEBE ser mayor

- [ ] **Changelog preparado**
  - Lista de cambios y mejoras
  - Correcciones de bugs
  - Nuevas funcionalidades

### Compilación

- [ ] **APK compilado**
  ```bash
  flutter clean
  flutter build apk --release
  ```

- [ ] **APK generado correctamente**
  - Ubicación: `build/app/outputs/flutter-apk/app-release.apk`
  - Tamaño razonable (15-50 MB típicamente)

- [ ] **Probado en dispositivo real (opcional pero recomendado)**
  ```bash
  adb install -r build/app/outputs/flutter-apk/app-release.apk
  ```

### GitHub Release

- [ ] **Release creado en GitHub**
  - Tag: `vX.Y.Z` (ejemplo: `v1.0.1`)
  - Título descriptivo
  - Changelog incluido

- [ ] **APK subido al Release**
  - Arrastra el archivo al release
  - Nombre claro (ejemplo: `refmp-v1.0.1.apk`)

- [ ] **APK publicado (release público)**

- [ ] **URL del APK copiada**
  - Click derecho en APK → Copiar enlace
  - Debe terminar en `.apk`
  - Ejemplo: `https://github.com/.../releases/download/v1.0.1/app.apk`

### Registro en Supabase

- [ ] **Versión insertada en app_version**
  ```sql
  INSERT INTO app_version (version, build_number, required, release_notes, android_url)
  VALUES ('1.0.1', 2, false, 'Changelog aquí', 'URL_APK');
  ```

- [ ] **Build number es único**
  - No debe existir otro registro con el mismo build_number

- [ ] **URL del APK correcta**
  - Termina en `.apk`
  - Es accesible públicamente (probar en navegador)

- [ ] **Registro verificado**
  ```sql
  SELECT * FROM app_version ORDER BY build_number DESC LIMIT 1;
  -- Debe mostrar la nueva versión
  ```

### Pruebas Post-Publicación

- [ ] **Actualización detectada**
  - Abre la app en dispositivo con versión anterior
  - Ve a Ajustes → Buscar actualizaciones
  - Debe mostrar diálogo de actualización

- [ ] **Descarga funciona**
  - Acepta actualización
  - Progreso se muestra correctamente
  - Descarga completa sin errores

- [ ] **Instalación funciona**
  - Se solicita permiso de instalación (si es necesario)
  - APK se instala correctamente
  - App se actualiza exitosamente

---

## 🔍 Verificación de Versiones

### Comando para verificar versión instalada

```bash
# Ver versión y build number actual
adb shell dumpsys package com.tu.paquete | grep versionName
adb shell dumpsys package com.tu.paquete | grep versionCode
```

### Query para ver todas las versiones registradas

```sql
SELECT 
    version, 
    build_number, 
    required,
    created_at,
    LENGTH(android_url) as url_length
FROM app_version 
ORDER BY build_number DESC;
```

---

## ⚠️ Verificaciones Críticas

### ANTES de marcar como obligatoria (required = true)

- [ ] Versión probada exhaustivamente
- [ ] Sin bugs críticos conocidos
- [ ] APK disponible y accesible
- [ ] URL del APK permanente (no expira)
- [ ] Usuarios podrán descargar e instalar

### ANTES de publicar versión nueva

- [ ] Build number es MAYOR que todos los anteriores
- [ ] URL del APK es pública y accesible
- [ ] APK está completo (no corrupto)
- [ ] Changelog es claro y descriptivo

---

## 🐛 Checklist de Troubleshooting

Si algo falla, verifica:

- [ ] **Internet habilitado en dispositivo**
- [ ] **URL del APK accesible** (probar en navegador)
- [ ] **Permisos en AndroidManifest.xml** están correctos
- [ ] **FileProvider configurado** correctamente
- [ ] **Tabla app_version** tiene RLS habilitado
- [ ] **Build numbers únicos** en la tabla
- [ ] **Versión actual < Versión disponible**
- [ ] **APK no está corrupto** (descargar manualmente y verificar)

---

## 📊 Métricas de Éxito

Después de publicar, verifica:

- [ ] Usuarios reciben notificación de actualización
- [ ] Tasa de actualización > 60% en 24 horas
- [ ] Sin reportes de fallos de instalación
- [ ] No hay APKs corruptos reportados

---

## 🎯 Comandos Útiles

```bash
# Verificar dependencias instaladas
flutter pub deps | grep -E "(dio|install_plugin|device_info)"

# Limpiar antes de compilar
flutter clean && flutter pub get

# Compilar APK de release
flutter build apk --release --verbose

# Ver tamaño del APK
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Calcular hash del APK
sha256sum build/app/outputs/flutter-apk/app-release.apk

# Instalar APK en dispositivo conectado
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Ver logs de instalación
adb logcat | grep -i "install"
```

---

**✅ Checklist completo = Listo para publicar actualización**

**Última actualización:** 10 de marzo de 2026
