// Guarda de despliegue: aborta si un `functions/.env*` intenta hacerse pasar
// por un emulador.
//
// Se invoca desde el `predeploy` del bloque `functions` de `firebase.json`,
// que es el unico punto por el que pasa todo `firebase deploy --only
// functions`.
//
// **Que protege.** `functions/src/clienteDelModelo.js` decide entre Gemini y
// el doble de emulador mirando `FUNCTIONS_EMULATOR === 'true'`. La pone el
// propio emulador de Firebase (`firebase-tools/lib/emulator/
// functionsEmulator.js:993`) y no existe en una funcion desplegada, asi que
// como compuerta es solida frente a un descuido de codigo. Lo que NO cubre es
// la CONFIGURACION: este proyecto manda variables al runtime por
// `functions/.env.<projectId>` —el mecanismo de `APP_CHECK_ENFORCEMENT`—, y
// **`FUNCTIONS_EMULATOR` no esta en la lista de claves reservadas de
// firebase-tools** (`lib/functions/env.js`, `RESERVED_KEYS`; comprobado con
// la version 15.28.2). Una linea ahi viajaria al proceso desplegado y abriria
// la compuerta.
//
// La consecuencia seria el peor fallo posible de esa pieza, porque es
// silencioso: el asistente serviria respuestas enlatadas con toda la pinta de
// ser buenas. Nada falla, nadie ve un error, y los numeros que lee la persona
// salen de una plantilla en vez de sus datos.
//
// **Por que una guarda de despliegue y no un test.** Los `.env.<projectId>`
// estan en `functions/.gitignore`: no se versionan, se editan a mano por
// proyecto y **ninguna suite del repositorio puede verlos**. Es exactamente
// la forma del incidente del 2026-09-13 — el fuente estaba bien y lo
// contaminado era lo que se desplegaba — y la respuesta es la misma que
// entonces: mirar el artefacto justo antes de publicarlo.
//
// **Por que no un segundo candado en el codigo.** La via natural seria
// exigir ademas que no exista `K_SERVICE`, que es reservada y por tanto no se
// puede poner desde un `.env`. Pero **el emulador tambien define `K_SERVICE`**
// (`functionsEmulator.js:987`), asi que ese candado dejaria al E2E sin doble:
// el arreglo habria roto justo lo que venia a permitir. Comprobado antes de
// descartarlo.
//
// Uso directo (util antes de desplegar a mano):
//   node scripts/verificar_env_functions.js

'use strict';

const fs = require('fs');
const path = require('path');

const DIRECTORIO = path.join(__dirname, '..', 'functions');

/**
 * Claves que no pueden aparecer en un `.env` de funciones, con el motivo.
 *
 * `ASISTENTE_MODELO_REAL` NO esta: es la escotilla legitima para hablar con
 * Gemini de verdad desde el emulador, y en produccion no hace nada.
 */
const PROHIBIDAS = {
  FUNCTIONS_EMULATOR:
    'hace que la funcion desplegada se crea un emulador y sirva respuestas ' +
    'enlatadas del doble de `modeloFalso.js` en vez de hablar con Gemini',
  FIRESTORE_EMULATOR_HOST:
    'redirige el Admin SDK al Firestore de otra maquina: la funcion ' +
    'desplegada dejaria de leer y escribir los datos reales',
  FIREBASE_AUTH_EMULATOR_HOST: 'redirige Auth de la funcion desplegada a un emulador',
  FIREBASE_STORAGE_EMULATOR_HOST: 'redirige Storage de la funcion desplegada a un emulador',
};

/** Los `.env` que firebase-tools despliega. `.env.local` es solo del emulador. */
function ficherosDeEntorno() {
  if (!fs.existsSync(DIRECTORIO)) return [];
  return fs
    .readdirSync(DIRECTORIO)
    .filter((n) => n === '.env' || (n.startsWith('.env.') && n !== '.env.local'))
    .filter((n) => !n.endsWith('.example'));
}

/** Clave de cada linea, ignorando comentarios. No interpreta valores. */
function clavesDe(contenido) {
  return contenido
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && l[0] !== '#')
    .map((l) => {
      const m = /^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=/.exec(l);
      return m ? m[1] : null;
    })
    .filter(Boolean);
}

function verificar() {
  const problemas = [];

  for (const nombre of ficherosDeEntorno()) {
    const ruta = path.join(DIRECTORIO, nombre);
    let claves;
    try {
      claves = clavesDe(fs.readFileSync(ruta, 'utf8'));
    } catch (e) {
      problemas.push('No se pudo leer functions/' + nombre + ': ' + e.message);
      continue;
    }
    for (const clave of claves) {
      if (Object.prototype.hasOwnProperty.call(PROHIBIDAS, clave)) {
        problemas.push(
          'functions/' + nombre + ' define ' + clave + ', y ' + PROHIBIDAS[clave] + '.'
        );
      }
    }
  }

  return problemas;
}

if (require.main === module) {
  const problemas = verificar();
  if (problemas.length) {
    console.error('');
    console.error('DESPLIEGUE ABORTADO — un .env de funciones simula un emulador:');
    console.error('');
    problemas.forEach((p) => console.error('  - ' + p));
    console.error('');
    console.error('Retira esas claves de functions/.env* antes de desplegar.');
    console.error('Si de verdad hacen falta, van en functions/.env.local, que');
    console.error('solo lee el emulador y no se despliega.');
    console.error('');
    process.exit(1);
  }
  console.log('OK: ningun .env de functions simula un emulador.');
}

module.exports = { PROHIBIDAS, ficherosDeEntorno, clavesDe, verificar };
