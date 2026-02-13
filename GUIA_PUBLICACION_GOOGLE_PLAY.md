# 📱 Guía para Publicar en Google Play Store

## 📋 Requisitos Previos

1. **Cuenta de Google Play Console** ($25 USD pago único)
   - Registrarse en: https://play.google.com/console/signup
   - Completar verificación de identidad
   - Esperar aprobación (1-3 días)

2. **Archivos necesarios:**
   - ✅ App funcional y probada
   - ✅ Íconos y recursos gráficos
   - ✅ Descripción de la app
   - ✅ Capturas de pantalla

---

## 🔐 Paso 1: Generar Keystore (Una sola vez)

```bash
keytool -genkey -v -keystore C:\Users\Personal\refmp-key.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias refmp
```

**Te preguntará:**
- Contraseña del keystore (mínimo 6 caracteres)
- Nombre, organización, ciudad, país
- Confirmar información

⚠️ **MUY IMPORTANTE:**
- Guarda el archivo `refmp-key.jks` en lugar SEGURO
- Anota las contraseñas en lugar seguro
- ¡Sin este archivo NO podrás publicar actualizaciones!
- Haz backup del archivo

---

## 📝 Paso 2: Configurar key.properties

Ya está creado en `android/key.properties`:

```properties
storePassword=TU_PASSWORD_AQUI
keyPassword=TU_PASSWORD_AQUI
keyAlias=refmp
storeFile=C:\\Users\\Personal\\refmp-key.jks
```

**Edita el archivo y reemplaza:**
- `TU_PASSWORD_AQUI` con tu contraseña real (ambas líneas)
- Verifica que `storeFile` apunte a tu archivo .jks

✅ Este archivo NO se subirá a Git (ya está en .gitignore)

---

## 🏗️ Paso 3: Configurar build.gradle

✅ Ya está configurado en `android/app/build.gradle`

Verifica que tenga:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')

signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
    }
}
```

---

## 🎨 Paso 4: Preparar Recursos Gráficos

### Íconos de la app
Ya tienes el ícono configurado en `pubspec.yaml` con `flutter_launcher_icons`

### Capturas de pantalla necesarias:
- **Teléfono:** 2-8 imágenes (mín: 320px, máx: 3840px)
- **Tablet 7":** 2-8 imágenes (opcional pero recomendado)
- **Tablet 10":** 2-8 imágenes (opcional)

### Gráfico promocional (Feature Graphic):
- Tamaño: 1024 x 500 px
- Formato: PNG o JPG
- Requerido para aparecer en búsquedas destacadas

---

## 🔨 Paso 5: Compilar APK/Bundle de Release

### Opción A: App Bundle (Recomendado por Google)
```bash
flutter build appbundle --release
```

📁 El archivo se generará en:
`build/app/outputs/bundle/release/app-release.aab`

### Opción B: APK (Para instalación directa)
```bash
flutter build apk --release
```

📁 El archivo se generará en:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📤 Paso 6: Crear la App en Google Play Console

1. **Accede a Play Console:** https://play.google.com/console
2. **Crear aplicación:**
   - Click en "Crear aplicación"
   - Nombre de la app: **REFMP** (o el que prefieras)
   - Idioma predeterminado: Español (España) o (Latinoamérica)
   - Tipo: Aplicación o juego
   - Gratuita o de pago: Gratuita
   - Aceptar políticas

---

## 📋 Paso 7: Completar Ficha de la Tienda

### Información principal:
- **Nombre de la app:** REFMP (máx 30 caracteres)
- **Descripción breve:** 80 caracteres explicando qué hace
- **Descripción completa:** Hasta 4000 caracteres con detalles

### Ejemplo de descripción breve:
```
Aprende trompeta con juegos educativos y gestiona tu práctica musical diaria
```

### Categorías:
- **Categoría:** Educación o Música
- **Etiquetas:** Música, Educación, Trompeta, Práctica

### Información de contacto:
- Correo de soporte
- Sitio web (opcional)
- Número de teléfono (opcional)

### Política de privacidad:
⚠️ **REQUERIDO si usas datos personales**

Si usas Firebase Auth/Firestore/Supabase con datos de usuarios:
```
URL de política de privacidad: [Tu sitio web]/privacidad
```

Puedes crear una simple en:
- GitHub Pages
- Google Sites
- Blogger

---

## 🎮 Paso 8: Subir el Build

1. **Ir a "Producción" > "Versiones"**
2. **Crear nueva versión**
3. **Subir archivo:** `app-release.aab`
4. **Nombre de la versión:** `1` (o `1.0.0`)
5. **Notas de la versión:** (Por idioma)

### Ejemplo de notas:
```
🎺 Primera versión de REFMP

✨ Funcionalidades:
• Juego educativo de trompeta
• Gestión de eventos y alertas
• Sistema de experiencia (XP)
• Tips musicales diarios
• Modo oscuro/claro

¡Gracias por probar nuestra app!
```

---

## 🔍 Paso 9: Clasificación de Contenido

1. **Completar cuestionario:**
   - ¿Hay violencia? No
   - ¿Contenido sexual? No
   - ¿Lenguaje inapropiado? No
   - ¿Drogas/alcohol? No
   - ¿Discriminación? No
   - etc.

2. **Clasificación resultante:**
   - Probablemente será: **PEGI 3** o **Everyone**

---

## 👥 Paso 10: Público Objetivo

- **Edad objetivo:** Todas las edades o específica (ej: 13+)
- **¿App para niños?** Sí/No (según tu público)
- **Anuncios:** No (si no usas AdMob)

---

## 🚀 Paso 11: Enviar a Revisión

1. **Revisar todos los apartados:**
   - ✅ Ficha de la tienda completada
   - ✅ Clasificación de contenido
   - ✅ Público objetivo
   - ✅ Build subido
   - ✅ Política de privacidad (si aplica)

2. **Enviar a revisión:**
   - Click en "Enviar a revisión"
   - Esperar aprobación (1-7 días)

---

## 📬 Paso 12: Después de la Aprobación

### Obtener URL de Google Play:
```
https://play.google.com/store/apps/details?id=com.music.refmp
```

### Activar el Sistema de Actualizaciones:

1. **Ejecutar SQL en Supabase:**
```sql
-- Ya lo tienes en sql_triggers/app_version_table.sql
-- Actualiza la URL de Android:
UPDATE app_version 
SET android_url = 'https://play.google.com/store/apps/details?id=com.music.refmp'
WHERE version = '1.0.0';
```

2. **Descomentar el código en settings.dart:**
```dart
// En lib/interfaces/menu/settings.dart
// Busca la línea ~674 y elimina /* y */ para habilitar:
ListTile(
  leading: Icon(Icons.system_update, ...),
  title: Text("Buscar actualizaciones", ...),
  onTap: _checkForUpdates,
)
```

---

## 🔄 Cómo Publicar Actualizaciones

### 1. Incrementar versión en pubspec.yaml:
```yaml
version: 1.0.1+2  # version+buildNumber
```

### 2. Compilar nuevo build:
```bash
flutter build appbundle --release
```

### 3. Subir a Play Console:
- Producción > Crear nueva versión
- Subir `app-release.aab`
- Agregar notas de la versión

### 4. Actualizar Supabase:
```sql
INSERT INTO app_version (version, build_number, required, release_notes, android_url, ios_url)
VALUES (
    '1.0.1',
    2,
    false,  -- true si es obligatoria
    '- Corrección de errores
- Mejoras de rendimiento
- Nueva funcionalidad X',
    'https://play.google.com/store/apps/details?id=com.music.refmp',
    'https://apps.apple.com/app/idTU_APP_ID'  -- Cuando tengas iOS
);
```

---

## 🎯 Checklist Final

Antes de publicar, verifica:

- [ ] App funciona correctamente sin errores
- [ ] Probada en varios dispositivos/emuladores
- [ ] Todos los permisos necesarios en AndroidManifest.xml
- [ ] Íconos y recursos gráficos de calidad
- [ ] Descripción clara y completa
- [ ] Capturas de pantalla actualizadas
- [ ] Política de privacidad (si aplica)
- [ ] Keystore guardado en lugar seguro con backup
- [ ] Contraseñas anotadas en lugar seguro
- [ ] key.properties NO está en Git

---

## 🆘 Problemas Comunes

### Error: "App not signed correctly"
✅ Verifica que `key.properties` tenga las contraseñas correctas

### Error: "You uploaded a debuggable APK"
✅ Usa `--release` en el comando de build

### Error: "Version code already used"
✅ Incrementa el build number en pubspec.yaml

### Rechazo: "Falta información"
✅ Completa todos los campos obligatorios en Play Console

### Rechazo: "Contenido inapropiado"
✅ Revisa imágenes y descripciones, asegúrate que sean apropiadas

---

## 📞 Recursos Útiles

- **Play Console:** https://play.google.com/console
- **Documentación oficial:** https://developer.android.com/distribute
- **Política de contenido:** https://support.google.com/googleplay/android-developer/answer/9876937
- **Centro de ayuda:** https://support.google.com/googleplay/android-developer

---

## 💡 Consejos Adicionales

1. **Primera versión:** Publica con features básicas pero bien probadas
2. **Actualiza frecuentemente:** Los usuarios aprecian mejoras constantes
3. **Lee reseñas:** Responde feedback y mejora en base a comentarios
4. **Usa versiones beta:** Play Console permite testers antes de producción
5. **Monitorea crashes:** Usa Firebase Crashlytics para detectar errores
6. **Optimiza ASO:** Usa keywords relevantes en título/descripción
7. **Pide reseñas:** Usuarios satisfechos ayudan con mejores ratings

---

**¡Éxito con tu publicación!** 🚀

Cualquier duda durante el proceso, consulta la documentación oficial o el centro de ayuda de Google Play.
