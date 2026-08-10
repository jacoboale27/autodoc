// Script de mantenimiento único (no es una Cloud Function desplegada) para
// vehículos viejos creados antes de que existieran los campos de vínculo con
// talleres (commits 8ffc2a8/90204e2). Hace dos cosas sobre la colección
// `vehiculos`:
//
//   1. Normaliza `placa` al formato canónico P###-### (ver
//      lib/core/utils/plate_formatter.dart, misma lógica replicada aquí en
//      JS) — corrige placas guardadas sin guion, en minúscula, con espacios,
//      etc.
//   2. Rellena los campos que el modelo actual espera y que los documentos
//      viejos no tienen: talleres_vinculados, talleres_rechazados (arrays
//      vacíos), y taller_pendiente_confirmacion/_nombre/_servicio_id (null).
//      Sin esto, `firestore.rules` (match /vehiculos/{vehiculoId}, que lee
//      `resource.data.get('talleres_vinculados', [])`) sigue funcionando por
//      el default de `get()`, pero cualquier código que lea el campo
//      directamente (p.ej. queries `array-contains`) no encuentra el doc.
//
// Uso (contra producción, con las credenciales del proyecto):
//   node migrate_vehiculos.js            # dry-run, solo imprime qué cambiaría
//   node migrate_vehiculos.js --apply    # aplica los cambios en batches
//
// Uso (contra el emulador):
//   FIRESTORE_EMULATOR_HOST=localhost:8080 node migrate_vehiculos.js --apply

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'autodoc-6ef5a' });
const db = admin.firestore();

const APPLY = process.argv.includes('--apply');
const BATCH_SIZE = 400; // límite de Firestore es 500 escrituras/batch

// Misma lógica que PlateFormatter.formatEditUpdate en
// lib/core/utils/plate_formatter.dart: mayúsculas, solo hex (0-9A-F), prefijo
// P obligatorio, tope de 7 caracteres útiles, guion tras el 4to.
function normalizarPlaca(input) {
  let text = String(input || '').toUpperCase().replace(/-/g, '');
  text = text.replace(/[^0-9A-F]/g, '');
  if (!text.startsWith('P')) {
    text = 'P' + text;
  }
  if (text.length > 1) {
    text = 'P' + text.slice(1).replace(/P/g, '');
  }
  if (text.length > 7) {
    text = text.slice(0, 7);
  }
  if (text.length > 4) {
    return text.slice(0, 4) + '-' + text.slice(4);
  }
  return text;
}

const PLACA_VALIDA = /^P[0-9A-F]{3}-[0-9A-F]{3}$/;

const CAMPOS_VINCULO_DEFAULT = {
  talleres_vinculados: [],
  talleres_rechazados: [],
  taller_pendiente_confirmacion: null,
  taller_pendiente_nombre: null,
  taller_pendiente_servicio_id: null,
};

async function main() {
  console.log(APPLY ? 'Modo: APLICAR cambios' : 'Modo: DRY-RUN (usa --apply para escribir)');

  const snap = await db.collection('vehiculos').get();
  console.log(`Vehículos encontrados: ${snap.size}`);

  let placasCorregidas = 0;
  let placasInvalidas = 0;
  let camposRellenados = 0;
  let sinCambios = 0;

  let batch = db.batch();
  let opsEnBatch = 0;
  const flushes = [];

  for (const doc of snap.docs) {
    const data = doc.data();
    const update = {};

    const placaActual = data.placa || '';
    const placaNormalizada = normalizarPlaca(placaActual);
    if (placaNormalizada !== placaActual) {
      update.placa = placaNormalizada;
      placasCorregidas++;
      console.log(`  [placa] ${doc.id}: "${placaActual}" -> "${placaNormalizada}"`);
    }
    if (!PLACA_VALIDA.test(placaNormalizada)) {
      placasInvalidas++;
      console.warn(`  [placa][ADVERTENCIA] ${doc.id}: "${placaNormalizada}" no cumple el patrón P###-### incluso tras normalizar — revisar a mano.`);
    }

    for (const [campo, valorDefault] of Object.entries(CAMPOS_VINCULO_DEFAULT)) {
      if (!(campo in data)) {
        update[campo] = valorDefault;
      }
    }
    const camposNuevos = Object.keys(update).filter((k) => k !== 'placa');
    if (camposNuevos.length > 0) {
      camposRellenados++;
      console.log(`  [campos] ${doc.id}: agrega ${camposNuevos.join(', ')}`);
    }

    if (Object.keys(update).length === 0) {
      sinCambios++;
      continue;
    }

    if (APPLY) {
      batch.update(doc.ref, update);
      opsEnBatch++;
      if (opsEnBatch >= BATCH_SIZE) {
        flushes.push(batch.commit());
        batch = db.batch();
        opsEnBatch = 0;
      }
    }
  }

  if (APPLY && opsEnBatch > 0) {
    flushes.push(batch.commit());
  }
  if (flushes.length > 0) {
    await Promise.all(flushes);
  }

  console.log('---');
  console.log(`Placas corregidas: ${placasCorregidas}`);
  console.log(`Placas inválidas incluso tras normalizar (revisar a mano): ${placasInvalidas}`);
  console.log(`Documentos con campos de vínculo rellenados: ${camposRellenados}`);
  console.log(`Documentos sin cambios: ${sinCambios}`);
  if (!APPLY) {
    console.log('Nada se escribió (dry-run). Vuelve a correr con --apply para aplicar.');
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
