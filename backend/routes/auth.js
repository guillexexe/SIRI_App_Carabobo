import { Router } from 'express'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import pool from '../db/connection.js'

const router = Router()
const JWT_SECRET = process.env.JWT_SECRET || 'clave_secreta_cambiar_en_produccion'
const SALT_ROUNDS = 10
const MIN_PASSWORD_LENGTH = 6
const cedulaRegex = /^[VJE]\d{6,9}$/
// Móvil Venezuela: 04 + operadora (2) + 7 = 11 dígitos (ej. 04124413318)
const telefonoRegex = /^04\d{9}$/

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const nombreRegex = /^[A-Za-zÁÉÍÓÚáéíóúÑñÜü\s.'-]{2,60}$/

function estatusEsActivo(estatusRaw) {
  const est = String(estatusRaw || '')
    .trim()
    .toLowerCase()
  return est === 'activo' || est === 'aprobado' 
}

function estatusUiDesdeDb(estatusRaw, rolRaw = '') {
  const est = String(estatusRaw || '')
    .trim()
    .toLowerCase()
  const rol = String(rolRaw || '')
    .trim()
    .toLowerCase()
  if (est === 'pendiente') return 'pendiente'
  // Compatibilidad: algunos registros móviles antiguos quedaron como "inactivo".
  // Esos usuarios aún no fueron bloqueados por un administrador, por eso deben aprobarse.
  if (est === 'inactivo' && (rol === 'ciudadano' || rol === 'oficial')) return 'pendiente'
  return estatusEsActivo(est) ? 'activo' : 'inactivo'
}

function authTokenDesdeHeader(req) {
  const auth = req.headers.authorization || ''
  if (!auth.startsWith('Bearer ')) return null
  return auth.slice(7)
}

/** Bearer JWT: expone `req.userId` para rutas protegidas (app móvil). */
export function verifyToken(req, res, next) {
  const token = authTokenDesdeHeader(req)
  if (!token) {
    return res.status(401).json({ error: 'Token no proporcionado.' })
  }
  try {
    const decoded = jwt.verify(token, JWT_SECRET)
    const id = decoded?.id
    if (id == null || !Number.isFinite(Number(id))) {
      return res.status(403).json({ error: 'Token inválido o expirado.' })
    }
    req.userId = Number(id)
    next()
  } catch {
    return res.status(403).json({ error: 'Token inválido o expirado.' })
  }
}

/** La app puede enviar "civil"; en BD el rol es `ciudadano`. No se permite alta como admin por esta vía. */
function rolDesdeApp(rolRaw) {
  const r = String(rolRaw ?? '')
    .trim()
    .toLowerCase()
  if (r === 'civil' || r === 'ciudadano' || r === '') return 'ciudadano'
  if (r === 'oficial') return 'oficial'
  return 'ciudadano'
}

async function requireAdmin(req, res, next) {
  try {
    const token = authTokenDesdeHeader(req)
    if (!token) return res.status(401).json({ error: 'No autorizado.' })
    const payload = jwt.verify(token, JWT_SECRET)
    const [rows] = await pool.query('SELECT id, rol, estatus FROM usuarios WHERE id = ?', [payload.id])
    if (!rows.length) return res.status(401).json({ error: 'No autorizado.' })
    const u = rows[0]
    if (!estatusEsActivo(u.estatus)) return res.status(403).json({ error: 'Usuario inactivo.' })
    if (u.rol !== 'admin') return res.status(403).json({ error: 'Acceso solo para administrador.' })
    req.authUser = { id: u.id, rol: u.rol }
    next()
  } catch {
    return res.status(401).json({ error: 'Token inválido o expirado.' })
  }
}

function validarRegistro(body) {
  const errores = []
  const { nombre, apellido, correo, cedula, telefono, password, confirmacion } = body

  if (!nombre || !nombre.toString().trim()) errores.push('El nombre es requerido.')
  else if (!nombreRegex.test(nombre.toString().trim())) errores.push('El nombre solo debe contener letras y tener entre 2 y 60 caracteres.')
  if (!apellido || !apellido.toString().trim()) errores.push('El apellido es requerido.')
  else if (!nombreRegex.test(apellido.toString().trim())) errores.push('El apellido solo debe contener letras y tener entre 2 y 60 caracteres.')
  if (!correo || !correo.toString().trim()) errores.push('El correo es requerido.')
  else if (!emailRegex.test(correo)) errores.push('El correo no tiene un formato válido.')
  if (!cedula || !cedula.toString().trim()) errores.push('La cédula es requerida.')
  else {
    const c = cedula.toString().replace(/\s/g, '').toUpperCase()
    if (!cedulaRegex.test(c)) errores.push('La cédula debe ser tipo V, J o E seguido de 6 a 9 dígitos.')
  }
  if (!telefono || !telefono.toString().trim()) errores.push('El teléfono es requerido.')
  else {
    const t = telefono.toString().replace(/\s/g, '')
    if (!telefonoRegex.test(t)) {
      errores.push('El teléfono debe ser móvil Venezuela: 04xx más 7 dígitos (11 en total, ej. 04124413318).')
    }
  }
  if (!password || !password.toString()) errores.push('La contraseña es requerida.')
  else if (password.length < MIN_PASSWORD_LENGTH) errores.push(`La contraseña debe tener al menos ${MIN_PASSWORD_LENGTH} caracteres.`)
  if (!confirmacion || confirmacion !== password) errores.push('La confirmación de contraseña no coincide.')

  return errores
}

router.post('/registro', requireAdmin, async (req, res) => {
  try {
    const errores = validarRegistro(req.body)
    if (errores.length > 0) {
      return res.status(400).json({ error: errores.join(' ') })
    }

    const nombre = req.body.nombre.toString().trim()
    const apellido = req.body.apellido.toString().trim()
    const correo = req.body.correo.toString().trim().toLowerCase()
    const cedula = req.body.cedula.toString().replace(/\s/g, '').toUpperCase()
    const telefono = req.body.telefono.toString().replace(/\s/g, '')
    const password = req.body.password
    // Registro web (solo admin): siempre oficial. Civil/oficial vía app móvil, más adelante.
    const rol = 'oficial'

    const [existingEmail] = await pool.query('SELECT id FROM usuarios WHERE correo = ?', [correo])
    if (existingEmail.length > 0) {
      return res.status(400).json({ error: 'Ya existe un usuario con ese correo electrónico.' })
    }
    const [existingCedula] = await pool.query('SELECT id FROM usuarios WHERE cedula = ?', [cedula])
    if (existingCedula.length > 0) {
      return res.status(400).json({ error: 'Ya existe un usuario con ese número de cédula.' })
    }

    const password_hash = await bcrypt.hash(password, SALT_ROUNDS)
    await pool.query(
      `INSERT INTO usuarios
       (nombre, apellido, correo, cedula, telefono, rol, estatus, password_hash)
       VALUES (?, ?, ?, ?, ?, ?, 'aprobado', ?)`,
      [nombre, apellido, correo, cedula, telefono, rol, password_hash]
    )
    res.status(201).json({ message: 'Usuario registrado correctamente.' })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Error al registrar el usuario.' })
  }
})

router.get('/usuarios', requireAdmin, async (req, res) => {
  try {
    const estatus = String(req.query.estatus || 'activo').toLowerCase()
    let sql =
      'SELECT id, nombre, apellido, correo, cedula, telefono, rol, estatus, motivo_bloqueo, created_at FROM usuarios'
    const params = []
    if (estatus === 'activo') {
      sql += " WHERE estatus IN ('activo', 'aprobado')"
    } else if (estatus === 'inactivo') {
      sql += " WHERE estatus = 'bloqueado'"
    } else if (estatus === 'pendiente') {
      sql += " WHERE rol IN ('ciudadano', 'oficial') AND estatus IN ('pendiente', 'inactivo')"
    }
    sql += ' ORDER BY created_at DESC'
    const [rows] = await pool.query(sql, params)
    res.json(
      rows.map((u) => ({
        ...u,
        estatus: estatusUiDesdeDb(u.estatus, u.rol),
      }))
    )
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Error al consultar usuarios.' })
  }
})

router.patch('/usuarios/:id/estatus', requireAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10)
    if (isNaN(id)) return res.status(400).json({ error: 'Id inválido.' })
    const estatus = String(req.body.estatus || '').toLowerCase()
    if (estatus !== 'activo' && estatus !== 'inactivo') {
      return res.status(400).json({ error: 'Estatus inválido. Debe ser activo o inactivo.' })
    }
    const motivoBloqueo = String(req.body.motivo_bloqueo || '').trim()
    if (estatus === 'inactivo' && !motivoBloqueo) {
      return res.status(400).json({ error: 'Debe indicar el motivo del bloqueo.' })
    }
    if (motivoBloqueo.length > 1000) {
      return res.status(400).json({ error: 'El motivo del bloqueo no puede superar 1000 caracteres.' })
    }
    if (id === req.authUser.id) {
      return res.status(400).json({ error: 'No puede cambiar su propio estatus.' })
    }
    const estatusDb = estatus === 'activo' ? 'aprobado' : 'bloqueado'
    const [result] = await pool.query(
      'UPDATE usuarios SET estatus = ?, motivo_bloqueo = ? WHERE id = ?',
      [estatusDb, estatus === 'inactivo' ? motivoBloqueo : null, id]
    )
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado.' })
    }
    res.json({ ok: true })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Error al actualizar estatus del usuario.' })
  }
})

/** Registro desde app móvil (sin sesión admin). Usuario queda `pendiente` hasta aprobación. */
router.post('/register-app', async (req, res) => {
  try {
    const { nombre, apellido, correo, cedula, telefono, password, rol } = req.body

    if (!nombre || !String(nombre).trim()) {
      return res.status(400).json({ error: 'El nombre es requerido.' })
    }
    if (!nombreRegex.test(String(nombre).trim())) {
      return res.status(400).json({ error: 'El nombre solo debe contener letras y tener entre 2 y 60 caracteres.' })
    }
    if (!apellido || !String(apellido).trim()) {
      return res.status(400).json({ error: 'El apellido es requerido.' })
    }
    if (!nombreRegex.test(String(apellido).trim())) {
      return res.status(400).json({ error: 'El apellido solo debe contener letras y tener entre 2 y 60 caracteres.' })
    }
    if (!correo || !password || !cedula || !telefono) {
      return res.status(400).json({
        error: 'Faltan campos obligatorios (correo, cédula, teléfono o contraseña).',
      })
    }

    const correoNorm = correo.toString().trim().toLowerCase()
    if (!emailRegex.test(correoNorm)) {
      return res.status(400).json({ error: 'El correo no tiene un formato válido.' })
    }

    const cedulaNorm = cedula.toString().replace(/\s/g, '').toUpperCase()
    if (!cedulaRegex.test(cedulaNorm)) {
      return res.status(400).json({
        error: 'La cédula debe ser tipo V, J o E seguido de 6 a 9 dígitos.',
      })
    }

    const telNorm = telefono.toString().replace(/\s/g, '')
    if (!telefonoRegex.test(telNorm)) {
      return res.status(400).json({
        error:
          'El teléfono debe ser móvil Venezuela: 04xx más 7 dígitos (11 dígitos en total).',
      })
    }

    if (String(password).length < MIN_PASSWORD_LENGTH) {
      return res.status(400).json({
        error: `La contraseña debe tener al menos ${MIN_PASSWORD_LENGTH} caracteres.`,
      })
    }

    const [existe] = await pool.query(
      'SELECT id FROM usuarios WHERE correo = ? OR cedula = ?',
      [correoNorm, cedulaNorm]
    )
    if (existe.length > 0) {
      return res.status(400).json({ error: 'El correo o la cédula ya están registrados.' })
    }

    const [telDup] = await pool.query('SELECT id FROM usuarios WHERE telefono = ?', [telNorm])
    if (telDup.length > 0) {
      return res.status(400).json({ error: 'Ya existe un usuario con ese número de teléfono.' })
    }

    const rolDb = rolDesdeApp(rol)
    const password_hash = await bcrypt.hash(password, SALT_ROUNDS)

    await pool.query(
      `INSERT INTO usuarios
       (nombre, apellido, correo, cedula, telefono, rol, estatus, password_hash)
       VALUES (?, ?, ?, ?, ?, ?, 'pendiente', ?)`,
      [
        nombre.toString().trim(),
        apellido.toString().trim(),
        correoNorm,
        cedulaNorm,
        telNorm,
        rolDb,
        password_hash,
      ]
    )

    res.status(201).json({ ok: true, message: 'Usuario de la App registrado con éxito.' })
  } catch (err) {
    console.error('Error en register-app:', err)
    res.status(500).json({ error: 'Error interno del servidor.' })
  }
})

router.post('/login', async (req, res) => {
  try {
    const { correo, password } = req.body
    if (!correo || !password) {
      return res.status(400).json({ error: 'Correo y contraseña son requeridos.' })
    }
    const correoNorm = correo.toString().trim().toLowerCase()
    if (!emailRegex.test(correoNorm)) {
      return res.status(400).json({ error: 'El correo no tiene un formato válido.' })
    }

    const [rows] = await pool.query(
      `SELECT id, nombre, apellido, correo, cedula, telefono, rol, estatus, password_hash
       FROM usuarios WHERE correo = ?`,
      [correoNorm]
    )
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Credenciales incorrectas.' })
    }
    const user = rows[0]
    if (!estatusEsActivo(user.estatus)) {
      return res.status(403).json({ error: 'Usuario inactivo. Contacte al administrador.' })
    }
    const match = await bcrypt.compare(password, user.password_hash)
    if (!match) {
      return res.status(401).json({ error: 'Credenciales incorrectas.' })
    }

    const token = jwt.sign(
      { id: user.id, correo: user.correo },
      JWT_SECRET,
      { expiresIn: '7d' }
    )
    res.json({
      token,
      usuario: {
        id: user.id,
        nombre: user.nombre,
        apellido: user.apellido,
        correo: user.correo,
        cedula: user.cedula,
        telefono: user.telefono,
        rol: user.rol,
        estatus: estatusUiDesdeDb(user.estatus, user.rol),
      },
    })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Error al iniciar sesión.' })
  }
})

router.put('/update-profile', verifyToken, async (req, res) => {
  const { nombre, apellido, telefono } = req.body
  const id = req.userId

  if (!nombre || !String(nombre).trim() || !apellido || !String(apellido).trim()) {
    return res.status(400).json({ error: 'Nombre y apellido son requeridos.' })
  }
  const telNorm =
    telefono != null && String(telefono).trim()
      ? String(telefono).replace(/\s/g, '')
      : null
  if (!telNorm || !telefonoRegex.test(telNorm)) {
    return res.status(400).json({
      error:
        'El teléfono debe ser móvil Venezuela: 04xx más 7 dígitos (11 dígitos en total).',
    })
  }

  try {
    const [otros] = await pool.query(
      'SELECT id FROM usuarios WHERE telefono = ? AND id <> ?',
      [telNorm, id]
    )
    if (otros.length > 0) {
      return res.status(400).json({ error: 'Ese número de teléfono ya está en uso.' })
    }

    await pool.query(
      'UPDATE usuarios SET nombre = ?, apellido = ?, telefono = ? WHERE id = ?',
      [nombre.toString().trim(), apellido.toString().trim(), telNorm, id]
    )
    res.json({ ok: true, message: 'Perfil actualizado correctamente' })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Error al actualizar el perfil' })
  }
})

router.put('/change-password', verifyToken, async (req, res) => {
  const { currentPassword, newPassword } = req.body
  const userId = req.userId

  if (
    currentPassword == null ||
    String(currentPassword).length === 0 ||
    newPassword == null ||
    String(newPassword).length < MIN_PASSWORD_LENGTH
  ) {
    return res.status(400).json({
      error: `Contraseña actual y nueva contraseña (mínimo ${MIN_PASSWORD_LENGTH} caracteres).`,
    })
  }

  try {
    const [rows] = await pool.query('SELECT password_hash FROM usuarios WHERE id = ?', [
      userId,
    ])
    if (rows.length === 0) return res.status(404).json({ error: 'Usuario no encontrado' })

    const match = await bcrypt.compare(currentPassword, rows[0].password_hash)
    if (!match) return res.status(401).json({ error: 'La contraseña actual es incorrecta' })

    const newHash = await bcrypt.hash(newPassword, SALT_ROUNDS)
    await pool.query('UPDATE usuarios SET password_hash = ? WHERE id = ?', [newHash, userId])

    res.json({ ok: true, message: 'Contraseña actualizada con éxito' })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Error interno del servidor' })
  }
})

// CONFIGURACIÓN DE NODEMAILER PARA RECUPERACIÓN DE CONTRASEÑA
import nodemailer from 'nodemailer'

const getMailTransporter = () => {
  const host = process.env.SMTP_HOST || 'smtp.gmail.com'
  const port = parseInt(process.env.SMTP_PORT || '465', 10)
  const user = process.env.SMTP_USER || 'prueba1@gmail.com'
  const pass = process.env.SMTP_PASS || ''
  const secure = process.env.SMTP_SECURE === 'false' ? false : true

  return nodemailer.createTransport({
    host,
    port,
    secure,
    auth: {
      user,
      pass
    }
  })
}

// 1. SOLICITAR CÓDIGO DE RECUPERACIÓN
router.post('/solicitar-codigo', async (req, res) => {
  try {
    const { correo } = req.body
    if (!correo) {
      return res.status(400).json({ error: 'El correo electrónico es requerido.' })
    }
    const correoNorm = correo.toString().trim().toLowerCase()
    if (!emailRegex.test(correoNorm)) {
      return res.status(400).json({ error: 'El correo electrónico no tiene un formato válido.' })
    }

    // Buscar si existe el usuario
    const [usuarios] = await pool.query('SELECT id, nombre, apellido FROM usuarios WHERE correo = ?', [correoNorm])
    if (usuarios.length === 0) {
      // Por seguridad, para evitar enumeración de usuarios, devolvemos un mensaje genérico de éxito,
      // pero en este caso de Protección Civil podemos ser más directos.
      return res.status(404).json({ error: 'No existe ningún usuario registrado con ese correo.' })
    }

    const usuario = usuarios[0]
    // Generar código numérico aleatorio de 6 dígitos
    const codigo = Math.floor(100000 + Math.random() * 900000).toString()
    // Expiración en 15 minutos (900,000 milisegundos)
    const expiracion = new Date(Date.now() + 15 * 60 * 1000)

    // Guardar el código y la expiración en la base de datos
    await pool.query(
      'UPDATE usuarios SET codigo_recuperacion = ?, expiracion_codigo = ? WHERE id = ?',
      [codigo, expiracion, usuario.id]
    )

    // Enviar el correo
    const transporter = getMailTransporter()
    const mailOptions = {
      from: `"Protección Civil Carabobo" <${process.env.SMTP_USER || 'no-reply@proteccioncivil.gob.ve'}>`,
      to: correoNorm,
      subject: 'Código de Recuperación de Contraseña — Protección Civil',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #dde5ef; border-radius: 8px; background-color: #f2f6fb;">
          <h2 style="color: #0033CC; text-align: center;">Protección Civil Carabobo</h2>
          <p>Hola <strong>${usuario.nombre} ${usuario.apellido}</strong>,</p>
          <p>Hemos recibido una solicitud para restablecer la contraseña de acceso a tu cuenta.</p>
          <div style="background-color: #ffffff; border: 2px dashed #FF8000; padding: 15px; text-align: center; margin: 20px 0; border-radius: 8px;">
            <p style="font-size: 14px; margin: 0; color: #4a4a55;">Tu código de verificación de 6 dígitos es:</p>
            <h1 style="font-size: 36px; margin: 10px 0; color: #800000; letter-spacing: 5px;">${codigo}</h1>
            <p style="font-size: 12px; margin: 0; color: #800000;">Este código expirará en 15 minutos.</p>
          </div>
          <p style="font-size: 13px; color: #4a4a55;">Si no has solicitado este cambio, por favor ignora este correo electrónico.</p>
          <hr style="border: 0; border-top: 1px solid #dde5ef; margin: 20px 0;" />
          <p style="font-size: 11px; color: #854d0e; text-align: center;">Sistema de Emergencias e Incidentes — Estado Carabobo</p>
        </div>
      `
    }

    await transporter.sendMail(mailOptions)

    res.json({ ok: true, message: 'Código de recuperación enviado con éxito a su correo.' })
  } catch (err) {
    console.error('Error al solicitar código de recuperación:', err)
    res.status(500).json({ error: 'Error al enviar el correo de recuperación. Verifique la configuración del servidor SMTP.' })
  }
})

// 2. VERIFICAR CÓDIGO Y ESTABLECER NUEVA CONTRASEÑA
router.post('/cambiar-password', async (req, res) => {
  try {
    const { correo, codigo, password } = req.body

    if (!correo || !codigo || !password) {
      return res.status(400).json({ error: 'El correo, el código de verificación y la nueva contraseña son requeridos.' })
    }

    const correoNorm = correo.toString().trim().toLowerCase()
    const codigoNorm = codigo.toString().trim()

    if (password.length < MIN_PASSWORD_LENGTH) {
      return res.status(400).json({ error: `La contraseña debe tener al menos ${MIN_PASSWORD_LENGTH} caracteres.` })
    }

    // Buscar al usuario que tenga el código y que no haya expirado
    const [usuarios] = await pool.query(
      'SELECT id, codigo_recuperacion, expiracion_codigo FROM usuarios WHERE correo = ?',
      [correoNorm]
    )

    if (usuarios.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado.' })
    }

    const usuario = usuarios[0]

    // Validar el código de recuperación
    if (!usuario.codigo_recuperacion || usuario.codigo_recuperacion !== codigoNorm) {
      return res.status(400).json({ error: 'El código de verificación es incorrecto.' })
    }

    // Validar expiración
    const ahora = new Date()
    const expiracion = new Date(usuario.expiracion_codigo)
    if (ahora > expiracion) {
      return res.status(400).json({ error: 'El código de verificación ha expirado. Por favor, solicite uno nuevo.' })
    }

    // Todo correcto: Encriptar nueva contraseña y actualizar
    const password_hash = await bcrypt.hash(password, SALT_ROUNDS)
    await pool.query(
      'UPDATE usuarios SET password_hash = ?, codigo_recuperacion = NULL, expiracion_codigo = NULL WHERE id = ?',
      [password_hash, usuario.id]
    )

    res.json({ ok: true, message: 'Su contraseña ha sido restablecida con éxito.' })
  } catch (err) {
    console.error('Error al restablecer contraseña:', err)
    res.status(500).json({ error: 'Error interno del servidor al intentar cambiar la contraseña.' })
  }
})

export default router

