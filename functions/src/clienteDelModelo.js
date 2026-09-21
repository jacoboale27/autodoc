'use strict';

/**
 * Decide con que cliente de modelo corre el asistente: el de Gemini o el
 * doble de emulador.
 *
 * Vive en su propio modulo **para que la decision tenga tests**. Metida en
 * `functions/index.js` seria una linea dentro de un callable, o sea
 * exactamente donde este repositorio ya ha tenido dos defectos que ninguna
 * suite veia: el `iniciarReparacionPorVehiculo` de FUNC-02 y el `e.message`
 * que el gate encontro en este mismo asistente.
 *
 * **La compuerta es `FUNCTIONS_EMULATOR`, y la eleccion no es casual.** La
 * pone el propio emulador de Firebase y **no existe en una funcion
 * desplegada**: no es una bandera nuestra que alguien pueda encender por
 * error, ni un modo de build que se cuele en un artefacto. Esa es la
 * diferencia con el incidente del 2026-09-13, donde los dos candados
 * (`_flagEmuladores && !kReleaseMode`) SI podian abrirse a la vez en un build
 * `--profile` y el bundle de E2E acabo en produccion.
 *
 * **El doble es el DEFECTO en el emulador, no una opcion.** Al reves —exigir
 * una segunda variable para activarlo— la suite E2E dependeria de que esa
 * variable llegue viva hasta el proceso hijo que ejecuta las funciones, que
 * es justo la clase de suposicion que cuesta una tarde cuando falla. Y un
 * emulador sin clave no puede hacer nada util de todos modos. Quien quiera
 * hablar con Gemini de verdad desde el emulador pone
 * `ASISTENTE_MODELO_REAL=1`.
 */

const modeloGemini = require('./modeloGemini');
const { crearModeloFalso } = require('./modeloFalso');

/** La pone el emulador de Firebase. Nunca esta en una funcion desplegada. */
const VARIABLE_EMULADOR = 'FUNCTIONS_EMULATOR';

/** Escotilla para hablar con Gemini de verdad desde el emulador. */
const VARIABLE_MODELO_REAL = 'ASISTENTE_MODELO_REAL';

/**
 * `true` solo dentro del emulador y sin haber pedido el modelo real.
 *
 * La comparacion es con la cadena `'true'` exacta, no con un valor
 * verdadero: `FUNCTIONS_EMULATOR` es una variable de entorno, y ahi TODO es
 * cadena — `'false'` es un valor verdadero en JavaScript, asi que un
 * `if (env.FUNCTIONS_EMULATOR)` se abriria con `'false'` dentro.
 *
 * @param {object} [env]
 * @returns {boolean}
 */
function usaModeloFalso(env) {
  const e = env || {};
  return e[VARIABLE_EMULADOR] === 'true' && e[VARIABLE_MODELO_REAL] !== '1';
}

/**
 * El cliente que corresponde al entorno.
 *
 * @param {object} [env]
 * @returns {{modelo: string, generar: Function}}
 */
function crearClienteDelModelo(env) {
  const entorno = env || process.env;

  if (usaModeloFalso(entorno)) {
    // Ruidoso a proposito. Si esta linea apareciera alguna vez en los logs de
    // produccion, se lee de un vistazo que lo que se sirvio fue una respuesta
    // enlatada — que es el unico fallo de esta pieza que seria grave y
    // silencioso.
    console.warn(
      'asistente: EMULADOR — se usa el doble del modelo, no Gemini. ' +
        'Las respuestas son enlatadas. Pon ' +
        VARIABLE_MODELO_REAL +
        '=1 para hablar con Gemini de verdad.'
    );
    return crearModeloFalso();
  }

  return modeloGemini.crearClienteGemini({
    apiKey: modeloGemini.claveDelEntorno(entorno),
    env: entorno,
  });
}

module.exports = {
  VARIABLE_EMULADOR,
  VARIABLE_MODELO_REAL,
  usaModeloFalso,
  crearClienteDelModelo,
};
