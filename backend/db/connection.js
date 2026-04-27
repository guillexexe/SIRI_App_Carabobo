import mysql from 'mysql2/promise'

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '*hola/555/hawai*',
  database: process.env.DB_NAME || 'proteccion_civil_carabobo',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
})

export default pool
