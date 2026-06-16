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

RENAME TABLE incidentes TO incidentes_legacy_backup_1;

CREATE TABLE incidentes (
  id INT NOT NULL AUTO_INCREMENT,
  id_tipo INT NOT NULL,
  nombre_incidente VARCHAR(100) NOT NULL,
  categoria VARCHAR(100) NOT NULL,
  descripcion TEXT DEFAULT NULL,
  afectados ENUM('No', 'Heridos', 'Muertos') DEFAULT 'No',
  lat DECIMAL(10,8) DEFAULT NULL,
  lng DECIMAL(10,8) DEFAULT NULL,
  municipio VARCHAR(100) DEFAULT NULL,
  parroquia VARCHAR(100) DEFAULT NULL,
  via VARCHAR(100) DEFAULT NULL,
  estatus_incidente ENUM('nuevo', 'en_proceso', 'culminado') DEFAULT 'nuevo',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_cierre DATETIME DEFAULT NULL,
  id_de_reportante INT NOT NULL,
  tipo_de_reportante ENUM('ciudadano', 'oficial') NOT NULL,
  evidencia_visual VARCHAR(255) DEFAULT NULL,
  procedencia ENUM('movil', '') DEFAULT '',
  PRIMARY KEY (id),
  CONSTRAINT fk_tipo_catalogo
    FOREIGN KEY (id_tipo) REFERENCES tipos_de_incidentes(id),
  CONSTRAINT fk_reportante_inc
    FOREIGN KEY (id_de_reportante) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
