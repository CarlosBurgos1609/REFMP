# 🚀 Cómo Subir tu App a GitHub Releases

## 📦 PASO 1: Construir el APK

Abre una terminal en VS Code y ejecuta:

```bash
flutter clean
flutter build apk --release
```

⏱️ **Espera 5-10 minutos** mientras se construye el APK.

✅ **Cuando termine**, verás un mensaje como:
```
✓ Built build/app/outputs/flutter-apk/app-release.apk (XX.X MB)
```

---

## 🌐 PASO 2: Ir a tu Repositorio en GitHub

1. Abre tu navegador
2. Ve a: `https://github.com/TU_USUARIO/refmp`
3. Si no sabes tu usuario, ejecuta en terminal:
   ```bash
   git remote get-url origin
   ```
   Te mostrará algo como: `https://github.com/TU_USUARIO/refmp.git`

---

## 📝 PASO 3: Crear el Release

### 3.1 Click en "Releases"

En la página principal de tu repositorio, busca en la **barra lateral derecha**:

```
About
├─ Releases
└─ Packages
```

Click en **"Releases"** (o ve directamente a `https://github.com/TU_USUARIO/refmp/releases`)

---

### 3.2 Click en "Create a new release"

Verás un botón verde que dice **"Create a new release"** o **"Draft a new release"**.

Click ahí.

---

### 3.3 Llenar el Formulario

GitHub te mostrará un formulario. Llénalo así:

#### 📌 **Choose a tag**
- Click en el campo que dice "Find or create a new tag"
- Escribe: `v1.0.0`
- Click en "**Create new tag: v1.0.0 on publish**"

#### 🎯 **Release title**
```
Versión 1.0.0 - Lanzamiento Inicial
```

#### 📄 **Describe this release**
```markdown
## 🎉 Primera Versión de Refmp

### ✨ Características
- 🎺 Juego educativo de trompeta
- 📊 Sistema de logros y recompensas
- 📶 Modo offline con sincronización
- 🔄 Sistema de actualizaciones automáticas
- 🗺️ Mapa interactivo para profesores
- 📅 Calendario de eventos

### 📥 Instalación
1. Descarga el archivo `app-release.apk`
2. Activa "Instalar apps de fuentes desconocidas" en tu Android
3. Abre el archivo APK
4. Sigue las instrucciones de instalación
```

---

### 3.4 Subir el APK

#### Busca la sección **"Attach binaries by dropping them here or selecting them."**

Tienes dos opciones:

**Opción A: Arrastrar y soltar**
1. Abre el Explorador de Archivos de Windows
2. Navega a: `C:\Users\Personal\Documents\proyecto\refmp\build\app\outputs\flutter-apk`
3. Arrastra el archivo `app-release.apk` a la página de GitHub

**Opción B: Seleccionar archivo**
1. Click en "**selecting them**" (es un enlace)
2. Busca: `C:\Users\Personal\Documents\proyecto\refmp\build\app\outputs\flutter-apk\app-release.apk`
3. Click en "Abrir"

Verás que el archivo aparece en la lista con un indicador de progreso. **Espera** a que termine de subir.

---

### 3.5 Publicar el Release

Una vez que el APK haya terminado de subir:

1. Click en el botón verde **"Publish release"** (abajo del formulario)
2. ✅ ¡Listo! Tu versión está publicada

---

## 🔗 PASO 4: Copiar la URL del APK

Después de publicar, GitHub te mostrará la página del release.

### Para copiar la URL directa del APK:

1. Busca el nombre del archivo: **`app-release.apk`** (está en la sección "Assets")
2. **Click derecho** sobre el nombre del archivo
3. Selecciona **"Copiar enlace"** o **"Copy link address"**

La URL se verá así:
```
https://github.com/TU_USUARIO/refmp/releases/download/v1.0.0/app-release.apk
```

📋 **Guarda esta URL**, la necesitarás para el siguiente paso.

---

## 💾 PASO 5: Registrar la Versión en Supabase

1. Ve a tu proyecto en Supabase: https://supabase.com/dashboard
2. Click en **SQL Editor**
3. Pega este código (reemplaza la URL con la que copiaste):

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

4. Click en **Run**
5. Verifica que se guardó:
   ```sql
   SELECT * FROM app_version;
   ```

---

## ✅ PASO 6: Probar

### En tu teléfono Android:

1. **Descargar**: Ve a `https://github.com/TU_USUARIO/refmp/releases` desde tu teléfono
2. **Instalar**: Click en `app-release.apk` y sigue las instrucciones
3. **Probar actualización**: 
   - Abre la app
   - Ve a Configuración
   - Busca "Buscar actualizaciones"
   - Debería decir: "Ya tienes la última versión (1.0.0)"

---

## 📱 Compartir la App

Una vez publicada, puedes compartir tu app de dos formas:

### 🔗 Link Directo al Release:
```
https://github.com/TU_USUARIO/refmp/releases/latest
```

### 🔗 Link Directo al APK:
```
https://github.com/TU_USUARIO/refmp/releases/download/v1.0.0/app-release.apk
```

---

## 🔄 Para Futuras Versiones (v1.0.1, v1.0.2, etc.)

1. **Actualiza la versión en `pubspec.yaml`**:
   ```yaml
   version: 1.0.1+2  # versión+build_number
   ```

2. **Construye el nuevo APK**:
   ```bash
   flutter build apk --release
   ```

3. **Crea un nuevo Release**:
   - Tag: `v1.0.1`
   - Title: "Versión 1.0.1 - Mejoras y correcciones"
   - Sube el nuevo APK

4. **Registra en Supabase** (con build_number = 2):
   ```sql
   INSERT INTO app_version (version, build_number, required, release_notes, android_url)
   VALUES ('1.0.1', 2, false, 'Mejoras y correcciones', 'LA_NUEVA_URL_APK');
   ```

---

## ❓ Preguntas Frecuentes

### ¿Puedo borrar un release?
Sí, en la página del release, click en el ícono de tres puntos (⋯) → "Delete"

### ¿Puedo editar un release después de publicarlo?
Sí, en la página del release, click en el ícono de lápiz (✏️) → "Edit release"

### ¿Los releases son públicos?
Sí, si tu repositorio es público. Si es privado, solo personas con acceso al repo pueden descargar.

### ¿Puedo subir múltiples archivos?
Sí, puedes subir tantos archivos como quieras (APK, capturas, documentos, etc.)

### ¿Cuál es el tamaño máximo?
GitHub permite archivos de hasta 2 GB por release.

---

## 🆘 ¿Problemas?

### "No encuentro el botón Releases"
- Asegúrate de estar en la página principal del repositorio
- Si no aparece, ve directamente a: `https://github.com/TU_USUARIO/refmp/releases`

### "No puedo subir el APK"
- Verifica que el archivo existe en: `build/app/outputs/flutter-apk/app-release.apk`
- Asegúrate de que el build terminó correctamente (sin errores)

### "El tag ya existe"
- Cada tag debe ser único. Usa `v1.0.1`, `v1.0.2`, etc. para nuevas versiones
- O borra el tag anterior si no lo necesitas

### "La app no detecta actualizaciones"
1. Verifica que la tabla `app_version` existe en Supabase
2. Verifica que la política RLS permite SELECT público
3. Verifica que la URL del APK sea correcta (debe ser el link directo)
4. Revisa los logs en la consola de Flutter

---

¡Listo! 🎉 Ahora tienes tu app en GitHub Releases y un sistema de actualizaciones automático funcionando.
