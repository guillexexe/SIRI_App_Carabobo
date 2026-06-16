import pool from './connection.js'
import { seedCatalogoVacio, syncNombresCatalogoSemilla } from './seedCatalogoVacio.js'

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

function qCol(n) {
  return '`' + String(n).replace(/`/g, '') + '`'
}

/** Añade columnas que falten a reportes_edan (tablas viejas o incompletas). */
const REPORTES_EDAN_COLUMNAS = [
  ['id_oficial', 'INT(11) NOT NULL'],
  ['fecha_reporte', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'],
  ['numero_planilla', 'VARCHAR(50) DEFAULT NULL'],
  ['propetario', 'VARCHAR(100) DEFAULT NULL'],
  ['p_cedula', 'VARCHAR(20) DEFAULT NULL'],
  ['P_edad', 'INT(11) DEFAULT NULL'],
  ['P_telefono', 'VARCHAR(20) DEFAULT NULL'],
  ['municipio', 'VARCHAR(100) DEFAULT NULL'],
  ['parroquia', 'VARCHAR(100) DEFAULT NULL'],
  ['sector', 'VARCHAR(100) DEFAULT NULL'],
  ['nro_casa', 'VARCHAR(20) DEFAULT NULL'],
  ['urbanizacion', 'VARCHAR(100) DEFAULT NULL'],
  ['direccion', 'VARCHAR(255) DEFAULT NULL'],
  ['lat', 'DECIMAL(10,8) DEFAULT NULL'],
  ['lng', 'DECIMAL(10,8) DEFAULT NULL'],
  ['nro_informe', 'VARCHAR(50) DEFAULT NULL'],
  ['fecha_solicitud', 'DATETIME DEFAULT NULL'],
  ['fecha_afectacion', 'DATETIME DEFAULT NULL'],
  ['descripcion_afectacion', 'TEXT DEFAULT NULL'],
  [
    'tipo_afectacion',
    "ENUM('anegacion','inundacion','deslizamiento','otros') DEFAULT NULL",
  ],
  ['afectacion_otros', 'VARCHAR(255) DEFAULT NULL'],
  [
    'condicion_vivienda',
    "ENUM('afectada','alto_riesgo','destruida') DEFAULT NULL",
  ],
  [
    'tipo_vivienda',
    "ENUM('anarquica', 'improvisada', 'casa convencional') DEFAULT NULL",
  ],
  ['descripcion_vivienda', 'TEXT DEFAULT NULL'],
  ['lact.Fem', 'INT(11) DEFAULT NULL'],
  ['lact.Masc', 'INT(11) DEFAULT NULL'],
  ['niños.Fem', 'INT(11) DEFAULT NULL'],
  ['niños.Masc', 'INT(11) DEFAULT NULL'],
  ['adultos.Fem', 'INT(11) DEFAULT NULL'],
  ['adultos.Masc', 'INT(11) DEFAULT NULL'],
  ['3era_edad.Fem', 'INT(11) DEFAULT NULL'],
  ['3era_edad.Masc', 'INT(11) DEFAULT NULL'],
  ['discapacitados', 'INT(11) DEFAULT NULL'],
  ['total_personas', 'INT(11) DEFAULT NULL'],
  ['nro_familias', 'INT(11) DEFAULT NULL'],
  ['requerimientos_afectacion', 'TEXT DEFAULT NULL'],
  ['P_enseres_total', 'TEXT DEFAULT NULL'],
  ['P_enseres_parcial', 'TEXT DEFAULT NULL'],
  ['p_enseres_no', 'TEXT DEFAULT NULL'],
  ['necesidades_agua', "ENUM('si','no') DEFAULT NULL"],
  ['necesidades_alimentos', "ENUM('si','no') DEFAULT NULL"],
  ['necesidades_luz', "ENUM('si','no') DEFAULT NULL"],
]

async function ensureReportesEdanCompleto(dbName) {
  if (!(await hasTable(dbName, 'reportes_edan'))) return

  for (const [nombre, def] of REPORTES_EDAN_COLUMNAS) {
    if (await hasColumn(dbName, 'reportes_edan', nombre)) continue
    try {
      await pool.query(
        `ALTER TABLE reportes_edan ADD COLUMN ${qCol(nombre)} ${def}`
      )
      console.log(`[db] reportes_edan: columna ${nombre} añadida.`)
    } catch (e) {
      console.warn(`[db] reportes_edan: no se pudo añadir ${nombre}:`, e.message)
    }
  }

  // No intentar DROP de idx_edan_id_oficial: a menudo es el índice que usa la FK en id_oficial
  // y MySQL responde "needed in a foreign key constraint". Si existe, no afecta al esquema.

  try {
    await pool.query(
      'ALTER TABLE reportes_edan CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci'
    )
  } catch (e) {
    console.warn('[db] reportes_edan: CONVERT TO utf8mb4:', e.message)
  }

  if (await hasConstraint(dbName, 'reportes_edan', 'fk_reportes_edan_usuario')) {
    try {
      await pool.query(
        'ALTER TABLE reportes_edan DROP FOREIGN KEY fk_reportes_edan_usuario'
      )
      console.log('[db] reportes_edan: FK antigua fk_reportes_edan_usuario eliminada.')
    } catch (e) {
      console.warn('[db] reportes_edan: DROP fk_reportes_edan_usuario:', e.message)
    }
  }

  if (
    (await hasTable(dbName, 'usuarios')) &&
    !(await hasConstraint(dbName, 'reportes_edan', 'fk_usuario_reporte'))
  ) {
    try {
      await pool.query(
        `ALTER TABLE reportes_edan
         ADD CONSTRAINT fk_usuario_reporte
         FOREIGN KEY (id_oficial) REFERENCES usuarios (id)`
      )
      console.log('[db] reportes_edan: FK fk_usuario_reporte creada.')
    } catch (e) {
      console.warn('[db] reportes_edan: no se pudo crear fk_usuario_reporte:', e.message)
    }
  }
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
        \`id\` INT(11) NOT NULL AUTO_INCREMENT,
        \`id_oficial\` INT(11) NOT NULL,
        \`fecha_reporte\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        \`numero_planilla\` VARCHAR(50) DEFAULT NULL,
        \`propetario\` VARCHAR(100) DEFAULT NULL,
        \`p_cedula\` VARCHAR(20) DEFAULT NULL,
        \`P_edad\` INT(11) DEFAULT NULL,
        \`P_telefono\` VARCHAR(20) DEFAULT NULL,
        \`municipio\` VARCHAR(100) DEFAULT NULL,
        \`parroquia\` VARCHAR(100) DEFAULT NULL,
        \`sector\` VARCHAR(100) DEFAULT NULL,
        \`nro_casa\` VARCHAR(20) DEFAULT NULL,
        \`urbanizacion\` VARCHAR(100) DEFAULT NULL,
        \`direccion\` VARCHAR(255) DEFAULT NULL,
        \`lat\` DECIMAL(10,8) DEFAULT NULL,
        \`lng\` DECIMAL(10,8) DEFAULT NULL,
        \`nro_informe\` VARCHAR(50) DEFAULT NULL,
        \`fecha_solicitud\` DATETIME DEFAULT NULL,
        \`fecha_afectacion\` DATETIME DEFAULT NULL,
        \`descripcion_afectacion\` TEXT DEFAULT NULL,
        \`tipo_afectacion\` ENUM('anegacion','inundacion','deslizamiento','otros') DEFAULT NULL,
        \`afectacion_otros\` VARCHAR(255) DEFAULT NULL,
        \`condicion_vivienda\` ENUM('afectada','alto_riesgo','destruida') DEFAULT NULL,
        \`tipo_vivienda\` ENUM('anarquica', 'improvisada', 'casa convencional') DEFAULT NULL,
        \`descripcion_vivienda\` TEXT DEFAULT NULL,
        \`lact.Fem\` INT(11) DEFAULT NULL,
        \`lact.Masc\` INT(11) DEFAULT NULL,
        \`niños.Fem\` INT(11) DEFAULT NULL,
        \`niños.Masc\` INT(11) DEFAULT NULL,
        \`adultos.Fem\` INT(11) DEFAULT NULL,
        \`adultos.Masc\` INT(11) DEFAULT NULL,
        \`3era_edad.Fem\` INT(11) DEFAULT NULL,
        \`3era_edad.Masc\` INT(11) DEFAULT NULL,
        \`discapacitados\` INT(11) DEFAULT NULL,
        \`total_personas\` INT(11) DEFAULT NULL,
        \`nro_familias\` INT(11) DEFAULT NULL,
        \`requerimientos_afectacion\` TEXT DEFAULT NULL,
        \`P_enseres_total\` TEXT DEFAULT NULL,
        \`P_enseres_parcial\` TEXT DEFAULT NULL,
        \`p_enseres_no\` TEXT DEFAULT NULL,
        \`necesidades_agua\` ENUM('si','no') DEFAULT NULL,
        \`necesidades_alimentos\` ENUM('si','no') DEFAULT NULL,
        \`necesidades_luz\` ENUM('si','no') DEFAULT NULL,
        PRIMARY KEY (\`id\`),
        CONSTRAINT \`fk_usuario_reporte\` FOREIGN KEY (\`id_oficial\`) REFERENCES \`usuarios\` (\`id\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`
    )

    await ensureReportesEdanCompleto(dbName)

    await pool.query(
      `CREATE TABLE IF NOT EXISTS afectados_detalle (
        id INT AUTO_INCREMENT PRIMARY KEY,
        id_reporte INT NOT NULL,
        nombre_completo VARCHAR(150) DEFAULT NULL,
        cedula VARCHAR(20) DEFAULT NULL,
        edad INT DEFAULT NULL,
        genero ENUM('Femenino', 'Masculino') DEFAULT NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
    )

    if (!(await hasConstraint(dbName, 'afectados_detalle', 'fk_reporte'))) {
      await pool.query(
        `ALTER TABLE afectados_detalle
         ADD CONSTRAINT fk_reporte
         FOREIGN KEY (id_reporte) REFERENCES reportes_edan(id) ON DELETE CASCADE`
      )
    }

    await pool.query(
      `CREATE TABLE IF NOT EXISTS auditoria_incidentes (
        id INT NOT NULL AUTO_INCREMENT,
        incidente_id INT NOT NULL,
        usuario_id INT DEFAULT NULL,
        usuario_nombre VARCHAR(100) DEFAULT NULL,
        usuario_apellido VARCHAR(100) DEFAULT NULL,
        usuario_cedula VARCHAR(20) DEFAULT NULL,
        usuario_telefono VARCHAR(20) DEFAULT NULL,
        fecha_edicion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        datos_antes LONGTEXT NOT NULL,
        datos_despues LONGTEXT NOT NULL,
        campos_modificados LONGTEXT NOT NULL,
        PRIMARY KEY (id),
        INDEX idx_auditoria_incidente (incidente_id),
        INDEX idx_auditoria_fecha (fecha_edicion)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`
    )

    if (!(await hasColumn(dbName, 'usuarios', 'rol'))) {
      await pool.query(
        "ALTER TABLE usuarios ADD COLUMN rol ENUM('ciudadano', 'oficial', 'jefe_despacho', 'admin') NOT NULL DEFAULT 'ciudadano' AFTER telefono"
      )
      console.log('[db] Columna usuarios.rol creada.')
    } else {
      await pool.query(
        "ALTER TABLE usuarios MODIFY COLUMN rol ENUM('ciudadano', 'oficial', 'jefe_despacho', 'admin') NOT NULL DEFAULT 'ciudadano'"
      )
    }

    if (!(await hasColumn(dbName, 'usuarios', 'estatus'))) {
      await pool.query(
        "ALTER TABLE usuarios ADD COLUMN estatus ENUM('pendiente', 'aprobado', 'bloqueado') NOT NULL DEFAULT 'pendiente' AFTER rol"
      )
      console.log('[db] Columna usuarios.estatus creada.')
    } else {
      await pool.query(
        "ALTER TABLE usuarios MODIFY COLUMN estatus ENUM('pendiente', 'aprobado', 'bloqueado') NOT NULL DEFAULT 'pendiente'"
      )
    }

    if (!(await hasColumn(dbName, 'usuarios', 'motivo_bloqueo'))) {
      await pool.query(
        "ALTER TABLE usuarios ADD COLUMN motivo_bloqueo TEXT NULL AFTER estatus"
      )
      console.log('[db] Columna usuarios.motivo_bloqueo creada.')
    }

    if (!(await hasColumn(dbName, 'usuarios', 'codigo_recuperacion'))) {
      await pool.query(
        "ALTER TABLE usuarios ADD COLUMN codigo_recuperacion VARCHAR(10) DEFAULT NULL AFTER estatus"
      )
      console.log('[db] Columna usuarios.codigo_recuperacion creada.')
    }

    if (!(await hasColumn(dbName, 'usuarios', 'expiracion_codigo'))) {
      await pool.query(
        "ALTER TABLE usuarios ADD COLUMN expiracion_codigo DATETIME DEFAULT NULL AFTER codigo_recuperacion"
      )
      console.log('[db] Columna usuarios.expiracion_codigo creada.')
    }

    if (!(await hasTable(dbName, 'incidentes'))) {
      await pool.query(
        `CREATE TABLE incidentes (
          id INT NOT NULL AUTO_INCREMENT,
          tipo VARCHAR(80) NOT NULL,
          tipo_nombre VARCHAR(255) NOT NULL,
          categoria VARCHAR(50) NOT NULL,
          descripcion TEXT DEFAULT NULL,
          lat DECIMAL(10,6) DEFAULT NULL,
          lng DECIMAL(10,6) DEFAULT NULL,
          municipio VARCHAR(80) DEFAULT NULL,
          parroquia VARCHAR(80) DEFAULT NULL,
          via VARCHAR(500) DEFAULT NULL,
          fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          cerrado TINYINT(1) NOT NULL DEFAULT 0,
          estado ENUM('abierto', 'en_proceso', 'cerrado') NOT NULL DEFAULT 'abierto',
          fecha_cierre DATETIME DEFAULT NULL,
          afectados ENUM('No', 'Heridos', 'Muertos') DEFAULT 'No',
          heridos INT DEFAULT 0,
          fallecidos INT DEFAULT 0,
          tipo_de_reportante ENUM('ciudadano', 'oficial') DEFAULT NULL,
          id_de_reportante INT NOT NULL,
          evidencia_visual VARCHAR(255) DEFAULT NULL,
          procedencia ENUM('movil', '') DEFAULT '',
          PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
      )
    }

    const incidentesUsaTipoTexto = await hasColumn(dbName, 'incidentes', 'tipo')
    if (!(await hasConstraint(dbName, 'incidentes', 'fk_tipo_catalogo')) && incidentesUsaTipoTexto) {
      // La base de integración guarda tipo como texto; no forzamos FK a tipos_de_incidentes.id (INT).
      console.log('[db] FK fk_tipo_catalogo omitida: incidentes.tipo es texto en base integrada.')
    }

    if (await hasTable(dbName, 'incidentes')) {
      if (!(await hasColumn(dbName, 'incidentes', 'tipo'))) {
        try {
          await pool.query('ALTER TABLE incidentes ADD COLUMN tipo VARCHAR(80) NULL')
          if (await hasColumn(dbName, 'incidentes', 'id_tipo')) {
            await pool.query(
              "UPDATE incidentes SET tipo = CONCAT('id_tipo_', id_tipo) WHERE id_tipo IS NOT NULL"
            )
          }
          await pool.query(
            "UPDATE incidentes SET tipo = 'sin_clasificar' WHERE tipo IS NULL OR TRIM(tipo) = ''"
          )
          await pool.query('ALTER TABLE incidentes MODIFY COLUMN tipo VARCHAR(80) NOT NULL')
          console.log(
            '[db] Columna incidentes.tipo añadida (esquema antiguo con id_tipo: valores de respaldo generados).'
          )
        } catch (e) {
          console.warn('[db] incidentes.tipo (migración desde id_tipo):', e.message)
        }
      }
      if (!(await hasColumn(dbName, 'incidentes', 'estado'))) {
        try {
          await pool.query(
            "ALTER TABLE incidentes ADD COLUMN estado ENUM('abierto', 'en_proceso', 'cerrado') NOT NULL DEFAULT 'abierto'"
          )
          if (await hasColumn(dbName, 'incidentes', 'cerrado')) {
            await pool.query(
              `UPDATE incidentes SET estado = 'cerrado' WHERE cerrado = 1 OR cerrado = TRUE`
            )
          }
          console.log('[db] Columna incidentes.estado añadida.')
        } catch (e) {
          console.warn('[db] incidentes.estado:', e.message)
        }
      }
      if (!(await hasColumn(dbName, 'incidentes', 'cerrado'))) {
        try {
          await pool.query(
            'ALTER TABLE incidentes ADD COLUMN cerrado TINYINT(1) NOT NULL DEFAULT 0 COMMENT \'1 = cerrado\''
          )
          console.log('[db] Columna incidentes.cerrado añadida (faltaba en esquema antiguo).')
        } catch (e) {
          console.warn('[db] incidentes: no se pudo añadir cerrado:', e.message)
        }
      }
      if (await hasColumn(dbName, 'incidentes', 'estado')) {
        if (await hasColumn(dbName, 'incidentes', 'cerrado')) {
          await pool.query(
            `UPDATE incidentes
             SET estado = 'cerrado'
             WHERE (cerrado = 1 OR cerrado = TRUE) AND (estado IS NULL OR estado NOT IN ('abierto', 'en_proceso', 'cerrado'))`
          )
          await pool.query(
            `UPDATE incidentes
             SET estado = 'abierto'
             WHERE (cerrado = 0 OR cerrado IS NULL) AND (estado IS NULL OR estado NOT IN ('abierto', 'en_proceso', 'cerrado'))`
          )
        }
        try {
          await pool.query(
            "ALTER TABLE incidentes MODIFY COLUMN estado ENUM('abierto', 'en_proceso', 'cerrado') NOT NULL DEFAULT 'abierto'"
          )
        } catch (e) {
          console.warn('[db] incidentes: MODIFY estado a ENUM:', e.message)
        }
      }
      if (!(await hasColumn(dbName, 'incidentes', 'resultado_cierre'))) {
        await pool.query('ALTER TABLE incidentes ADD COLUMN resultado_cierre TEXT NULL')
        console.log('[db] Columna incidentes.resultado_cierre creada.')
      }
      if (!(await hasColumn(dbName, 'incidentes', 'observacion_cierre_abierto'))) {
        await pool.query(
          'ALTER TABLE incidentes ADD COLUMN observacion_cierre_abierto TEXT NULL'
        )
        console.log('[db] Columna incidentes.observacion_cierre_abierto creada.')
      }
      if (!(await hasColumn(dbName, 'incidentes', 'heridos_cierre'))) {
        await pool.query(
          'ALTER TABLE incidentes ADD COLUMN heridos_cierre INT UNSIGNED NULL DEFAULT NULL'
        )
        console.log('[db] Columna incidentes.heridos_cierre creada.')
      }
      if (!(await hasColumn(dbName, 'incidentes', 'fallecidos_cierre'))) {
        await pool.query(
          'ALTER TABLE incidentes ADD COLUMN fallecidos_cierre INT UNSIGNED NULL DEFAULT NULL'
        )
        console.log('[db] Columna incidentes.fallecidos_cierre creada.')
      }
      if (!(await hasColumn(dbName, 'incidentes', 'created_at'))) {
        try {
          await pool.query(
            "ALTER TABLE incidentes ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP"
          )
          console.log('[db] Columna incidentes.created_at añadida.')
        } catch (e) {
          console.warn('[db] incidentes.created_at:', e.message)
        }
      }
      if (!(await hasColumn(dbName, 'incidentes', 'tipo_nombre'))) {
        try {
          await pool.query('ALTER TABLE incidentes ADD COLUMN tipo_nombre VARCHAR(255) NULL')
          if (await hasColumn(dbName, 'incidentes', 'nombre_incidente')) {
            await pool.query(
              'UPDATE incidentes SET tipo_nombre = nombre_incidente WHERE tipo_nombre IS NULL'
            )
          }
          console.log('[db] Columna incidentes.tipo_nombre añadida (migración legacy).')
        } catch (e) {
          console.warn('[db] incidentes.tipo_nombre:', e.message)
        }
      }
      if (!(await hasColumn(dbName, 'incidentes', 'fecha'))) {
        try {
          await pool.query('ALTER TABLE incidentes ADD COLUMN fecha DATETIME NULL')
          if (await hasColumn(dbName, 'incidentes', 'created_at')) {
            await pool.query(
              'UPDATE incidentes SET fecha = created_at WHERE fecha IS NULL'
            )
          }
          console.log('[db] Columna incidentes.fecha añadida (migración legacy).')
        } catch (e) {
          console.warn('[db] incidentes.fecha:', e.message)
        }
      }
      if (!(await hasColumn(dbName, 'incidentes', 'tipo_de_reportante'))) {
        try {
          await pool.query(
            "ALTER TABLE incidentes ADD COLUMN tipo_de_reportante ENUM('ciudadano','oficial') NULL DEFAULT 'ciudadano'"
          )
          console.log('[db] Columna incidentes.tipo_de_reportante añadida.')
        } catch (e) {
          console.warn('[db] incidentes.tipo_de_reportante:', e.message)
        }
      }
      if (!(await hasColumn(dbName, 'incidentes', 'id_de_reportante'))) {
        try {
          await pool.query('ALTER TABLE incidentes ADD COLUMN id_de_reportante INT NULL')
          const [ur] = await pool.query(
            "SELECT id FROM usuarios WHERE estatus IN ('aprobado','pendiente') ORDER BY id ASC LIMIT 1"
          )
          const fallback = ur[0] != null && ur[0].id != null ? Number(ur[0].id) : null
          if (fallback != null) {
            await pool.query('UPDATE incidentes SET id_de_reportante = ? WHERE id_de_reportante IS NULL', [
              fallback,
            ])
            await pool.query('UPDATE incidentes SET tipo_de_reportante = ? WHERE tipo_de_reportante IS NULL', [
              'ciudadano',
            ])
            await pool.query('ALTER TABLE incidentes MODIFY id_de_reportante INT NOT NULL')
            console.log('[db] Columna incidentes.id_de_reportante añadida y filas rellenadas (usuario ' + fallback + ').')
          } else {
            console.warn(
              '[db] incidentes: id_de_reportante añadida como NULL; inserte al menos un usuario o asigne a mano.'
            )
          }
        } catch (e) {
          console.warn('[db] incidentes.id_de_reportante:', e.message)
        }
      }
      if (
        (await hasColumn(dbName, 'incidentes', 'id_de_reportante')) &&
        !(await hasConstraint(dbName, 'incidentes', 'fk_reportante_inc')) &&
        (await hasTable(dbName, 'usuarios'))
      ) {
        try {
          await pool.query(
            `ALTER TABLE incidentes
             ADD CONSTRAINT fk_reportante_inc
             FOREIGN KEY (id_de_reportante) REFERENCES usuarios (id)`
          )
          console.log('[db] incidentes: FK fk_reportante_inc creada.')
        } catch (e) {
          console.warn('[db] incidentes fk_reportante_inc:', e.message)
        }
      }
    }
  } catch (err) {
    console.error('[db] No se pudo comprobar el esquema de incidentes:', err.message)
    throw err
  }
}

/**
 * columnas y semilla de categorías / tipos de incidente (catálogo en BD).
 */
export async function ensureCatalogoEstructura() {
  const dbName = process.env.DB_NAME || 'proteccion_civil_carabobo'
  try {
    if (!(await hasTable(dbName, 'categorias_incidentes'))) {
      return
    }
    if (!(await hasColumn(dbName, 'categorias_incidentes', 'slug'))) {
      try {
        await pool.query('ALTER TABLE categorias_incidentes ADD COLUMN slug VARCHAR(100) NULL')
      } catch (e) {
        console.warn('[db] categorias_incidentes.slug:', e.message)
      }
    }
    if (!(await hasColumn(dbName, 'categorias_incidentes', 'color'))) {
      try {
        await pool.query(
          "ALTER TABLE categorias_incidentes ADD COLUMN color VARCHAR(20) NULL DEFAULT '#64748b'"
        )
      } catch (e) {
        console.warn('[db] categorias_incidentes.color:', e.message)
      }
    }
    if (!(await hasColumn(dbName, 'categorias_incidentes', 'activo'))) {
      try {
        await pool.query(
          'ALTER TABLE categorias_incidentes ADD COLUMN activo TINYINT(1) NOT NULL DEFAULT 1'
        )
      } catch (e) {
        console.warn('[db] categorias_incidentes.activo:', e.message)
      }
    }
    if (!(await hasColumn(dbName, 'categorias_incidentes', 'orden'))) {
      try {
        await pool.query('ALTER TABLE categorias_incidentes ADD COLUMN orden INT NOT NULL DEFAULT 0')
      } catch (e) {
        console.warn('[db] categorias_incidentes.orden:', e.message)
      }
    }
    const categoriasBaseColor = [
      { slug: 'hecho_vial', color: '#6d28d9' },
      { slug: 'incendio', color: '#a21caf' },
      { slug: 'busqueda_rescate', color: '#4338ca' },
      { slug: 'guardia_seguridad_prevencion', color: '#7c2d12' },
      { slug: 'condicion_arborea', color: '#14532d' },
      { slug: 'solicitud_traslado', color: '#9f1239' },
      { slug: 'clima', color: '#3b82f6' },
      { slug: 'hidrometeorologico', color: '#0f766e' },
      { slug: 'colapso_estructura', color: '#374151' },
      { slug: 'inspeccion_reubicacion_animal', color: '#854d0e' },
      { slug: 'eliminacion_peligro', color: '#4c1d95' },
      { slug: 'otro', color: '#334155' },
    ]
    // Asegura categoría base para eventos climáticos en bases ya pobladas.
    try {
      await pool.query(
        `INSERT INTO categorias_incidentes (slug, nombre, color, activo, orden, emergencia)
         SELECT 'clima', 'Clima', '#3b82f6', 1, 7, 'Si'
         WHERE NOT EXISTS (
           SELECT 1 FROM categorias_incidentes WHERE slug = 'clima'
         )`
      )
    } catch (e) {
      console.warn('[db] categorias_incidentes.clima:', e.message)
    }
    for (const c of categoriasBaseColor) {
      try {
        await pool.query('UPDATE categorias_incidentes SET color = ? WHERE slug = ?', [c.color, c.slug])
      } catch (e) {
        console.warn(`[db] categorias_incidentes.${c.slug}.color:`, e.message)
      }
    }
    if (!(await hasTable(dbName, 'tipos_de_incidentes'))) {
      return
    }
    if (!(await hasColumn(dbName, 'tipos_de_incidentes', 'slug'))) {
      try {
        await pool.query('ALTER TABLE tipos_de_incidentes ADD COLUMN slug VARCHAR(120) NULL')
      } catch (e) {
        console.warn('[db] tipos_de_incidentes.slug:', e.message)
      }
    }
    if (!(await hasColumn(dbName, 'tipos_de_incidentes', 'color'))) {
      try {
        await pool.query('ALTER TABLE tipos_de_incidentes ADD COLUMN color VARCHAR(20) NULL')
      } catch (e) {
        console.warn('[db] tipos_de_incidentes.color:', e.message)
      }
    }
    if (!(await hasColumn(dbName, 'tipos_de_incidentes', 'activo'))) {
      try {
        await pool.query('ALTER TABLE tipos_de_incidentes ADD COLUMN activo TINYINT(1) NOT NULL DEFAULT 1')
      } catch (e) {
        console.warn('[db] tipos_de_incidentes.activo:', e.message)
      }
    }
    if (!(await hasColumn(dbName, 'tipos_de_incidentes', 'orden'))) {
      try {
        await pool.query('ALTER TABLE tipos_de_incidentes ADD COLUMN orden INT NOT NULL DEFAULT 0')
      } catch (e) {
        console.warn('[db] tipos_de_incidentes.orden:', e.message)
      }
    }
    const tiposClimaBase = [
      { slug: 'despejado', nombre: 'Despejado', orden: 1, color: '#ffffff' },
      { slug: 'nublado', nombre: 'Nublado', orden: 2, color: '#9ca3af' },
      { slug: 'precipitaciones_leves', nombre: 'Precipitaciones leves', orden: 3, color: '#3b82f6' },
      { slug: 'precipitaciones_moderadas', nombre: 'Precipitaciones moderadas', orden: 4, color: '#84cc16' },
      { slug: 'precipitaciones_fuertes', nombre: 'Precipitaciones fuertes', orden: 5, color: '#facc15' },
      { slug: 'precipitaciones_severas', nombre: 'Precipitaciones severas', orden: 6, color: '#d97706' },
      { slug: 'precipitaciones_torrenciales', nombre: 'Precipitaciones torrenciales', orden: 7, color: '#dc2626' },
    ]
    const legacyClima = [
      'lluvia_fuerte',
      'lluvia_moderada',
      'lluvia_leve',
      'tormenta_electrica',
      'vientos_fuertes',
      'granizada',
      'ola_de_calor',
    ]
    for (const t of tiposClimaBase) {
      try {
        await pool.query(
          `INSERT INTO tipos_de_incidentes (slug, nombre, id_categoria, color, activo, orden)
           SELECT ?, ?, c.id, ?, 1, ?
           FROM categorias_incidentes c
           WHERE c.slug = 'clima'
           AND NOT EXISTS (
             SELECT 1 FROM tipos_de_incidentes x WHERE x.slug = ?
           )`,
          [t.slug, t.nombre, t.color, t.orden, t.slug]
        )
        await pool.query(
          `UPDATE tipos_de_incidentes
           SET color = ?, nombre = ?, orden = ?
           WHERE slug = ?`,
          [t.color, t.nombre, t.orden, t.slug]
        )
      } catch (e) {
        console.warn(`[db] tipos_de_incidentes.${t.slug}:`, e.message)
      }
    }
    for (const legacySlug of legacyClima) {
      try {
        await pool.query('UPDATE tipos_de_incidentes SET activo = 0 WHERE slug = ?', [legacySlug])
      } catch (e) {
        console.warn(`[db] tipos_de_incidentes.${legacySlug}.activo:`, e.message)
      }
    }
    await seedCatalogoVacio()
    await syncNombresCatalogoSemilla()
  } catch (err) {
    console.error('[db] ensureCatalogoEstructura:', err.message)
    throw err
  }
}
