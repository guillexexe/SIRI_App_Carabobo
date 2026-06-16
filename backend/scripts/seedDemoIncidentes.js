import 'dotenv/config'
import bcrypt from 'bcryptjs'
import pool from '../db/connection.js'

const DEMO_MARK = '[DEMO_PRESENTACION_2024_2026]'
const YEARS = [2024, 2025, 2026]
const CERRADOS_PER_YEAR = 200
const ABIERTOS_PER_YEAR = 25
const EN_PROCESO_PER_YEAR = 12
const ROWS_PER_YEAR = CERRADOS_PER_YEAR + ABIERTOS_PER_YEAR + EN_PROCESO_PER_YEAR

const MUNICIPIOS = [
  { municipio: 'Valencia', parroquias: ['Candelaria', 'Catedral', 'Miguel Peña', 'San José'], lat: 10.162, lng: -68.007 },
  { municipio: 'Naguanagua', parroquias: ['Naguanagua'], lat: 10.256, lng: -68.018 },
  { municipio: 'San Diego', parroquias: ['San Diego'], lat: 10.255, lng: -67.953 },
  { municipio: 'Guacara', parroquias: ['Guacara', 'Ciudad Alianza', 'Yagua'], lat: 10.226, lng: -67.877 },
  { municipio: 'Puerto Cabello', parroquias: ['Bartolomé Salom', 'Goaigoaza', 'Juan José Flores', 'Unión'], lat: 10.473, lng: -68.012 },
  { municipio: 'Juan José Mora', parroquias: ['Morón', 'Urama'], lat: 10.487, lng: -68.203 },
  { municipio: 'Bejuma', parroquias: ['Bejuma', 'Canoabo', 'Simón Bolívar'], lat: 10.174, lng: -68.258 },
  { municipio: 'Carlos Arvelo', parroquias: ['Belén', 'Güigüe', 'Tacarigua'], lat: 10.083, lng: -67.779 },
  { municipio: 'Los Guayos', parroquias: ['Los Guayos'], lat: 10.189, lng: -67.939 },
  { municipio: 'San Joaquín', parroquias: ['San Joaquín'], lat: 10.263, lng: -67.787 },
]

const FALLBACK_TIPOS = [
  { tipo: 'arrollado_peaton', tipo_nombre: 'Arrollado (Peatón)', categoria: 'hecho_vial' },
  { tipo: 'colision_entre_vehiculos', tipo_nombre: 'Colisión entre Vehículos', categoria: 'hecho_vial' },
  { tipo: 'derrape_de_moto', tipo_nombre: 'Derrape de Moto', categoria: 'hecho_vial' },
  { tipo: 'vegetacion', tipo_nombre: 'Vegetación', categoria: 'incendio' },
  { tipo: 'estructura', tipo_nombre: 'Estructura', categoria: 'incendio' },
  { tipo: 'persona_desaparecida_en_montana', tipo_nombre: 'Persona desaparecida en montaña', categoria: 'busqueda_rescate' },
  { tipo: 'guardia_de_seguridad_y_prevencion', tipo_nombre: 'Guardia de Seguridad y Prevención', categoria: 'guardia_seguridad_prevencion' },
  { tipo: 'arbol_caido_en_via_publica', tipo_nombre: 'Árbol caído en vía pública', categoria: 'condicion_arborea' },
  { tipo: 'lesionado_por_arma_blanca', tipo_nombre: 'Lesionado por arma blanca', categoria: 'solicitud_traslado' },
  { tipo: 'precipitaciones_fuertes', tipo_nombre: 'Precipitaciones fuertes', categoria: 'clima' },
  { tipo: 'anegacion', tipo_nombre: 'Anegación', categoria: 'hidrometeorologico' },
  { tipo: 'colapso_de_estructura', tipo_nombre: 'Colapso de estructura', categoria: 'colapso_estructura' },
  { tipo: 'serpiente', tipo_nombre: 'Serpiente', categoria: 'inspeccion_reubicacion_animal' },
  { tipo: 'fuga_de_glp', tipo_nombre: 'Fuga de GLP', categoria: 'eliminacion_peligro' },
]

function pick(arr, idx) {
  return arr[idx % arr.length]
}

function pad(n) {
  return String(n).padStart(2, '0')
}

function demoDate(year, index) {
  if (year === 2026) {
    // Para la presentación de junio 2026 no se deben generar incidentes futuros.
    const inicio = new Date(Date.UTC(2026, 0, 1))
    const fin = new Date(Date.UTC(2026, 5, 11))
    const rangoDias = Math.floor((fin - inicio) / 86400000) + 1
    const d = new Date(inicio)
    d.setUTCDate(d.getUTCDate() + (index % rangoDias))
    const hour = (index * 3) % 24
    const minute = (index * 11) % 60
    return `${year}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())} ${pad(hour)}:${pad(minute)}:00`
  }
  const month = (index % 12) + 1
  const day = ((index * 7) % 27) + 1
  const hour = (index * 3) % 24
  const minute = (index * 11) % 60
  return `${year}-${pad(month)}-${pad(day)} ${pad(hour)}:${pad(minute)}:00`
}

function jitter(base, index, factor = 0.035) {
  const offset = ((index % 9) - 4) * factor * 0.15
  return Number((base + offset).toFixed(8))
}

function estadoPorIndice(index) {
  if (index < CERRADOS_PER_YEAR) return 'cerrado'
  if (index < CERRADOS_PER_YEAR + ABIERTOS_PER_YEAR) return 'abierto'
  return 'en_proceso'
}

async function obtenerTipos() {
  try {
    const [rows] = await pool.query(
      `SELECT
         COALESCE(NULLIF(TRIM(t.slug), ''), CONCAT('id_', t.id)) AS tipo,
         t.nombre AS tipo_nombre,
         COALESCE(NULLIF(TRIM(c.slug), ''), c.nombre) AS categoria
       FROM tipos_de_incidentes t
       INNER JOIN categorias_incidentes c ON t.id_categoria = c.id
       WHERE (t.activo = 1 OR t.activo IS NULL) AND (c.activo = 1 OR c.activo IS NULL)
       ORDER BY c.nombre, t.nombre`
    )
    if (rows.length > 0) return rows
  } catch {
    // Fallback para bases sin catálogo completo.
  }
  return FALLBACK_TIPOS
}

async function obtenerReportanteDemo() {
  const [rows] = await pool.query(
    `SELECT id FROM usuarios
     WHERE rol IN ('admin', 'oficial', 'ciudadano')
     ORDER BY FIELD(rol, 'admin', 'oficial', 'ciudadano'), id
     LIMIT 1`
  )
  if (rows.length > 0) return rows[0].id

  const passwordHash = await bcrypt.hash('Demo12345', 10)
  const [result] = await pool.query(
    `INSERT INTO usuarios
     (nombre, apellido, correo, cedula, telefono, rol, estatus, password_hash)
     VALUES (?, ?, ?, ?, ?, 'admin', 'aprobado', ?)`,
    ['Demo', 'Presentacion', 'demo.presentacion@iasiedagrec.local', 'V99999999', '04120000000', passwordHash]
  )
  return result.insertId
}

function construirFila({ year, index, tipos, reportanteId }) {
  const tipo = pick(tipos, index + year)
  const zona = pick(MUNICIPIOS, index * 3 + year)
  const parroquia = pick(zona.parroquias, index)
  const fecha = demoDate(year, index)
  const estado = estadoPorIndice(index)
  const cerrado = estado === 'cerrado' ? 1 : 0
  const heridos = estado === 'cerrado' && index % 4 === 0 ? (index % 5) + 1 : 0
  const fallecidos = estado === 'cerrado' && index % 23 === 0 ? 1 : 0
  const afectados = fallecidos > 0 ? 'Muertos' : heridos > 0 ? 'Heridos' : 'No'
  const resultado = estado === 'cerrado' ? `Cierre demo para presentación ${year}.` : null

  return [
    tipo.tipo,
    tipo.tipo_nombre,
    tipo.categoria,
    `${DEMO_MARK} Registro de prueba ${year}-${index + 1}: ${tipo.tipo_nombre} en ${zona.municipio}.`,
    jitter(zona.lat, index),
    jitter(zona.lng, index, 0.045),
    zona.municipio,
    parroquia,
    `Av. principal / referencia demo ${index + 1}`,
    fecha,
    fecha,
    cerrado,
    estado,
    estado === 'cerrado' ? fecha : null,
    afectados,
    index % 3 === 0 ? 'oficial' : 'ciudadano',
    reportanteId,
    index % 5 === 0 ? 'movil' : '',
    estado === 'cerrado' ? resultado : null,
    estado === 'cerrado' && heridos === 0 && fallecidos === 0 ? 'Cierre sin víctimas para datos demo.' : null,
    estado === 'cerrado' ? heridos : null,
    estado === 'cerrado' ? fallecidos : null,
  ]
}

async function main() {
  const tipos = await obtenerTipos()
  const reportanteId = await obtenerReportanteDemo()

  await pool.query('DELETE FROM incidentes WHERE descripcion LIKE ?', [`${DEMO_MARK}%`])

  const sql = `
    INSERT INTO incidentes
    (tipo, tipo_nombre, categoria, descripcion, lat, lng, municipio, parroquia, via, fecha, created_at,
     cerrado, estado, fecha_cierre, afectados, tipo_de_reportante, id_de_reportante,
     procedencia, resultado_cierre, observacion_cierre_abierto, heridos_cierre, fallecidos_cierre)
    VALUES ?`

  let total = 0
  for (const year of YEARS) {
    const rows = []
    for (let i = 0; i < ROWS_PER_YEAR; i++) {
      rows.push(construirFila({ year, index: i, tipos, reportanteId }))
    }
    await pool.query(sql, [rows])
    total += rows.length
    console.log(`[demo] ${rows.length} incidentes insertados para ${year}`)
  }

  console.log(`[demo] Total insertado: ${total}`)
  console.log('[demo] Clave de marca:', DEMO_MARK)
}

main()
  .catch((err) => {
    console.error('[demo] Error:', err)
    process.exitCode = 1
  })
  .finally(async () => {
    await pool.end()
  })
