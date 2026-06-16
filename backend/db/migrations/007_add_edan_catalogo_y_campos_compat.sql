USE proteccion_civil_carabobo;

CREATE TABLE IF NOT EXISTS categorias_incidentes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  emergencia ENUM('Si', 'No') DEFAULT 'Si'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tipos_de_incidentes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  id_categoria INT NOT NULL,
  INDEX idx_tipos_categoria (id_categoria)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE tipos_de_incidentes
  ADD CONSTRAINT fk_categoria_catalogo
  FOREIGN KEY (id_categoria) REFERENCES categorias_incidentes(id);

CREATE TABLE IF NOT EXISTS reportes_edan (
  id INT PRIMARY KEY AUTO_INCREMENT,
  id_oficial INT,
  municipio VARCHAR(100),
  parroquia VARCHAR(100),
  sector VARCHAR(100),
  condicion_vivienda ENUM('afectada', 'alto_riesgo', 'destruida'),
  tipo_vivienda VARCHAR(100),
  total_personas INT,
  necesidades_insumos TEXT,
  lat DECIMAL(10,8),
  lng DECIMAL(10,8),
  fecha_afectacion DATETIME,
  INDEX idx_edan_id_oficial (id_oficial)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE reportes_edan
  ADD CONSTRAINT fk_reportes_edan_usuario
  FOREIGN KEY (id_oficial) REFERENCES usuarios(id);

ALTER TABLE incidentes ADD COLUMN id_tipo INT NULL;
ALTER TABLE incidentes ADD COLUMN nombre_incidente VARCHAR(100) NULL;
ALTER TABLE incidentes ADD COLUMN afectados ENUM('No', 'Heridos', 'Muertos') DEFAULT 'No';
ALTER TABLE incidentes ADD COLUMN estatus_incidente ENUM('nuevo', 'en_proceso', 'culminado') DEFAULT 'nuevo';
ALTER TABLE incidentes ADD COLUMN fecha_cierre DATETIME NULL;
ALTER TABLE incidentes ADD COLUMN id_de_reportante INT NULL;
ALTER TABLE incidentes ADD COLUMN tipo_de_reportante ENUM('ciudadano', 'oficial') NULL;
ALTER TABLE incidentes ADD COLUMN evidencia_visual VARCHAR(255) NULL;
ALTER TABLE incidentes ADD COLUMN procedencia ENUM('movil', '') DEFAULT '';
