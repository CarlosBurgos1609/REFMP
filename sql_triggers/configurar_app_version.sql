-- ================================================
-- CONFIGURACIÓN TABLA app_version PARA ACTUALIZACIONES
-- ================================================
-- Ejecuta este script en Supabase SQL Editor
-- Esto permitirá que la app verifique actualizaciones sin autenticación

-- 1. Crear tabla app_version si no existe
CREATE TABLE IF NOT EXISTS app_version (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version TEXT NOT NULL,
  build_number INTEGER NOT NULL,
  release_notes TEXT,
  android_url TEXT,
  ios_url TEXT,
  required BOOLEAN DEFAULT false,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Crear índice para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_app_version_build_number 
ON app_version(build_number DESC);

CREATE INDEX IF NOT EXISTS idx_app_version_active 
ON app_version(active) WHERE active = true;

-- 3. Habilitar RLS (Row Level Security)
ALTER TABLE app_version ENABLE ROW LEVEL SECURITY;

-- 4. Eliminar políticas anteriores si existen
DROP POLICY IF EXISTS "Permitir lectura pública de versiones" ON app_version;
DROP POLICY IF EXISTS "Permitir lectura pública de versiones activas" ON app_version;

-- 5. Crear política para lectura pública (sin autenticación)
CREATE POLICY "Permitir lectura pública de versiones activas"
ON app_version
FOR SELECT
TO anon, authenticated
USING (active = true);

-- 6. Insertar versión inicial de ejemplo
-- ⚠️ MODIFICA ESTOS VALORES SEGÚN TU VERSIÓN ACTUAL
INSERT INTO app_version (
  version,
  build_number,
  release_notes,
  android_url,
  ios_url,
  required,
  active
) VALUES (
  '1.0.0',                    -- ← Cambiar: Versión actual de tu app
  1,                          -- ← Cambiar: Build number actual
  '• Versión inicial\n• Todas las funcionalidades básicas implementadas',
  '',                         -- Dejar vacío si no hay APK aún
  '',                         -- Dejar vacío para iOS
  false,                      -- No es obligatoria
  true                        -- Está activa
)
ON CONFLICT DO NOTHING;  -- No insertar si ya existe una versión

-- ================================================
-- VERIFICAR CONFIGURACIÓN
-- ================================================

-- Ver todas las versiones
SELECT 
  version,
  build_number,
  release_notes,
  android_url,
  required,
  active,
  created_at
FROM app_version
ORDER BY build_number DESC;

-- Verificar políticas RLS
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'app_version';

-- ================================================
-- EJEMPLO: INSERTAR NUEVA VERSIÓN (ACTUALIZACIÓN)
-- ================================================

-- Cuando publiques una actualización, ejecuta esto:
-- (Modifica los valores según tu actualización)

/*
INSERT INTO app_version (
  version,
  build_number,
  release_notes,
  android_url,
  ios_url,
  required,
  active
) VALUES (
  '1.0.1',                    -- ← Nueva versión
  2,                          -- ← Nuevo build number (debe ser MAYOR)
  '• Corrección de errores en carga de objetos
• Mejoras en velocidad de actualizaciones
• Nuevo sistema de caché
• Optimización de rendimiento',
  'https://github.com/TU_USUARIO/TU_REPO/releases/download/v1.0.1/refmp-v1.0.1.apk',
  '',                         -- iOS (opcional)
  false,                      -- ¿Es obligatoria? (false = opcional)
  true                        -- Activa
);
*/

-- ================================================
-- FUNCIONES ÚTILES
-- ================================================

-- Desactivar una versión antigua
/*
UPDATE app_version 
SET active = false 
WHERE version = '1.0.0';
*/

-- Ver solo versión activa más reciente
/*
SELECT * FROM app_version 
WHERE active = true 
ORDER BY build_number DESC 
LIMIT 1;
*/

-- Hacer una actualización obligatoria
/*
UPDATE app_version 
SET required = true 
WHERE version = '1.0.1';
*/

-- Cambiar URL del APK
/*
UPDATE app_version 
SET android_url = 'https://nueva-url.com/app.apk',
    updated_at = NOW()
WHERE version = '1.0.1';
*/

-- ================================================
-- NOTAS IMPORTANTES
-- ================================================

/*
1. BUILD NUMBER siempre debe aumentar:
   - Versión 1.0.0 → build_number: 1
   - Versión 1.0.1 → build_number: 2
   - Versión 1.1.0 → build_number: 3
   - etc.

2. ACTIVE debe ser true para que la app la detecte

3. REQUIRED = true hace que el usuario NO pueda cerrar el diálogo
   (Solo usar para actualizaciones críticas de seguridad)

4. ANDROID_URL debe apuntar a un APK público en GitHub Releases

5. Para probar actualizaciones:
   - Instala versión antigua en dispositivo
   - Publica versión nueva en GitHub
   - Inserta nueva versión en esta tabla
   - Abre la app → debe mostrar diálogo de actualización

6. La app compara BUILD_NUMBER, NO la versión de texto
   - Si app tiene build_number 1 y tabla tiene 2 → pide actualizar
   - Si app tiene build_number 2 y tabla tiene 2 → no pide actualizar
*/

-- ================================================
-- FIN DEL SCRIPT
-- ================================================
