USE proteccion_civil_carabobo;
ALTER TABLE incidentes
  MODIFY lat DECIMAL(10, 6) NULL,
  MODIFY lng DECIMAL(10, 6) NULL;
