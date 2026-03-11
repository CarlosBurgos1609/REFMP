-- ========================================
-- SCRIPT PARA CREAR TABLA DE VERSIONES
-- Copia y pega todo esto en el SQL Editor de Supabase
-- ========================================

-- Crear tabla app_version
CREATE TABLE app_version (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version VARCHAR(20) NOT NULL,
    build_number INTEGER NOT NULL UNIQUE,
    required BOOLEAN DEFAULT false,
    release_notes TEXT,
    android_url TEXT,
    ios_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índice para búsquedas rápidas
CREATE INDEX idx_app_version_build_number ON app_version(build_number DESC);

-- Habilitar RLS (Row Level Security)
ALTER TABLE app_version ENABLE ROW LEVEL SECURITY;

-- Política para permitir lectura pública (la app necesita leer versiones)
CREATE POLICY "Permitir lectura pública de versiones"
ON app_version FOR SELECT
TO public
USING (true);

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

-- ========================================
-- LISTO! Ahora inserta tu primera versión:
-- ========================================
-- Después de crear el APK y subirlo a GitHub, ejecuta este INSERT
-- reemplazando la URL con la real de tu GitHub Release:

-- INSERT INTO app_version (version, build_number, required, release_notes, android_url)
-- VALUES (
--     '1.0.0',
--     1,
--     false,
--     'Versión inicial de la aplicación',
--     'https://github.com/TU_USUARIO/TU_REPO/releases/download/v1.0.0/app-release.apk'
-- );
