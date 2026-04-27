const PHOTON_URL = 'https://photon.komoot.io/api/'
const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search'
const NOMINATIM_REVERSE_URL = 'https://nominatim.openstreetmap.org/reverse'

const MUNICIPIOS_CARABOBO_ORDENADOS = [
  'Juan José Mora',
  'Puerto Cabello',
  'Diego Ibarra',
  'Carlos Arvelo',
  'Naguanagua',
  'Montalbán',
  'Miranda',
  'Guacara',
  'Mariara',
  'Bejuma',
  'San Diego',
  'Valencia',
].map((m) => m)

function enriquecerConsulta(texto) {
  const t = texto.trim()
  if (!t) return t
  const lower = t.toLowerCase()
  if (lower.includes('venezuela') || lower.includes('carabobo')) return t
  return `${t}, Carabobo, Venezuela`
}

function zoomDesdePropiedades(props) {
  if (!props) return 14
  const tipo = props.type
  const osm = props.osm_value || ''
  if (tipo === 'house' || osm === 'house' || osm === 'building') return 17
  if (tipo === 'street' || osm === 'residential' || osm === 'road') return 16
  if (tipo === 'district_town' || tipo === 'district' || tipo === 'locality' || osm === 'suburb' || osm === 'neighbourhood') {
    return 15
  }
  if (tipo === 'city' || tipo === 'town' || osm === 'city' || osm === 'town') return 12
  if (tipo === 'state' || osm === 'state') return 10
  return 13
}

function parsearFeaturePhoton(mejor, consultaUsuario) {
  const props = mejor.properties || {}
  const geom = mejor.geometry
  if (!geom || !geom.coordinates) return null

  let lng
  let lat
  if (geom.type === 'Point') {
    ;[lng, lat] = geom.coordinates
  } else if (geom.type === 'Polygon' && geom.coordinates && geom.coordinates[0]) {
    const ring = geom.coordinates[0]
    let sumLat = 0
    let sumLng = 0
    const n = Math.max(0, ring.length - 1)
    for (let j = 0; j < n; j++) {
      sumLng += ring[j][0]
      sumLat += ring[j][1]
    }
    if (n < 1) return null
    lng = sumLng / n
    lat = sumLat / n
  } else {
    return null
  }

  let bounds = null
  if (props.extent && Array.isArray(props.extent) && props.extent.length === 4) {
    const [minLon, minLat, maxLon, maxLat] = props.extent
    bounds = [
      [minLat, minLon],
      [maxLat, maxLon],
    ]
  }

  const partes = [props.name, props.city || props.town, props.state, props.country].filter(Boolean)
  const label = partes.length ? partes.join(', ') : consultaUsuario

  return {
    lat,
    lng,
    zoom: zoomDesdePropiedades(props),
    bounds,
    label,
  }
}

async function buscarPhoton(consultaUsuario) {
  const q = consultaUsuario.trim()
  const params = new URLSearchParams({
    q: enriquecerConsulta(q),
    lang: 'es',
    limit: '8',
  })
  const res = await fetch(`${PHOTON_URL}?${params.toString()}`, {
    headers: { Accept: 'application/json' },
  })
  if (!res.ok) return null
  const data = await res.json()
  const features = data.features
  if (!features || features.length === 0) return null

  const enCarabobo = (f) => {
    const p = f.properties || {}
    const st = (p.state || '').toLowerCase()
    const county = (p.county || '').toLowerCase()
    return st.includes('carabobo') || county.includes('carabobo')
  }

  const mejor = features.find(enCarabobo) || features[0]
  return parsearFeaturePhoton(mejor, consultaUsuario)
}

function zoomDesdeTipoNominatim(tipo, clase) {
  const t = (tipo || '').toLowerCase()
  const c = (clase || '').toLowerCase()
  if (t === 'house' || c === 'building') return 17
  if (t === 'road' || t === 'residential') return 16
  if (t === 'neighbourhood' || t === 'suburb' || t === 'quarter') return 15
  if (t === 'city' || t === 'town' || t === 'municipality') return 12
  if (t === 'state' || t === 'region') return 10
  return 13
}

async function buscarNominatim(consultaUsuario) {
  const q = consultaUsuario.trim()
  const params = new URLSearchParams({
    format: 'json',
    q: enriquecerConsulta(q),
    limit: '6',
    countrycodes: 've',
    'accept-language': 'es',
  })
  const res = await fetch(`${NOMINATIM_URL}?${params.toString()}`, {
    headers: {
      Accept: 'application/json',
      'User-Agent': 'ProteccionCivilCarabobo/1.0 (sistema-interno; contacto=admin@local)',
    },
  })
  if (!res.ok) return null
  const rows = await res.json()
  if (!Array.isArray(rows) || rows.length === 0) return null

  const pref = rows.find((r) => {
    const dn = ((r.display_name || '') + (r.address?.state || '')).toLowerCase()
    return dn.includes('carabobo')
  })
  const item = pref || rows[0]

  const lat = parseFloat(item.lat)
  const lon = parseFloat(item.lon)
  if (Number.isNaN(lat) || Number.isNaN(lon)) return null

  let bounds = null
  const bb = item.boundingbox
  if (bb && bb.length >= 4) {
    const south = parseFloat(bb[0])
    const north = parseFloat(bb[1])
    const west = parseFloat(bb[2])
    const east = parseFloat(bb[3])
    if (!Number.isNaN(south) && !Number.isNaN(north) && !Number.isNaN(west) && !Number.isNaN(east)) {
      bounds = [
        [south, west],
        [north, east],
      ]
    }
  }

  return {
    lat,
    lng: lon,
    zoom: zoomDesdeTipoNominatim(item.type, item.class),
    bounds,
    label: item.display_name || consultaUsuario,
  }
}

function textoNormalizado(s) {
  if (s == null || s === '') return ''
  return String(s)
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
}

function viaDesdeAddressNominatim(address) {
  if (!address || typeof address !== 'object') return ''
  const partes = []
  const num = address.house_number
  const road =
    address.road ||
    address.pedestrian ||
    address.footway ||
    address.path ||
    address.cycleway ||
    address.residential ||
    address.living_street ||
    address.unclassified ||
    address.service ||
    address.tertiary ||
    address.secondary ||
    address.primary ||
    address.trunk ||
    address.track
  if (road) {
    partes.push([num, road].filter(Boolean).join(' ').trim())
  }
  const barrio =
    address.suburb ||
    address.neighbourhood ||
    address.quarter ||
    address.hamlet
  if (barrio) partes.push(barrio)
  return partes.filter(Boolean).join(', ').trim()
}

function municipioDesdeAddressNominatim(address, displayName) {
  const partes = []
  if (displayName) partes.push(displayName)
  if (address && typeof address === 'object') {
    const keys = [
      'city',
      'town',
      'village',
      'municipality',
      'county',
      'state_district',
      'suburb',
      'neighbourhood',
      'quarter',
    ]
    for (const k of keys) {
      if (address[k]) partes.push(address[k])
    }
  }
  const blob = textoNormalizado(partes.join(' '))
  if (!blob) return null
  for (const mun of MUNICIPIOS_CARABOBO_ORDENADOS) {
    const n = textoNormalizado(mun)
    if (n && blob.includes(n)) return mun
  }
  return null
}

const PHOTON_REVERSE_URL = 'https://photon.komoot.io/reverse'

async function reversePhoton(lat, lng) {
  const params = new URLSearchParams({
    lat: String(lat),
    lon: String(lng),
    lang: 'es',
  })
  const res = await fetch(`${PHOTON_REVERSE_URL}?${params.toString()}`, {
    headers: { Accept: 'application/json' },
  })
  if (!res.ok) return null
  const data = await res.json()
  const f = data.features && data.features[0]
  if (!f || !f.properties) return null
  const p = f.properties
  const fakeAddr = {
    city: p.city || p.name,
    town: p.district || p.locality,
    county: p.county,
    state: p.state,
  }
  const display = [p.name, p.street, p.city, p.state, p.country].filter(Boolean).join(', ')
  const municipio = municipioDesdeAddressNominatim(fakeAddr, display)
  let via = ''
  if (p.street) via = [p.housenumber, p.street].filter(Boolean).join(' ').trim()
  else if (p.name && (p.osm_value === 'residential' || p.type === 'street' || p.osm_key === 'highway')) {
    via = String(p.name)
  } else if (p.name && String(p.type || '').toLowerCase() === 'street') {
    via = String(p.name)
  }
  return { municipio: municipio || null, via, display_name: display }
}

async function reverseNominatim(lat, lng) {
  const params = new URLSearchParams({
    format: 'json',
    lat: String(lat),
    lon: String(lng),
    'accept-language': 'es',
    zoom: '18',
    addressdetails: '1',
  })
  const res = await fetch(`${NOMINATIM_REVERSE_URL}?${params.toString()}`, {
    headers: {
      Accept: 'application/json',
      'User-Agent': 'ProteccionCivilCarabobo/1.0 (sistema-interno; contacto=admin@local)',
    },
  })
  if (!res.ok) return null
  const data = await res.json()
  if (!data || data.error) return null
  const via = viaDesdeAddressNominatim(data.address)
  const mun = municipioDesdeAddressNominatim(data.address, data.display_name)
  return {
    municipio: mun,
    via: via || '',
    display_name: data.display_name || '',
  }
}

function primeraParteUtilDisplayName(displayName, municipioResuelto) {
  if (!displayName || typeof displayName !== 'string') return ''
  const primera = displayName.split(',')[0].trim()
  if (!primera) return ''
  const blob = textoNormalizado(displayName)
  const mNorm = municipioResuelto ? textoNormalizado(municipioResuelto) : ''
  if (mNorm && blob.startsWith(mNorm + ',')) {
    const resto = displayName.slice(displayName.indexOf(',') + 1).trim()
    const segunda = resto.split(',')[0].trim()
    return segunda || ''
  }
  const pNorm = textoNormalizado(primera)
  if (mNorm && pNorm === mNorm) return ''
  for (const mun of MUNICIPIOS_CARABOBO_ORDENADOS) {
    if (pNorm === textoNormalizado(mun)) return ''
  }
  return primera.length > 500 ? primera.slice(0, 500) : primera
}

export async function reverseMunicipioCarabobo(lat, lng) {
  const la = Number(lat)
  const lo = Number(lng)
  if (Number.isNaN(la) || Number.isNaN(lo)) {
    return { municipio: null, via: '', display_name: '' }
  }

  let nominatim = null
  let photon = null

  try {
    nominatim = await reverseNominatim(la, lo)
  } catch (e) {
    console.warn('[geocoding] reverse Nominatim:', e.message)
  }

  try {
    photon = await reversePhoton(la, lo)
  } catch (e) {
    console.warn('[geocoding] reverse Photon:', e.message)
  }

  const municipio = nominatim?.municipio || photon?.municipio || null
  let via = (nominatim?.via && String(nominatim.via).trim()) || (photon?.via && String(photon.via).trim()) || ''
  let display_name = nominatim?.display_name || photon?.display_name || ''

  if (!via && display_name) {
    const fallback = primeraParteUtilDisplayName(display_name, municipio)
    if (fallback) via = fallback
  }

  if (!municipio && !via && !display_name) {
    return { municipio: null, via: '', display_name: '' }
  }

  return { municipio: municipio || null, via: via || '', display_name: display_name || '' }
}

export async function buscarLugar(consultaUsuario) {
  const q = consultaUsuario.trim()
  if (!q) return null

  try {
    const r1 = await buscarPhoton(q)
    if (r1) return r1
  } catch (e) {
    console.warn('[geocoding] Photon:', e.message)
  }

  try {
    const r2 = await buscarNominatim(q)
    if (r2) return r2
  } catch (e) {
    console.warn('[geocoding] Nominatim:', e.message)
  }

  return null
}
