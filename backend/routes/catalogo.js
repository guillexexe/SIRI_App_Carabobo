import { Router } from 'express'
import pool from '../db/connection.js'
import { requireUser, requireAdmin } from '../middleware/jwtUser.js'

const router = Router()

const SLUG_RE = /^[a-z0-9_]{1,100}$/
const HEX_COLOR_RE = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i
const NOMBRE_CATALOGO_RE = /^[A-Za-z0-9ÁÉÍÓÚáéíóúÑñÜü\s().,/-]{2,100}$/

const CATEGORY_COLOR_BY_SLUG = {
  hecho_vial: '#6d28d9',
  incendio: '#a21caf',
  busqueda_rescate: '#4338ca',
  guardia_seguridad_prevencion: '#7c2d12',
  condicion_arborea: '#14532d',
  solicitud_traslado: '#9f1239',
  clima: '#3b82f6',
  hidrometeorologico: '#0f766e',
  colapso_estructura: '#374151',
  inspeccion_reubicacion_animal: '#854d0e',
  eliminacion_peligro: '#4c1d95',
  otro: '#334155',
}
const RESERVED_CATEGORY_COLORS = new Set(Object.values(CATEGORY_COLOR_BY_SLUG).map((c) => c.toLowerCase()))
const CLIMA_COLOR_BY_TIPO = {
  despejado: '#ffffff',
  nublado: '#9ca3af',
  precipitaciones_leves: '#3b82f6',
  precipitaciones_moderadas: '#84cc16',
  precipitaciones_fuertes: '#facc15',
  precipitaciones_severas: '#d97706',
  precipitaciones_torrenciales: '#dc2626',
}
const RESERVED_TIPO_COLORS = new Set(Object.values(CLIMA_COLOR_BY_TIPO).map((c) => c.toLowerCase()))

function slugify(nombre) {
  const t = String(nombre || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 100)
  return t || 'categoria'
}

function trunc100(s) {
  const t = String(s || '').trim()
  return t.length > 100 ? t.slice(0, 100) : t
}

function validarNombreCatalogo(nombre, etiqueta) {
  const n = trunc100(nombre)
  if (!n) return `Indique el nombre ${etiqueta}.`
  if (!NOMBRE_CATALOGO_RE.test(n)) {
    return `El nombre ${etiqueta} solo admite letras, números y signos básicos.`
  }
  return ''
}

function normalizeColor(input, fallback = '#64748b') {
  const c = String(input || '').trim()
  if (!c) return fallback
  if (!HEX_COLOR_RE.test(c)) return null
  return c.toLowerCase()
}

function isCategoryColorReservedForOthers(slug, color) {
  const col = String(color || '').toLowerCase()
  if (!RESERVED_CATEGORY_COLORS.has(col)) return false
  return CATEGORY_COLOR_BY_SLUG[slug] !== col
}

function isTipoColorReservedForOthers(slug, color) {
  const col = String(color || '').toLowerCase()
  if (!RESERVED_TIPO_COLORS.has(col)) return false
  return CLIMA_COLOR_BY_TIPO[slug] !== col
}

/** Catálogo activo: categorías con tipos activos (formulario registro, leyenda). */
router.get('/registro', requireUser, async (req, res) => {
  try {
    const [cats] = await pool.query(
      `SELECT id, slug, nombre, color, emergencia, orden
       FROM categorias_incidentes
       WHERE activo = 1
       ORDER BY orden ASC, id ASC`
    )
    const [tips] = await pool.query(
      `SELECT t.id, t.slug, t.nombre, t.id_categoria, t.color, t.activo, t.orden
       FROM tipos_de_incidentes t
       INNER JOIN categorias_incidentes c ON c.id = t.id_categoria AND c.activo = 1
       WHERE t.activo = 1
       ORDER BY t.orden ASC, t.id ASC`
    )
    const byCat = {}
    for (const t of tips) {
      if (!byCat[t.id_categoria]) byCat[t.id_categoria] = []
      byCat[t.id_categoria].push({
        id: t.id,
        slug: t.slug,
        nombre: t.nombre,
        color: t.color || null,
        orden: t.orden,
      })
    }
    const categorias = (cats || []).map((c) => ({
      id: c.id,
      slug: c.slug,
      nombre: c.nombre,
      color: c.color || '#64748b',
      emergencia: c.emergencia,
      orden: c.orden,
      tipos: byCat[c.id] || [],
    }))
    res.json({ categorias })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Error al cargar el catálogo.' })
  }
})

/** Toda la jerarquía (admin): incluye inactivos. */
router.get('/completo', requireAdmin, async (req, res) => {
  try {
    const [cats] = await pool.query(
      `SELECT id, slug, nombre, color, activo, orden, emergencia
       FROM categorias_incidentes
       ORDER BY orden ASC, id ASC`
    )
    const [tips] = await pool.query(
      `SELECT id, slug, nombre, id_categoria, color, activo, orden
       FROM tipos_de_incidentes
       ORDER BY id_categoria ASC, orden ASC, id ASC`
    )
    const byCat = {}
    for (const t of tips) {
      if (!byCat[t.id_categoria]) byCat[t.id_categoria] = []
      byCat[t.id_categoria].push(t)
    }
    res.json({
      categorias: (cats || []).map((c) => ({
        ...c,
        activo: c.activo === 1 || c.activo === true,
        tipos: (byCat[c.id] || []).map((t) => ({
          ...t,
          activo: t.activo === 1 || t.activo === true,
        })),
      })),
    })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Error al cargar el catálogo (admin).' })
  }
})

router.post('/categorias', requireAdmin, async (req, res) => {
  try {
    const { nombre, slug: slugIn, color, emergencia, orden } = req.body
    const errorNombre = validarNombreCatalogo(nombre, 'de la categoría')
    if (errorNombre) return res.status(400).json({ error: errorNombre })
    const slug = (slugIn && String(slugIn).trim()) || slugify(nombre)
    if (!SLUG_RE.test(slug)) {
      return res.status(400).json({
        error: 'El identificador (slug) solo puede usar minúsculas, números y guion bajo.',
      })
    }
    const [dup] = await pool.query('SELECT id FROM categorias_incidentes WHERE slug = ?', [slug])
    if (dup.length) {
      return res.status(409).json({ error: 'Ya existe una categoría con ese identificador.' })
    }
    const [dupNombre] = await pool.query(
      'SELECT id FROM categorias_incidentes WHERE LOWER(nombre) = LOWER(?)',
      [trunc100(nombre)]
    )
    if (dupNombre.length) {
      return res.status(409).json({ error: 'Ya existe una categoría con ese nombre.' })
    }
    const defaultColor = CATEGORY_COLOR_BY_SLUG[slug] || '#475569'
    const col = normalizeColor(color, defaultColor)
    if (!col) {
      return res.status(400).json({ error: 'Color inválido. Use formato HEX (#RRGGBB).' })
    }
    if (isCategoryColorReservedForOthers(slug, col)) {
      return res.status(409).json({
        error: 'Color reservado del sistema. Elija otro para evitar mezclar categorías.',
      })
    }
    const em = emergencia === 'No' ? 'No' : 'Si'
    const or = Number.isFinite(Number(orden)) ? Math.floor(Number(orden)) : 0
    const [r] = await pool.query(
      `INSERT INTO categorias_incidentes (slug, nombre, color, activo, orden, emergencia)
       VALUES (?, ?, ?, 1, ?, ?)`,
      [slug, trunc100(nombre), col, or, em]
    )
    res.status(201).json({
      id: r.insertId,
      slug,
      nombre: trunc100(nombre),
      color: col,
      activo: true,
      orden: or,
      emergencia: em,
    })
  } catch (err) {
    console.error(err)
    if (err && err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'Identificador duplicado.' })
    }
    res.status(500).json({ error: 'Error al crear la categoría.' })
  }
})

router.patch('/categorias/:id', requireAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10)
    if (isNaN(id)) return res.status(400).json({ error: 'Id inválido' })
    const { activo, nombre, color, orden, emergencia } = req.body
    const [prev] = await pool.query('SELECT id, slug, color FROM categorias_incidentes WHERE id = ?', [id])
    if (!prev.length) return res.status(404).json({ error: 'Categoría no encontrada' })
    const prevCat = prev[0]
    const parts = []
    const vals = []
    if (activo !== undefined) {
      parts.push('activo = ?')
      vals.push(activo === true || activo === 1 || activo === '1' ? 1 : 0)
    }
    if (nombre != null && String(nombre).trim() !== '') {
      const errorNombre = validarNombreCatalogo(nombre, 'de la categoría')
      if (errorNombre) return res.status(400).json({ error: errorNombre })
      const [dupNombre] = await pool.query(
        'SELECT id FROM categorias_incidentes WHERE LOWER(nombre) = LOWER(?) AND id <> ?',
        [trunc100(nombre), id]
      )
      if (dupNombre.length) return res.status(409).json({ error: 'Ya existe una categoría con ese nombre.' })
      parts.push('nombre = ?')
      vals.push(trunc100(nombre))
    }
    if (color != null && String(color).trim() !== '') {
      const col = normalizeColor(color, '')
      if (!col) {
        return res.status(400).json({ error: 'Color inválido. Use formato HEX (#RRGGBB).' })
      }
      if (Object.prototype.hasOwnProperty.call(CATEGORY_COLOR_BY_SLUG, prevCat.slug)) {
        return res.status(403).json({ error: 'Color bloqueado para categorías base del sistema.' })
      }
      if (isCategoryColorReservedForOthers(prevCat.slug, col)) {
        return res.status(409).json({
          error: 'Color reservado del sistema. Elija otro para evitar mezclar categorías.',
        })
      }
      parts.push('color = ?')
      vals.push(col)
    }
    if (orden !== undefined && Number.isFinite(Number(orden))) {
      parts.push('orden = ?')
      vals.push(Math.floor(Number(orden)))
    }
    if (emergencia === 'Si' || emergencia === 'No') {
      parts.push('emergencia = ?')
      vals.push(emergencia)
    }
    if (parts.length === 0) {
      return res.status(400).json({ error: 'Nada que actualizar.' })
    }
    vals.push(id)
    await pool.query(
      `UPDATE categorias_incidentes SET ${parts.join(', ')} WHERE id = ?`,
      vals
    )
    res.json({ ok: true })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Error al actualizar la categoría.' })
  }
})

router.post('/tipos', requireAdmin, async (req, res) => {
  try {
    const { id_categoria, nombre, slug: slugIn, color, orden } = req.body
    const idCat = parseInt(id_categoria, 10)
    if (isNaN(idCat)) {
      return res.status(400).json({ error: 'Indique la categoría (id_categoria).' })
    }
    const errorNombre = validarNombreCatalogo(nombre, 'del tipo')
    if (errorNombre) return res.status(400).json({ error: errorNombre })
    const [c] = await pool.query('SELECT id FROM categorias_incidentes WHERE id = ?', [idCat])
    if (!c.length) {
      return res.status(400).json({ error: 'Categoría no encontrada.' })
    }
    const slug = (slugIn && String(slugIn).trim()) || slugify(nombre)
    if (!SLUG_RE.test(slug)) {
      return res.status(400).json({
        error: 'El identificador (slug) solo puede usar minúsculas, números y guion bajo.',
      })
    }
    const or = Number.isFinite(Number(orden)) ? Math.floor(Number(orden)) : 0
    const colorIn = normalizeColor(color, '')
    if (color != null && !colorIn) {
      return res.status(400).json({ error: 'Color inválido. Use formato HEX (#RRGGBB).' })
    }
    const tipoColor = CLIMA_COLOR_BY_TIPO[slug] || colorIn || null
    if (CLIMA_COLOR_BY_TIPO[slug] && colorIn && colorIn !== CLIMA_COLOR_BY_TIPO[slug]) {
      return res.status(403).json({ error: 'Color bloqueado para tipos climáticos base.' })
    }
    if (tipoColor && isTipoColorReservedForOthers(slug, tipoColor)) {
      return res.status(409).json({
        error: 'Color reservado para tipos climáticos. Elija otro color.',
      })
    }
    const [dup] = await pool.query('SELECT id FROM tipos_de_incidentes WHERE slug = ?', [slug])
    if (dup.length) {
      return res.status(409).json({ error: 'Ya existe un tipo con ese identificador.' })
    }
    const [dupNombre] = await pool.query(
      'SELECT id FROM tipos_de_incidentes WHERE id_categoria = ? AND LOWER(nombre) = LOWER(?)',
      [idCat, trunc100(nombre)]
    )
    if (dupNombre.length) {
      return res.status(409).json({ error: 'Ya existe un tipo con ese nombre en la categoría seleccionada.' })
    }
    const [r] = await pool.query(
      `INSERT INTO tipos_de_incidentes (slug, nombre, id_categoria, color, activo, orden)
       VALUES (?, ?, ?, ?, 1, ?)`,
      [slug, trunc100(nombre), idCat, tipoColor, or]
    )
    res.status(201).json({
      id: r.insertId,
      slug,
      nombre: trunc100(nombre),
      id_categoria: idCat,
      color: tipoColor,
      activo: true,
      orden: or,
    })
  } catch (err) {
    console.error(err)
    if (err && err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'Identificador duplicado.' })
    }
    res.status(500).json({ error: 'Error al crear el tipo de incidente.' })
  }
})

router.patch('/tipos/:id', requireAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10)
    if (isNaN(id)) return res.status(400).json({ error: 'Id inválido' })
    const { activo, nombre, id_categoria, color, orden } = req.body
    const [prev] = await pool.query('SELECT id, slug, color, nombre, id_categoria FROM tipos_de_incidentes WHERE id = ?', [id])
    if (!prev.length) return res.status(404).json({ error: 'Tipo no encontrado' })
    const prevTipo = prev[0]
    if (id_categoria != null) {
      const idCat = parseInt(id_categoria, 10)
      if (isNaN(idCat) || idCat < 1) {
        return res.status(400).json({ error: 'Categoría inválida.' })
      }
      const [c] = await pool.query('SELECT id FROM categorias_incidentes WHERE id = ?', [idCat])
      if (!c.length) {
        return res.status(400).json({ error: 'Categoría no encontrada.' })
      }
    }
    const parts = []
    const vals = []
    if (activo !== undefined) {
      parts.push('activo = ?')
      vals.push(activo === true || activo === 1 || activo === '1' ? 1 : 0)
    }
    if (nombre != null && String(nombre).trim() !== '') {
      const errorNombre = validarNombreCatalogo(nombre, 'del tipo')
      if (errorNombre) return res.status(400).json({ error: errorNombre })
      parts.push('nombre = ?')
      vals.push(trunc100(nombre))
    }
    if (id_categoria != null) {
      parts.push('id_categoria = ?')
      vals.push(parseInt(id_categoria, 10))
    }
    if (orden !== undefined && Number.isFinite(Number(orden))) {
      parts.push('orden = ?')
      vals.push(Math.floor(Number(orden)))
    }
    if (color != null && String(color).trim() !== '') {
      const col = normalizeColor(color, '')
      if (!col) {
        return res.status(400).json({ error: 'Color inválido. Use formato HEX (#RRGGBB).' })
      }
      if (Object.prototype.hasOwnProperty.call(CLIMA_COLOR_BY_TIPO, prevTipo.slug)) {
        return res.status(403).json({ error: 'Color bloqueado para tipos climáticos base.' })
      }
      if (isTipoColorReservedForOthers(prevTipo.slug, col)) {
        return res.status(409).json({
          error: 'Color reservado para tipos climáticos. Elija otro color.',
        })
      }
      parts.push('color = ?')
      vals.push(col)
    }
    if (nombre != null || id_categoria != null) {
      const nombreFinal = nombre != null && String(nombre).trim() !== '' ? trunc100(nombre) : prevTipo.nombre
      const idCategoriaFinal = id_categoria != null ? parseInt(id_categoria, 10) : prevTipo.id_categoria
      const [dupNombre] = await pool.query(
        'SELECT id FROM tipos_de_incidentes WHERE id_categoria = ? AND LOWER(nombre) = LOWER(?) AND id <> ?',
        [idCategoriaFinal, nombreFinal, id]
      )
      if (dupNombre.length) {
        return res.status(409).json({ error: 'Ya existe un tipo con ese nombre en la categoría seleccionada.' })
      }
    }
    if (parts.length === 0) {
      return res.status(400).json({ error: 'Nada que actualizar.' })
    }
    vals.push(id)
    await pool.query(
      `UPDATE tipos_de_incidentes SET ${parts.join(', ')} WHERE id = ?`,
      vals
    )
    res.json({ ok: true })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Error al actualizar el tipo.' })
  }
})

export default router
