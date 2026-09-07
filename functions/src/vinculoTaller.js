'use strict';

const { FieldValue } = require('firebase-admin/firestore');
const { ESTADOS_TICKET_CERRADO } = require('./aceptarCotizacion');

/**
 * RONDA 5 — el vinculo taller-vehiculo sigue a la POSESION del coche, no a la
 * historia.
 *
 * Hasta aqui, `vehiculos.talleres_vinculados` se escribia al ACEPTARSE la
 * cotizacion y no se borraba nunca. Eso le daba al taller acceso permanente e
 * irrevocable a la ficha del coche, su galeria, sus alertas, sus
 * mantenimientos y su historial de mantenimientos — desde antes de que el
 * coche llegara al taller y para siempre despues de que se fuera.
 *
 * Que ese acceso no hiciera falta se comprueba facil: el historial de trabajo
 * del propio taller (`servicios`) se autoriza por `actuaPorTaller(id_taller)`
 * en firestore.rules, NO por este vinculo. Un taller conserva sus propios
 * registros aunque pierda el vinculo; lo unico que el vinculo le da de mas,
 * pasada la visita, es leer la ficha ajena y el historial que escribieron
 * OTROS talleres.
 *
 * Asi que el vinculo pasa a nacer y morir con la visita:
 *   - se OTORGA al recibir el vehiculo (`pendiente_recepcion` -> `recibido`),
 *     que es el momento en que el coche esta fisicamente en el taller;
 *   - se REVOCA cuando el ticket se cierra (`ESTADOS_TICKET_CERRADO`), que
 *     desde la ronda 6 es 'entregado' o 'cancelado' — el momento en que el
 *     coche SALE. Antes lo cerraba `listo_para_entrega`, que revocaba el
 *     acceso con el coche todavia aparcado en el taller.
 *
 * `talleres_vinculados` pasa a significar «este taller tiene el coche ahora
 * mismo», que es una frase verificable, en vez de «este taller paso por aqui
 * alguna vez».
 *
 * `db` se inyecta por el mismo motivo que en `aceptarCotizacion.js`: leer
 * `admin.firestore` dispara `ensureApp()`, hostil para stubbear en tests.
 */

/** Estado en el que nace el ticket, antes de que el coche llegue. */
const ESTADO_PENDIENTE_RECEPCION = 'pendiente_recepcion';
const ESTADO_RECIBIDO = 'recibido';

/**
 * Errores del callable de recepcion, con `code` traducible a HttpsError. Se
 * distinguen para que el cliente pueda decir QUE pasa en vez de un
 * `internal` pelado: "este ticket esta cancelado" y "no hay ticket" llevan a
 * acciones distintas.
 */
class ErrorRecepcion extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

/**
 * ¿Este cambio de estado cierra el ticket, y por tanto devuelve el coche?
 *
 * Solo cuenta la TRANSICION de abierto a cerrado. Sin esa condicion, cualquier
 * escritura posterior sobre un ticket ya cerrado (una correccion, un reintento
 * del propio trigger) volveria a revocar — inofensivo hoy, pero dejaria de
 * serlo en cuanto el vehiculo se vincule de nuevo por una visita nueva:
 * revocaria el vinculo VIVO de la visita siguiente.
 *
 * @param {object} antes documento previo de `reparaciones`
 * @param {object} despues documento resultante
 * @returns {boolean}
 */
function debeRevocarVinculo(antes, despues) {
  const estadoAntes = ((antes && antes.estado) || ESTADO_RECIBIDO).toString();
  const estadoDespues = ((despues && despues.estado) || ESTADO_RECIBIDO).toString();
  if (estadoAntes === estadoDespues) return false;
  if (ESTADOS_TICKET_CERRADO.includes(estadoAntes)) return false;
  return ESTADOS_TICKET_CERRADO.includes(estadoDespues);
}

/**
 * Quita a este taller de `talleres_vinculados` del vehiculo.
 *
 * No usa transaccion ni lee antes: `arrayRemove` es idempotente y no necesita
 * saber si el uid estaba. Tampoco falla si el vehiculo ya no existe — el dueño
 * pudo borrarlo — porque eso no es un error que reintentar: si no hay
 * vehiculo, no hay vinculo que revocar.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{idVehiculo: string, idTaller: string}} args
 * @returns {Promise<boolean>} `true` si se escribio
 */
async function revocarVinculo(db, { idVehiculo, idTaller }) {
  if (!idVehiculo || !idTaller) return false;
  try {
    await db.collection('vehiculos').doc(idVehiculo).update({
      talleres_vinculados: FieldValue.arrayRemove(idTaller),
    });
    return true;
  } catch (error) {
    if (error && (error.code === 5 || error.code === 'not-found')) return false;
    throw error;
  }
}

/**
 * Recibe el vehiculo de un ticket: lo mueve a `recibido` y otorga el vinculo,
 * en UNA sola escritura atomica.
 *
 * Va en el servidor —y no en el cliente, como hasta ahora— porque las dos
 * mitades tienen que pasar juntas y el cliente no puede escribir la segunda
 * (`firestore.rules` solo le deja tocar `kilometraje_actual` del vehiculo).
 * Partirlo en "el cliente mueve el ticket, un trigger otorga el vinculo"
 * tampoco vale: el trigger es asincrono, y la pantalla que recibe el vehiculo
 * necesita leer la ficha INMEDIATAMENTE despues para seguir trabajando.
 *
 * Idempotente: recibir dos veces no es un error. Si el ticket ya paso de
 * `pendiente_recepcion` devuelve `recibidoAhora: false` sin escribir el
 * estado, pero SI reasegura el vinculo — asi un ticket legado, abierto antes
 * de que existiera este flujo, recupera el acceso al reabrirlo en vez de
 * quedarse permanentemente sin ficha.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{idReparacion: string, ahora: Date}} args
 * @returns {Promise<{idVehiculo: string, idTaller: string, recibidoAhora: boolean}>}
 */
async function recibirTicketYVincular(db, { idReparacion, ahora }) {
  const ref = db.collection('reparaciones').doc(idReparacion);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new ErrorRecepcion('not-found', 'Este ticket de servicio ya no existe.');
  }

  const ticket = snap.data();
  // Los tickets anteriores a A4b no traen `estado`; nacian en 'recibido'.
  const estado = (ticket.estado || ESTADO_RECIBIDO).toString();
  const idVehiculo = (ticket.id_vehiculo || '').toString();
  const idTaller = (ticket.id_taller || '').toString();

  // Un ticket ya CERRADO no se puede recibir: la visita termino. Recibir uno
  // volveria a otorgar el vinculo al vehiculo sobre una visita que ya no
  // existe — exactamente el acceso permanente que este diseño elimina.
  if (ESTADOS_TICKET_CERRADO.includes(estado)) {
    throw new ErrorRecepcion(
      'failed-precondition',
      estado === 'entregado'
        ? 'Este vehículo ya se entregó: hace falta una cotización aceptada ' +
            'nueva para volver a recibirlo.'
        : 'El ticket de este vehículo está cancelado: hace falta una ' +
            'cotización aceptada nueva.'
    );
  }
  if (!idVehiculo || !idTaller) {
    throw new ErrorRecepcion(
      'failed-precondition',
      'A este ticket le faltan datos para recibir el vehículo. Avisa a soporte ' +
        'con la placa.'
    );
  }

  const lote = db.batch();
  const recibidoAhora = estado === ESTADO_PENDIENTE_RECEPCION;
  if (recibidoAhora) {
    const historial = Array.isArray(ticket.historial_estados)
      ? ticket.historial_estados.slice()
      : [];
    historial.push({ estado: ESTADO_RECIBIDO, timestamp: ahora });
    lote.update(ref, {
      estado: ESTADO_RECIBIDO,
      historial_estados: historial,
      fecha_actualizacion: ahora,
    });
  }
  // El vinculo se reasegura siempre (ver la nota de idempotencia de arriba).
  //
  // Son DOS arrays con significados distintos y ciclos de vida distintos:
  //
  //   talleres_vinculados  "este taller tiene el coche AHORA". Se revoca al
  //                        cerrarse el ticket. Autoriza LEER la ficha.
  //   talleres_conocidos   "este taller ha tenido el coche alguna vez".
  //                        Append-only, nunca se revoca. Autoriza ESCRIBIR un
  //                        `servicios`/`historial_mantenimientos` mas.
  //
  // El segundo nace de la revision adversarial de la ronda 6: el carve-out de
  // walk-in de firestore.rules preguntaba si `talleres_vinculados` estaba
  // vacio para dejar pasar al primer taller de un coche nuevo. En cuanto la
  // ronda 5 empezo a revocar ese array, "vacio" paso a significar "coche ya
  // entregado", que es el estado de reposo de casi toda la flota — y con el,
  // cualquier taller podia inyectar un servicio falso en el historial de
  // cualquier cliente. Separar el "ahora" del "alguna vez" cierra el hueco sin
  // romper el walk-in legitimo.
  lote.update(db.collection('vehiculos').doc(idVehiculo), {
    talleres_vinculados: FieldValue.arrayUnion(idTaller),
    talleres_conocidos: FieldValue.arrayUnion(idTaller),
  });

  try {
    await lote.commit();
  } catch (error) {
    if (error && (error.code === 5 || error.code === 'not-found')) {
      throw new ErrorRecepcion(
        'not-found',
        'El vehículo de este ticket ya no existe: el propietario lo eliminó ' +
          'de su garaje.'
      );
    }
    throw error;
  }

  return { idVehiculo, idTaller, recibidoAhora };
}

module.exports = {
  ESTADO_PENDIENTE_RECEPCION,
  ESTADO_RECIBIDO,
  ErrorRecepcion,
  debeRevocarVinculo,
  revocarVinculo,
  recibirTicketYVincular,
};
