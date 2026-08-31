// Script de mantenimiento único (no es una Cloud Function desplegada) para el
// hallazgo §2.15 del recorrido QA del 2026-08-28: en /admin/usuarios hay
// cuentas con la insignia USUARIO, pero los chips de filtro son
// Propietario / Mecanico / Administrador / Superusuario, así que esas cuentas
// no aparecen bajo ningún filtro por rol.
//
// `'Usuario'` es vocabulario viejo, sinónimo de `'Propietario'`. Esto no es
// una suposición del script: `appRoleOf()` en lib/core/utils/role_utils.dart
// manda cualquier valor desconocido —y `'Usuario'` lo es— a `AppRole.owner`,
// así que esas cuentas YA se comportan como propietarias en toda la app. Y en
// firestore.rules la única comparación exacta con `'Propietario'` está en el
// create de auto-registro (línea ~210), no en lecturas ni escrituras, así que
// nadie está bloqueado hoy. O sea: la migración es cosmética y de coherencia
// de datos, no desbloquea permisos.
//
// Qué hace, sobre la colección `usuarios`:
//
//   1. Cambia `rol` a 'Propietario' en los documentos cuyo valor actual es un
//      sinónimo viejo de propietario ('Usuario' y sus variantes de caja,
//      espacios y acentos).
//   2. NO toca ningún otro valor. Los documentos cuyo `rol` cae en owner por
//      ser desconocido pero que no son un sinónimo reconocido (incluidos los
//      que tienen el campo vacío o ausente) se REPORTAN para revisión a mano
//      y se dejan intactos: adivinar el rol de una cuenta en producción es
//      exactamente lo que no debe hacer un script de migración.
//
// Es idempotente: una segunda pasada no encuentra nada que cambiar.
//
// Uso (contra producción, con las credenciales del proyecto):
//   node migrate_rol_usuario.js            # dry-run, solo imprime qué cambiaría
//   node migrate_rol_usuario.js --apply    # aplica los cambios en batches
//
// Uso (contra el emulador):
//   FIRESTORE_EMULATOR_HOST=localhost:8080 node migrate_rol_usuario.js --apply

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

const ROL_CANONICO = 'Propietario';

// Misma lógica que `_normalizar` en lib/core/utils/role_utils.dart:
// minúsculas, sin espacios sobrantes y sin acentos. Lo de los acentos no es
// cosmético: 'Mecánico' con tilde no casaba con 'mecanico' y la cuenta caía al
// rol por defecto. Aquí se replica en JS por el mismo motivo que
// migrate_vehiculos.js replica PlateFormatter: el script corre fuera de Dart.
const SIN_ACENTOS = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
};

function normalizar(rol) {
  let r = String(rol == null ? '' : rol).trim().toLowerCase();
  for (const [acentuada, plana] of Object.entries(SIN_ACENTOS)) {
    r = r.split(acentuada).join(plana);
  }
  return r;
}

// Sinónimos viejos de propietario que este script SÍ migra. Deliberadamente
// corto: solo lo que sabemos que significa "propietario" por historia del
// producto. Todo lo demás se reporta, no se adivina.
const SINONIMOS_PROPIETARIO = ['usuario', 'propietario'];

// Valores que `appRoleOf` reconoce explícitamente y que por tanto NO son
// candidatos a migración: tienen dueño conocido en otro rol funcional.
const ROLES_RECONOCIDOS = [
  'admin', 'administrador', 'superusuario', 'mecanico', 'taller', 'propietario',
];

async function main() {
  console.log(APPLY ? 'Modo: APLICAR cambios' : 'Modo: DRY-RUN (usa --apply para escribir)');

  const snap = await db.collection('usuarios').get();
  console.log(`Usuarios encontrados: ${snap.size}`);

  let migrados = 0;
  let yaCanonicos = 0;
  let otrosRoles = 0;
  const paraRevisar = [];

  let batch = db.batch();
  let opsEnBatch = 0;
  const flushes = [];

  for (const doc of snap.docs) {
    const data = doc.data();
    const rolActual = data.rol;
    const norm = normalizar(rolActual);

    if (rolActual === ROL_CANONICO) {
      yaCanonicos++;
      continue;
    }

    if (SINONIMOS_PROPIETARIO.includes(norm)) {
      migrados++;
      console.log(`  [rol] ${doc.id}: "${rolActual}" -> "${ROL_CANONICO}"`);
      if (APPLY) {
        batch.update(doc.ref, { rol: ROL_CANONICO });
        opsEnBatch++;
        if (opsEnBatch >= BATCH_SIZE) {
          flushes.push(batch.commit());
          batch = db.batch();
          opsEnBatch = 0;
        }
      }
      continue;
    }

    if (ROLES_RECONOCIDOS.includes(norm)) {
      otrosRoles++;
      continue;
    }

    // Desconocido: la app lo trata como propietario por el default de
    // `appRoleOf`, pero no lo migramos a ciegas.
    paraRevisar.push({ id: doc.id, rol: rolActual });
  }

  if (APPLY && opsEnBatch > 0) {
    flushes.push(batch.commit());
  }
  if (flushes.length > 0) {
    await Promise.all(flushes);
  }

  console.log('---');
  console.log(`Migrados a "${ROL_CANONICO}": ${migrados}`);
  console.log(`Ya estaban en "${ROL_CANONICO}": ${yaCanonicos}`);
  console.log(`Con otro rol reconocido (intactos): ${otrosRoles}`);

  if (paraRevisar.length > 0) {
    console.warn(`\n[ADVERTENCIA] ${paraRevisar.length} documento(s) con un 'rol' que no se reconoce y que NO se han tocado.`);
    console.warn('La app los trata como Propietario (default de appRoleOf), pero seguirán sin aparecer');
    console.warn('en los filtros por rol del panel de admin. Revísalos a mano y decide qué rol les toca:');
    for (const u of paraRevisar) {
      console.warn(`  - ${u.id}: rol = ${JSON.stringify(u.rol)}`);
    }
  } else {
    console.log('Sin documentos con rol desconocido.');
  }

  if (!APPLY) {
    console.log('\nNada se escribió (dry-run). Vuelve a correr con --apply para aplicar.');
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
