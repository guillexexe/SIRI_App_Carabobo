USE proteccion_civil_carabobo;

ALTER TABLE incidentes
  ADD COLUMN estado ENUM('abierto', 'en_proceso', 'cerrado') NOT NULL DEFAULT 'abierto'
  COMMENT 'abierto | en_proceso | cerrado' AFTER cerrado;

UPDATE incidentes SET estado = 'cerrado' WHERE cerrado = 1;
UPDATE incidentes SET estado = 'abierto' WHERE (cerrado = 0 OR cerrado IS NULL) AND estado NOT IN ('cerrado', 'en_proceso');
