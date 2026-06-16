USE proteccion_civil_carabobo;

-- Normaliza valores previos antes de convertir a ENUM.
UPDATE incidentes
SET estado = 'cerrado'
WHERE (cerrado = 1 OR cerrado = TRUE) AND (estado IS NULL OR estado NOT IN ('abierto', 'en_proceso', 'cerrado'));

UPDATE incidentes
SET estado = 'abierto'
WHERE (cerrado = 0 OR cerrado IS NULL) AND (estado IS NULL OR estado NOT IN ('abierto', 'en_proceso', 'cerrado'));

ALTER TABLE incidentes
  MODIFY COLUMN estado ENUM('abierto', 'en_proceso', 'cerrado') NOT NULL DEFAULT 'abierto'
  COMMENT 'abierto | en_proceso | cerrado';
