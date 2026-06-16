import jwt from 'jsonwebtoken'
import pool from '../db/connection.js'

const JWT_SECRET = process.env.JWT_SECRET || 'clave_secreta_cambiar_en_produccion'

function estatusEsActivo(estatusRaw) {
  const est = String(estatusRaw || '')
    .trim()
    .toLowerCase()
  return est === 'activo' || est === 'aprobado' || est === 'pendiente'
}

function authTokenDesdeHeader(req) {
  const auth = req.headers.authorization || ''
  if (!auth.startsWith('Bearer ')) return null
  return auth.slice(7)
}

export async function requireUser(req, res, next) {
  try {
    const token = authTokenDesdeHeader(req)
    if (!token) return res.status(401).json({ error: 'Inicie sesión.' })
    const payload = jwt.verify(token, JWT_SECRET)
    const [rows] = await pool.query('SELECT id, rol, estatus FROM usuarios WHERE id = ?', [payload.id])
    if (!rows.length) return res.status(401).json({ error: 'No autorizado.' })
    const u = rows[0]
    if (!estatusEsActivo(u.estatus)) return res.status(403).json({ error: 'Usuario inactivo.' })
    req.authUser = { id: u.id, rol: u.rol }
    next()
  } catch {
    return res.status(401).json({ error: 'Token inválido o expirado.' })
  }
}

export async function requireAdmin(req, res, next) {
  try {
    const token = authTokenDesdeHeader(req)
    if (!token) return res.status(401).json({ error: 'Inicie sesión.' })
    const payload = jwt.verify(token, JWT_SECRET)
    const [rows] = await pool.query('SELECT id, rol, estatus FROM usuarios WHERE id = ?', [payload.id])
    if (!rows.length) return res.status(401).json({ error: 'No autorizado.' })
    const u = rows[0]
    if (!estatusEsActivo(u.estatus)) return res.status(403).json({ error: 'Usuario inactivo.' })
    if (u.rol !== 'admin') return res.status(403).json({ error: 'Solo administrador.' })
    req.authUser = { id: u.id, rol: u.rol }
    next()
  } catch {
    return res.status(401).json({ error: 'Token inválido o expirado.' })
  }
}
