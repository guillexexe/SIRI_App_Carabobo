import 'dotenv/config'
import readline from 'node:readline/promises'
import { stdin as input, stdout as output } from 'node:process'
import bcrypt from 'bcryptjs'
import pool from '../db/connection.js'

const SALT_ROUNDS = 10
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const cedulaRegex = /^[VJE]\d{6,9}$/
const telefonoRegex = /^04\d{9}$/

function normalizar(valor) {
  return String(valor || '').trim()
}

function normalizarCorreo(valor) {
  return normalizar(valor).toLowerCase()
}

async function preguntarObligatorio(rl, pregunta, validar, mensajeError) {
  while (true) {
    const respuesta = normalizar(await rl.question(pregunta))
    if (validar(respuesta)) return respuesta
    console.log(mensajeError)
  }
}

async function main() {
  const rl = readline.createInterface({ input, output })

  try {
    console.log('Crear o actualizar usuario administrador')
    console.log(`Base de datos: ${process.env.DB_NAME || 'proteccion_civil_carabobo'}`)
    console.log(`Servidor MySQL: ${process.env.DB_HOST || 'localhost'}`)
    console.log('')

    const nombre = await preguntarObligatorio(
      rl,
      'Nombre: ',
      (v) => v.length > 0,
      'El nombre es obligatorio.'
    )
    const apellido = await preguntarObligatorio(
      rl,
      'Apellido: ',
      (v) => v.length > 0,
      'El apellido es obligatorio.'
    )
    const correo = normalizarCorreo(
      await preguntarObligatorio(
        rl,
        'Correo: ',
        (v) => emailRegex.test(v),
        'El correo no tiene un formato válido.'
      )
    )
    const cedula = (
      await preguntarObligatorio(
        rl,
        'Cédula (ej. V12345678): ',
        (v) => cedulaRegex.test(v.replace(/\s/g, '').toUpperCase()),
        'La cédula debe comenzar por V, J o E y tener de 6 a 9 dígitos.'
      )
    )
      .replace(/\s/g, '')
      .toUpperCase()
    const telefono = (
      await preguntarObligatorio(
        rl,
        'Teléfono (ej. 04124413318): ',
        (v) => telefonoRegex.test(v.replace(/\s/g, '')),
        'El teléfono debe tener formato venezolano: 04xx + 7 dígitos.'
      )
    ).replace(/\s/g, '')
    const password = await preguntarObligatorio(
      rl,
      'Contraseña: ',
      (v) => v.length >= 6,
      'La contraseña debe tener al menos 6 caracteres.'
    )

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS)
    const [existentes] = await pool.query('SELECT id FROM usuarios WHERE correo = ?', [correo])

    if (existentes.length > 0) {
      await pool.query(
        `UPDATE usuarios
         SET nombre = ?, apellido = ?, cedula = ?, telefono = ?, rol = 'admin',
             estatus = 'aprobado', password_hash = ?
         WHERE correo = ?`,
        [nombre, apellido, cedula, telefono, passwordHash, correo]
      )
      console.log('')
      console.log(`Admin actualizado correctamente: ${correo}`)
    } else {
      await pool.query(
        `INSERT INTO usuarios
         (nombre, apellido, correo, cedula, telefono, rol, estatus, password_hash)
         VALUES (?, ?, ?, ?, ?, 'admin', 'aprobado', ?)`,
        [nombre, apellido, correo, cedula, telefono, passwordHash]
      )
      console.log('')
      console.log(`Admin creado correctamente: ${correo}`)
    }
  } finally {
    rl.close()
    await pool.end()
  }
}

main().catch((err) => {
  console.error('')
  console.error('No se pudo crear el administrador.')
  console.error(err.message)
  process.exit(1)
})
