'use strict';

/**
 * Doble del cliente de Gemini para los EMULADORES.
 *
 * **El problema que resuelve.** La suite E2E corre contra emuladores, y el
 * emulador de Functions no tiene Secret Manager: `claveDelEntorno()` lanza y
 * `asistenteAutoDoc` responde `failed-precondition` a todo. O sea que sin
 * esto la pantalla del asistente solo se puede probar en su estado de error,
 * que es justo la mitad que menos importa.
 *
 * Las tres salidas posibles eran: gastar cuota real en cada corrida (cara, no
 * reproducible y dependiente de que Google este de pie), probar solo los
 * caminos de error, o esto. Esto es ademas lo unico **determinista**: un
 * modelo de verdad redacta distinto en cada corrida, y una suite E2E que
 * afirme sobre prosa generada es una suite que se pone roja sola.
 *
 * **Lo que NO hace, y es lo importante:** no simula al modelo. Reproduce el
 * CONTRATO —clasificar devuelve una etiqueta del enum, redactar devuelve
 * prosa a partir del envelope— para que el E2E ejercite el codigo de
 * alrededor: la autorizacion, el cupo, el interruptor, la cache, el mapeo de
 * errores y la pantalla. Lo que un modelo de verdad hace con un prompt se
 * mide en los evals, no aqui.
 *
 * **Por que la prosa sale del envelope y no es un texto fijo.** Un texto fijo
 * pasaria el E2E aunque el envelope llegara vacio, aunque llegara el de otro
 * usuario o aunque no llegara. Derivarla de los items es lo que convierte el
 * E2E en una prueba de que el dato correcto cruzo las cinco capas.
 */

/**
 * Nombre visible del modelo. Se elige para que **delate** en un log: si
 * alguna vez aparece en produccion, se lee de un vistazo que lo que se
 * sirvio fue una respuesta enlatada.
 */
const MODELO_FALSO = 'emulador-sin-modelo';

/**
 * Prefijo del prompt del clasificador en `asistente.js`. Es como el doble
 * sabe que le estan pidiendo, sin que haga falta pasarle una bandera por
 * fuera del contrato: recibe lo mismo que recibiria Gemini.
 */
const PREFIJO_CLASIFICADOR = 'Clasifica la pregunta';

/**
 * Marcadores para provocar un fallo a proposito.
 *
 * Existen porque hay estados de la pantalla que no se pueden alcanzar de otra
 * forma: el proveedor caido y el timeout no se pueden provocar sembrando
 * Firestore, a diferencia del cupo agotado y del interruptor apagado, que si.
 * Solo viven aqui, o sea solo en el emulador.
 *
 * **Son solo letras y espacios, y eso no es estetica.** La primera version
 * uso `#fallo-proveedor`, y `normalizar()` de `asistente.js` borra todo lo
 * que no sea letra, numero o espacio ANTES de que la pregunta llegue al
 * cliente: lo que recibia el doble era `fallo proveedor`, que no casaba con
 * nada. Los marcadores estaban muertos desde el primer dia y su test estaba
 * VERDE, porque llamaba a `generar()` a pelo y se saltaba `normalizar`. Es el
 * patron que este repositorio ya tiene documentado dos veces: un test que
 * ejercita una puerta distinta de la que dice probar.
 *
 * Por eso el test de estos marcadores pasa AHORA por `normalizar()`, y por
 * eso las claves estan escritas ya normalizadas.
 */
const FALLOS = {
  'probar fallo proveedor': {
    code: 'unavailable',
    detalle: 'proveedor',
    mensaje: 'Proveedor caido.',
  },
  'probar fallo lento': {
    code: 'deadline-exceeded',
    mensaje: 'El modelo no respondio a tiempo.',
  },
  'probar fallo bloqueado': {
    code: 'aborted',
    detalle: 'SAFETY',
    mensaje: 'Respuesta bloqueada.',
  },
};

/**
 * Palabras que bastan para clasificar en el doble, **en los dos idiomas**.
 *
 * El ingles no es un extra: el bundle de E2E se renderiza en ingles porque
 * Chromium arranca con el locale del sistema, asi que TODAS las preguntas de
 * la suite llegan en ingles. Con solo pistas en espanol, «what expires in the
 * next days» no casaba con nada y caia a `fuera_de_alcance` — y el test del
 * rechazo pasaba por eso, acertando por accidente mientras los tres de agenda
 * fallaban. Un doble que solo entiende el idioma en el que no corre la suite
 * es un doble que miente.
 */
const PISTAS_AGENDA = [
  'alerta',
  'vence',
  'vencimiento',
  'cita',
  'mantenimiento',
  'agenda',
  'km',
  'expire',
  'appointment',
  'maintenance',
  'schedule',
  'alert',
  'due date',
];
/**
 * `explicar` se reconoce por TERMINOS DEL DOMINIO, no por «que es».
 *
 * El primer intento uso `'que es'` y `'what is'`, y con eso «what is the
 * capital of France» salia `explicar`: una pregunta de fuera del alcance
 * clasificada como buena. Un doble que se equivoca asi le da verde a un E2E
 * que deberia estar rojo.
 */
const PISTAS_EXPLICAR = [
  'soat',
  'tecnomecanica',
  'tecno mecanica',
  'tarjeta de operacion',
  'tramite',
  'revision tecnica',
];

function errorFalso(codigo, mensaje, detalle) {
  const e = new Error(mensaje);
  e.code = codigo;
  if (detalle !== undefined) e.detalle = detalle;
  return e;
}

function sinTildes(texto) {
  return String(texto || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();
}

/**
 * La etiqueta que devolveria el clasificador.
 *
 * **`agenda` se comprueba ANTES que `explicar`**, y el orden decide casos
 * reales: «cuando vence mi SOAT» menciona un documento pero es una pregunta
 * de agenda, no de que-es-esto. Al reves, «que es el SOAT» no lleva ningun
 * verbo de agenda, asi que cae en `explicar` sin ambiguedad.
 *
 * (La primera version comentaba justo lo contrario, y el comentario era
 * falso: `soat` no estaba en las pistas de agenda, asi que el solape que
 * decia evitar no existia.)
 */
function clasificar(pregunta) {
  const limpio = sinTildes(pregunta);
  if (PISTAS_AGENDA.some((p) => limpio.indexOf(p) !== -1)) return 'agenda';
  if (PISTAS_EXPLICAR.some((p) => limpio.indexOf(p) !== -1)) return 'explicar';
  return 'fuera_de_alcance';
}

/** Prosa derivada del envelope. Una frase por item, con sus numeros. */
function redactar(envelope) {
  const items = (envelope && envelope.items) || [];
  if (!items.length) return 'No hay nada pendiente.';

  const frases = items.map((item) => {
    const placa = item.placa ? ' (' + item.placa + ')' : '';
    if (typeof item.km_restantes === 'number') {
      // En kilometros, NUNCA en dias: es la regla dura del §1.3 del plan, y
      // el doble la respeta para que el E2E pueda afirmarla.
      return item.nombre + placa + ': faltan ' + item.km_restantes + ' km';
    }
    if (typeof item.dias_restantes === 'number') {
      const d = item.dias_restantes;
      const cuando = d < 0 ? 'vencido hace ' + Math.abs(d) + ' dias' : 'en ' + d + ' dias';
      return (item.tipo || 'compromiso') + placa + ': ' + cuando;
    }
    return (item.tipo || 'compromiso') + placa + ': revisa los datos';
  });

  return frases.join('. ') + '.';
}

/**
 * Crea el doble. Misma forma que `crearClienteGemini`: `{ modelo, generar }`.
 *
 * @returns {{modelo: string, generar: Function}}
 */
function crearModeloFalso() {
  async function generar(peticion) {
    const sistema = String((peticion && peticion.sistema) || '');
    const usuario = String((peticion && peticion.usuario) || '');

    const marcador = Object.keys(FALLOS).find((m) => usuario.indexOf(m) !== -1);
    if (marcador) {
      const f = FALLOS[marcador];
      throw errorFalso(f.code, f.mensaje, f.detalle);
    }

    if (sistema.indexOf(PREFIJO_CLASIFICADOR) === 0) {
      return clasificar(usuario);
    }

    // El redactor recibe el envelope serializado; el explicador, la pregunta
    // cruda. Distinguirlos por el contenido y no por una bandera mantiene el
    // doble pegado al contrato real.
    let envelope = null;
    try {
      const posible = JSON.parse(usuario);
      if (posible && Array.isArray(posible.items)) envelope = posible;
    } catch (e) {
      envelope = null;
    }

    if (envelope) return redactar(envelope);

    return 'Explicacion de emulador para: ' + usuario.slice(0, 120);
  }

  return { modelo: MODELO_FALSO, generar };
}

module.exports = {
  MODELO_FALSO,
  PREFIJO_CLASIFICADOR,
  FALLOS,
  clasificar,
  redactar,
  crearModeloFalso,
};
