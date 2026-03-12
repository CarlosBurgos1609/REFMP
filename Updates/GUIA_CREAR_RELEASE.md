# 🚀 Guía Completa: Crear APK y Subirlo a GitHub

## 📋 PASOS A SEGUIR

### 1️⃣ Primero: Crear Tabla en Supabase

1. Ve a tu proyecto en Supabase: https://supabase.com/dashboard
2. Click en **SQL Editor** (icono de base de datos en el menú izquierdo)
3. Abre el archivo: `sql_triggers/app_version_table.sql`
4. **Copia TODO el contenido** y pégalo en el SQL Editor
5. Click en **Run** (botón verde)
6. ✅ Deberías ver: "Success. No rows returned"

---

### 2️⃣ Construir el APK de Release

En la terminal de VS Code, ejecuta estos comandos **en orden**:

```bash
# 1. Limpiar build anterior
flutter clean

# 2. Obtener dependencias
flutter pub get

# 3. Construir APK de release (toma varios minutos)
flutter build apk --release
```

**⏱️ IMPORTANTE**: El paso 3 puede tardar 5-10 minutos. Es normal.

**📦 Resultado**: El APK se creará en:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

### 3️⃣ Subir APK a GitHub Releases

#### Opción A: Desde la Web (Más Fácil)

1. **Ve a tu repositorio en GitHub**:
   - Ejemplo: `https://github.com/TU_USUARIO/refmp`

2. **Click en "Releases"** (en la barra lateral derecha)

3. **Click en "Create a new release"** (botón verde)

4. **Llenar el formulario**:
   ```
   Tag version: v1.0.0
   Release title: Versión 1.0.0 - Lanzamiento Inicial
   Description:
   - 🎺 Juego educativo de trompeta
   - 📊 Sistema de logros y recompensas
   - 📶 Modo offline
   - 🔄 Sistema de actualizaciones automáticas
   ```

5. **Subir el APK**:
   - Arrastra el archivo `app-release.apk` a la sección "Attach binaries"
   - O click en "Choose files" y selecciona: `build/app/outputs/flutter-apk/app-release.apk`

6. **Publicar**:
   - Click en **"Publish release"** (botón verde)

7. **Copiar URL del APK**:
   - Una vez publicado, haz **click derecho** sobre el nombre del archivo `app-release.apk`
   - Selecciona **"Copiar enlace"**
   - La URL será algo como:
   ```
   https://github.com/TU_USUARIO/refmp/releases/download/v1.0.0/app-release.apk
   ```

#### Opción B: Desde Terminal (Avanzado)

Si tienes GitHub CLI instalado:

```bash
# Crear el release y subir el APK
gh release create v1.0.0 \
  build/app/outputs/flutter-apk/app-release.apk \
  --title "Versión 1.0.0 - Lanzamiento Inicial" \
  --notes "Primera versión de la aplicación"
```

---

### 4️⃣ Registrar Versión en Supabase

1. **Ve al SQL Editor de Supabase**

2. **Ejecuta este INSERT** (reemplaza la URL con la que copiaste):

```sql
INSERT INTO app_version (version, build_number, required, release_notes, android_url)
VALUES (
    '1.0.0',
    1,
    false,
    '🎉 Versión inicial
- Juego educativo de trompeta
- Sistema de logros
- Modo offline
- Actualizaciones automáticas',
    'https://github.com/TU_USUARIO/refmp/releases/download/v1.0.0/app-release.apk'
);
```

3. **Verifica que se guardó**:

```sql
SELECT * FROM app_version ORDER BY build_number DESC;
```

---

### 5️⃣ Probar el Sistema de Actualización

1. **Instala el APK en tu teléfono**:
   - Descarga el APK desde GitHub Releases
   - Instálalo en tu dispositivo Android

2. **Abre la app**:
   - Ve a **Configuración**
   - Desplázate hacia abajo
   - Busca el botón "Buscar actualizaciones"

3. **Si todo está bien**:
   - Debería mostrar: "Ya tienes la última versión"

---

## 🔄 Para Versiones Futuras

### Cuando quieras lanzar v1.0.1:

1. **Actualiza la versión en `pubspec.yaml`**:
```yaml
version: 1.0.1+2  # ← cambia esto (versión+build_number)
```

2. **Construye el nuevo APK**:
```bash
flutter clean
flutter build apk --release
```

3. **Crea nuevo Release en GitHub**:
   - Tag: `v1.0.1`
   - Sube el nuevo `app-release.apk`

4. **Registra en Supabase**:
```sql
INSERT INTO app_version (version, build_number, required, release_notes, android_url)
VALUES (
    '1.0.1',
    2,
    false,
    '🔧 Mejoras y correcciones
- Corrección de errores
- Mejoras de rendimiento',
    'https://github.com/TU_USUARIO/refmp/releases/download/v1.0.1/app-release.apk'
);
```

---

## ⚠️ Solución de Problemas

### Error: "BUILD FAILED"
```bash
# Intenta esto:
flutter clean
rm -rf build/
flutter pub get
flutter build apk --release
```

### Error al crear el Release en GitHub
- Verifica que tengas permisos de escritura en el repositorio
- Asegúrate de que el tag sea único (no puedes usar v1.0.0 dos veces)

### La app dice "Error al verificar actualizaciones"
1. Verifica que la tabla `app_version` existe en Supabase
2. Verifica las políticas RLS (debe permitir SELECT público)
3. Revisa los logs en el Dart DevTools

### El APK no se descarga
- Verifica que la URL sea correcta
- Debe ser un enlace directo, no la página del Release
- Formato correcto: `https://github.com/USER/REPO/releases/download/v1.0.0/app-release.apk`

---

## 📝 Checklist Rápido

Antes de publicar un release:

- [ ] Actualizada versión en `pubspec.yaml`
- [ ] Ejecutado `flutter clean`
- [ ] Ejecutado `flutter build apk --release`
- [ ] APK creado correctamente en `build/app/outputs/flutter-apk/`
- [ ] Release creado en GitHub
- [ ] APK subido al Release
- [ ] URL del APK copiada
- [ ] Versión registrada en Supabase
- [ ] Probado en dispositivo real

---

## 🎯 Resultado Final

Una vez completados todos los pasos:

✅ Tu APK estará disponible en GitHub
✅ Los usuarios podrán descargar la app
✅ El sistema detectará automáticamente nuevas versiones
✅ Los usuarios recibirán notificaciones de actualización
✅ Las actualizaciones se instalarán automáticamente

---

## 📞 ¿Necesitas Ayuda?

Si algo no funciona, revisa:
1. Los logs en la consola de Flutter (`flutter run --release`)
2. Los logs en Supabase (Table Editor → app_version)
3. Los logs en la app (Dart DevTools)

**Comando útil para ver logs en tiempo real**:
```bash
flutter run --release
# Luego presiona 'l' para ver logs detallados
```
