// Relleno puntual: proyecta a `talleres` los mecanicos ya existentes.
//
// Ejecutar UNA vez con: node functions/src/backfillTalleres.js
//
// I5 (Fase C, revision de correcciones): este script (y publishTallerProfile)
// ponen `estado: 'pendiente'` por defecto cuando el documento de origen en
// `usuarios` no trae `estado`. El directorio publico (workshop_service.dart)
// filtra estrictamente por `estado == 'aprobado'`. La query ORIGINAL (antes
// de la Fase C) filtraba solo por `rol`, asi que es muy posible que los
// talleres reales de produccion NO tengan `estado == 'aprobado'` puesto
// explicitamente, en cuyo caso el directorio quedaria vacio tras desplegar
// esto. No se puede verificar esto sin acceso a los datos reales, asi que
// el script AHORA por defecto solo reporta (dry-run) y no escribe nada.
//
// VERIFICACION OBLIGATORIA antes de desplegar esta fase a produccion:
//   node functions/src/backfillTalleres.js
// Revisar el reporte de conteo por valor de `estado`. Si la mayoria de
// mecanicos/talleres reales caen en "(sin estado)" o en un valor distinto de
// 'aprobado', decidir con el equipo de producto si hace falta un backfill
// explicito de `estado: 'aprobado'` para los talleres ya verificados
// manualmente ANTES de correr el backfill real, para que el directorio no
// quede vacio. Solo entonces ejecutar con --write.
const admin = require('firebase-admin');
admin.initializeApp();

const CAMPOS_PUBLICOS = [
  'nombre', 'especialidad', 'ubicacion', 'direccion', 'foto_url',
  'calificacion_promedio', 'total_resenias', 'estado',
];

const MAX_POR_BATCH = 500;
const WRITE = process.argv.includes('--write');

(async () => {
  const db = admin.firestore();
  const snap = await db.collection('usuarios').get();
  const refs = [];
  const conteoEstados = {};
  for (const doc of snap.docs) {
    const d = doc.data();
    const rol = String(d.rol || '').trim().toLowerCase();
    if (rol !== 'mecanico' && rol !== 'taller') continue;

    const estadoOriginal = d.estado === undefined ? '(sin estado)' : String(d.estado);
    conteoEstados[estadoOriginal] = (conteoEstados[estadoOriginal] || 0) + 1;

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

  console.log('--- Reporte de backfillTalleres (usuarios con rol Mecanico/Taller) ---');
  console.log(`Total de mecanicos/talleres encontrados: ${refs.length}`);
  console.log('Conteo por valor de "estado" en usuarios (origen):');
  for (const [estado, cuenta] of Object.entries(conteoEstados).sort((a, b) => b[1] - a[1])) {
    console.log(`  ${estado}: ${cuenta}`);
  }
  const aprobados = conteoEstados['aprobado'] || 0;
  if (aprobados === 0 && refs.length > 0) {
    console.log('');
    console.log('ADVERTENCIA: ningun usuario Mecanico/Taller tiene estado == "aprobado".');
    console.log('Si se ejecuta el backfill tal cual, el directorio publico de talleres');
    console.log('(que filtra por estado == "aprobado") quedara VACIO. Revisar con el');
    console.log('equipo de producto antes de continuar.');
  }

  if (!WRITE) {
    console.log('');
    console.log('Modo reporte (dry-run): no se escribio nada. Ejecutar con --write para aplicar el backfill.');
    process.exit(0);
    return;
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
