// Script puntual de PRUEBA: marca estado: 'aprobado' en todos los usuarios
// con rol Mecanico/Taller. La escritura en 'usuarios' dispara
// publishTallerProfile (ya desplegada), que proyecta el cambio a 'talleres'
// automaticamente, asi que no hace falta correr backfillTalleres aparte.
//
// REVISAR LA LISTA A MANO antes de ejecutar con --write: aprobar en masa es
// una decision de negocio, no tecnica (igual que backfillEstadoMecanicos.js).
// Este script NUNCA debe apuntar al proyecto real `autodoc-6ef5a` sin esa
// revision manual previa ni sin dejar rastro en `admin_logs` (CONVENTIONS.md
// 3.2 exige que todo cambio de rol/estado admin quede auditado; este backfill
// puntual es una excepcion deliberada, no un patron a repetir).
//
// Uso:
//   node functions/src/aprobarTodosTalleres.js           (dry-run, solo reporta)
//   node functions/src/aprobarTodosTalleres.js --write   (aplica el cambio)
//
// Al escribir contra el proyecto real ademas se exige la variable de entorno
// CONFIRMAR_PROD=si, para evitar que un --write accidental (ej. copiado de un
// historial de shell) mute datos de produccion sin intencion explicita.
//
// Requiere las mismas variables de entorno que backfillTalleres.js:
//   GCLOUD_PROJECT=autodoc-6ef5a
//   GOOGLE_APPLICATION_CREDENTIALS=<ruta a tu clave de cuenta de servicio>
const admin = require('firebase-admin');
admin.initializeApp();

const WRITE = process.argv.includes('--write');
const PROYECTO_REAL = 'autodoc-6ef5a';

(async () => {
  const db = admin.firestore();
  const snap = await db.collection('usuarios').get();
  const candidatos = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    const rol = String(d.rol || '').trim().toLowerCase();
    if (rol !== 'mecanico' && rol !== 'taller') continue;
    candidatos.push({ id: doc.id, estadoActual: d.estado, ref: doc.ref });
  }

  console.log('--- aprobarTodosTalleres ---');
  console.log(`Proyecto objetivo: ${process.env.GCLOUD_PROJECT || '(no definido)'}`);
  console.log(`Talleres/mecanicos encontrados: ${candidatos.length}`);
  for (const c of candidatos) {
    console.log(`  ${c.id}: estado actual = ${c.estadoActual ?? '(sin estado)'}`);
  }

  if (!WRITE) {
    console.log('');
    console.log('Modo reporte (dry-run): no se escribio nada. Ejecutar con --write para aplicar.');
    process.exit(0);
    return;
  }

  if (process.env.GCLOUD_PROJECT === PROYECTO_REAL && process.env.CONFIRMAR_PROD !== 'si') {
    console.error('');
    console.error(`ABORTADO: --write contra el proyecto real (${PROYECTO_REAL}) requiere`);
    console.error('CONFIRMAR_PROD=si despues de revisar la lista de candidatos a mano.');
    process.exit(1);
    return;
  }

  let escritos = 0;
  for (const c of candidatos) {
    await c.ref.update({ estado: 'aprobado' });
    escritos += 1;
  }
  console.log(`Actualizados a estado 'aprobado': ${escritos}`);
  process.exit(0);
})();
