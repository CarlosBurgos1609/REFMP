# Lista de Verificación: Por qué no llegan las notificaciones

## 1. ✅ Verificar que ejecutaste el SQL Trigger en Supabase

Ve a Supabase → SQL Editor y ejecuta:

```sql
-- Ver si el trigger existe
SELECT * FROM pg_trigger WHERE tgname = 'on_notification_created';

-- Ver si la función existe
SELECT * FROM pg_proc WHERE proname = 'create_user_notifications';
```

Si no aparecen, ejecuta el archivo `sql_triggers/notifications_trigger.sql`

## 2. ✅ Verificar Permisos de Android

En `android/app/src/main/AndroidManifest.xml` debe tener:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

## 3. ✅ Verificar que las tablas existen

En Supabase → Table Editor, verifica:

### Tabla `notifications`
```sql
SELECT * FROM notifications ORDER BY created_at DESC LIMIT 5;
```

### Tabla `user_notifications`
```sql
SELECT * FROM user_notifications ORDER BY created_at DESC LIMIT 5;
```

## 4. 🧪 Prueba Manual

### Paso 1: Crear una notificación de prueba
En Supabase → SQL Editor:

```sql
INSERT INTO notifications (title, message, icon, redirect_to, image)
VALUES (
  '🧪 Notificación de Prueba',
  'Esta es una notificación de prueba del sistema',
  'notifications',
  '/home',
  NULL
);
```

### Paso 2: Verificar que se crearon los registros en user_notifications

```sql
SELECT 
  un.id,
  un.user_id,
  un.is_read,
  un.is_deleted,
  n.title,
  n.message
FROM user_notifications un
JOIN notifications n ON n.id = un.notification_id
WHERE un.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY un.created_at DESC;
```

**Deberías ver un registro por cada usuario autenticado.**

### Paso 3: Ver cuántos usuarios tienen cuenta

```sql
SELECT COUNT(*) as total_users FROM auth.users;
```

## 5. 🔍 Depuración en Flutter

### Ver logs en Android Studio o VS Code:

1. Abre la terminal de debug
2. Busca estos mensajes:

```
✅ Notificaciones inicializadas correctamente
✅ Fetching notifications for userId: xxx
✅ Online: Received response with X notifications
```

Si ves:
```
❌ No authenticated user found
❌ Error fetching notifications
```

Significa que hay un problema con la autenticación.

## 6. 📱 Verificar Permisos en el Dispositivo

### En tu celular:
1. Ve a **Ajustes** → **Aplicaciones** → **REFMP**
2. Ve a **Notificaciones**
3. Asegúrate de que las notificaciones estén **ACTIVADAS**
4. Verifica que el canal "Notificaciones" esté activado

## 7. 🚀 Pasos para probar correctamente

### Opción A: Crear un evento nuevo
1. Cierra completamente la app
2. Abre la app y espera 3 segundos
3. Inicia sesión (si no estás autenticado)
4. Como admin/profesor, crea un **nuevo evento**
5. La notificación debería aparecer inmediatamente para todos los usuarios

### Opción B: Reabrir la app
1. Crea un evento/sede/instrumento/objeto desde la web de Supabase o desde la app
2. Cierra completamente la app (deslizar desde recientes)
3. Abre la app de nuevo
4. Espera 1 segundo después de iniciar sesión
5. Deberías ver la notificación

## 8. 🐛 Problemas Comunes

### Problema: "No se muestra ninguna notificación"
**Solución:**
```bash
# Reinstala la app completamente
flutter clean
flutter pub get
flutter run
```

### Problema: "Error: notification permission denied"
**Solución:**
1. Desinstala la app
2. Instala de nuevo
3. Acepta los permisos de notificación cuando los pida

### Problema: "Las imágenes no se muestran"
**Solución:**
- Verifica que las URLs de las imágenes sean públicas
- Verifica que tengas internet activo
- Las imágenes se descargan temporalmente, puede tardar unos segundos

### Problema: "Solo recibo notificaciones al abrir la app"
**Explicación:** Esto es normal. Las notificaciones se muestran cuando:
- Abres la app (se verifica si hay notificaciones nuevas)
- Se crea algo nuevo mientras tienes la app abierta (stream en tiempo real)

Para notificaciones en segundo plano necesitas Firebase Cloud Messaging (FCM).

## 9. 📊 Verificar el flujo completo

1. **Usuario A (Admin)** crea un evento:
   ```
   ✅ Se inserta en tabla 'events'
   ✅ Se inserta en tabla 'notifications'
   ✅ El trigger crea N registros en 'user_notifications' (uno por usuario)
   ```

2. **Usuario B** abre la app:
   ```
   ✅ main.dart llama a NotificationPage.checkAndShowNotifications()
   ✅ Se consulta user_notifications WHERE user_id = B AND is_read = false
   ✅ Se muestran las notificaciones pendientes
   ✅ Se marcan como is_read = true
   ```

3. **Usuario B** está usando la app:
   ```
   ✅ El stream de Supabase detecta nuevas notificaciones
   ✅ Se muestran automáticamente
   ```

## 10. 🔧 Comandos útiles para depurar

### Ver todas las notificaciones de un usuario específico:
```sql
-- Reemplaza 'USER_ID_AQUI' con el ID del usuario
SELECT 
  n.title,
  n.message,
  un.is_read,
  un.created_at
FROM user_notifications un
JOIN notifications n ON n.id = un.notification_id
WHERE un.user_id = 'USER_ID_AQUI'
ORDER BY un.created_at DESC;
```

### Resetear todas las notificaciones (para probar de nuevo):
```sql
-- CUIDADO: Esto marca todas como no leídas
UPDATE user_notifications SET is_read = false WHERE is_deleted = false;
```

### Eliminar todas las notificaciones de prueba:
```sql
DELETE FROM notifications WHERE title LIKE '%Prueba%';
```

## 11. ✨ Checklist Final

Antes de decir "no funciona", verifica:

- [ ] El trigger SQL está creado en Supabase
- [ ] Hay usuarios autenticados en `auth.users`
- [ ] Los permisos de Android están en el Manifest
- [ ] Los permisos de notificación están activados en el celular
- [ ] Has creado un evento/sede/instrumento/objeto DESPUÉS de instalar la app actualizada
- [ ] Has cerrado y abierto la app después de crear la notificación
- [ ] No hay errores en los logs de Flutter

## 12. 📞 Si sigue sin funcionar

Envíame estos datos:

1. Output de: `SELECT * FROM pg_trigger WHERE tgname = 'on_notification_created';`
2. Output de: `SELECT COUNT(*) FROM notifications;`
3. Output de: `SELECT COUNT(*) FROM user_notifications;`
4. Logs de Flutter (copia todo lo que dice sobre "notification")
5. Captura de pantalla de los permisos de la app en el celular
