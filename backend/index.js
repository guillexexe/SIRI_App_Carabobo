import 'dotenv/config'
import express from 'express'
import cors from 'cors'
import incidentesRouter from './routes/incidentes.js'
import authRouter from './routes/auth.js'
import geocodingRouter from './routes/geocoding.js'
import { ensureIncidentesSchema, ensureCatalogoEstructura } from './db/ensureSchema.js'
import catalogoRouter from './routes/catalogo.js'
import edanRoutes from './routes/edan.js'

const app = express()
const PORT = process.env.PORT || 3000

/* origin: true refleja el Origin (localhost:5000, etc.) y responde al preflight OPTIONS */
app.use(
  cors({
    origin: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  })
)
app.use(express.json())

app.use('/api/incidentes', incidentesRouter)
app.use('/api/auth', authRouter)
app.use('/api/geocoding', geocodingRouter)
app.use('/api/catalogo', catalogoRouter)
app.use('/api/edan', edanRoutes)

app.get('/api/health', (req, res) => res.json({ ok: true }))

try {
  await ensureIncidentesSchema()
  await ensureCatalogoEstructura()
} catch {
  console.error('Revise la conexión a MySQL y que exista la base de datos.')
  process.exit(1)
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor en http://localhost:${PORT}`)
})