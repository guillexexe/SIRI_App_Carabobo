# Backend — Protección Civil Carabobo

API REST (Node.js + Express + MySQL) para la gestión de incidentes.

## Requisitos

- Node.js 18+
- MySQL (XAMPP o instalación independiente)

## 1. Base de datos MySQL

En phpMyAdmin (XAMPP) o en la consola de MySQL, ejecuta el script:

```
backend/db/proteccion_civil_carabobo.sql
```

Crea la base de datos `proteccion_civil_carabobo` y las tablas principales del sistema.

> Importante: este script hace `DROP DATABASE` y reemplaza por completo la base. Si ya tienes datos, respáldalos antes.

## 2. Configuración

Copia el archivo de ejemplo y ajusta los valores si es necesario:

```
cp .env.example .env
```

En `.env`:

- `PORT=3000` — Puerto del servidor
- `DB_HOST=localhost`
- `DB_USER=root`
- `DB_PASSWORD=` — Contraseña de MySQL (vacía por defecto en XAMPP)
- `DB_NAME=proteccion_civil_carabobo`

## 3. Instalar y ejecutar

```bash
cd backend
npm install
npm run dev
```

El servidor quedará en **http://localhost:3000**. El frontend (Vue en puerto 5173) consumirá `http://localhost:3000/api/incidentes`.

## Endpoints

- `GET /api/incidentes` — Lista todos los incidentes
- `POST /api/incidentes` — Crea un incidente (body JSON: tipo, tipo_nombre, categoria, descripcion, lat, lng, municipio, fecha)
