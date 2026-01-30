-- Agregar columna coins a la tabla game
-- Esta columna almacenará la cantidad de monedas que se obtienen al completar un juego

ALTER TABLE game 
ADD COLUMN IF NOT EXISTS coins INTEGER DEFAULT 0;

-- Actualizar algunos registros de ejemplo (opcional - ajusta según tus necesidades)
-- UPDATE game SET coins = 10 WHERE difficulty = 'easy';
-- UPDATE game SET coins = 20 WHERE difficulty = 'medium';
-- UPDATE game SET coins = 30 WHERE difficulty = 'hard';

COMMENT ON COLUMN game.coins IS 'Cantidad de monedas que se obtienen al completar el juego';
