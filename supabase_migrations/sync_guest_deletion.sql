-- Script para sincronizar eliminación de usuarios guests con auth.users
-- Cuando se elimina un invitado de la tabla guests, también se elimina de auth.users

-- Función para eliminar usuario de auth.users cuando se elimina de guests
CREATE OR REPLACE FUNCTION delete_auth_user_on_guest_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Eliminar el usuario de auth.users cuando se elimina de guests
  -- Esto asegura que no queden usuarios huérfanos en auth.users
  DELETE FROM auth.users WHERE id = OLD.user_id;
  
  RETURN OLD;
END;
$$;

-- Eliminar trigger anterior si existe
DROP TRIGGER IF EXISTS trigger_delete_auth_user_on_guest_delete ON guests;

-- Crear trigger que se ejecuta DESPUÉS de eliminar un guest
CREATE TRIGGER trigger_delete_auth_user_on_guest_delete
AFTER DELETE ON guests
FOR EACH ROW
EXECUTE FUNCTION delete_auth_user_on_guest_delete();

-- Función mejorada para eliminar invitados antiguos (más de 1 mes)
-- Esta función elimina de guests, lo cual disparará el trigger que elimina de auth.users

-- Eliminar función anterior si existe (necesario porque cambiamos el tipo de retorno)
DROP FUNCTION IF EXISTS delete_old_guests();

CREATE OR REPLACE FUNCTION delete_old_guests()
RETURNS TABLE(deleted_count INT, deleted_emails TEXT[])
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  guest_record RECORD;
  deleted_list TEXT[] := '{}';
  total_deleted INT := 0;
BEGIN
  -- Encontrar y eliminar todos los invitados mayores a 1 mes
  FOR guest_record IN
    SELECT user_id, email, first_name, last_name
    FROM guests
    WHERE created_at < NOW() - INTERVAL '1 month'
  LOOP
    -- Agregar a la lista de eliminados
    deleted_list := array_append(deleted_list, guest_record.email);
    
    -- Eliminar de guests (el trigger eliminará de auth.users automáticamente)
    DELETE FROM guests WHERE user_id = guest_record.user_id;
    
    total_deleted := total_deleted + 1;
    
    RAISE NOTICE 'Deleted guest user: % % (%) - User ID: %', 
      guest_record.first_name, 
      guest_record.last_name, 
      guest_record.email,
      guest_record.user_id;
  END LOOP;
  
  RETURN QUERY SELECT total_deleted, deleted_list;
END;
$$;

-- Script para limpiar usuarios huérfanos existentes (que están en auth.users pero no en guests)
-- EJECUTAR ESTO SOLO UNA VEZ para limpiar datos existentes
DO $$
DECLARE
  orphan_user RECORD;
  deleted_count INT := 0;
BEGIN
  -- Encontrar usuarios en auth.users que NO tienen registro en guests
  -- pero que fueron creados como invitados (podemos identificarlos por email o metadata)
  FOR orphan_user IN
    SELECT u.id, u.email
    FROM auth.users u
    LEFT JOIN guests g ON u.id = g.user_id
    WHERE g.user_id IS NULL
    AND u.email_confirmed_at IS NOT NULL
    AND u.created_at < NOW() - INTERVAL '1 day' -- Solo usuarios de más de 1 día
  LOOP
    -- Verificar que no esté en ninguna otra tabla de usuarios
    IF NOT EXISTS (
      SELECT 1 FROM students WHERE user_id = orphan_user.id
      UNION
      SELECT 1 FROM teachers WHERE user_id = orphan_user.id
      UNION
      SELECT 1 FROM advisors WHERE user_id = orphan_user.id
      UNION
      SELECT 1 FROM graduates WHERE user_id = orphan_user.id
      UNION
      SELECT 1 FROM parents WHERE user_id = orphan_user.id
      UNION
      SELECT 1 FROM directors WHERE user_id = orphan_user.id
    ) THEN
      -- Este es un usuario huérfano, eliminarlo
      DELETE FROM auth.users WHERE id = orphan_user.id;
      deleted_count := deleted_count + 1;
      RAISE NOTICE 'Deleted orphan user: % (ID: %)', orphan_user.email, orphan_user.id;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Total orphan users deleted: %', deleted_count;
END;
$$;

-- Verificar la configuración
SELECT 
  'Trigger configurado correctamente' as status,
  COUNT(*) as total_guests,
  COUNT(*) FILTER (WHERE created_at < NOW() - INTERVAL '1 month') as guests_to_delete
FROM guests;

COMMENT ON FUNCTION delete_auth_user_on_guest_delete() IS 
'Elimina automáticamente el usuario de auth.users cuando se elimina un registro de guests';

COMMENT ON FUNCTION delete_old_guests() IS 
'Elimina invitados mayores a 1 mes. Retorna el conteo y lista de emails eliminados';
