USE proteccion_civil_carabobo;

ALTER TABLE usuarios
  MODIFY COLUMN rol ENUM('civil', 'oficial', 'admin') NOT NULL DEFAULT 'civil';
