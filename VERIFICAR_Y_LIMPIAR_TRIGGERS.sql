-- ============================================
-- VERIFICAR Y LIMPIAR TRIGGERS DUPLICADOS
-- ============================================

-- PASO 1: Ver TODOS los triggers en la tabla EVENTS
-- (Si hay algún trigger aquí, puede estar duplicando eventos)
SELECT 
    t.tgname AS trigger_name,
    pg_get_triggerdef(t.oid) AS definicion_completa
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'events'
AND t.tgisinternal = false
ORDER BY t.tgname;

-- ❗ SI APARECE ALGÚN TRIGGER AQUÍ, COPIA EL NOMBRE Y EJECUTA:
-- DROP TRIGGER IF EXISTS nombre_del_trigger ON events;


-- ============================================
-- PASO 2: Ver TODOS los triggers en la tabla NOTIFICATIONS
SELECT 
    t.tgname AS trigger_name,
    pg_get_triggerdef(t.oid) AS definicion_completa
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'notifications'
AND t.tgisinternal = false
ORDER BY t.tgname;

-- ✅ DEBE APARECER SOLO: on_notification_created
-- ❗ Si aparece MÁS DE UNO, hay duplicación


-- ============================================
-- PASO 3: Ver TODOS los triggers en la tabla USER_NOTIFICATIONS
SELECT 
    t.tgname AS trigger_name,
    pg_get_triggerdef(t.oid) AS definicion_completa
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'user_notifications'
AND t.tgisinternal = false
ORDER BY t.tgname;

-- ✅ DEBE APARECER SOLO: on_user_notification_deleted
-- ❗ Si aparece MÁS DE UNO, hay duplicación


-- ============================================
-- PASO 4: ELIMINAR TODOS LOS TRIGGERS (EMPEZAR DE CERO)
-- ============================================

-- Eliminar trigger de events (SI EXISTE)
DROP TRIGGER IF EXISTS on_notification_created ON events;
DROP TRIGGER IF EXISTS on_event_created ON events;
DROP TRIGGER IF EXISTS create_notification ON events;
DROP TRIGGER IF EXISTS event_notification ON events;

-- Eliminar triggers de notifications (LIMPIAR TODO)
DROP TRIGGER IF EXISTS on_notification_created ON notifications;

-- Eliminar triggers de user_notifications (LIMPIAR TODO)
DROP TRIGGER IF EXISTS on_user_notification_deleted ON user_notifications;


-- ============================================
-- PASO 5: RECREAR TRIGGERS CORRECTOS
-- ============================================

-- 1️⃣ Función para crear user_notifications cuando se inserta en notifications
CREATE OR REPLACE FUNCTION create_user_notifications()
RETURNS TRIGGER AS $$
BEGIN
  -- Insertar una notificación para cada usuario autenticado
  INSERT INTO user_notifications (user_id, notification_id, is_read, is_deleted, created_at)
  SELECT 
    id,
    NEW.id,
    false,
    false,
    NOW()
  FROM auth.users;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2️⃣ Crear trigger en NOTIFICATIONS (NO en events)
CREATE TRIGGER on_notification_created
AFTER INSERT ON notifications
FOR EACH ROW
EXECUTE FUNCTION create_user_notifications();


-- 3️⃣ Función para limpiar user_notifications cuando is_deleted = true
CREATE OR REPLACE FUNCTION cleanup_deleted_user_notifications()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_deleted = true THEN
    DELETE FROM user_notifications WHERE id = NEW.id;
    RETURN NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4️⃣ Crear trigger en USER_NOTIFICATIONS
CREATE TRIGGER on_user_notification_deleted
AFTER UPDATE OF is_deleted ON user_notifications
FOR EACH ROW
WHEN (NEW.is_deleted = true)
EXECUTE FUNCTION cleanup_deleted_user_notifications();


-- ============================================
-- PASO 6: VERIFICAR QUE TODO ESTÁ CORRECTO
-- ============================================

-- Debe aparecer SOLO 1 trigger en notifications
SELECT COUNT(*) as triggers_en_notifications
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'notifications'
AND t.tgisinternal = false;

-- Debe aparecer SOLO 1 trigger en user_notifications
SELECT COUNT(*) as triggers_en_user_notifications
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'user_notifications'
AND t.tgisinternal = false;

-- Debe aparecer 0 triggers en events
SELECT COUNT(*) as triggers_en_events
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'events'
AND t.tgisinternal = false;


-- ============================================
-- PASO 7: PRUEBA MANUAL
-- ============================================

-- Inserta un evento de prueba
INSERT INTO events (
    name, 
    date, 
    time, 
    time_fin, 
    location, 
    month, 
    year, 
    start_datetime, 
    end_datetime
) VALUES (
    '🧪 TEST DUPLICACIÓN',
    NOW(),
    '10:00',
    '11:00',
    'Ubicación de prueba',
    EXTRACT(MONTH FROM NOW()),
    EXTRACT(YEAR FROM NOW()),
    NOW(),
    NOW() + INTERVAL '1 hour'
)
RETURNING *;

-- Verifica cuántos eventos "TEST DUPLICACIÓN" se crearon
SELECT COUNT(*) as cantidad, name 
FROM events 
WHERE name LIKE '%TEST DUPLICACIÓN%'
GROUP BY name;

-- ✅ Debe aparecer: cantidad = 1
-- ❌ Si aparece: cantidad = 2 o más → HAY UN TRIGGER EN EVENTS


-- Si se creó solo 1 evento, elimínalo
DELETE FROM events WHERE name LIKE '%TEST DUPLICACIÓN%';


-- ============================================
-- RESUMEN DE QUÉ DEBE APARECER:
-- ============================================
-- ✅ notifications: 1 trigger (on_notification_created)
-- ✅ user_notifications: 1 trigger (on_user_notification_deleted)  
-- ✅ events: 0 triggers
-- ✅ Al insertar en events: se crea solo 1 evento
-- ✅ Al insertar en notifications: se crean user_notifications para todos los usuarios
