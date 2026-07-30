const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const UIDS = {
  owner1: 'uid-owner-1',
  owner2: 'uid-owner-2',
  taller1: 'uid-taller-1',
  taller2: 'uid-taller-2',
  admin: 'uid-admin-1',
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

module.exports = { makeEnv, seed, withRole, anon, UIDS };
