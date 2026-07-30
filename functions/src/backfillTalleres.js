// Relleno puntual: proyecta a `talleres` los mecanicos ya existentes.
// Ejecutar UNA vez con: node functions/src/backfillTalleres.js
const admin = require('firebase-admin');
admin.initializeApp();

const CAMPOS_PUBLICOS = [
  'nombre', 'especialidad', 'ubicacion', 'direccion', 'foto_url',
  'calificacion_promedio', 'total_resenias', 'estado',
];

const MAX_POR_BATCH = 500;

(async () => {
  const db = admin.firestore();
  const snap = await db.collection('usuarios').get();
  const refs = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    const rol = String(d.rol || '').trim().toLowerCase();
    if (rol !== 'mecanico' && rol !== 'taller') continue;
    const perfil = { id_taller: doc.id };
    for (const c of CAMPOS_PUBLICOS) if (d[c] !== undefined) perfil[c] = d[c];
    perfil.nombre = perfil.nombre || d.nombre_completo || 'Taller sin nombre';
    perfil.especialidad = perfil.especialidad || 'General';
    perfil.calificacion_promedio = perfil.calificacion_promedio || 0;
    perfil.total_resenias = perfil.total_resenias || 0;
    perfil.estado = perfil.estado || 'pendiente';
    if (typeof d.latitud === 'number' && typeof d.longitud === 'number') {
      perfil.ubicacion = new admin.firestore.GeoPoint(d.latitud, d.longitud);
    }
    refs.push({ ref: db.collection('talleres').doc(doc.id), perfil });
  }

  let escritos = 0;
  for (let i = 0; i < refs.length; i += MAX_POR_BATCH) {
    const chunk = refs.slice(i, i + MAX_POR_BATCH);
    const batch = db.batch();
    for (const { ref, perfil } of chunk) {
      batch.set(ref, perfil, { merge: false });
    }
    await batch.commit();
    escritos += chunk.length;
  }
  console.log(`talleres proyectados: ${escritos}`);
  process.exit(0);
})();
