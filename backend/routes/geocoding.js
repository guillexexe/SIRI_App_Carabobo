import { Router } from 'express'
import { buscarLugar, reverseMunicipioCarabobo } from '../services/geocoding.js'

const router = Router()

router.get('/reverse', async (req, res) => {
  const lat = req.query.lat
  const lng = req.query.lng
  if (lat == null || lng == null || String(lat).trim() === '' || String(lng).trim() === '') {
    return res.status(400).json({ ok: false, error: 'Faltan lat y lng.' })
  }
  try {
    const out = await reverseMunicipioCarabobo(lat, lng)
    return res.json({ ok: true, ...out })
  } catch (err) {
    console.error('[geocoding reverse]', err)
    return res.status(502).json({ ok: false, error: 'No se pudo obtener el municipio.' })
  }
})

router.get('/', async (req, res) => {
  const q = req.query.q
  if (q == null || String(q).trim() === '') {
    return res.status(400).json({ ok: false, error: 'Falta el parámetro de búsqueda (q).' })
  }
  try {
    const result = await buscarLugar(String(q))
    return res.json({ ok: true, result })
  } catch (err) {
    console.error('[geocoding]', err)
    return res.status(502).json({ ok: false, error: 'No se pudo contactar el servicio de mapas.' })
  }
})

export default router
