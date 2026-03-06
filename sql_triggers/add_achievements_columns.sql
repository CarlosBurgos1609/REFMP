-- Agregar columnas faltantes a la tabla achievements
-- Ejecutar este script en la base de datos de Supabase

-- 1. Agregar columna level_id (relación con la tabla levels)
ALTER TABLE public.achievements 
ADD COLUMN IF NOT EXISTS level_id uuid REFERENCES public.levels(id) ON DELETE CASCADE;

-- 2. Agregar columna created_at para timestamp de creación
ALTER TABLE public.achievements 
ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- 3. Crear índice para búsquedas más rápidas por level_id
CREATE INDEX IF NOT EXISTS idx_achievements_level_id ON public.achievements(level_id);

-- 4. Agregar comentarios para documentación
COMMENT ON COLUMN public.achievements.level_id IS 'ID del nivel asociado al logro. Cuando un usuario completa este nivel, recibe el logro.';
COMMENT ON COLUMN public.achievements.created_at IS 'Fecha y hora de creación del logro';

-- Ejemplo de inserción de logros para niveles:
-- INSERT INTO public.achievements (name, description, image, level_id, created_at) VALUES
-- ('Trompetista Nivel 2', 'Esta medalla se da a los usuarios que han completado el nivel 2', 'URL_DE_IMAGEN', 'UUID_DEL_NIVEL_2', now()),
-- ('Trompetista Nivel 3', 'Esta medalla se da a los usuarios que han completado el nivel 3', 'URL_DE_IMAGEN', 'UUID_DEL_NIVEL_3', now()),
-- ('Trompetista Nivel 4', 'Esta medalla se da a los usuarios que han completado el nivel 4', 'URL_DE_IMAGEN', 'UUID_DEL_NIVEL_4', now());
