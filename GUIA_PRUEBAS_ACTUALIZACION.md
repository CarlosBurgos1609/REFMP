# 🧪 Guía de Pruebas del Sistema de Actualización

Esta guía te ayudará a probar y solucionar problemas con el sistema de actualización automática de la aplicación.

## 📋 Pre-requisitos

Antes de comenzar las pruebas:

1. ✅ **AndroidManifest.xml** debe tener el permiso:
   ```xml
   <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
   ```

2. ✅ **pubspec.yaml** debe tener configurada una versión:
   ```yaml
   version: 1.0.0+1
   ```

3. ✅ **Supabase** debe tener la tabla `app_version` con datos

## 🔍 Verificar Configuración Actual

### 1. Verificar Versión de la App

Ejecuta en terminal:
```bash
flutter run
```

En los logs, busca:
```
📱 Versión actual: 1.0.0+1
```

### 2. Verificar Datos en Supabase

En Supabase SQL Editor:
```sql
SELECT * FROM app_version ORDER BY build_number DESC;
```

Deberías ver algo como:
```
version | build_number | android_url                          | active
--------|--------------|--------------------------------------|--------
1.0.1   | 2            | https://github.com/.../app.apk       | true
```

### 3. Verificar Permisos en AndroidManifest.xml

Abre: `android/app/src/main/AndroidManifest.xml`

Busca estas líneas:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```

## 🧪 Pruebas Paso a Paso

### Prueba 1: Verificar que NO pide actualización (versión actual)

**Objetivo:** Confirmar que cuando tienes la última versión, NO aparece el diálogo.

**Pasos:**
1. Asegúrate de que tu app tiene la misma versión que Supabase
   - App: `1.0.0+1`
   - Supabase: `version='1.0.0', build_number=1`

2. Abre la app

3. Espera 2 segundos

**Resultado esperado:**
- ❌ NO debe aparecer diálogo de actualización
- ✅ La app funciona normalmente

**Si aparece diálogo de actualización:**
- ⚠️ Tu versión en pubspec.yaml no coincide con Supabase
- Verifica los números de versión

---

### Prueba 2: Activar diálogo de actualización

**Objetivo:** Hacer que aparezca el diálogo de actualización.

**Pasos:**

1. En Supabase, inserta una versión más nueva:
   ```sql
   INSERT INTO app_version (
     version, 
     build_number, 
     release_notes, 
     android_url, 
     required, 
     active
   ) VALUES (
     '1.0.1',
     2,
     '• Corrección de errores\n• Mejoras de rendimiento',
     'https://github.com/TU_USUARIO/TU_REPO/releases/download/v1.0.1/app-release.apk',
     false,
     true
   );
   ```

2. Reinicia completamente la app (cerrar y abrir)

3. Espera 2 segundos

**Resultado esperado:**
- ✅ Debe aparecer diálogo "Actualización Disponible"
- ✅ Debe mostrar la nueva versión (1.0.1)
- ✅ Debe tener botón "Actualizar" y "Más tarde"

**En los logs deberías ver:**
```
📱 Versión actual: 1.0.0+1
☁️ Versión disponible: 1.0.1+2
```

**Si NO aparece el diálogo:**
- Verifica conexión a internet
- Verifica que `active = true` en Supabase
- Verifica que `build_number` en Supabase sea MAYOR que el de tu app
- Mira los logs para ver errores

---

### Prueba 3: Verificar permisos de instalación

**Objetivo:** Probar que el sistema de permisos funciona correctamente.

**Pasos:**

1. **Limpiar permisos anteriores:**
   - Abre Configuración del dispositivo
   - Apps → REFMP → Permisos
   - Si hay "Instalar apps desconocidas", desactívalo

2. **Abrir la app y buscar actualización:**
   - Abre REFMP
   - Espera 2 segundos (aparece diálogo de actualización)
   - Toca "Actualizar"

3. **Verificar solicitud de permiso:**
   - Debe aparecer diálogo: "Permiso para Instalar"
   - Debe explicar qué es "Instalar apps desconocidas"
   - Toca "Activar"

4. **Verificar solicitud del sistema:**
   - Android te llevará a Configuración
   - Busca el interruptor "Permitir de esta fuente"
   - Actívalo

5. **Regresar a la app**

**Resultado esperado:**
- ✅ El permiso debe quedar activado
- ✅ La descarga debe iniciar automáticamente

**Logs esperados:**
```
📋 Estado permiso instalación: PermissionStatus.denied
📋 Resultado solicitud permiso: PermissionStatus.granted
✅ Permisos verificados, iniciando descarga...
```

---

### Prueba 4: Descargar e instalar actualización

**Objetivo:** Verificar que la descarga e instalación funcionan.

**Pre-requisito:**
- Debes tener un APK real en GitHub Releases con la URL correcta

**Pasos:**

1. En el diálogo de actualización, toca "Actualizar"

2. Si pide permisos, otórgalos (ver Prueba 3)

3. Observa el diálogo de descarga:
   - Debe mostrar "Descargando actualización"
   - Debe mostrar barra de progreso
   - Debe mostrar porcentaje (0% → 100%)

4. Cuando termina la descarga:
   - Debe aparecer instalador de Android
   - Toca "Instalar"

**Resultado esperado:**
- ✅ Descarga completa exitosamente
- ✅ Se abre instalador de Android
- ✅ Instalación exitosa
- ✅ App actualizada

**Logs esperados:**
```
📥 Descargando APK desde: https://github.com/.../app.apk
💾 Guardando en: /storage/emulated/0/Android/data/.../files/refmp_v1.0.1.apk
📊 Progreso: 0%
📊 Progreso: 25%
📊 Progreso: 50%
📊 Progreso: 75%
📊 Progreso: 100%
✅ Descarga completada
📲 Instalando APK
✅ APK abierto: true
```

---

### Prueba 5: Verificar que permiso permanece

**Objetivo:** Confirmar que no vuelve a pedir permiso después de otorgarlo.

**Pasos:**

1. Cierra completamente la app

2. Vuelve a abrir la app

3. Toca "Actualizar" en el diálogo (o en Configuración)

**Resultado esperado:**
- ✅ NO debe pedir permiso de instalación de nuevo
- ✅ Debe ir directo a descargar

**Logs esperados:**
```
📋 Estado permiso instalación: PermissionStatus.granted
✅ Permisos verificados, iniciando descarga...
```

---

### Prueba 6: Diálogo "Todo al día"

**Objetivo:** Ver el diálogo cuando ya tienes la última versión.

**Pasos:**

1. Asegúrate de tener la última versión instalada
   - Versión en app = Versión en Supabase

2. Abre Configuración (menú lateral)

3. Toca en "Buscar actualizaciones"

**Resultado esperado:**
- ✅ Debe aparecer diálogo "¡Todo al día!"
- ✅ Debe mostrar tu versión actual
- ✅ Diseño bonito con check verde

---

## 🐛 Solución de Problemas

### Problema 1: "Siempre pide actualizar aunque tengo la última versión"

**Causa:** El build number no coincide

**Solución:**
1. Verifica versión en `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2
            ↑     ↑
   ```

2. Verifica en Supabase:
   ```sql
   SELECT version, build_number FROM app_version WHERE active = true;
   ```

3. El `build_number` de tu app debe ser >= al de Supabase

4. Si tu app tiene +1 y Supabase tiene 2, la app pedirá actualizar

---

### Problema 2: "No aparece diálogo de actualización"

**Diagnóstico:**

Ejecuta `flutter run` y busca en los logs:

**Si ves:**
```
📱 Versión actual: 1.0.0+1
⚠️ No se encontraron versiones en la tabla app_version
```

**Solución:** Inserta datos en Supabase (ver Prueba 2)

---

**Si ves:**
```
📱 Versión actual: 1.0.0+1
☁️ Versión disponible: 1.0.0+1
```

**Solución:** Las versiones son iguales, aumenta `build_number` en Supabase

---

**Si ves:**
```
❌ Error al verificar actualizaciones: ...
```

**Soluciones:**
- Verifica conexión a internet
- Verifica que la tabla `app_version` exista en Supabase
- Verifica políticas RLS en Supabase (deben permitir SELECT público)

---

### Problema 3: "Error al descargar APK"

**Diagnóstico en logs:**

**Si ves:**
```
❌ Error al descargar/instalar APK: ClientException: Failed host lookup
```

**Solución:** URL incorrecta o no hay internet

---

**Si ves:**
```
❌ Error al descargar/instalar APK: Response status: 404
```

**Solución:** El APK no existe en esa URL

**Verifica:**
1. La URL es correcta y pública
2. El Release en GitHub es público (no Draft)
3. El archivo existe y es un APK válido

---

### Problema 4: "No pide permiso de instalación"

**Si la descarga inicia pero no pide permisos:**

**Verifica en AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```

**Si no está, agrégalo y recompila:**
```bash
flutter clean
flutter build apk --release
```

---

### Problema 5: "El APK se descarga pero no instala"

**Logs esperados:**
```
✅ Descarga completada: /path/to/file.apk
📲 Instalando APK: /path/to/file.apk
✅ APK abierto: true
```

**Si ves `APK abierto: false`:**

**Causas posibles:**
1. No tienes permiso "Instalar apps desconocidas"
2. El archivo no es un APK válido
3. El APK está corrupto

**Solución:**
1. Verifica que el permiso esté activado (Configuración → Apps → REFMP → Instalar apps desconocidas)
2. Descarga el APK manualmente y verifica que se pueda instalar
3. Recompila el APK

---

## 📱 Verificación Manual de Permisos

Para verificar manualmente el estado de los permisos:

1. Abre **Configuración** del dispositivo
2. **Apps** o **Aplicaciones**
3. Busca **REFMP**
4. **Permisos** o **Permisos de la app**
5. Busca **"Instalar apps desconocidas"** o **"Instalar aplicaciones desconocidas"**

**Debe estar activado (✅)** para que funcione la instalación automática.

---

## 🔄 Resetear Todo y Empezar de Nuevo

Si nada funciona, resetea completamente:

```bash
# 1. Desinstalar app del dispositivo
adb uninstall com.refmp.app  # O desinstala desde el dispositivo

# 2. Limpiar proyecto
flutter clean

# 3. Obtener dependencias
flutter pub get

# 4. Recompilar
flutter build apk --release

# 5. Instalar APK manualmente
adb install build/app/outputs/flutter-apk/app-release.apk
# O transfiérelo al dispositivo e instálalo manualmente

# 6. Probar de nuevo desde Prueba 1
```

---

## ✅ Checklist de Funcionamiento Correcto

Todo funciona bien cuando:

- [ ] El diálogo de actualización aparece cuando hay versión nueva
- [ ] NO aparece cuando tienes la última versión
- [ ] El diálogo "Todo al día" se muestra correctamente
- [ ] El permiso se solicita solo la primera vez
- [ ] La descarga muestra progreso (0% → 100%)
- [ ] El instalador de Android se abre automáticamente
- [ ] La instalación completa exitosamente
- [ ] Después de actualizar, ya no pide actualizar de nuevo

---

## 📞 Ayuda Adicional

Si después de seguir todos estos pasos aún tienes problemas:

1. **Recopila logs completos:**
   ```bash
   flutter run > logs.txt 2>&1
   ```
   
2. **Toma captura de los errores en consola**

3. **Verifica:**
   - Versión de Android del dispositivo
   - Versión de Flutter (`flutter --version`)
   - Contenido de la tabla `app_version` en Supabase

4. **Revisa el archivo COMO_CAMBIAR_VERSION.md** para asegurarte de que los números de versión están correctos

---

**Última actualización:** 2026-03-11  
**Versión de este documento:** 1.0
