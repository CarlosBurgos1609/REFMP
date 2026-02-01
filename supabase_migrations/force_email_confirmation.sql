-- EJECUTAR ESTE SCRIPT EN SUPABASE SQL EDITOR
-- Este script deshabilitará completamente la verificación de email para permitir
-- que los usuarios invitados accedan inmediatamente después del registro

-- Opción 1: Deshabilitar verificación de email para todos los usuarios
-- Ve a: Supabase Dashboard > Authentication > Settings > Email Auth
-- Y desmarca "Enable email confirmations"

-- Opción 2: Actualizar usuarios existentes que estén pendientes de verificación
-- Esta query confirma TODOS los usuarios que están esperando verificación
-- NOTA: confirmed_at es una columna generada, solo actualizamos email_confirmed_at
UPDATE auth.users
SET 
  email_confirmed_at = NOW()
WHERE 
  email_confirmed_at IS NULL;

-- Opción 3: Función para auto-confirmar solo a invitados al momento de registro
-- Primero, eliminamos la función anterior si existe
DROP FUNCTION IF EXISTS auto_confirm_guest_user() CASCADE;

-- Crear función que se ejecuta ANTES de insertar en guests
CREATE OR REPLACE FUNCTION auto_confirm_guest_before_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Confirmar el usuario en auth.users inmediatamente
  -- NOTA: confirmed_at es una columna generada, se actualiza automáticamente
  UPDATE auth.users
  SET 
    email_confirmed_at = NOW(),
    raw_app_meta_data = raw_app_meta_data || '{"provider":"email","providers":["email"]}'::jsonb,
    raw_user_meta_data = raw_user_meta_data || '{"email_verified":true}'::jsonb
  WHERE id = NEW.user_id;
  
  RETURN NEW;
END;
$$;

-- Eliminar trigger anterior si existe
DROP TRIGGER IF EXISTS trigger_auto_confirm_guest ON guests;

-- Crear trigger que se ejecuta ANTES de insertar en guests
CREATE TRIGGER trigger_auto_confirm_guest
BEFORE INSERT ON guests
FOR EACH ROW
EXECUTE FUNCTION auto_confirm_guest_before_insert();

-- Verificación: Esta query te mostrará los usuarios invitados y su estado de confirmación
SELECT 
  g.first_name,
  g.last_name,
  g.email,
  g.charge,
  u.email_confirmed_at,
  u.confirmed_at,
  u.last_sign_in_at,
  g.created_at
FROM guests g
LEFT JOIN auth.users u ON g.user_id = u.id
ORDER BY g.created_at DESC
LIMIT 10;

COMMENT ON FUNCTION auto_confirm_guest_before_insert() IS 
'Confirma automáticamente el email de usuarios invitados ANTES de insertar en la tabla guests';
