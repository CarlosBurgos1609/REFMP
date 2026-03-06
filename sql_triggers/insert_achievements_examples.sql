-- Script de ejemplo para insertar logros (achievements) vinculados a niveles
-- Reemplaza los UUID con los IDs reales de tus niveles

-- NOTA: Primero debes obtener los IDs de los niveles ejecutando:
-- SELECT id, name, number FROM public.levels WHERE instrument_id = (SELECT id FROM instruments WHERE name = 'Trompeta');

-- Ejemplo de inserción de logros para cada nivel de trompeta:

-- Logro para completar Nivel 2
INSERT INTO public.achievements (name, description, image, level_id, created_at) 
VALUES (
  'Trompetista Nivel 2',
  'Esta medalla se da a los usuarios que han completado el nivel 2',
  'https://dmhyuogexghhnvfgroup.supabase.co/storage/v1/object/public/achievements/nivel2.png',
  'UUID_DEL_NIVEL_2', -- Reemplazar con el ID real del nivel 2
  now()
);

-- Logro para completar Nivel 3
INSERT INTO public.achievements (name, description, image, level_id, created_at) 
VALUES (
  'Trompetista Nivel 3',
  'Esta medalla se da a los usuarios que han completado el nivel 3',
  'https://dmhyuogexghhnvfgroup.supabase.co/storage/v1/object/public/achievements/nivel3.png',
  'UUID_DEL_NIVEL_3', -- Reemplazar con el ID real del nivel 3
  now()
);

-- Logro para completar Nivel 4 (Experto)
INSERT INTO public.achievements (name, description, image, level_id, created_at) 
VALUES (
  'Trompetista Experto',
  'Esta medalla se da a los usuarios que han completado el nivel 4 y dominan la trompeta',
  'https://dmhyuogexghhnvfgroup.supabase.co/storage/v1/object/public/achievements/experto.png',
  'UUID_DEL_NIVEL_4', -- Reemplazar con el ID real del nivel 4
  now()
);

-- Para obtener los UUID correctos, ejecuta esta consulta:
-- SELECT l.id, l.name, l.number, i.name as instrument
-- FROM public.levels l
-- JOIN public.instruments i ON l.instrument_id = i.id
-- WHERE i.name = 'Trompeta'
-- ORDER BY l.number;

-- Luego reemplaza los UUID_DEL_NIVEL_X con los IDs reales
