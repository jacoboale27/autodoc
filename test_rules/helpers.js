const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const UIDS = {
  owner1: 'uid-owner-1',
  owner2: 'uid-owner-2',
  taller1: 'uid-taller-1',
  taller2: 'uid-taller-2',
  admin: 'uid-admin-1',
  // Sub-cuentas de empleado (fix de integracion de empleados): empleado1
  // pertenece a taller1 (id_taller_propietario == taller1), empleado2
  // pertenece a un taller DISTINTO (taller2), para los casos negativos.
  empleado1: 'uid-empleado-1',
  empleado2: 'uid-empleado-2',
  // Superusuario: el nivel por encima de Administrador (isSuperUser()). No
  // existia actor para el, asi que sus permisos EXCLUSIVOS —crear
  // Administradores, hard-delete de cuentas— no tenian ni positivo ni
  // negativo en la matriz de roles.
  superusuario: 'uid-superusuario-1',
};

async function makeEnv() {
  return initializeTestEnvironment({
    projectId: 'autodoc-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
}

/**
 * Vacia el emulador de Storage de verdad.
 *
 * **`env.clearStorage()` NO limpia nada en esta version, y lo hace en
 * silencio.** Medido: se sube un objeto, se llama a `clearStorage()` y el
 * objeto sigue ahi. El endpoint REST del emulador
 * (`DELETE /emulator/v1/projects/{p}/buckets/{b}/objects`) responde 501, o sea
 * tampoco esta implementado.
 *
 * Ninguna suite podia notarlo porque **todas las reglas de Storage permitian
 * sobrescribir**: subir sobre un objeto que la limpieza deberia haber borrado
 * daba el mismo verde que subirlo en limpio. Aparecio al cerrar el gap de las
 * facturas inmutables, cuando la regla empezo a mirar `resource == null`: tres
 * tests que llevaban tiempo pasando resultaron estar subiendo encima de lo que
 * habia dejado el test anterior, o sea eran dependientes del orden.
 *
 * Se borra listando y eliminando, que es lo unico que el emulador implementa.
 */
async function limpiarStorage(env) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const borrarPrefijo = async (ref) => {
      const listado = await ref.listAll();
      await Promise.all(listado.items.map((item) => item.delete()));
      await Promise.all(listado.prefixes.map(borrarPrefijo));
    };
    await borrarPrefijo(ctx.storage().ref());
  });
}

// Ejecuta una funcion con las reglas desactivadas, para sembrar datos.
async function seed(env, fn) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

// Devuelve un Firestore autenticado como `uid`, con su documento de usuario ya creado.
async function withRole(env, uid, rol, extra = {}) {
  await seed(env, async (db) => {
    await db.collection('usuarios').doc(uid).set({
      id_usuario: uid,
      correo: `${uid}@test.com`,
      nombre_completo: `Usuario ${uid}`,
      rol,
      estado: 'activo',
      ...extra,
    });
  });
  return env.authenticatedContext(uid).firestore();
}

function anon(env) {
  return env.unauthenticatedContext().firestore();
}

module.exports = { makeEnv, seed, withRole, anon, limpiarStorage, UIDS };
