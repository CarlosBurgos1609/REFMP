# 🔍 VERIFICACIÓN RÁPIDA DE NOTIFICACIONES

## ✅ PASO 1: Verificar que el trigger existe

Ejecuta en el **SQL Editor de Supabase**:

```sql
-- Debe devolver 1 fila con el trigger
SELECT * FROM pg_trigger 
WHERE tgname = 'on_notification_created';
```

**Si no aparece nada:**
```sql
-- Ejecuta el contenido del archivo sql_triggers/notifications_trigger.sql
```

---

## ✅ PASO 2: Verificar tablas y datos

```sql
-- 1. Ver cuántas notificaciones hay
SELECT COUNT(*) as total FROM notifications;

-- 2. Ver las últimas 5 notificaciones
SELECT * FROM notifications ORDER BY created_at DESC LIMIT 5;

-- 3. Ver cuántos user_notifications hay
SELECT COUNT(*) as total FROM user_notifications;

-- 4. Ver notificaciones de tu usuario (REEMPLAZA con tu user_id)
SELECT 
    un.id,
    un.is_read,
    un.is_deleted,
    n.title,
    n.message,
    n.created_at
FROM user_notifications un
JOIN notifications n ON n.id = un.notification_id
WHERE un.user_id = 'TU_USER_ID_AQUI'
ORDER BY n.created_at DESC
LIMIT 10;
```

**Para obtener tu user_id:**
```sql
SELECT id, email FROM auth.users WHERE email = 'tu_email@ejemplo.com';
```

---

## ✅ PASO 3: Prueba manual del trigger

```sql
-- Inserta una notificación de prueba
INSERT INTO notifications (title, message, icon, redirect_to) 
VALUES ('🧪 TEST', 'Notificación de prueba', 'notifications', '/home')
RETURNING *;

-- Verifica que se crearon user_notifications automáticamente
SELECT 
    un.user_id,
    n.title,
    n.message
FROM user_notifications un
JOIN notifications n ON n.id = un.notification_id
WHERE n.title = '🧪 TEST';
```

**Resultado esperado:** Debe aparecer una fila por cada usuario autenticado.

---

## ✅ PASO 4: Verificar permisos del celular

1. Ve a: **Configuración → Apps → REFMP**
2. Toca en **Permisos** o **Notifications**
3. Asegúrate que esté **ACTIVADO**

---

## ✅ PASO 5: Ver logs en Flutter

Ejecuta la app con:
```bash
flutter run --verbose
```

Busca en los logs:
- `🔔 Verificando notificaciones para usuario: ...`
- `📥 Notificaciones no leídas encontradas: X`
- `📢 Mostrando notificación: ...`
- `✅ Notificación marcada como leída`

**Si ves:**
- `❌ No hay usuario autenticado` → No has iniciado sesión
- `ℹ️ No hay notificaciones pendientes` → No hay notificaciones sin leer
- `📥 Notificaciones no leídas encontradas: 0` → El trigger no está creando user_notifications

---

## ✅ PASO 6: Prueba completa

1. **Crea un evento desde la app**
2. **Ve a Supabase y verifica:**
   ```sql
   -- Ver la última notificación creada
   SELECT * FROM notifications ORDER BY id DESC LIMIT 1;
   
   -- Ver si se crearon user_notifications para esa notificación
   SELECT COUNT(*) as usuarios_notificados
   FROM user_notifications
   WHERE notification_id = (SELECT MAX(id) FROM notifications);
   ```
   
3. **Cierra COMPLETAMENTE la app** (desliza desde las apps recientes)
4. **Abre la app nuevamente**
5. **Mira los logs de Flutter**
6. **Deberías ver la notificación emergente**

---

## 🚨 PROBLEMAS COMUNES

### "No hay notificaciones pendientes" pero creé un evento

**Causa:** El trigger no está ejecutándose

**Solución:**
1. Verifica que el trigger existe (PASO 1)
2. Si no existe, ejecuta `sql_triggers/notifications_trigger.sql`
3. Prueba manualmente (PASO 3)

---

### "Notificaciones no leídas encontradas: 0"

**Causa 1:** Ya las leíste
```sql
-- Resetear notificaciones para que aparezcan de nuevo
UPDATE user_notifications 
SET is_read = false 
WHERE user_id = 'TU_USER_ID';
```

**Causa 2:** No se están creando user_notifications
```sql
-- Verificar si hay user_notifications
SELECT COUNT(*) FROM user_notifications WHERE user_id = 'TU_USER_ID';
```

Si es 0, el trigger no está funcionando.

---

### Permiso denegado en Android

```bash
# Desinstala completamente la app
flutter clean
adb uninstall com.example.refmp

# Reinstala
flutter run
```

Cuando se abra, **DEBES aceptar el permiso de notificaciones**.

---

## 📋 CHECKLIST RÁPIDO

- [ ] Trigger `on_notification_created` existe
- [ ] Tabla `notifications` tiene datos
- [ ] Tabla `user_notifications` tiene datos
- [ ] Tengo mi `user_id` correcto
- [ ] Hay notificaciones con `is_read = false` para mi usuario
- [ ] Permiso de notificaciones ACTIVADO en el celular
- [ ] App reinstalada con `flutter clean`
- [ ] Acepto el permiso cuando la app lo pide
- [ ] Cierro y abro la app para activar la verificación

---

## 🆘 SI NADA FUNCIONA

Copia y envía estos resultados:

```sql
-- 1. ¿Existe el trigger?
SELECT COUNT(*) as existe FROM pg_trigger WHERE tgname = 'on_notification_created';

-- 2. ¿Cuántas notificaciones hay?
SELECT COUNT(*) as total FROM notifications;

-- 3. ¿Cuántos user_notifications hay?
SELECT COUNT(*) as total FROM user_notifications;

-- 4. Mi user_id es:
SELECT id FROM auth.users WHERE email = 'tu_email@ejemplo.com';

-- 5. ¿Tengo notificaciones sin leer?
SELECT COUNT(*) FROM user_notifications 
WHERE user_id = 'TU_USER_ID' AND is_read = false AND is_deleted = false;
```

**Y envía un screenshot de:**
- Los permisos de la app en el celular (Configuración → Apps → REFMP → Permisos)
- Los logs de Flutter cuando abres la app
