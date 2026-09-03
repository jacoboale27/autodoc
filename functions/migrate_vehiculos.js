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
const path = require('path');
const fs = require('fs');

// Contra producción hace falta una service account key (ADC no está
// configurado en esta máquina): Firebase Console > Configuración del
// proyecto > Cuentas de servicio > Generar nueva clave privada, guardarla
// como functions/serviceAccountKey.json (ya está en .gitignore) o apuntar
// GOOGLE_APPLICATION_CREDENTIALS a su ruta. Contra el emulador
// (FIRESTORE_EMULATOR_HOST definido) no hace falta ninguna credencial real.
const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS
  || path.join(__dirname, 'serviceAccountKey.json');

if (!process.env.FIRESTORE_EMULATOR_HOST && fs.existsSync(keyPath)) {
  admin.initializeApp({
    credential: admin.credential.cert(require(keyPath)),
    projectId: 'autodoc-6ef5a',
  });
} else {
  admin.initializeApp({ projectId: 'autodoc-6ef5a' });
}
const db = admin.firestore();

const APPLY = process.argv.includes('--apply');
const BATCH_SIZE = 400; // límite de Firestore es 500 escrituras/batch

// Tipos de placa que cubre AutoDoc, con la letra que usa el VMT.
const PREFIJOS = ['P', 'M', 'C', 'A'];

// Espejo de normalizarPlaca en lib/core/utils/plate_formatter.dart:
// mayúsculas, se respeta el prefijo que traiga el texto (P particular,
// M moto, C carga, A alquiler; si no trae ninguno se asume P), solo hex
// (0-9A-F) en el correlativo, tope de 6 caracteres y guion siempre delante
// de los tres últimos.
//
// Dos trampas al tocar esto:
//  1. Con la regla vieja (guion fijo tras el 4to carácter) una placa legítima
//     de cinco, "P12-345", se reescribía como "P123-45" y quedaba corrupta.
//  2. `A` y `C` son además dígitos hexadecimales válidos, así que el prefijo
//     se recorta UNA sola vez en vez de filtrarlo por carácter; si no, una
//     placa de alquiler "AA12-345" perdería una A.
function normalizarPlaca(input) {
  const texto = String(input || '').trim().toUpperCase();
  const prefijo = PREFIJOS.find((pre) => texto.startsWith(pre)) || 'P';
  let text = texto.startsWith(prefijo) ? texto.slice(1) : texto;
  text = text.replace(/[^0-9A-F]/g, '');
  if (text.length > 6) {
    text = text.slice(0, 6);
  }
  if (text.length <= 3) {
    return prefijo + text;
  }
  const corte = text.length - 3;
  return prefijo + text.slice(0, corte) + '-' + text.slice(corte);
}

// Letra de tipo + correlativo de 1-3 hex + guion + 3 hex.
const PLACA_VALIDA = /^[PMCA][0-9A-F]{1,3}-[0-9A-F]{3}$/;

// Correlativo que empieza por cero. No se puede corregir automáticamente:
// "P012-345" puede ser una placa legítima del esquema alfanumérico (que sí
// rellena a tres posiciones, como la primera emitida, "P 001 00A") o el
// apaño de alguien que metió un cero para colar una placa de cinco
// caracteres cuando el validador exigía seis. Solo se reportan.
const CORRELATIVO_CON_CERO = /^[PMCA]0/;

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
  const placasConCeroInicial = [];
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
      console.warn(`  [placa][ADVERTENCIA] ${doc.id}: "${placaNormalizada}" no cumple el patrón <tipo>#-### / <tipo>##-### / <tipo>###-### incluso tras normalizar — revisar a mano.`);
    }
    if (CORRELATIVO_CON_CERO.test(placaNormalizada)) {
      placasConCeroInicial.push({
        id: doc.id,
        placa: placaNormalizada,
        propietario: data.id_propietario || '(sin dueño)',
      });
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
  if (placasConCeroInicial.length > 0) {
    console.log(`Placas cuyo correlativo empieza por 0 (${placasConCeroInicial.length}) — revisar a mano:`);
    console.log('  Puede ser legítimo (esquema alfanumérico, p.ej. P001-00A) o un cero');
    console.log('  metido a mano para colar una placa de cinco caracteres cuando el');
    console.log('  validador exigía seis. El script NO las toca.');
    for (const v of placasConCeroInicial) {
      console.log(`  [cero] ${v.id}  placa=${v.placa}  propietario=${v.propietario}`);
    }
    console.log('---');
  }
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
