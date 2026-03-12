# 📱 Cómo Cambiar la Versión de la Aplicación

Esta guía explica cómo actualizar correctamente el número de versión de tu aplicación Flutter para que el sistema de actualización automática funcione correctamente.

## 🔍 Entendiendo las Versiones

Tu aplicación tiene dos números importantes:
- **Versión (versionName)**: El nombre que ven los usuarios (ej: 1.0.0, 1.1.0, 2.0.0)
- **Build Number (versionCode)**: Un número entero que aumenta con cada actualización (ej: 1, 2, 3, 4...)

### Formato en pubspec.yaml:
```yaml
version: 1.0.0+1
         ↑     ↑
    versionName  buildNumber
```

## 📝 Pasos para Actualizar la Versión

### 1. **Editar el archivo `pubspec.yaml`**

Abre el archivo `pubspec.yaml` en la raíz del proyecto y busca la línea `version:`:

```yaml
# Versión ACTUAL (antes de actualizar)
version: 1.0.0+1

# Versión NUEVA (después de actualizar)
version: 1.0.1+2
```

### 2. **Reglas para cambiar el número de versión:**

#### Build Number (el número después del +)
- ⚠️ **SIEMPRE debe aumentar en cada actualización**
- Es el número que compara el sistema para saber si hay actualizaciones
- Ejemplo: `+1` → `+2` → `+3` → `+4`

#### Version Name (el número antes del +)
Sigue el formato **MAJOR.MINOR.PATCH:**

- **PATCH** (1.0.0 → 1.0.1): Correcciones de errores pequeños
- **MINOR** (1.0.0 → 1.1.0): Nuevas funcionalidades sin romper compatibilidad
- **MAJOR** (1.0.0 → 2.0.0): Cambios grandes que pueden romper compatibilidad

### 3. **Ejemplos prácticos:**

```yaml
# Versión inicial
version: 1.0.0+1

# Primera corrección de errores
version: 1.0.1+2

# Segunda corrección
version: 1.0.2+3

# Nueva funcionalidad (añadir juegos)
version: 1.1.0+4

# Otra funcionalidad más
version: 1.2.0+5

# Rediseño completo de la app
version: 2.0.0+6
```

## 🗄️ Actualizar la Base de Datos (Supabase)

Después de cambiar la versión en `pubspec.yaml`, debes actualizar la tabla `app_version` en Supabase:

### 1. **Accede a Supabase SQL Editor**
Ve a tu proyecto en Supabase → SQL Editor

### 2. **Ejecuta esta consulta SQL:**

```sql
-- Insertar la nueva versión
INSERT INTO app_version (
  version,
  build_number,
  release_notes,
  android_url,
  ios_url,
  required,
  active,
  created_at,
  updated_at
)
VALUES (
  '1.0.1',                    -- ← Cambiar: Versión nueva (SIN el +buildNumber)
  2,                          -- ← Cambiar: Build number nuevo
  '• Corrección de errores en carga de objetos
• Mejoras en velocidad de actualizaciones
• Nuevo sistema de caché',  -- ← Cambiar: Notas de la versión
  'https://github.com/TU_USUARIO/TU_REPO/releases/download/v1.0.1/app-release.apk',  -- ← URL del APK
  '',                         -- iOS URL (opcional)
  false,                      -- ¿Es obligatoria? (true/false)
  true,                       -- ¿Está activa? (true)
  NOW(),
  NOW()
);
```

### 3. **Ejemplo completo con tus datos:**

```sql
INSERT INTO app_version (
  version,
  build_number,
  release_notes,
  android_url,
  ios_url,
  required,
  active,
  created_at,
  updated_at
)
VALUES (
  '1.0.1',
  2,
  '• Se optimizó la carga de objetos (70-80% más rápido)
• Se agregó sistema de actualización automática
• Mejoras en permisos de instalación
• Corrección de errores menores',
  'https://github.com/usuario/refmp/releases/download/v1.0.1/refmp-v1.0.1.apk',
  '',
  false,  -- No obligatoria, el usuario puede elegir "Más tarde"
  true,
  NOW(),
  NOW()
);
```

## 🚀 Publicar la Nueva Versión

### 1. **Compilar el APK:**

```bash
# Limpiar proyecto
flutter clean

# Obtener dependencias
flutter pub get

# Compilar APK de producción
flutter build apk --release
```

El APK estará en: `build/app/outputs/flutter-apk/app-release.apk`

### 2. **Crear Release en GitHub:**

1. Ve a tu repositorio en GitHub
2. Clic en "Releases" → "Create a new release"
3. Tag version: `v1.0.1` (debe coincidir con la versión)
4. Release title: `Versión 1.0.1`
5. Descripción: Copia las notas de la versión
6. Arrastra el archivo `app-release.apk`
7. **Renómbralo** a `refmp-v1.0.1.apk` (más claro para los usuarios)
8. Publica el release

### 3. **Copiar URL del APK:**

Después de publicar, haz clic derecho en el APK → "Copiar enlace"

Ejemplo:
```
https://github.com/usuario/refmp/releases/download/v1.0.1/refmp-v1.0.1.apk
```

### 4. **Actualizar la URL en Supabase:**

Pega esa URL en el campo `android_url` de tu consulta SQL.

## 🔍 Verificar que Funciona

### 1. **Instala la versión antigua en tu dispositivo**
- Por ejemplo, la versión `1.0.0+1`

### 2. **Actualiza la base de datos con la nueva versión**
- Ejecuta el SQL con `version: 1.0.1` y `build_number: 2`

### 3. **Abre la app**
- Después de 2 segundos, debería aparecer el diálogo de actualización
- O ve a Configuración y toca "Buscar actualizaciones"

### 4. **Si NO aparece el diálogo:**

Verifica en los logs de la app (con `flutter run` o `adb logcat`):
```
📱 Versión actual: 1.0.0+1
☁️ Versión disponible: 1.0.1+2
```

Si ves que la versión actual es mayor o igual que la disponible, no aparecerá el diálogo.

## ⚡ Consejos Rápidos

### ✅ **Siempre hacer:**
- Aumentar el build number en cada compilación
- Actualizar Supabase después de cambiar `pubspec.yaml`
- Probar en un dispositivo con versión anterior
- Hacer commit de los cambios en Git

### ❌ **Nunca hacer:**
- Usar el mismo build number para dos versiones diferentes
- Olvidar actualizar la base de datos
- Poner un build number menor que la versión anterior

## 🛠️ Solución de Problemas

### Problema: "Siempre me pide actualizar aunque tengo la última versión"

**Causa:** El build number en tu app no coincide con el de Supabase

**Solución:**
1. Verifica la versión en `pubspec.yaml`
2. Busca en Supabase qué build_number está registrado
3. Asegúrate de que el `build_number` en tu app sea MAYOR O IGUAL al de Supabase

```sql
-- Ver las versiones registradas en Supabase
SELECT version, build_number, active 
FROM app_version 
ORDER BY build_number DESC;
```

### Problema: "No aparece el diálogo de actualización"

**Soluciones:**
1. Verifica que `active = true` en Supabase
2. Asegúrate de que el `build_number` en Supabase sea MAYOR que el de tu app
3. Revisa los logs con `flutter run` para ver qué versiones se están comparando
4. Verifica tu conexión a internet

### Problema: "Error al descargar el APK"

**Soluciones:**
1. Verifica que la URL del APK sea pública y accesible
2. Prueba abrir la URL en un navegador
3. Asegúrate de que el Release en GitHub sea público, no draft
4. Verifica que el archivo se llame `.apk` al final

## 📋 Checklist de Actualización

Usa esta lista cada vez que publiques una actualización:

- [ ] Incrementar build number en `pubspec.yaml` (ej: +1 → +2)
- [ ] Actualizar version name si es necesario (ej: 1.0.0 → 1.0.1)
- [ ] Escribir las notas de la versión (release notes)
- [ ] Ejecutar `flutter clean && flutter pub get`
- [ ] Compilar APK con `flutter build apk --release`
- [ ] Crear Release en GitHub con el APK
- [ ] Copiar la URL del APK
- [ ] Ejecutar SQL en Supabase con la nueva versión
- [ ] Hacer commit y push a Git
- [ ] Probar en dispositivo con versión anterior
- [ ] Verificar que aparece el diálogo de actualización
- [ ] Probar la descarga e instalación del APK

## 🎯 Resumen Rápido

```bash
# 1. Cambiar versión
# En pubspec.yaml: version: 1.0.0+1 → version: 1.0.1+2

# 2. Compilar
flutter clean
flutter pub get
flutter build apk --release

# 3. Subir a GitHub
# Crear release con tag v1.0.1 y subir el APK

# 4. Actualizar Supabase
# Ejecutar INSERT INTO app_version con la nueva versión y URL del APK

# 5. Probar
# Instalar versión anterior, abrir app, verificar que pide actualizar
```

---

**Última actualización:** 2026-03-11  
**Versión de este documento:** 1.0
