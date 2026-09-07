// Script de mantenimiento único (no es una Cloud Function desplegada).
//
// ROLE-01 (plan de remediacion): unifica `usuarios/{uid}.rol` al vocabulario
// canonico UNICO que exigen tanto `firestore.rules` (isAdmin(), isMecanico(),
// isSuperUser() — comparan literales EXACTOS) como
// `lib/core/utils/role_utils.dart` (appRoleOf, tras ROLE-01 — ya NO tolera
// variantes de caja/acento para autorizar). Los 5 valores canonicos son:
// 'Propietario', 'Mecanico', 'Taller', 'Administrador', 'Superusuario'.
//
// Absorbe y reemplaza la migracion anterior (hallazgo §2.15, solo
// 'Usuario' -> 'Propietario'): ahora cubre las cinco familias de rol, porque
// cualquier variante de caja/acento en CUALQUIER rol (no solo Propietario) es
// exactamente la divergencia que describe ROLE-01 — la UI puede clasificar
// una cuenta como mecanico/admin (appRoleOf, antes de ROLE-01, era tolerante)
// mientras firestore.rules la trata como sin rol reconocido por comparar
// literales exactos.
//
// Toda la clasificacion (que es canonico, que es una variante migrable y a
// que destino, que es desconocido) vive en `src/rolMigracion.js`, pura y con
// su propio test (`test/rolMigracion.test.js`) — este archivo solo hace I/O.
//
// Que hace, sobre la coleccion `usuarios`:
//
//   1. Migra `rol` a su forma canonica en los documentos cuyo valor actual es
//      una variante reconocida (caja/acento, o un sinonimo historico como
//      'Usuario' -> 'Propietario', o el alias 'admin' -> 'Administrador' que
//      firestore.rules SI tolera pero que no es uno de los 5 valores del
//      vocabulario unico).
//   2. NO toca ningun documento cuyo `rol` ya es un literal canonico exacto.
//   3. NO adivina: un `rol` que no coincide con ningun sinonimo conocido
//      (incluidos vacio, ausente o un valor sin relacion) se REPORTA para
//      revision manual y se deja intacto.
//   4. Antes de escribir NADA (solo con --apply), guarda un respaldo JSON con
//      el valor anterior de cada documento que va a tocar. Es el mecanismo de
//      rollback: `node migrate_rol_usuario.js --rollback <archivo>` restaura
//      exactamente esos valores, documento por documento.
//
// Es idempotente: una segunda pasada no encuentra nada que cambiar (todo ya
// es canonico), y el rollback tambien lo es (restaura el valor exacto que
// habia).
//
// Por que esto NO eleva privilegios: migrar 'mecanico' -> 'Mecanico' (o
// 'admin' -> 'Administrador') no le da a la cuenta ninguna capacidad que hoy
// no tuviera segun `firestore.rules` — al contrario, hoy esa cuenta con
// 'mecanico' en minuscula YA es rechazada por isMecanico() en cualquier
// lectura/escritura real (falla cerrado). La migracion simplemente hace que
// la UI y el backend por fin esten de acuerdo. Es puramente cosmetica desde
// el punto de vista de autorizacion: el conjunto de literales que
// `firestore.rules` acepta no cambia con este script.
//
// Uso (dry-run, contra produccion, con las credenciales del proyecto):
//   node migrate_rol_usuario.js                     # solo imprime que migraria
//   node migrate_rol_usuario.js --apply             # aplica y escribe el respaldo
//   node migrate_rol_usuario.js --rollback <backup.json>   # restaura el respaldo
//
// Uso (contra el emulador, sin credenciales reales):
//   FIRESTORE_EMULATOR_HOST=localhost:8080 node migrate_rol_usuario.js --apply

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const { ROLES_CANONICOS, resumenMigracion } = require('./src/rolMigracion');

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
const ROLLBACK_IDX = process.argv.indexOf('--rollback');
const ROLLBACK_FILE = ROLLBACK_IDX >= 0 ? process.argv[ROLLBACK_IDX + 1] : null;
const BATCH_SIZE = 400; // límite de Firestore es 500 escrituras/batch

function backupPath() {
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  return path.join(__dirname, `rol_migracion_backup_${ts}.json`);
}

async function migrar() {
  console.log(APPLY ? 'Modo: APLICAR cambios' : 'Modo: DRY-RUN (usa --apply para escribir)');

  const snap = await db.collection('usuarios').get();
  const docs = snap.docs.map((d) => ({ id: d.id, rol: d.data().rol, ref: d.ref }));
  console.log(`Usuarios encontrados: ${docs.length}`);

  const resumen = resumenMigracion(docs);

  console.log('---');
  console.log(`Ya canonicos (sin tocar): ${resumen.yaCanonicos.length}`);
  console.log(`Migrables: ${resumen.migrables.length}`);
  if (Object.keys(resumen.conteoPorVariante).length > 0) {
    console.log('Conteo por variante -> destino:');
    for (const [variante, n] of Object.entries(resumen.conteoPorVariante)) {
      console.log(`  ${variante}: ${n}`);
    }
  }

  if (APPLY && resumen.migrables.length > 0) {
    // Respaldo ANTES de escribir nada: es el mecanismo de rollback.
    const respaldo = resumen.migrables.map((m) => ({ id: m.id, rolAnterior: m.rolActual }));
    const archivo = backupPath();
    fs.writeFileSync(archivo, JSON.stringify(respaldo, null, 2));
    console.log(`Respaldo escrito en: ${archivo}`);
    console.log(`Para revertir: node migrate_rol_usuario.js --rollback ${archivo}`);

    const docsPorId = new Map(docs.map((d) => [d.id, d]));
    let batch = db.batch();
    let opsEnBatch = 0;
    const flushes = [];
    for (const m of resumen.migrables) {
      const ref = docsPorId.get(m.id).ref;
      console.log(`  [rol] ${m.id}: "${m.rolActual}" -> "${m.rolCanonico}"`);
      batch.update(ref, { rol: m.rolCanonico });
      opsEnBatch++;
      if (opsEnBatch >= BATCH_SIZE) {
        flushes.push(batch.commit());
        batch = db.batch();
        opsEnBatch = 0;
      }
    }
    if (opsEnBatch > 0) flushes.push(batch.commit());
    await Promise.all(flushes);
  } else {
    for (const m of resumen.migrables) {
      console.log(`  [rol] ${m.id}: "${m.rolActual}" -> "${m.rolCanonico}"`);
    }
  }

  if (resumen.desconocidos.length > 0) {
    console.warn(`\n[ADVERTENCIA] ${resumen.desconocidos.length} documento(s) con un 'rol' que no se reconoce y que NO se han tocado.`);
    console.warn(`La app los trata como Propietario (default de appRoleOf en lib/core/utils/role_utils.dart),`);
    console.warn('pero seguiran sin aparecer en los filtros por rol del panel de admin.');
    console.warn('Revisalos a mano y decide que rol canonico les toca:');
    for (const u of resumen.desconocidos) {
      console.warn(`  - ${u.id}: rol = ${JSON.stringify(u.rol)}`);
    }
  } else {
    console.log('Sin documentos con rol desconocido.');
  }

  if (!APPLY) {
    console.log('\nNada se escribió (dry-run). Vuelve a correr con --apply para aplicar.');
  }
}

async function rollback(archivo) {
  if (!fs.existsSync(archivo)) {
    console.error(`No existe el archivo de respaldo: ${archivo}`);
    process.exit(1);
  }
  const respaldo = JSON.parse(fs.readFileSync(archivo, 'utf8'));
  console.log(`Restaurando ${respaldo.length} documento(s) desde ${archivo}...`);

  let batch = db.batch();
  let opsEnBatch = 0;
  const flushes = [];
  for (const { id, rolAnterior } of respaldo) {
    console.log(`  [rollback] ${id}: -> "${rolAnterior}"`);
    batch.update(db.collection('usuarios').doc(id), { rol: rolAnterior });
    opsEnBatch++;
    if (opsEnBatch >= BATCH_SIZE) {
      flushes.push(batch.commit());
      batch = db.batch();
      opsEnBatch = 0;
    }
  }
  if (opsEnBatch > 0) flushes.push(batch.commit());
  await Promise.all(flushes);
  console.log('Rollback completo.');
}

async function main() {
  if (ROLLBACK_FILE) {
    await rollback(ROLLBACK_FILE);
    return;
  }
  await migrar();
}

// Sanidad del propio vocabulario canonico: si esto cambia sin querer, mejor
// reventar aqui que migrar datos a un valor equivocado.
if (ROLES_CANONICOS.length !== 5) {
  throw new Error('ROLES_CANONICOS debe tener exactamente 5 valores; revisa src/rolMigracion.js');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
