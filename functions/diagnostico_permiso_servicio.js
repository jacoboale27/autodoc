// Diagnóstico de solo lectura: explica POR QUÉ Firestore deniega (o
// permitiría) que un taller registre un servicio sobre un vehículo.
//
// Nace de un permission-denied al pulsar "FINALIZAR SERVICIO" tras buscar una
// placa. El error que ve el mecánico es siempre el mismo —"permission-denied"—
// pero la regla `match /servicios/{servicioId}` de firestore.rules tiene
// CUATRO condiciones que pueden fallar por separado, y desde la app no hay
// forma de saber cuál. Este script las evalúa una por una con el Admin SDK
// (que se salta las reglas y puede leerlo todo) y dice cuál es la que rompe.
//
// NO ESCRIBE NADA. Es seguro correrlo contra producción.
//
// Uso:
//   node diagnostico_permiso_servicio.js --placa P123-456 --taller <uid>
//   node diagnostico_permiso_servicio.js --vehiculo <idVehiculo> --taller <uid>
//
// El uid del taller es el de Authentication (el mismo que el id de su
// documento en `usuarios`).

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

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

function arg(nombre) {
  const i = process.argv.indexOf(nombre);
  return i !== -1 ? process.argv[i + 1] : null;
}

const PLACA = arg('--placa');
const VEHICULO = arg('--vehiculo');
const TALLER = arg('--taller');

const ok = (m) => console.log(`  [OK]     ${m}`);
const mal = (m) => console.log(`  [FALLA]  ${m}`);
const info = (m) => console.log(`  [info]   ${m}`);

async function buscarVehiculo() {
  if (VEHICULO) {
    const doc = await db.collection('vehiculos').doc(VEHICULO).get();
    return doc.exists ? doc : null;
  }
  const objetivo = String(PLACA).trim().toUpperCase();
  const directo = await db.collection('vehiculos').where('placa', '==', objetivo).limit(1).get();
  if (!directo.empty) return directo.docs[0];
  // La placa pudo guardarse sin normalizar (sin guion, en minúscula...).
  // Con el parque pequeño, un escaneo comparando solo dígitos y letras es
  // más útil que un "no encontrado" que no distingue ausencia de formato.
  const soloAlnum = (s) => String(s || '').toUpperCase().replace(/[^0-9A-Z]/g, '');
  const todos = await db.collection('vehiculos').get();
  return todos.docs.find((d) => soloAlnum(d.get('placa')) === soloAlnum(objetivo)) || null;
}

async function main() {
  if (!TALLER || (!PLACA && !VEHICULO)) {
    console.error('Uso: node diagnostico_permiso_servicio.js --placa <placa>|--vehiculo <id> --taller <uid>');
    process.exit(2);
  }

  let denegaria = false;

  console.log('=== 1. La cuenta del taller (isMecanico) ===');
  const userDoc = await db.collection('usuarios').doc(TALLER).get();
  if (!userDoc.exists) {
    mal(`no existe usuarios/${TALLER} — revisa que el uid sea el correcto`);
    denegaria = true;
  } else {
    const rol = userDoc.get('rol');
    const estado = userDoc.get('estado') || 'pendiente';
    if (['Mecanico', 'Taller'].includes(rol)) ok(`rol = "${rol}"`);
    else { mal(`rol = "${rol}" — la regla exige 'Mecanico' o 'Taller'`); denegaria = true; }

    if (['aprobado', 'activo'].includes(estado)) ok(`estado = "${estado}"`);
    else {
      mal(`estado = "${estado}" — la regla exige 'aprobado' o 'activo'`);
      info('Un taller pendiente de verificación NO puede registrar servicios.');
      denegaria = true;
    }

    const propietario = userDoc.get('id_taller_propietario');
    if (propietario) {
      info(`Es una SUB-CUENTA DE EMPLEADO del taller ${propietario}.`);
      info('Ojo: initiate_service_screen escribe id_taller = idUsuario (el uid del');
      info('empleado), y la regla de `servicios` exige id_taller == auth.uid, así que');
      info('el create pasa — pero el historial del taller dueño no lo verá, porque');
      info('mechanic_service_history filtra por su propio uid. Es un gap conocido.');
    }
  }

  console.log('\n=== 2. El vehículo ===');
  const vehDoc = await buscarVehiculo();
  if (!vehDoc) {
    mal(`no se encontró ningún vehículo con ${VEHICULO ? `id ${VEHICULO}` : `placa ${PLACA}`}`);
    info('La regla exige exists(/vehiculos/<id_vehiculo>): sin documento, el create se deniega.');
    console.log('\n=> VEREDICTO: el create de `servicios` SE DENEGARÍA.');
    process.exit(0);
  }
  ok(`vehiculos/${vehDoc.id}  placa=${vehDoc.get('placa')}`);

  console.log('\n=== 3. El vínculo taller-vehículo (mitigación C1) ===');
  const vinculados = vehDoc.get('talleres_vinculados') || [];
  info(`talleres_vinculados = ${JSON.stringify(vinculados)}`);
  if (vinculados.length === 0) {
    ok('lista vacía: es un walk-in legítimo, la regla lo permite');
  } else if (vinculados.includes(TALLER)) {
    ok('este taller ya está vinculado, la regla lo permite');
  } else {
    mal('el vehículo ya está vinculado a OTRO taller y este no está en la lista');
    info('Es la mitigación deliberada del hallazgo C1: un taller no puede crear');
    info('servicios sobre un vehículo que ya atiende otro. Para la demo, o usas un');
    info('vehículo sin vínculo, o el propietario confirma el vínculo desde su panel');
    info('(banner de taller_pendiente_confirmacion), o limpias talleres_vinculados.');
    denegaria = true;
  }
  const pendiente = vehDoc.get('taller_pendiente_confirmacion');
  if (pendiente) info(`taller_pendiente_confirmacion = ${pendiente} (esperando al propietario)`);

  console.log('\n=== 4. Las tareas de mantenimiento que vería el taller ===');
  const tareas = await db.collection('mantenimientos').where('id_vehiculo', '==', vehDoc.id).get();
  const porNombre = new Map();
  for (const d of tareas.docs) {
    porNombre.set(d.get('nombre'), (porNombre.get(d.get('nombre')) || 0) + 1);
  }
  const repetidas = [...porNombre.entries()].filter(([, n]) => n > 1);
  info(`${tareas.size} documentos en total, ${porNombre.size} nombres distintos`);
  if (repetidas.length > 0) {
    mal(`hay tareas REPETIDAS: ${repetidas.map(([n, c]) => `${n} x${c}`).join(', ')}`);
    info('Límpialas con: node seed_tareas_mantenimiento.js --vehiculo ' + vehDoc.id + ' --deduplicar --apply');
  }
  if (tareas.size === 0) {
    info('El vehículo no tiene NINGUNA tarea: el mecánico verá "este vehículo no');
    info('tiene tareas de mantenimiento configuradas". Siémbralas con:');
    info(`  node seed_tareas_mantenimiento.js --vehiculo ${vehDoc.id} --apply`);
  }
  const puedeLeer = vinculados.includes(TALLER);
  if (!puedeLeer) {
    info('Aunque existan, este taller NO puede LEERLAS: la regla de `mantenimientos`');
    info('solo deja leer al propietario, a un taller vinculado o a un admin.');
  }

  console.log('\n' + (denegaria
    ? '=> VEREDICTO: el create de `servicios` SE DENEGARÍA. Mira las líneas [FALLA].'
    : '=> VEREDICTO: el create de `servicios` estaría PERMITIDO por las reglas.'));
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
