// Script de mantenimiento único (no es una Cloud Function desplegada) para la
// colección `mantenimientos`. Hace dos cosas, cada una bajo su propia bandera:
//
//   1. SIEMBRA el plan de mantenimiento por defecto en los vehículos que no
//      lo tienen.
//   2. DEDUPLICA (--deduplicar) los vehículos que acabaron con el plan
//      repetido x2, x3, x6...
//
// POR QUÉ HACE FALTA SEMBRAR
//
// Las 8 tareas por defecto solo se crean desde el cliente, y solo por el
// PROPIETARIO: `AlertProvider.createDefaultTasks`, llamada al añadir un
// vehículo (dashboard_screen.dart / garage_screen.dart) y, como red de
// seguridad, desde `fetchAlerts` cuando la lista sale vacía. Un vehículo que
// no pasó por esos caminos —sembrado por script, importado, creado antes de
// que existiera esa llamada, o cuyo `createDefaultTasks` falló (su catch solo
// hace debugPrint)— se queda con CERO tareas para siempre.
//
// Y el taller no puede arreglarlo desde la app: `firestore.rules` solo deja
// CREAR `mantenimientos` al propietario o a un admin, y solo deja LEERLOS al
// propietario, a un taller ya vinculado o a un admin (invariante con prueba
// propia en test_rules/mecanico-scope.test.js). Por eso este script usa el
// Admin SDK.
//
// POR QUÉ HACE FALTA DEDUPLICAR
//
// Hasta el arreglo de idempotencia, `createDefaultTasks` escribía cada tarea
// con un id ALEATORIO, así que cada llamada añadía un juego completo de ocho.
// Como se llama al añadir el vehículo y otra vez desde `fetchAlerts` siempre
// que la lista salga vacía, bastaba con abrir el vehículo un par de veces
// antes de que la primera escritura fuera visible para acabar con el plan
// duplicado. El cliente ya no las genera, pero las que hay en producción
// siguen ahí: eso es lo que limpia --deduplicar.
//
// LOS VALORES y el id determinista son los de
// lib/core/constants/maintenance_defaults.dart, replicados aquí en JS. Si
// cambias uno, cambia el otro.
//
// Uso (contra producción, con las credenciales del proyecto):
//   node seed_tareas_mantenimiento.js                  # dry-run: informa de todo, no escribe
//   node seed_tareas_mantenimiento.js --apply          # siembra los vehículos SIN ninguna tarea
//   node seed_tareas_mantenimiento.js --completar --apply   # además rellena los planes a medias
//   node seed_tareas_mantenimiento.js --deduplicar --apply  # BORRA las tareas repetidas
//   node seed_tareas_mantenimiento.js --vehiculo <id>  # limita todo a un solo vehículo
//
// Uso (contra el emulador):
//   FIRESTORE_EMULATOR_HOST=localhost:8080 node seed_tareas_mantenimiento.js --apply

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Mismo arranque de credenciales que migrate_vehiculos.js: contra producción
// hace falta una service account key (functions/serviceAccountKey.json, ya en
// .gitignore, o GOOGLE_APPLICATION_CREDENTIALS); contra el emulador, ninguna.
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
const COMPLETAR = process.argv.includes('--completar');
const DEDUPLICAR = process.argv.includes('--deduplicar');
const BATCH_SIZE = 400; // el límite de Firestore es 500 escrituras/batch

const idxVehiculo = process.argv.indexOf('--vehiculo');
const SOLO_VEHICULO = idxVehiculo !== -1 ? process.argv[idxVehiculo + 1] : null;

// Espejo de kTareasMantenimientoPorDefecto en
// lib/core/constants/maintenance_defaults.dart. Las claves son exactamente
// las que lee MaintenanceTask.fromMap.
const TAREAS_POR_DEFECTO = [
  { nombre: 'Cambio de Aceite', frecuencia_km: 5000, frecuencia_meses: 6 },
  { nombre: 'Filtro de Aire', frecuencia_km: 10000, frecuencia_meses: 12 },
  { nombre: 'Filtro de Aceite', frecuencia_km: 5000, frecuencia_meses: 6 },
  { nombre: 'Pastillas de Freno', frecuencia_km: 20000, frecuencia_meses: 24 },
  { nombre: 'Rotación de Llantas', frecuencia_km: 10000, frecuencia_meses: 12 },
  { nombre: 'Revisión de Frenos', frecuencia_km: 15000, frecuencia_meses: 18 },
  { nombre: 'Cambio de Refrigerante', frecuencia_km: 40000, frecuencia_meses: 24 },
  { nombre: 'Bujías', frecuencia_km: 30000, frecuencia_meses: 24 },
];

// Gemela en JS de idTareaMantenimiento (maintenance_defaults.dart). Escribir
// con este id es lo que hace que sembrar sea idempotente.
const CON_ACENTO = 'áàäâãéèëêíìïîóòöôõúùüûñç';
const SIN_ACENTO = 'aaaaaeeeeiiiiooooouuuunc';

function idTareaMantenimiento(vehicleId, nombre) {
  let slug = '';
  for (const char of String(nombre).toLowerCase()) {
    const idx = CON_ACENTO.indexOf(char);
    const normal = idx === -1 ? char : SIN_ACENTO[idx];
    slug += /[a-z0-9]/.test(normal) ? normal : '_';
  }
  return `${vehicleId}__${slug}`;
}

// De un grupo de documentos con el MISMO nombre de tarea, cuál se conserva.
// Gana el que más kilometraje registrado tenga: es el que refleja el último
// servicio real, y perderlo reescribiría el historial del propietario. A
// igualdad de km, gana el que ya use el id determinista.
function elegirSuperviviente(docs, vehicleId, nombre) {
  const idBueno = idTareaMantenimiento(vehicleId, nombre);
  return docs.slice().sort((a, b) => {
    const kmA = typeof a.get('ultimo_km') === 'number' ? a.get('ultimo_km') : -1;
    const kmB = typeof b.get('ultimo_km') === 'number' ? b.get('ultimo_km') : -1;
    if (kmA !== kmB) return kmB - kmA;
    if (a.id === idBueno) return -1;
    if (b.id === idBueno) return 1;
    return 0;
  })[0];
}

async function main() {
  console.log(APPLY ? 'MODO APLICAR' : 'MODO DRY-RUN (no escribe nada)');
  if (DEDUPLICAR) console.log('Deduplicación ACTIVADA: se borrarán tareas repetidas');
  if (SOLO_VEHICULO) console.log(`Limitado al vehículo ${SOLO_VEHICULO}`);
  console.log('---');

  // Dos lecturas completas y una sola pasada en memoria, en vez de consultar
  // `mantenimientos` una vez por vehículo: eso serían N+1 consultas y el
  // coste crecería con el parque entero.
  const [vehiculosSnap, tareasSnap] = await Promise.all([
    db.collection('vehiculos').get(),
    db.collection('mantenimientos').get(),
  ]);

  // id_vehiculo -> (nombre de tarea -> lista de documentos con ese nombre).
  // La lista, y no un Set, es lo que permite ver los duplicados.
  const porVehiculo = new Map();
  for (const doc of tareasSnap.docs) {
    const idVehiculo = doc.get('id_vehiculo');
    if (!idVehiculo) continue;
    if (!porVehiculo.has(idVehiculo)) porVehiculo.set(idVehiculo, new Map());
    const porNombre = porVehiculo.get(idVehiculo);
    const nombre = doc.get('nombre');
    if (!porNombre.has(nombre)) porNombre.set(nombre, []);
    porNombre.get(nombre).push(doc);
  }

  let batch = db.batch();
  let opsEnBatch = 0;
  const flushes = [];

  const encolar = (fn) => {
    if (!APPLY) return;
    fn(batch);
    opsEnBatch++;
    if (opsEnBatch >= BATCH_SIZE) {
      flushes.push(batch.commit());
      batch = db.batch();
      opsEnBatch = 0;
    }
  };

  let sembrados = 0;
  let completados = 0;
  let yaCompletos = 0;
  let tareasEscritas = 0;
  let duplicadasBorradas = 0;
  const aMedias = [];
  const conDuplicados = [];

  for (const doc of vehiculosSnap.docs) {
    if (SOLO_VEHICULO && doc.id !== SOLO_VEHICULO) continue;

    const data = doc.data();
    const placa = data.placa || '(sin placa)';
    const porNombre = porVehiculo.get(doc.id) || new Map();

    // --- 1. Duplicados ---
    let sobrantesDelVehiculo = 0;
    for (const [nombre, docs] of porNombre) {
      if (docs.length <= 1) continue;
      sobrantesDelVehiculo += docs.length - 1;
      const superviviente = elegirSuperviviente(docs, doc.id, nombre);
      for (const d of docs) {
        if (d.id === superviviente.id) continue;
        duplicadasBorradas++;
        if (DEDUPLICAR) encolar((b) => b.delete(d.ref));
      }
    }
    if (sobrantesDelVehiculo > 0) {
      conDuplicados.push({ id: doc.id, placa, sobrantes: sobrantesDelVehiculo });
      if (DEDUPLICAR) {
        console.log(`  [dedup]    ${doc.id} (${placa}): -${sobrantesDelVehiculo} tareas repetidas`);
      }
    }

    // --- 2. Siembra ---
    const existentes = new Set(porNombre.keys());
    const faltantes = TAREAS_POR_DEFECTO.filter((t) => !existentes.has(t.nombre));

    if (faltantes.length === 0) {
      yaCompletos++;
      continue;
    }

    const parcial = existentes.size > 0;
    if (parcial) {
      aMedias.push({ id: doc.id, placa, tiene: existentes.size, faltan: faltantes.length });
      // Un plan a medias puede ser deliberado: el propietario pudo borrar las
      // tareas que no le aplican (una moto no lleva rotación de llantas).
      // Rellenarlo se las devolvería sin que él lo pidiera, así que por
      // defecto solo se informa y hace falta --completar para tocarlo.
      if (!COMPLETAR) continue;
      completados++;
      console.log(`  [completa] ${doc.id} (${placa}): +${faltantes.length} de ${TAREAS_POR_DEFECTO.length}`);
    } else {
      sembrados++;
      console.log(`  [siembra]  ${doc.id} (${placa}): ${faltantes.length} tareas`);
    }

    // `fecha_ultimo_servicio` NO puede faltar: MaintenanceTask.fromMap la
    // castea sin comprobar null (`map['fecha_ultimo_servicio'] as Timestamp`),
    // así que un documento sin ella revienta al leerlo.
    const ahora = admin.firestore.Timestamp.now();
    const km = typeof data.kilometraje_actual === 'number' ? data.kilometraje_actual : 0;

    for (const tarea of faltantes) {
      tareasEscritas++;
      encolar((b) => b.set(db.collection('mantenimientos').doc(idTareaMantenimiento(doc.id, tarea.nombre)), {
        id_vehiculo: doc.id,
        nombre: tarea.nombre,
        ultimo_km: km,
        fecha_ultimo_servicio: ahora,
        frecuencia_km: tarea.frecuencia_km,
        frecuencia_meses: tarea.frecuencia_meses,
      }));
    }
  }

  if (APPLY && opsEnBatch > 0) flushes.push(batch.commit());
  if (flushes.length > 0) await Promise.all(flushes);

  console.log('---');
  if (conDuplicados.length > 0 && !DEDUPLICAR) {
    console.log(`Vehículos con tareas REPETIDAS (${conDuplicados.length}) — no se tocan sin --deduplicar:`);
    for (const v of conDuplicados) {
      console.log(`  [repetidas] ${v.id}  placa=${v.placa}  sobran=${v.sobrantes}`);
    }
    console.log('---');
  }
  if (aMedias.length > 0 && !COMPLETAR) {
    console.log(`Vehículos con el plan A MEDIAS (${aMedias.length}) — no se tocan sin --completar:`);
    console.log('  Puede ser deliberado: el propietario pudo borrar las tareas que no le');
    console.log('  aplican. --completar le devuelve solo las que falten.');
    for (const v of aMedias) {
      console.log(`  [a medias] ${v.id}  placa=${v.placa}  tiene=${v.tiene}  faltan=${v.faltan}`);
    }
    console.log('---');
  }
  console.log(`Vehículos leídos: ${vehiculosSnap.size}`);
  console.log(`Vehículos sin ninguna tarea (sembrados): ${sembrados}`);
  console.log(`Vehículos a medias completados: ${completados}`);
  console.log(`Vehículos que ya tenían el plan completo: ${yaCompletos}`);
  console.log(`Tareas ${APPLY ? 'escritas' : 'que se escribirían'}: ${tareasEscritas}`);
  console.log(`Tareas repetidas ${APPLY && DEDUPLICAR ? 'borradas' : 'que se borrarían con --deduplicar'}: ${duplicadasBorradas}`);
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
