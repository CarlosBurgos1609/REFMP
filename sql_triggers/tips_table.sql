-- Tabla para almacenar tips/viñetas educativas por subnivel
CREATE TABLE IF NOT EXISTS tips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sublevel_id UUID NOT NULL REFERENCES sublevels(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    img_url TEXT,
    description TEXT NOT NULL,
    tip_order INTEGER NOT NULL DEFAULT 1, -- Orden de la viñeta (1, 2, 3, etc.)
    experience_points INTEGER DEFAULT 0, -- Puntos XP por completar todas las viñetas
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice para mejorar búsquedas por sublevel_id
CREATE INDEX IF NOT EXISTS idx_tips_sublevel_id ON tips(sublevel_id);

-- Índice para ordenar las viñetas
CREATE INDEX IF NOT EXISTS idx_tips_order ON tips(sublevel_id, tip_order);

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_tips_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tips_updated_at_trigger
    BEFORE UPDATE ON tips
    FOR EACH ROW
    EXECUTE FUNCTION update_tips_updated_at();

-- Comentarios para documentación
COMMENT ON TABLE tips IS 'Almacena tips educativos (viñetas) asociados a sublevels';
COMMENT ON COLUMN tips.tip_order IS 'Orden de presentación de la viñeta (1 = primera, 2 = segunda, etc.)';
COMMENT ON COLUMN tips.experience_points IS 'Puntos XP otorgados al completar TODAS las viñetas del sublevel';
