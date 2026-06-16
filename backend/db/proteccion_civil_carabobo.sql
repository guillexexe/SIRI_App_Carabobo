-- Base de datos definitiva.
-- OJO: BORRA la base entera y la vuelve a crear (para evitar "mezclas" con tablas/columnas viejas).
-- Si tienes datos que quieras conservar, exporta un respaldo ANTES.
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS=0;

DROP DATABASE IF EXISTS proteccion_civil_carabobo;
CREATE DATABASE proteccion_civil_carabobo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE proteccion_civil_carabobo;

CREATE TABLE IF NOT EXISTS categorias_incidentes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  emergencia ENUM('Si', 'No') DEFAULT 'Si'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS tipos_de_incidentes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  id_categoria INT NOT NULL,
  KEY idx_tipos_categoria (id_categoria),
  CONSTRAINT fk_categoria_catalogo FOREIGN KEY (id_categoria) REFERENCES categorias_incidentes(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL,
  correo VARCHAR(255) NOT NULL UNIQUE,
  cedula VARCHAR(20) NOT NULL UNIQUE,
  telefono VARCHAR(20) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  rol ENUM('ciudadano', 'oficial', 'jefe_despacho', 'admin') DEFAULT 'ciudadano',
  estatus ENUM('pendiente', 'aprobado', 'bloqueado') DEFAULT 'pendiente',
  codigo_recuperacion VARCHAR(6) NULL,
  expiracion_codigo DATETIME NULL,
  
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE IF NOT EXISTS incidentes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tipo VARCHAR(80) NOT NULL,
  tipo_nombre VARCHAR(255) NOT NULL,
  categoria VARCHAR(50) NOT NULL,
  descripcion TEXT DEFAULT NULL,
  lat DECIMAL(10,6) DEFAULT NULL,
  lng DECIMAL(10,6) DEFAULT NULL,
  municipio VARCHAR(80) DEFAULT NULL,
  parroquia VARCHAR(80) DEFAULT NULL,
  via VARCHAR(500) DEFAULT NULL COMMENT 'calle o referencia',
  fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  cerrado TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = cerrado',
  estado ENUM('abierto','en_proceso','cerrado') NOT NULL DEFAULT 'abierto' COMMENT 'abierto | en_proceso | cerrado',
  fecha_cierre DATETIME DEFAULT NULL,
  afectados ENUM('No','Heridos','Muertos') DEFAULT 'No',
  heridos INT DEFAULT 0,
  fallecidos INT DEFAULT 0,
  tipo_de_reportante ENUM('ciudadano','oficial') DEFAULT NULL,
  id_de_reportante INT NOT NULL,
  evidencia_visual VARCHAR(255) DEFAULT NULL,
  procedencia ENUM('movil','') DEFAULT '',
  resultado_cierre TEXT NULL,
  observacion_cierre_abierto TEXT NULL,
  heridos_cierre INT UNSIGNED NULL DEFAULT NULL COMMENT 'Sólo si pasó por en_proceso al cerrar',
  fallecidos_cierre INT UNSIGNED NULL DEFAULT NULL COMMENT 'Sólo si pasó por en_proceso al cerrar',
  CONSTRAINT fk_reportante_inc FOREIGN KEY (id_de_reportante) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS reportes_edan (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_oficial` int(11) NOT NULL,
  `fecha_reporte` datetime NOT NULL DEFAULT current_timestamp(),
  `numero_planilla` varchar(50) DEFAULT NULL,
  `propetario` varchar(100) DEFAULT NULL,
  `p_cedula` varchar(20) DEFAULT NULL,
  `P_edad` int(11) DEFAULT NULL,
  `P_telefono` varchar(20) DEFAULT NULL,
  `municipio` varchar(100) DEFAULT NULL,
  `parroquia` varchar(100) DEFAULT NULL,
  `sector` varchar(100) DEFAULT NULL,
  `nro_casa` varchar(20) DEFAULT NULL,
  `urbanizacion` varchar(100) DEFAULT NULL,
  `direccion` varchar(255) DEFAULT NULL,
  `lat` decimal(10,8) DEFAULT NULL,
  `lng` decimal(10,8) DEFAULT NULL,
  `nro_informe` varchar(50) DEFAULT NULL,
  `fecha_solicitud` datetime DEFAULT NULL,
  `fecha_afectacion` datetime DEFAULT NULL,
  `descripcion_afectacion` text DEFAULT NULL,
  `tipo_afectacion` enum('anegacion','inundacion','deslizamiento','otros') DEFAULT NULL,
  `afectacion_otros` varchar(255) DEFAULT NULL,
  `condicion_vivienda` enum('afectada','alto_riesgo','destruida') DEFAULT NULL,
  `tipo_vivienda` enum('anarquica', 'improvisada', 'casa convencional') DEFAULT NULL,
  `descripcion_vivienda` text DEFAULT NULL,
  `lact.Fem` int(11) DEFAULT NULL,
  `lact.Masc` int(11) DEFAULT NULL,
  `niños.Fem` int(11) DEFAULT NULL,
  `niños.Masc` int(11) DEFAULT NULL,
  `adultos.Fem` int(11) DEFAULT NULL,
  `adultos.Masc` int(11) DEFAULT NULL,
  `3era_edad.Fem` int(11) DEFAULT NULL,
  `3era_edad.Masc` int(11) DEFAULT NULL,
  `discapacitados` int(11) DEFAULT NULL,
  `total_personas` int(11) DEFAULT NULL,
  `nro_familias` int(11) DEFAULT NULL,
  `requerimientos_afectacion` text DEFAULT NULL,
  `P_enseres_total` text DEFAULT NULL,
  `P_enseres_parcial` text DEFAULT NULL,
  `p_enseres_no` text DEFAULT NULL,
  `necesidades_agua` enum('si','no') DEFAULT NULL,
  `necesidades_alimentos` enum('si','no') DEFAULT NULL,
  `necesidades_luz` enum('si','no') DEFAULT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_usuario_reporte` FOREIGN KEY (`id_oficial`) REFERENCES `usuarios` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS afectados_detalle (
  id INT AUTO_INCREMENT PRIMARY KEY,
  id_reporte INT NOT NULL,
  nombre_completo VARCHAR(150) DEFAULT NULL,
  cedula VARCHAR(20) DEFAULT NULL,
  edad INT DEFAULT NULL,
  genero ENUM('Femenino', 'Masculino') DEFAULT NULL,
  CONSTRAINT fk_reporte FOREIGN KEY (id_reporte) REFERENCES reportes_edan(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS=1;
