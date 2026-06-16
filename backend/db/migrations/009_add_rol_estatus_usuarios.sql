USE proteccion_civil_carabobo;

ALTER TABLE usuarios
  ADD COLUMN rol ENUM('civil', 'oficial') NOT NULL DEFAULT 'civil' AFTER telefono;

ALTER TABLE usuarios
  ADD COLUMN estatus ENUM('activo', 'inactivo') NOT NULL DEFAULT 'activo' AFTER rol;
