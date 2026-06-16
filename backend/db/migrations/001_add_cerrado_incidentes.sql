-- Ejecutar en la base existente (MySQL). Nuevas instalaciones ya incluyen la columna en proteccion_civil_carabobo.sql.
USE proteccion_civil_carabobo;

ALTER TABLE incidentes
  ADD COLUMN cerrado TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = cerrado, fuera del mapa en vivo';

-- NO ejecute un UPDATE masivo aquí: haría que todos los reportes pasen a "cerrados" y desaparezcan del mapa en vivo.
-- Si ya ejecutó eso antes y quiere recuperarlos como abiertos en el mapa:
--   UPDATE incidentes SET cerrado = 0;
-- Para cerrar solo datos viejos de forma selectiva, use el listado o el archivo opcional en migrations.
