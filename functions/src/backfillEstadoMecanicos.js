// Relleno puntual: marca 'aprobado' a los mecanicos ya operativos, para que el
// nuevo defecto fail-closed de `estado` (UserModel.fromMap y firestore.rules
// isMecanico()) no los expulse. Los documentos `usuarios` con rol Mecanico o
// Taller que NUNCA tuvieron el campo `estado` se asumian implicitamente
// activos (fail-open); tras la Tarea 13 quedan bloqueados por defecto.
//
// REVISAR LA LISTA A MANO antes de ejecutar con --aplicar: aprobar en masa es
// una decision de negocio, no tecnica. Este script NUNCA debe apuntar al
// proyecto real `autodoc-6ef5a` sin esa revision manual previa.
//
// Uso:
//   node functions/src/backfillEstadoMecanicos.js            (modo reporte, no escribe nada)
//   node functions/src/backfillEstadoMecanicos.js --aplicar  (escribe estado: 'aprobado')
const admin = require('firebase-admin');
admin.initializeApp();

const MAX_POR_BATCH = 500;

(async () => {
  const db = admin.firestore();
  const snap = await db.collection('usuarios').get();
  const candidatos = [];
  snap.forEach((doc) => {
    const d = doc.data();
    const rol = String(d.rol || '').trim().toLowerCase();
    if ((rol === 'mecanico' || rol === 'taller') && d.estado === undefined) {
      candidatos.push({ uid: doc.id, correo: d.correo, nombre: d.nombre_completo });
    }
  });
  console.log(`Mecanicos sin campo estado: ${candidatos.length}`);
  console.table(candidatos);
  if (process.argv[2] !== '--aplicar') {
    console.log('\nEjecucion en seco. Repite con --aplicar para escribir.');
    process.exit(0);
    return;
  }

  let actualizados = 0;
  for (let i = 0; i < candidatos.length; i += MAX_POR_BATCH) {
    const chunk = candidatos.slice(i, i + MAX_POR_BATCH);
    const batch = db.batch();
    for (const c of chunk) {
      batch.update(db.collection('usuarios').doc(c.uid), { estado: 'aprobado' });
    }
    await batch.commit();
    actualizados += chunk.length;
  }
  console.log(`Actualizados: ${actualizados}`);
  process.exit(0);
})();
