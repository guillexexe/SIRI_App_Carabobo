USE proteccion_civil_carabobo;
ALTER TABLE incidentes
  ADD COLUMN parroquia VARCHAR(80) NULL AFTER municipio;
