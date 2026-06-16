-- Texto al cerrar desde "en proceso" y motivo registrado desde "abierto"
ALTER TABLE incidentes
  ADD COLUMN resultado_cierre TEXT NULL,
  ADD COLUMN observacion_cierre_abierto TEXT NULL;
