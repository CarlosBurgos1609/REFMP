-- Configuración para deshabilitar confirmación de email para invitados
-- Este script debe ejecutarse desde Supabase Dashboard > SQL Editor

-- Opción 1: Deshabilitar confirmación de email globalmente
-- Ve a: Dashboard > Authentication > Settings > Email Auth
-- Y deshabilita "Enable email confirmations"

-- Opción 2: Crear función para auto-confirmar usuarios invitados
CREATE OR REPLACE FUNCTION auto_confirm_guest_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verificar si el usuario es invitado
  IF EXISTS (
    SELECT 1 FROM guests WHERE user_id = NEW.id
  ) THEN
    -- Actualizar el usuario para que esté confirmado
    UPDATE auth.users
    SET email_confirmed_at = NOW(),
        confirmed_at = NOW()
    WHERE id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Crear trigger que se ejecuta después de insertar en guests
DROP TRIGGER IF EXISTS trigger_auto_confirm_guest ON guests;
CREATE TRIGGER trigger_auto_confirm_guest
AFTER INSERT ON guests
FOR EACH ROW
EXECUTE FUNCTION auto_confirm_guest_user();

COMMENT ON FUNCTION auto_confirm_guest_user() IS 
'Confirma automáticamente el email de usuarios invitados después del registro';
