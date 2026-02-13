-- Tabla para controlar versiones de la aplicación
-- Esta tabla permite verificar si hay actualizaciones disponibles

CREATE TABLE IF NOT EXISTS app_version (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version VARCHAR(20) NOT NULL, -- Ejemplo: "1.0.1"
    build_number INTEGER NOT NULL UNIQUE, -- Build number incremental (debe ser único)
    required BOOLEAN DEFAULT false, -- Si la actualización es obligatoria
    release_notes TEXT, -- Notas de la versión / changelog
    android_url TEXT, -- URL de Google Play Store
    ios_url TEXT, -- URL de App Store
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice para búsquedas rápidas por build_number
CREATE INDEX IF NOT EXISTS idx_app_version_build_number 
ON app_version(build_number DESC);

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_app_version_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_app_version_updated_at
    BEFORE UPDATE ON app_version
    FOR EACH ROW
    EXECUTE FUNCTION update_app_version_updated_at();

-- Insertar versión inicial (ejemplo)
INSERT INTO app_version (version, build_number, required, release_notes, android_url, ios_url)
VALUES (
    '1.0.0',
    1,
    false,
    'Versión inicial de la aplicación',
    'https://play.google.com/store/apps/details?id=tu.paquete.app',
    'https://apps.apple.com/app/idTU_APP_ID'
);

-- Comentarios explicativos
COMMENT ON TABLE app_version IS 'Tabla para gestionar versiones de la aplicación y control de actualizaciones';
COMMENT ON COLUMN app_version.version IS 'Versión semántica (ej: 1.0.0)';
COMMENT ON COLUMN app_version.build_number IS 'Número de build incremental único';
COMMENT ON COLUMN app_version.required IS 'Si es true, la actualización es obligatoria';
COMMENT ON COLUMN app_version.release_notes IS 'Descripción de cambios en esta versión';
COMMENT ON COLUMN app_version.android_url IS 'URL de Google Play Store para Android';
COMMENT ON COLUMN app_version.ios_url IS 'URL de App Store para iOS';

-- Ejemplo de cómo insertar una nueva versión:
-- INSERT INTO app_version (version, build_number, required, release_notes, android_url, ios_url)
-- VALUES (
--     '1.0.1',
--     2,
--     false,
--     '- Corrección de errores\n- Mejoras de rendimiento\n- Nueva funcionalidad X',
--     'https://play.google.com/store/apps/details?id=tu.paquete.app',
--     'https://apps.apple.com/app/idTU_APP_ID'
-- );
