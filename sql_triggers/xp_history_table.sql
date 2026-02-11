-- ============================================
-- TABLA: xp_history
-- Descripción: Historial completo de puntos de experiencia ganados por los usuarios
-- Autor: Sistema REFMP
-- Fecha de creación: 2026-02-10
-- ============================================

-- Eliminar tabla si existe (solo para desarrollo, comentar en producción)
-- DROP TABLE IF EXISTS public.xp_history CASCADE;

-- Crear la tabla de historial de XP
CREATE TABLE IF NOT EXISTS public.xp_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    points_earned INTEGER NOT NULL CHECK (points_earned > 0),
    source TEXT NOT NULL CHECK (source IN (
        'tips_completion',
        'educational_game',
        'beginner_game',
        'level_completion',
        'achievement_unlocked',
        'daily_bonus',
        'weekly_bonus',
        'other'
    )),
    source_id TEXT,
    source_name TEXT,
    source_details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_xp_history_user_id ON public.xp_history(user_id);
CREATE INDEX IF NOT EXISTS idx_xp_history_created_at ON public.xp_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_xp_history_source ON public.xp_history(source);
CREATE INDEX IF NOT EXISTS idx_xp_history_user_created ON public.xp_history(user_id, created_at DESC);

-- Comentarios para la tabla y columnas
COMMENT ON TABLE public.xp_history IS 'Historial detallado de puntos de experiencia ganados por los usuarios';
COMMENT ON COLUMN public.xp_history.id IS 'Identificador único del registro de historial';
COMMENT ON COLUMN public.xp_history.user_id IS 'ID del usuario que ganó los puntos';
COMMENT ON COLUMN public.xp_history.points_earned IS 'Cantidad de puntos XP ganados';
COMMENT ON COLUMN public.xp_history.source IS 'Origen de los puntos (tips, juego educativo, juego principiante, etc.)';
COMMENT ON COLUMN public.xp_history.source_id IS 'ID del elemento que generó los puntos (tip_id, level_id, etc.)';
COMMENT ON COLUMN public.xp_history.source_name IS 'Nombre descriptivo del elemento (ej: nombre del tip, nivel, etc.)';
COMMENT ON COLUMN public.xp_history.source_details IS 'Detalles adicionales en formato JSON (ej: dificultad, tiempo, estrellas, etc.)';
COMMENT ON COLUMN public.xp_history.created_at IS 'Fecha y hora en que se ganaron los puntos';

-- Políticas RLS (Row Level Security)
ALTER TABLE public.xp_history ENABLE ROW LEVEL SECURITY;

-- Política: Los usuarios pueden ver su propio historial
CREATE POLICY "Users can view their own XP history"
    ON public.xp_history
    FOR SELECT
    USING (auth.uid() = user_id);

-- Política: El sistema puede insertar registros de historial
CREATE POLICY "System can insert XP history"
    ON public.xp_history
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Política: Solo el propietario puede eliminar su propio historial (deshabilitado para seguridad)
-- Los registros de XP no deben eliminarse para mantener integridad del historial
-- Si se necesita esta funcionalidad, descomentar la siguiente política:
-- CREATE POLICY "Users can delete their own XP history"
--     ON public.xp_history
--     FOR DELETE
--     USING (auth.uid() = user_id);

-- Función para obtener el total de XP por fuente
CREATE OR REPLACE FUNCTION get_xp_by_source(p_user_id UUID)
RETURNS TABLE (
    source TEXT,
    total_points BIGINT,
    count_records BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        xp.source,
        SUM(xp.points_earned)::BIGINT as total_points,
        COUNT(*)::BIGINT as count_records
    FROM public.xp_history xp
    WHERE xp.user_id = p_user_id
    GROUP BY xp.source
    ORDER BY total_points DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para obtener historial de XP semanal
CREATE OR REPLACE FUNCTION get_weekly_xp_history(p_user_id UUID)
RETURNS TABLE (
    day_of_week INTEGER,
    total_points BIGINT,
    record_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        EXTRACT(DOW FROM xp.created_at)::INTEGER as day_of_week,
        SUM(xp.points_earned)::BIGINT as total_points,
        COUNT(*)::BIGINT as record_count
    FROM public.xp_history xp
    WHERE xp.user_id = p_user_id
    AND xp.created_at >= DATE_TRUNC('week', NOW())
    GROUP BY day_of_week
    ORDER BY day_of_week;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para obtener el historial reciente de XP
CREATE OR REPLACE FUNCTION get_recent_xp_history(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    points_earned INTEGER,
    source TEXT,
    source_name TEXT,
    source_details JSONB,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        xp.id,
        xp.points_earned,
        xp.source,
        xp.source_name,
        xp.source_details,
        xp.created_at
    FROM public.xp_history xp
    WHERE xp.user_id = p_user_id
    ORDER BY xp.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para validar que los puntos sean positivos
CREATE OR REPLACE FUNCTION validate_xp_points()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.points_earned <= 0 THEN
        RAISE EXCEPTION 'Los puntos de experiencia deben ser mayores a cero';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_xp_points
    BEFORE INSERT OR UPDATE ON public.xp_history
    FOR EACH ROW
    EXECUTE FUNCTION validate_xp_points();

-- Grant permissions
GRANT SELECT, INSERT ON public.xp_history TO authenticated;
GRANT EXECUTE ON FUNCTION get_xp_by_source(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_weekly_xp_history(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_recent_xp_history(UUID, INTEGER) TO authenticated;

-- ============================================
-- EJEMPLOS DE USO
-- ============================================

-- Insertar un registro de historial
-- INSERT INTO public.xp_history (user_id, points_earned, source, source_id, source_name, source_details)
-- VALUES (
--     'user-uuid-here',
--     100,
--     'tips_completion',
--     'tip-123',
--     'Técnica de respiración',
--     '{"sublevel": "Técnicas básicas", "total_tips": 5}'::jsonb
-- );

-- Obtener historial de un usuario
-- SELECT * FROM public.xp_history WHERE user_id = 'user-uuid-here' ORDER BY created_at DESC LIMIT 10;

-- Obtener total de XP por fuente
-- SELECT * FROM get_xp_by_source('user-uuid-here');

-- Obtener historial semanal
-- SELECT * FROM get_weekly_xp_history('user-uuid-here');

-- Obtener historial reciente
-- SELECT * FROM get_recent_xp_history('user-uuid-here', 20);
