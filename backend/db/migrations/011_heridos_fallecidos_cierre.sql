-- Víctimas al cerrar solo cuando el incidente pasó por en_proceso (NULL = cierre directo desde abierto)
ALTER TABLE incidentes
  ADD COLUMN heridos_cierre INT UNSIGNED NULL DEFAULT NULL COMMENT 'Sólo si pasó por en_proceso al cerrar';
ALTER TABLE incidentes
  ADD COLUMN fallecidos_cierre INT UNSIGNED NULL DEFAULT NULL COMMENT 'Sólo si pasó por en_proceso al cerrar';
