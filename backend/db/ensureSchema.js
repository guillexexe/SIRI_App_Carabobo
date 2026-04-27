import pool from './connection.js'

async function hasTable(dbName, tableName) {
  const [rows] = await pool.query(
    `SELECT COUNT(*) AS cnt
     FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?`,
    [dbName, tableName]
  )
  return (rows[0]?.cnt ?? 0) > 0
}

async function hasColumn(dbName, tableName, columnName) {
  const [rows] = await pool.query(
    `SELECT COUNT(*) AS cnt
     FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [dbName, tableName, columnName]
  )
  return (rows[0]?.cnt ?? 0) > 0
}

async function hasConstraint(dbName, tableName, constraintName) {
  const [rows] = await pool.query(
    `SELECT COUNT(*) AS cnt
     FROM information_schema.TABLE_CONSTRAINTS
     WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND CONSTRAINT_NAME = ?`,
    [dbName, tableName, constraintName]
  )
  return (rows[0]?.cnt ?? 0) > 0
}

export async function ensureIncidentesSchema() {
  const dbName = process.env.DB_NAME || 'proteccion_civil_carabobo'
  try {
    await pool.query(
      `CREATE TABLE IF NOT EXISTS categorias_incidentes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nombre VARCHAR(100) NOT NULL,
        emergencia ENUM('Si', 'No') DEFAULT 'Si'
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
    )

    await pool.query(
      `CREATE TABLE IF NOT EXISTS tipos_de_incidentes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nombre VARCHAR(100) NOT NULL,
        id_categoria INT NOT NULL,
        INDEX idx_tipos_categoria (id_categoria)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
    )

    if (!(await hasConstraint(dbName, 'tipos_de_incidentes', 'fk_categoria_catalogo'))) {
      await pool.query(
        `ALTER TABLE tipos_de_incidentes
         ADD CONSTRAINT fk_categoria_catalogo
         FOREIGN KEY (id_categoria) REFERENCES categorias_incidentes(id)`
      )
    }

    await pool.query(
      `CREATE TABLE IF NOT EXISTS reportes_edan (
  id int(11) NOT NULL AUTO_INCREMENT,
  id_oficial int(11) not NULL,
  fecha_reporte datetime NOT NULL DEFAULT current_timestamp(),
  numero_planilla varchar(50) DEFAULT NULL,
  propetario varchar(100) DEFAULT NULL,
  p_cedula varchar(20) DEFAULT NULL,
  P_edad int(11) DEFAULT NULL,
  P_telefono varchar(20) DEFAULT NULL,
  municipio varchar(100) DEFAULT NULL,
  parroquia varchar(100) DEFAULT NULL,
  sector varchar(100) DEFAULT NULL,
  nro_casa varchar(20) DEFAULT NULL,
  urbanizacion varchar(100) DEFAULT NULL,
  direccion varchar(255) DEFAULT NULL,
  lat decimal(10,8) DEFAULT NULL,
  lng decimal(10,8) DEFAULT NULL,
  nro_informe varchar(50) DEFAULT NULL,
  fecha_solicitud datetime DEFAULT NULL,
  fecha_afectacion datetime DEFAULT NULL,
  descripcion_afectacion text DEFAULT NULL,
  tipo_afectacion enum('anegacion','inundacion','deslizamiento','otros') DEFAULT NULL,
  afectacion_otros varchar(255) DEFAULT NULL,
  condicion_vivienda enum('afectada','alto_riesgo','destruida') DEFAULT NULL,
  tipo_vivienda enum('anarquica', 'improvisada', 'casa convencional') DEFAULT NULL,
  descripcion_vivienda text DEFAULT NULL,
  lact_Fem int(11) DEFAULT NULL,
  lact_Masc int(11) DEFAULT NULL,
  niños_Fem int(11) DEFAULT NULL,
  niños_Masc int(11) DEFAULT NULL,
  adultos_Fem int(11) DEFAULT NULL,
  adultos_Masc int(11) DEFAULT NULL,
  3era_edad_Fem int(11) DEFAULT NULL,
  3era_edad_Masc int(11) DEFAULT NULL,
  discapacitados int(11) DEFAULT NULL,
  total_personas int(11) DEFAULT NULL,
  nro_familias int(11) DEFAULT NULL,
  requerimientos_afectacion text DEFAULT NULL,
  P_enseres_total text DEFAULT NULL,
  P_enseres_parcial text DEFAULT NULL,
   p_enseres_no text DEFAULT NULL,
  necesidades_agua enum('si','no') DEFAULT NULL,
  necesidades_alimentos enum('si','no') DEFAULT NULL,
  necesidades_luz enum('si','no') DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;`
    )

    if (!(await hasConstraint(dbName, 'reportes_edan', 'fk_reportes_edan_usuario'))) {
      await pool.query(
        `ALTER TABLE reportes_edan
         ADD CONSTRAINT fk_reportes_edan_usuario
         FOREIGN KEY (id_oficial) REFERENCES usuarios(id)`
      )
    }

    if (!(await hasColumn(dbName, 'usuarios', 'rol'))) {
      await pool.query(
        "ALTER TABLE usuarios ADD COLUMN rol ENUM('ciudadano', 'oficial', 'admin', 'jefe_despacho') NOT NULL DEFAULT 'ciudadano' AFTER telefono"
      )
      console.log('[db] Columna usuarios.rol creada.')
    }
    await pool.query(
      "ALTER TABLE usuarios MODIFY COLUMN rol ENUM('ciudadano', 'oficial', 'admin', 'jefe_despacho') NOT NULL DEFAULT 'ciudadano'"
    )

    if (!(await hasColumn(dbName, 'usuarios', 'estatus'))) {
      await pool.query(
        "ALTER TABLE usuarios ADD COLUMN estatus ENUM('activo', 'inactivo') NOT NULL DEFAULT 'activo' AFTER rol"
      )
      console.log('[db] Columna usuarios.estatus creada.')
    }

    const incidentesExiste = await hasTable(dbName, 'incidentes')
    const incidentesEsNuevoModelo =
      incidentesExiste &&
      (await hasColumn(dbName, 'incidentes', 'id_tipo')) &&
      (await hasColumn(dbName, 'incidentes', 'id_de_reportante')) &&
      (await hasColumn(dbName, 'incidentes', 'estado')) 

    if (incidentesExiste && !incidentesEsNuevoModelo) {
      const [existsBackupRows] = await pool.query(
        `SELECT COUNT(*) AS cnt
         FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = ? AND TABLE_NAME LIKE 'incidentes_legacy_backup_%'`,
        [dbName]
      )
      const suffix = Number(existsBackupRows?.[0]?.cnt ?? 0) + 1
      const backupName = `incidentes_legacy_backup_${suffix}`
      await pool.query(`RENAME TABLE incidentes TO ${backupName}`)
      console.log(`[db] Tabla incidentes anterior respaldada como ${backupName}.`)
    }if (!(await hasTable(dbName, 'incidentes'))) {
      await pool.query(
        `CREATE TABLE incidentes (
          id int(11) NOT NULL AUTO_INCREMENT,
          id_tipo int(11) NOT NULL,
          tipo_nombre varchar(255) NOT NULL,
          categoria varchar(50) NOT NULL,
          descripcion text DEFAULT NULL,
          lat decimal(10,6) DEFAULT NULL,
          lng decimal(10,6) DEFAULT NULL,
          municipio varchar(80) DEFAULT NULL,
          parroquia varchar(80) DEFAULT NULL,
          via varchar(500) DEFAULT NULL COMMENT 'calle o referencia',
          created_at timestamp NOT NULL DEFAULT current_timestamp(),
          estado enum('abierto','en_proceso','cerrado') NOT NULL DEFAULT 'abierto' COMMENT 'abierto | en_proceso | cerrado',
          fecha_cierre datetime DEFAULT NULL,
          afectados enum('No','Heridos','Muertos', 'Heridos y Muertos') DEFAULT 'No',
          heridos_cierre INT DEFAULT 0,
          fallecidos_cierre INT DEFAULT 0,
          tipo_de_reportante enum('ciudadano','oficial') DEFAULT NULL,
          id_de_reportante int(11) NOT NULL,
          evidencia_visual varchar(255) DEFAULT NULL,
          procedencia enum('movil','') DEFAULT '',
          resultado_cierre text DEFAULT NULL,
          observacion_cierre_abierto text DEFAULT NULL,
          primary key (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`
      )
    }
  } catch (err) {
    console.error('[db] No se pudo comprobar el esquema de incidentes:', err.message)
    throw err
  }
}
