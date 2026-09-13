'use strict';

/**
 * SEC-04 — enforcement de App Check para Cloud Functions v1.
 *
 * En Functions **v2** el enforcement es una opcion declarativa
 * (`enforceAppCheck: true`) y en Firestore/Storage es un interruptor de la
 * consola de Firebase. En **v1**, que es lo que usa este repo, no existe
 * ninguna de las dos cosas: hay que mirar `context.app` dentro de cada
 * `onCall`. Por eso activar App Check en la consola no protegia ni una de las
 * Cloud Functions de este proyecto, aunque el cliente llevara firmando desde
 * `lib/main.dart:183`.
 *
 * El despliegue va en dos fases, como manda el runbook:
 *
 *   1. `monitor` (por defecto) — no rechaza nada, solo deja rastro en los logs
 *      de cada llamada sin token. Sirve para medir cuantos clientes reales se
 *      quedarian fuera antes de cerrar la puerta.
 *   2. `enforce` — rechaza. Se activa con `APP_CHECK_ENFORCEMENT=enforce`
 *      cuando las metricas de la consola pasen del 98 % de tokens validos.
 *
 * `off` existe para poder desactivarlo entero en una emergencia sin desplegar
 * codigo nuevo.
 */

const functions = require('firebase-functions');

const MODOS = ['off', 'monitor', 'enforce'];

/**
 * Ni `off` (inseguro en silencio) ni `enforce` (una errata de configuracion
 * dejaria fuera a la app entera). Monitor es el unico valor por defecto que ni
 * abre la puerta ni tira a nadie.
 */
const MODO_POR_DEFECTO = 'monitor';

/**
 * @param {object} [env] normalmente `process.env`
 * @returns {'off'|'monitor'|'enforce'}
 */
function modoDeEnforcement(env = process.env) {
  const bruto = String((env && env.APP_CHECK_ENFORCEMENT) || '')
    .trim()
    .toLowerCase();
  return MODOS.includes(bruto) ? bruto : MODO_POR_DEFECTO;
}

/**
 * Exige que la llamada traiga un token de App Check valido.
 *
 * Firebase ya valido el token antes de llegar aqui: si `context.app` esta
 * presente, el token era autentico. Lo que falta —y es lo que hace esta
 * funcion— es **decidir que hacer cuando no esta**.
 *
 * @param {object} context el `context` del `onCall`
 * @param {string} nombre nombre del callable, solo para el log
 * @param {{modo?: string, registrar?: Function}} [opciones]
 */
function exigirAppCheck(context, nombre, opciones = {}) {
  if (context && context.app) return;

  const modo = opciones.modo || modoDeEnforcement();
  if (modo === 'off') return;

  if (modo === 'monitor') {
    const registrar = opciones.registrar || console.warn;
    registrar(
      `[App Check] llamada sin token a ${nombre} (uid=${
        (context && context.auth && context.auth.uid) || 'anonimo'
      }). En modo monitor NO se rechaza.`
    );
    return;
  }

  // El mensaje es deliberadamente opaco: nombrar App Check, el proveedor o la
  // variable de configuracion le dice al atacante contra que esta chocando.
  // El detalle util queda en el log del servidor, no en la respuesta.
  console.warn(
    `[App Check] RECHAZADA llamada sin token a ${nombre} (uid=${
      (context && context.auth && context.auth.uid) || 'anonimo'
    })`
  );
  throw new functions.https.HttpsError(
    'failed-precondition',
    'No se pudo verificar la aplicación. Actualiza a la última versión e inténtalo de nuevo.'
  );
}

module.exports = {
  MODOS,
  MODO_POR_DEFECTO,
  modoDeEnforcement,
  exigirAppCheck,
};
