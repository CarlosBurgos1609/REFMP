-- Tabla para almacenar el historial de experiencia semanal por día
CREATE TABLE IF NOT EXISTS weekly_xp_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0 = Domingo, 6 = Sábado
  xp_earned DOUBLE PRECISION NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT unique_user_day UNIQUE (user_id, day_of_week, created_at::date)
);

-- Índice para búsquedas rápidas por usuario y fecha
CREATE INDEX IF NOT EXISTS idx_weekly_xp_history_user_id ON weekly_xp_history(user_id);
CREATE INDEX IF NOT EXISTS idx_weekly_xp_history_created_at ON weekly_xp_history(created_at);
CREATE INDEX IF NOT EXISTS idx_weekly_xp_history_user_date ON weekly_xp_history(user_id, created_at);

-- Habilitar RLS (Row Level Security)
ALTER TABLE weekly_xp_history ENABLE ROW LEVEL SECURITY;

-- Política para que los usuarios puedan ver su propio historial
CREATE POLICY "Users can view their own XP history" 
  ON weekly_xp_history FOR SELECT 
  USING (auth.uid() = user_id);

-- Política para que los usuarios puedan ver el historial de otros (para comparar)
CREATE POLICY "Users can view other users XP history for comparison" 
  ON weekly_xp_history FOR SELECT 
  USING (true);

-- Política para que el sistema pueda insertar registros
CREATE POLICY "System can insert XP history" 
  ON weekly_xp_history FOR INSERT 
  WITH CHECK (true);

COMMENT ON TABLE weekly_xp_history IS 'Almacena el historial diario de experiencia semanal de los usuarios para mostrar estadísticas';
COMMENT ON COLUMN weekly_xp_history.day_of_week IS '0 = Domingo, 1 = Lunes, ..., 6 = Sábado';
COMMENT ON COLUMN weekly_xp_history.xp_earned IS 'Experiencia ganada en ese día específico';
