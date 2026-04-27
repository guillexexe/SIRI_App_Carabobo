-- Base de datos para Protección Civil Carabobo (ejecutar en MySQL / XAMPP)
CREATE DATABASE IF NOT EXISTS proteccion_civil_carabobo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE proteccion_civil_carabobo;
CREATE TABLE `categorias_incidentes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `emergencia` enum('Si','No') DEFAULT 'Si'
  PRIMARY KEY (`id`);
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `tipos_de_incidentes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `id_categoria` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_categoria_catalogo` FOREIGN KEY (`id_categoria`) REFERENCES `categorias_incidentes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
--
CREATE TABLE `usuarios` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `apellido` varchar(100) NOT NULL,
  `correo` varchar(255) NOT NULL UNIQUE,
  `cedula` varchar(20) NOT NULL UNIQUE,
  `telefono` varchar(20) NOT NULL UNIQUE,
  `password_hash` varchar(255) NOT NULL,
  `rol` ENUM('ciudadano', 'oficial', 'jefe_despacho', 'admin') DEFAULT 'ciudadano',
  `estatus` ENUM('pendiente', 'aprobado', 'bloqueado') DEFAULT 'pendiente',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `incidentes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_tipo` int(11) NOT NULL,
  `tipo_nombre` varchar(255) NOT NULL,
  `categoria` varchar(50) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `lat` decimal(10,6) DEFAULT NULL,
  `lng` decimal(10,6) DEFAULT NULL,
  `municipio` varchar(80) DEFAULT NULL,
  `parroquia` varchar(80) DEFAULT NULL,
  `via` varchar(500) DEFAULT NULL COMMENT 'calle o referencia',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `estado` enum('abierto','en_proceso','cerrado') NOT NULL DEFAULT 'abierto' COMMENT 'abierto | en_proceso | cerrado',
  `fecha_cierre` datetime DEFAULT NULL,
  `afectados` enum('No','Heridos','Muertos', 'Heridos y Muertos') DEFAULT 'No',
  `heridos_cierre` INT DEFAULT 0,
  `fallecidos_cierre` INT DEFAULT 0,
  `tipo_de_reportante` enum('ciudadano','oficial') DEFAULT NULL,
  `id_de_reportante` int(11) NOT NULL,
  `evidencia_visual` varchar(255) DEFAULT NULL,
  `procedencia` enum('movil','') DEFAULT ''
  `resultado_cierre` text DEFAULT NULL,
  `observacion_cierre_abierto` text DEFAULT NULL
  primary key (`id`),
  CONSTRAINT `fk_reportante_inc` FOREIGN KEY (`id_de_reportante`) REFERENCES `usuarios` (`id`),
  CONSTRAINT `fk_tipo_catalogo` FOREIGN KEY (`id_tipo`) REFERENCES `tipos_de_incidentes` (`id`);
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE `reportes_edan` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_oficial` int(11) not NULL,--referencia al usuario oficial que hizo el reporte
  `fecha_reporte` datetime NOT NULL DEFAULT current_timestamp(),--fecha y hora del reporte
  `numero_planilla` varchar(50) DEFAULT NULL,--número de planilla del reporte
  `propetario` varchar(100) DEFAULT NULL,--nombre del propietario de la vivienda
  `p_cedula` varchar(20) DEFAULT NULL,--cédula del propietario
  `P_edad` int(11) DEFAULT NULL,--edad del propietario
  `P_telefono` varchar(20) DEFAULT NULL,--teléfono de contacto
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
  `lact_Fem` int(11) DEFAULT NULL,
  `lact_Masc` int(11) DEFAULT NULL,
  `niños_Fem` int(11) DEFAULT NULL,
  `niños_Masc` int(11) DEFAULT NULL,
  `adultos_Fem` int(11) DEFAULT NULL,
  `adultos_Masc` int(11) DEFAULT NULL,
  `3era_edad_Fem` int(11) DEFAULT NULL,
  `3era_edad_Masc` int(11) DEFAULT NULL,
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

CREATE TABLE `afectados_detalle` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_reporte` int(11) NOT NULL, -- Se une con el ID del reporte EDAN
  `nombre_completo` varchar(150) DEFAULT NULL,
  `cedula` varchar(20) DEFAULT NULL,
  `edad` int(11) DEFAULT NULL,
  `genero` enum('Femenino', 'Masculino') DEFAULT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_reporte` FOREIGN KEY (`id_reporte`) REFERENCES `reportes_edan` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
ALTER TABLE `reportes_edan`
  ADD KEY `idx_edan_id_oficial` (`id_oficial`);

--
ALTER TABLE `tipos_de_incidentes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_tipos_categoria` (`id_categoria`);

DELETE FROM `categorias_incidentes`;

INSERT INTO `categorias_incidentes` (`id`, `nombre`, `emergencia`) VALUES
(1, 'Hecho Vial', 'Si'),
(2, 'Incendio', 'Si'),
(3, 'Busqueda y Rescate', 'Si'),
(4, 'Guardia de Seguridad y Prevencion', 'No'),
(5, 'Condición Arbórea', 'No'),
(6, 'Solicitud de Traslado', 'Si'),
(7, 'Hidrometeorologico', 'No'),
(8, 'Colapso de Estructura', 'Si'),
(9, 'Inspeccion y Reubicacion Animal', 'No'),
(10, 'Eliminacion de Peligro', 'Si'),
(11, 'Clima', 'No');
ALTER TABLE `categorias_incidentes` AUTO_INCREMENT = 12;

INSERT INTO `tipos_de_incidentes` (`nombre`, `id_categoria`) VALUES
('Arrollado (Peatón)', 1),
('Caída de Nivel', 1),
('Caída de Vehículo en Marcha', 1),
('Choque contra Objeto Fijo', 1),
('Colisión con Unidad Colectiva involucrada', 1),
('Colisión con Vehículo de Carga involucrado', 1),
('Colisión entre Vehículos', 1),
('Colisión Moto - Moto', 1),
('Colisión Moto - Bicicleta', 1),
('Colisión Moto - Vehículo', 1),
('Colisión Vehículo - Animal', 1),
('Colisión Vehículo - Moto (Arrollado)', 1),
('Derrape de Moto', 1),
('Embarrancamiento', 1),
('Encunetamiento', 1),
('Perdida de Carga', 1),
('Volcamiento de Carga', 1),
('Volcamiento de Unidad Colectiva', 1),
('Volcamiento de Vehículo de Carga', 1),
('Volcamiento de Vehículo', 1),
('Vehículo caído en cuerpo de Agua (Caño, Rio, Canal)', 1),

-- ID 2: Incendio
('Vegetacion', 2),
('Estructura', 2),
('Vehiculo', 2),
('Equipos electricos', 2),
('Desechos solidos', 2),
('Vertedero de basura', 2),
('Deflagracion', 2),
('Embarcacion', 2),
('Mat-Pel', 2),
('Pirotecnico', 2),

-- ID 3: Busqueda y Rescate
('Persona desaparecida en montaña', 3),
('Persona desaparecida en agua', 3),
('Busqueda y Rescate en areas confinadas', 3),
('Rescate en ascensor', 3),
('Rescate de persona en agua', 3),
('Rescate animal', 3),
('Recuperacion de cadaver', 3),

-- ID 4: Guardia de Seguridad y Prevencion
('Guardia de Seguridad y Prevencion', 4),
('Atencion paramedica', 4),
('Atencion medica', 4),
('Puesto de Atencion', 4),
('Punto de Control', 4),

-- ID 5: Condición Arbórea
('Arbol caido en via publica', 5),
('Arbol caido sobre estructura', 5),
('Arbol caido sobre tendido electrico', 5),
('Arbol caido sobre vehiculo', 5),
('Poda de arbol', 5),
('Arbol en condicion de riesgo', 5),

-- ID 6: Solicitud de Traslado
('Lesionado por caido de altura', 6),
('Lesionado por arma blanca', 6),
('Lesionado por arma de fuego', 6),
('Lesionado por descarga electrica', 6),

-- ID 7: Hidrometeorologico
('Anegacion', 7),
('Inhundacion', 7),
('Desbordamiento (caño, rio, canal)', 7),

-- ID 8: Colapso de Estructura
('Colapso de estructura', 8),
('Colapso de puente', 8),

-- ID 9: Inspeccion y Reubicacion Animal
('Enajmbre de abejas', 9),
('Enajmbre de avispa', 9),
('Serpiente', 9),
('Alacran', 9),
('Animal agreste', 9),

-- ID 10: Eliminacion de Peligro
('Fuga de GLP', 10),
('Derrame de hidrocarburo', 10),

-- ID 11: Clima (Los 7 tipos finales que pediste)
('Despejado', 11),
('Nublado', 11),
('Precipitaciones leves', 11),
('Precipitaciones moderadas', 11),
('Precipitaciones fuertes', 11),
('Precipitaciones severas', 11),
('Precipitaciones torrenciales', 11);

-- Reiniciar el autoincrement para futuros registros
ALTER TABLE `tipos_de_incidentes` AUTO_INCREMENT = 72;