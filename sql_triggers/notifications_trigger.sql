-- Trigger para crear notificaciones automáticas para todos los usuarios
-- Ejecuta este SQL en tu base de datos Supabase

-- Función que se ejecuta cuando se inserta una nueva notificación
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

-- Eliminar el trigger si existe
DROP TRIGGER IF EXISTS on_notification_created ON notifications;

-- Crear el trigger
CREATE TRIGGER on_notification_created
AFTER INSERT ON notifications
FOR EACH ROW
EXECUTE FUNCTION create_user_notifications();

-- Función para limpiar user_notifications cuando is_deleted = true
CREATE OR REPLACE FUNCTION cleanup_deleted_user_notifications()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_deleted = true THEN
    DELETE FROM user_notifications WHERE id = NEW.id;
    RETURN NULL; -- No devuelve la fila porque se eliminó
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para eliminar automáticamente cuando is_deleted = true
DROP TRIGGER IF EXISTS on_user_notification_deleted ON user_notifications;

CREATE TRIGGER on_user_notification_deleted
AFTER UPDATE OF is_deleted ON user_notifications
FOR EACH ROW
WHEN (NEW.is_deleted = true)
EXECUTE FUNCTION cleanup_deleted_user_notifications();
