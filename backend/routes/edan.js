import { Router } from 'express'
import pool from '../db/connection.js'

const router = Router()
const MUNICIPIOS_CARABOBO = [
  'Valencia',
  'Naguanagua',
  'San Diego',
  'Guacara',
  'Mariara',
  'Diego Ibarra',
  'Puerto Cabello',
  'Juan José Mora',
  'Bejuma',
  'Miranda',
  'Montalbán',
  'Carlos Arvelo',
  'San Joaquín',
  'Los Guayos',
  'Libertador',
]
const CARABOBO_BOUNDS = {
  minLat: 9.95,
  maxLat: 10.48,
  minLng: -68.55,
  maxLng: -67.32,
}
const TIPOS_AFECTACION = ['anegacion', 'inundacion', 'deslizamiento', 'otros']
const CONDICIONES_VIVIENDA = ['afectada', 'alto_riesgo', 'destruida']
const TIPOS_VIVIENDA = ['anarquica', 'improvisada', 'casa convencional']
const OPCIONES_SI_NO = ['si', 'no']
const SOLO_LETRAS = /^[A-Za-zÁÉÍÓÚáéíóúÑñÜü\s.'-]+$/
const ALFANUM_GUION = /^[A-Za-z0-9-]+$/
const TEXTO_GENERAL = /^[A-Za-z0-9ÁÉÍÓÚáéíóúÑñÜü\s.,#°º/-]+$/
const TELEFONO_VENEZOLANO = /^04\d{2}-\d{7}$/
const CEDULA_VENEZOLANA = /^[VJE]\d{6,9}$/
const SELECT_EDAN = `
  id, id_oficial, fecha_reporte, numero_planilla, propetario, p_cedula, P_edad, P_telefono,
  municipio, parroquia, sector, nro_casa, urbanizacion, direccion, lat, lng, nro_informe,
  fecha_solicitud, fecha_afectacion, descripcion_afectacion, tipo_afectacion, afectacion_otros,
  condicion_vivienda, tipo_vivienda, descripcion_vivienda,
  \`lact.Fem\` AS lact_Fem, \`lact.Masc\` AS lact_Masc, \`niños.Fem\` AS ninos_Fem, \`niños.Masc\` AS ninos_Masc,
  \`adultos.Fem\` AS adultos_Fem, \`adultos.Masc\` AS adultos_Masc,
  \`3era_edad.Fem\` AS tercera_edad_Fem, \`3era_edad.Masc\` AS tercera_edad_Masc,
  discapacitados, total_personas, nro_familias, requerimientos_afectacion, P_enseres_total,
  P_enseres_parcial, p_enseres_no, necesidades_agua, necesidades_alimentos, necesidades_luz
`
const SQL_INSERT_EDAN = `
  INSERT INTO reportes_edan (
    id_oficial, numero_planilla, propetario, p_cedula, P_edad, P_telefono,
    municipio, parroquia, sector, nro_casa, urbanizacion, direccion,
    lat, lng, nro_informe, fecha_solicitud, fecha_afectacion,
    descripcion_afectacion, tipo_afectacion, afectacion_otros,
    condicion_vivienda, tipo_vivienda, descripcion_vivienda,
    \`lact.Fem\`, \`lact.Masc\`, \`niños.Fem\`, \`niños.Masc\`, \`adultos.Fem\`, \`adultos.Masc\`,
    \`3era_edad.Fem\`, \`3era_edad.Masc\`, discapacitados, total_personas,
    nro_familias, requerimientos_afectacion, P_enseres_total,
    P_enseres_parcial, p_enseres_no, necesidades_agua,
    necesidades_alimentos, necesidades_luz
  ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
`
const SQL_UPDATE_EDAN = `
  UPDATE reportes_edan SET
    numero_planilla = ?, propetario = ?, p_cedula = ?, P_edad = ?, P_telefono = ?,
    municipio = ?, parroquia = ?, sector = ?, nro_casa = ?, urbanizacion = ?, direccion = ?,
    lat = ?, lng = ?, nro_informe = ?, fecha_solicitud = ?, fecha_afectacion = ?,
    descripcion_afectacion = ?, tipo_afectacion = ?, afectacion_otros = ?,
    condicion_vivienda = ?, tipo_vivienda = ?, descripcion_vivienda = ?,
    \`lact.Fem\` = ?, \`lact.Masc\` = ?, \`niños.Fem\` = ?, \`niños.Masc\` = ?,
    \`adultos.Fem\` = ?, \`adultos.Masc\` = ?, \`3era_edad.Fem\` = ?, \`3era_edad.Masc\` = ?,
    discapacitados = ?, total_personas = ?, nro_familias = ?, requerimientos_afectacion = ?,
    P_enseres_total = ?, P_enseres_parcial = ?, p_enseres_no = ?, necesidades_agua = ?,
    necesidades_alimentos = ?, necesidades_luz = ?
  WHERE id = ?
`

/** Compat: body de la app puede usar `lact_Fem`, `lact.Fem`, `niños_Fem`, etc. */
function pick(d, ...keys) {
  for (const k of keys) {
    if (k != null && d[k] != null && d[k] !== '') return d[k]
  }
  for (const k of keys) {
    if (k != null && d[k] != null) return d[k]
  }
  return null
}

function normalizarTexto(s) {
  return String(s || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
}

function municipioDeCarabobo(municipio) {
  const mNorm = normalizarTexto(municipio)
  if (!mNorm) return ''
  const exacto = MUNICIPIOS_CARABOBO.find((m) => normalizarTexto(m) === mNorm)
  if (exacto) return exacto
  // Nominatim suele devolver "Municipio Valencia", etc.
  return (
    MUNICIPIOS_CARABOBO.find((m) => {
      const canon = normalizarTexto(m)
      return mNorm.includes(canon) || canon.includes(mNorm)
    }) || ''
  )
}

function textoRequerido(v, campo, maxLen = 255) {
  const t = String(v || '').trim()
  if (!t) throw new Error(`El campo ${campo} es obligatorio.`)
  if (t.length > maxLen) throw new Error(`El campo ${campo} supera el máximo permitido.`)
  return t
}

function validarPatron(t, campo, patron, mensaje) {
  if (!patron.test(String(t || '').trim())) {
    throw new Error(mensaje || `El campo ${campo} tiene un formato inválido.`)
  }
  return t
}

function normalizarCedula(v, campo = 'cédula') {
  let c = String(v || '').replace(/\s/g, '').toUpperCase()
  if (/^\d{6,9}$/.test(c)) c = `V${c}`
  if (!CEDULA_VENEZOLANA.test(c)) {
    throw new Error(`${campo} debe ser V, E o J seguido de 6 a 9 dígitos.`)
  }
  return c
}

function textoOpcional(v, maxLen = 255) {
  const t = String(v || '').trim()
  if (!t) return null
  return t.slice(0, maxLen)
}

function enteroNoNegativo(v, campo, max = 999999) {
  const n = Number.parseInt(String(v), 10)
  if (!Number.isFinite(n) || n < 0 || n > max) {
    throw new Error(`El campo ${campo} debe ser un entero entre 0 y ${max}.`)
  }
  return n
}

function enumRequerido(v, campo, opciones) {
  const x = normalizarTexto(v)
  if (!x || !opciones.includes(x)) {
    throw new Error(`El campo ${campo} es inválido.`)
  }
  return x
}

function fechaRequerida(v, campo) {
  if (v == null || String(v).trim() === '') throw new Error(`El campo ${campo} es obligatorio.`)
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) throw new Error(`El campo ${campo} no tiene una fecha válida.`)
  return d
}

function validarFechasEdan(fechaSolicitud, fechaAfectacion) {
  const ahora = new Date()
  if (fechaSolicitud > ahora) {
    throw new Error('La fecha de solicitud no puede ser futura.')
  }
  if (fechaAfectacion > ahora) {
    throw new Error('La fecha de afectación no puede ser futura.')
  }
  if (fechaAfectacion > fechaSolicitud) {
    throw new Error('La fecha de afectación no puede ser posterior a la solicitud.')
  }
}

function coordONull(v) {
  if (v == null || String(v).trim() === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : null
}

function validarCoordsCarabobo(lat, lng) {
  const tieneLat = lat != null
  const tieneLng = lng != null
  if (tieneLat !== tieneLng) {
    throw new Error('Debe indicar latitud y longitud juntas.')
  }
  if (!tieneLat) return
  const enRango =
    lat >= CARABOBO_BOUNDS.minLat &&
    lat <= CARABOBO_BOUNDS.maxLat &&
    lng >= CARABOBO_BOUNDS.minLng &&
    lng <= CARABOBO_BOUNDS.maxLng
  if (!enRango) {
    throw new Error('Las coordenadas deben estar dentro del estado Carabobo.')
  }
}

function normalizarDetallesFamiliares(arr) {
  const out = []
  for (const it of arr) {
    const nombre = String(it?.nombre_completo || '').trim()
    if (!nombre) throw new Error('El nombre del afectado es obligatorio.')
    validarPatron(nombre, 'nombre_completo', SOLO_LETRAS, 'El nombre del afectado solo permite letras.')
    const cedula = normalizarCedula(it?.cedula, 'La cédula del afectado')
    const edad = enteroNoNegativo(it?.edad ?? 0, 'edad de detalle familiar', 130)
    const generoBase = String(it?.genero || '').trim().toLowerCase()
    if (!['femenino', 'masculino'].includes(generoBase)) {
      throw new Error('El sexo del afectado debe ser Femenino o Masculino.')
    }
    const genero = generoBase === 'femenino' ? 'Femenino' : 'Masculino'
    out.push({
      nombre_completo: nombre.slice(0, 150),
      cedula: cedula.slice(0, 20),
      edad,
      genero,
    })
  }
  return out
}

function validarYNormalizarPayload(d, { requiereIdOficial }) {
  const id_oficial = enteroNoNegativo(
    requiereIdOficial ? d?.id_oficial : (d?.id_oficial ?? 0),
    'id_oficial',
    999999999
  )
  const municipioCanonico = municipioDeCarabobo(d?.municipio)
  if (!municipioCanonico) {
    throw new Error('Solo se permiten municipios del estado Carabobo.')
  }
  const tipo_afectacion = enumRequerido(d?.tipo_afectacion, 'tipo_afectacion', TIPOS_AFECTACION)
  const condicion_vivienda = enumRequerido(
    d?.condicion_vivienda,
    'condicion_vivienda',
    CONDICIONES_VIVIENDA
  )
  const tipo_vivienda = enumRequerido(d?.tipo_vivienda, 'tipo_vivienda', TIPOS_VIVIENDA)
  const necesidades_agua = enumRequerido(d?.necesidades_agua, 'necesidades_agua', OPCIONES_SI_NO)
  const necesidades_alimentos = enumRequerido(
    d?.necesidades_alimentos,
    'necesidades_alimentos',
    OPCIONES_SI_NO
  )
  const necesidades_luz = enumRequerido(d?.necesidades_luz, 'necesidades_luz', OPCIONES_SI_NO)
  const lat = coordONull(d?.lat)
  const lng = coordONull(d?.lng)
  validarCoordsCarabobo(lat, lng)
  const fecha_solicitud = fechaRequerida(d?.fecha_solicitud, 'fecha_solicitud')
  const fecha_afectacion = fechaRequerida(d?.fecha_afectacion, 'fecha_afectacion')
  validarFechasEdan(fecha_solicitud, fecha_afectacion)

  const numero_planilla = textoOpcional(d?.numero_planilla, 50) || `APP-${Date.now().toString().slice(-6)}`
  validarPatron(numero_planilla, 'numero_planilla', ALFANUM_GUION, 'Número de planilla solo admite letras, números y guion.')
  const nro_informe = textoOpcional(d?.nro_informe, 50) || `INF-${Date.now().toString().slice(-6)}`
  validarPatron(nro_informe, 'nro_informe', ALFANUM_GUION, 'Nro. informe solo admite letras, números y guion.')
  const propetario = textoRequerido(d?.propetario, 'propetario', 100)
  validarPatron(propetario, 'propetario', SOLO_LETRAS, 'Propietario solo permite letras.')
  const p_cedula = textoRequerido(d?.p_cedula, 'p_cedula', 20)
  if (!/^[VEJ]?\d{6,20}$/.test(p_cedula)) {
    throw new Error('Cédula debe ser numérica y tener entre 6 y 20 dígitos.')
  }
  const P_telefono = textoRequerido(d?.P_telefono, 'P_telefono', 20)
  validarPatron(P_telefono, 'P_telefono', TELEFONO_VENEZOLANO, 'Teléfono debe tener formato 0414-1234567.')
  const parroquia = textoRequerido(d?.parroquia, 'parroquia', 100)
  validarPatron(parroquia, 'parroquia', SOLO_LETRAS, 'Parroquia solo permite letras.')
  const sector = textoRequerido(d?.sector, 'sector', 100)
  validarPatron(sector, 'sector', SOLO_LETRAS, 'Sector solo permite letras.')
  const nro_casa = textoRequerido(d?.nro_casa, 'nro_casa', 20)
  validarPatron(nro_casa, 'nro_casa', ALFANUM_GUION, 'Nro. casa solo admite letras, números y guion.')
  const urbanizacion = textoRequerido(d?.urbanizacion, 'urbanizacion', 100)
  validarPatron(urbanizacion, 'urbanizacion', SOLO_LETRAS, 'Urbanización solo permite letras.')
  const direccion = textoRequerido(d?.direccion, 'direccion', 255)
  validarPatron(direccion, 'direccion', TEXTO_GENERAL, 'Dirección solo admite letras, números y signos básicos.')

  const payload = {
    id_oficial,
    numero_planilla,
    propetario,
    p_cedula,
    P_edad: enteroNoNegativo(d?.P_edad, 'P_edad', 130),
    P_telefono,
    municipio: municipioCanonico,
    parroquia,
    sector,
    nro_casa,
    urbanizacion,
    direccion,
    lat,
    lng,
    nro_informe,
    fecha_solicitud,
    fecha_afectacion,
    descripcion_afectacion: textoRequerido(d?.descripcion_afectacion, 'descripcion_afectacion', 4000),
    tipo_afectacion,
    afectacion_otros: tipo_afectacion === 'otros' ? textoRequerido(d?.afectacion_otros, 'afectacion_otros', 255) : textoOpcional(d?.afectacion_otros, 255),
    condicion_vivienda,
    tipo_vivienda,
    descripcion_vivienda: textoRequerido(d?.descripcion_vivienda, 'descripcion_vivienda', 4000),
    lact_Fem: enteroNoNegativo(pick(d, 'lact.Fem', 'lact_Fem') ?? 0, 'lact_Fem'),
    lact_Masc: enteroNoNegativo(pick(d, 'lact.Masc', 'lact_Masc') ?? 0, 'lact_Masc'),
    ninos_Fem: enteroNoNegativo(pick(d, 'niños.Fem', 'ninos_Fem', 'niños_Fem') ?? 0, 'ninos_Fem'),
    ninos_Masc: enteroNoNegativo(pick(d, 'niños.Masc', 'ninos_Masc', 'niños_Masc') ?? 0, 'ninos_Masc'),
    adultos_Fem: enteroNoNegativo(pick(d, 'adultos.Fem', 'adultos_Fem') ?? 0, 'adultos_Fem'),
    adultos_Masc: enteroNoNegativo(pick(d, 'adultos.Masc', 'adultos_Masc') ?? 0, 'adultos_Masc'),
    tercera_edad_Fem: enteroNoNegativo(
      pick(d, '3era_edad.Fem', '3era_edad_Fem') ?? 0,
      '3era_edad_Fem'
    ),
    tercera_edad_Masc: enteroNoNegativo(
      pick(d, '3era_edad.Masc', '3era_edad_Masc') ?? 0,
      '3era_edad_Masc'
    ),
    discapacitados: enteroNoNegativo(d?.discapacitados ?? 0, 'discapacitados'),
    total_personas: enteroNoNegativo(d?.total_personas, 'total_personas'),
    nro_familias: enteroNoNegativo(d?.nro_familias, 'nro_familias'),
    requerimientos_afectacion: textoRequerido(d?.requerimientos_afectacion, 'requerimientos_afectacion', 4000),
    P_enseres_total: textoRequerido(d?.P_enseres_total, 'P_enseres_total', 4000),
    P_enseres_parcial: textoRequerido(d?.P_enseres_parcial, 'P_enseres_parcial', 4000),
    p_enseres_no: textoRequerido(d?.p_enseres_no, 'p_enseres_no', 4000),
    necesidades_agua,
    necesidades_alimentos,
    necesidades_luz,
    detalles_familiares: normalizarDetallesFamiliares(d?.detalles_familiares),
  }

  if (payload.total_personas <= 0) {
    throw new Error('total_personas debe ser mayor que cero.')
  }
  if (payload.nro_familias <= 0) {
    throw new Error('nro_familias debe ser mayor que cero.')
  }
  const sumaPersonas =
    payload.lact_Fem +
    payload.lact_Masc +
    payload.ninos_Fem +
    payload.ninos_Masc +
    payload.adultos_Fem +
    payload.adultos_Masc +
    payload.tercera_edad_Fem +
    payload.tercera_edad_Masc
  if (sumaPersonas <= 0) {
    throw new Error('Debe registrar al menos una persona en los grupos etarios.')
  }
  if (payload.total_personas < sumaPersonas) {
    throw new Error('total_personas no puede ser menor a la suma de grupos etarios.')
  }
  return payload
}

function esErrorValidacion(msg) {
  return (
    msg.startsWith('El campo ') ||
    msg.includes('Carabobo') ||
    msg.includes('debe') ||
    msg.includes('solo') ||
    msg.includes('obligatorio') ||
    msg.includes('inválid') ||
    msg.includes('válid') ||
    msg.includes('posterior') ||
    msg.includes('futura')
  )
}

router.get('/health', (req, res) => {
  res.json({ ok: true, servicio: 'edan' })
})

router.get('/', async (_req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT ${SELECT_EDAN}
       FROM reportes_edan
       ORDER BY fecha_reporte DESC, id DESC`
    )
    res.json(rows)
  } catch (err) {
    console.error('Error en EDAN GET /:', err)
    res.status(500).json({ error: 'Error al listar reportes EDAN' })
  }
})

const DIAS_VIDA_EDAN_MAPA = 7

/** Reportes EDAN con ubicación para el mapa en vivo (últimos 7 días). */
router.get('/mapa-vivo', async (_req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT ${SELECT_EDAN}
       FROM reportes_edan
       WHERE lat IS NOT NULL
         AND lng IS NOT NULL
         AND fecha_reporte >= DATE_SUB(NOW(), INTERVAL ? DAY)
       ORDER BY fecha_reporte DESC, id DESC`,
      [DIAS_VIDA_EDAN_MAPA]
    )
    res.json(rows)
  } catch (err) {
    console.error('Error en EDAN GET /mapa-vivo:', err)
    res.status(500).json({ error: 'Error al listar reportes EDAN para el mapa' })
  }
})

/** Alias usado por clientes móviles: todos los reportes (filtrar en cliente si hace falta). */
router.get('/todos-los-reportes', async (_req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT ${SELECT_EDAN}
       FROM reportes_edan
       ORDER BY fecha_reporte DESC, id DESC`
    )
    res.json(rows)
  } catch (err) {
    console.error('Error en EDAN GET /todos-los-reportes:', err)
    res.status(500).json({ error: 'Error al listar reportes EDAN' })
  }
})

router.get('/:id', async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10)
    if (!Number.isFinite(id) || id < 1) {
      return res.status(400).json({ error: 'Id de EDAN inválido.' })
    }
    const [rows] = await pool.query(
      `SELECT ${SELECT_EDAN}
       FROM reportes_edan
       WHERE id = ?`,
      [id]
    )
    if (!rows || rows.length === 0) {
      return res.status(404).json({ error: 'Reporte EDAN no encontrado.' })
    }
    const [detalles] = await pool.query(
      `SELECT id, nombre_completo, cedula, edad, genero
       FROM afectados_detalle
       WHERE id_reporte = ?
       ORDER BY id ASC`,
      [id]
    )
    res.json({ ...rows[0], detalles_familiares: detalles || [] })
  } catch (err) {
    console.error('Error en EDAN GET /:id:', err)
    res.status(500).json({ error: 'Error al obtener reporte EDAN' })
  }
})

router.post('/registrar', async (req, res) => {
  const connection = await pool.getConnection()
  try {
    const payload = validarYNormalizarPayload(req.body || {}, { requiereIdOficial: true })

    await connection.beginTransaction()

    const [result] = await connection.query(SQL_INSERT_EDAN, [
      payload.id_oficial,
      payload.numero_planilla,
      payload.propetario,
      payload.p_cedula,
      payload.P_edad,
      payload.P_telefono,
      payload.municipio,
      payload.parroquia,
      payload.sector,
      payload.nro_casa,
      payload.urbanizacion,
      payload.direccion,
      payload.lat,
      payload.lng,
      payload.nro_informe,
      payload.fecha_solicitud,
      payload.fecha_afectacion,
      payload.descripcion_afectacion,
      payload.tipo_afectacion,
      payload.afectacion_otros,
      payload.condicion_vivienda,
      payload.tipo_vivienda,
      payload.descripcion_vivienda,
      payload.lact_Fem,
      payload.lact_Masc,
      payload.ninos_Fem,
      payload.ninos_Masc,
      payload.adultos_Fem,
      payload.adultos_Masc,
      payload.tercera_edad_Fem,
      payload.tercera_edad_Masc,
      payload.discapacitados,
      payload.total_personas,
      payload.nro_familias,
      payload.requerimientos_afectacion,
      payload.P_enseres_total,
      payload.P_enseres_parcial,
      payload.p_enseres_no,
      payload.necesidades_agua,
      payload.necesidades_alimentos,
      payload.necesidades_luz,
    ])

    const reporteId = result.insertId

    if (payload.detalles_familiares.length > 0) {
      const valoresFamiliares = payload.detalles_familiares.map((f) => [
        reporteId,
        f.nombre_completo,
        f.cedula,
        f.edad,
        f.genero,
      ])
      await connection.query(
        'INSERT INTO afectados_detalle (id_reporte, nombre_completo, cedula, edad, genero) VALUES ?',
        [valoresFamiliares]
      )
    }

    await connection.commit()
    res.status(201).json({ ok: true, id: reporteId })
  } catch (err) {
    await connection.rollback()
    const msg = err?.message || 'Error al registrar reporte EDAN'
    const status = esErrorValidacion(msg) ? 400 : 500
    console.error('Error en EDAN /registrar:', err)
    res.status(status).json({ error: msg })
  } finally {
    connection.release()
  }
})

router.put('/:id', async (req, res) => {
  const connection = await pool.getConnection()
  try {
    const id = parseInt(req.params.id, 10)
    if (!Number.isFinite(id) || id < 1) {
      return res.status(400).json({ error: 'Id de EDAN inválido.' })
    }
    const [existente] = await connection.query('SELECT id, id_oficial FROM reportes_edan WHERE id = ?', [id])
    if (!existente || existente.length === 0) {
      return res.status(404).json({ error: 'Reporte EDAN no encontrado.' })
    }

    const bodyConOficial = {
      ...(req.body || {}),
      id_oficial:
        req.body?.id_oficial != null ? req.body.id_oficial : existente[0].id_oficial,
    }
    const payload = validarYNormalizarPayload(bodyConOficial, { requiereIdOficial: true })

    await connection.beginTransaction()
    const [upd] = await connection.query(SQL_UPDATE_EDAN, [
      payload.numero_planilla,
      payload.propetario,
      payload.p_cedula,
      payload.P_edad,
      payload.P_telefono,
      payload.municipio,
      payload.parroquia,
      payload.sector,
      payload.nro_casa,
      payload.urbanizacion,
      payload.direccion,
      payload.lat,
      payload.lng,
      payload.nro_informe,
      payload.fecha_solicitud,
      payload.fecha_afectacion,
      payload.descripcion_afectacion,
      payload.tipo_afectacion,
      payload.afectacion_otros,
      payload.condicion_vivienda,
      payload.tipo_vivienda,
      payload.descripcion_vivienda,
      payload.lact_Fem,
      payload.lact_Masc,
      payload.ninos_Fem,
      payload.ninos_Masc,
      payload.adultos_Fem,
      payload.adultos_Masc,
      payload.tercera_edad_Fem,
      payload.tercera_edad_Masc,
      payload.discapacitados,
      payload.total_personas,
      payload.nro_familias,
      payload.requerimientos_afectacion,
      payload.P_enseres_total,
      payload.P_enseres_parcial,
      payload.p_enseres_no,
      payload.necesidades_agua,
      payload.necesidades_alimentos,
      payload.necesidades_luz,
      id,
    ])
    if (!upd || upd.affectedRows === 0) {
      await connection.rollback()
      return res.status(404).json({ error: 'Reporte EDAN no encontrado.' })
    }

    await connection.query('DELETE FROM afectados_detalle WHERE id_reporte = ?', [id])
    if (payload.detalles_familiares.length > 0) {
      const valoresFamiliares = payload.detalles_familiares.map((f) => [
        id,
        f.nombre_completo,
        f.cedula,
        f.edad,
        f.genero,
      ])
      await connection.query(
        'INSERT INTO afectados_detalle (id_reporte, nombre_completo, cedula, edad, genero) VALUES ?',
        [valoresFamiliares]
      )
    }

    await connection.commit()
    res.json({ ok: true, id })
  } catch (err) {
    await connection.rollback()
    const msg = err?.message || 'Error al actualizar reporte EDAN'
    const status = esErrorValidacion(msg) ? 400 : 500
    console.error('Error en EDAN PUT /:id:', err)
    res.status(status).json({ error: msg })
  } finally {
    connection.release()
  }
})

export default router