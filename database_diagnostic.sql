-- ============================================
-- DIAGNÓSTICO DE COLUMNAS EN CHROMATIC_SCALE
-- Ejecuta estas consultas para verificar la estructura
-- ============================================

-- 1. Verificar estructura de la tabla chromatic_scale
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'chromatic_scale'
ORDER BY ordinal_position;

-- 2. Verificar estructura de la tabla song_notes
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'song_notes'
ORDER BY ordinal_position;

-- 3. Consulta de prueba simple para chromatic_scale
SELECT id, english_name, piston_1, piston_2, piston_3, note_url
FROM chromatic_scale
LIMIT 5;

-- 4. Consulta de prueba con JOIN (la que usa la app)
SELECT 
    sn.id,
    sn.song_id,
    sn.start_time_ms,
    sn.chromatic_id,
    cs.english_name,
    cs.piston_1,
    cs.piston_2,
    cs.piston_3,
    cs.note_url
FROM song_notes sn
LEFT JOIN chromatic_scale cs ON sn.chromatic_id = cs.id
WHERE sn.song_id = '5bede34f-d78a-462e-bc94-4a3204a72ca5'
LIMIT 3;

-- 5. Verificar si hay datos en chromatic_scale
SELECT COUNT(*) as total_chromatic_notes FROM chromatic_scale;

-- 6. Verificar si hay song_notes con chromatic_id
SELECT 
    COUNT(*) as total_song_notes,
    COUNT(chromatic_id) as notes_with_chromatic_id
FROM song_notes 
WHERE song_id = '5bede34f-d78a-462e-bc94-4a3204a72ca5';