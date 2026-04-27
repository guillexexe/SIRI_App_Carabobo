// server/routes/edan.js
import { Router } from 'express';
import pool from '../db/connection.js';

const router = Router();

router.post('/registrar', async (req, res) => {
  const connection = await pool.getConnection(); // Necesario para transacciones
  const d = req.body;
  try {
    // Verificación rápida de datos
    if (!d || Object.keys(d).length === 0) {
      return res.status(400).json({ error: "No se recibieron datos en el cuerpo de la petición" });
    }
    await connection.beginTransaction();
    // 1. Insertar en reportes_edan
    const queryEdan = `
      INSERT INTO reportes_edan (
        id_oficial, numero_planilla, propetario, p_cedula, P_edad, P_telefono,
        municipio, parroquia, sector, nro_casa, urbanizacion, direccion,
        lat, lng, nro_informe, fecha_solicitud, fecha_afectacion,
        descripcion_afectacion, tipo_afectacion, afectacion_otros,
        condicion_vivienda, tipo_vivienda, descripcion_vivienda,
        lact_Fem, lact_Masc, niños_Fem, niños_Masc, adultos_Fem, adultos_Masc,
        \`3era_edad_Fem\`, \`3era_edad_Masc\`, discapacitados, total_personas,
        nro_familias, requerimientos_afectacion, P_enseres_total,
        P_enseres_parcial, p_enseres_no, necesidades_agua,
        necesidades_alimentos, necesidades_luz
      ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`;

    const [result] = await connection.query(queryEdan, [
      d.id_oficial, d.numero_planilla, d.propetario, d.p_cedula, d.P_edad, d.P_telefono,
      d.municipio, d.parroquia, d.sector, d.nro_casa, d.urbanizacion, d.direccion,
      d.lat, d.lng, d.nro_informe, d.fecha_solicitud || null, d.fecha_afectacion || null,
      d.descripcion_afectacion, d.tipo_afectacion, d.afectacion_otros,
      d.condicion_vivienda, d.tipo_vivienda, d.descripcion_vivienda,
      d.lact_Fem, d.lact_Masc, d.niños_Fem, d.niños_Masc, d.adultos_Fem, d.adultos_Masc,
      d['3era_edad_Fem'], d['3era_edad_Masc'], d.discapacitados, d.total_personas,
      d.nro_familias, d.requerimientos_afectacion, d.P_enseres_total,
      d.P_enseres_parcial, d.p_enseres_no, d.necesidades_agua,
      d.necesidades_alimentos, d.necesidades_luz
    ]);

    const reporteId = result.insertId;

    // 2. Insertar detalles de afectados (si existen)
if (d.detalles_familiares && Array.isArray(d.detalles_familiares) && d.detalles_familiares.length > 0) {
      const valoresFamiliares = d.detalles_familiares.map(f => [
        reporteId, 
        f.nombre_completo, 
        f.cedula, 
        f.edad || 0, 
        f.genero || 'Masculino'
      ]);
      await connection.query(
        `INSERT INTO afectados_detalle (id_reporte, nombre_completo, cedula, edad, genero) VALUES ?`,
        [valoresFamiliares]
      );
    }

    await connection.commit();
    res.status(201).json({ ok: true, id: reporteId });
  } catch (err) {
    await connection.rollback();
    console.error('❌ Error detallado en EDAN:', err);
    res.status(500).json({ error: err.message });
  } finally {
    connection.release();
  }
});

export default router;