-- ============================================
-- MIGRACIÓN DE BASE DE DATOS: SONG_NOTES 
-- Agregar chromatic_id y eliminar note_name
-- ============================================

-- 1. Agregar la columna chromatic_id como foreign key
ALTER TABLE song_notes 
ADD COLUMN chromatic_id INTEGER REFERENCES chromatic_scale(id);

-- 2. Eliminar la columna note_name (ya no se necesita)
ALTER TABLE song_notes 
DROP COLUMN IF EXISTS note_name;

-- 3. Crear índice para mejorar performance en las consultas con JOIN
CREATE INDEX idx_song_notes_chromatic_id ON song_notes(chromatic_id);

-- 4. Crear índice compuesto para optimizar consultas por canción y tiempo
CREATE INDEX idx_song_notes_song_time ON song_notes(song_id, start_time_ms);

-- ============================================
-- CONSULTAS DE EJEMPLO PARA USAR EN LA APP
-- ============================================

-- Consulta principal: Obtener notas con datos de chromatic_scale
-- Esta es la consulta que usa DatabaseService.getSongNotes()
/*
SELECT 
    sn.id,
    sn.song_id,
    sn.start_time_ms,
    sn.duration_ms,
    sn.beat_position,
    sn.measure_number,
    sn.note_type,
    sn.velocity,
    sn.chromatic_id,
    sn.created_at,
    -- Datos de chromatic_scale (incluyendo english_name y note_url)
    cs.id as chromatic_scale_id,
    cs.instrument_id,
    cs.english_name,        -- PRINCIPAL: Nombre de la nota (F4, G4, etc.)
    cs.spanish_name,        -- Opcional: Nombre en español
    cs.octave,
    cs.alternative,
    cs.piston_1,            -- "Tocando" o "Aire"
    cs.piston_2,            -- "Tocando" o "Aire"  
    cs.piston_3,            -- "Tocando" o "Aire"
    cs.note_url             -- IMPORTANTE: URL del audio de la nota
FROM song_notes sn
LEFT JOIN chromatic_scale cs ON sn.chromatic_id = cs.id
WHERE sn.song_id = 'TU_SONG_ID_AQUI'
ORDER BY sn.start_time_ms;
*/

-- Consulta simple para verificar la migración
/*
SELECT 
    COUNT(*) as total_notes,
    COUNT(chromatic_id) as notes_with_chromatic,
    COUNT(*) - COUNT(chromatic_id) as notes_without_chromatic
FROM song_notes;
*/

-- Consulta para ver ejemplos de notas con sus datos cromáticos
/*
SELECT 
    sn.song_id,
    sn.start_time_ms,
    cs.english_name,        -- Nombre de la nota que se muestra
    cs.piston_1,
    cs.piston_2,
    cs.piston_3,
    cs.note_url             -- URL del audio para reproducir
FROM song_notes sn
JOIN chromatic_scale cs ON sn.chromatic_id = cs.id
LIMIT 10;
*/

-- ============================================
-- CONSULTAS PARA POBLACIÓN DE DATOS (OPCIONAL)
-- ============================================

-- Si necesitas migrar notas existentes que tenían note_name:
-- NOTA: Esta consulta es solo de ejemplo, ajusta según tus datos
/*
UPDATE song_notes 
SET chromatic_id = (
    SELECT cs.id 
    FROM chromatic_scale cs 
    WHERE cs.english_name = song_notes.note_name 
    OR cs.spanish_name = song_notes.note_name
    LIMIT 1
)
WHERE chromatic_id IS NULL 
AND note_name IS NOT NULL;

-- Después de la migración, eliminar la columna note_name
-- ALTER TABLE song_notes DROP COLUMN note_name;
*/

-- ============================================
-- VERIFICACIONES POST-MIGRACIÓN
-- ============================================

-- Verificar que la foreign key funciona correctamente
/*
SELECT 
    constraint_name,
    table_name,
    column_name,
    foreign_table_name,
    foreign_column_name
FROM information_schema.key_column_usage
WHERE table_name = 'song_notes' 
AND column_name = 'chromatic_id';
*/

-- Verificar índices creados
/*
SELECT 
    indexname,
    tablename,
    indexdef
FROM pg_indexes 
WHERE tablename = 'song_notes'
ORDER BY indexname;
*/

-- ============================================
-- NOTAS IMPORTANTES
-- ============================================
/*
1. La columna chromatic_id es opcional (NULL permitido) para compatibilidad
2. Las notas sin chromatic_id usarán el sistema fallback en la aplicación
3. Se recomienda poblar chromatic_id para todas las notas nuevas
4. El campo note_name fue ELIMINADO de song_notes, ahora se obtiene del JOIN con chromatic_scale.english_name
5. Las consultas incluyen LEFT JOIN para manejar notas sin chromatic_id
6. El sistema de audio usa note_url de chromatic_scale para reproducir sonidos
7. Cuando el jugador hace "hit", se reproduce automáticamente el sonido de la nota

FLUJO DE AUDIO:
- Jugador presiona pistones → Hit exitoso → Se reproduce note_url de chromatic_scale
- El nombre mostrado viene de english_name (F4, G4, A4, etc.)
- Los estados de pistones vienen de piston_1, piston_2, piston_3 ("Tocando" o "Aire")
*/