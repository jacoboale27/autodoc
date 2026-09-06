'use strict';

/**
 * Compuerta para `sincronizarReservaYReparacionAlCotizar` (Ronda 2, FIX 4).
 *
 * Ese trigger toma `after.id_reserva` de la cotizacion — dato que escribe
 * quien crea la cotizacion (ver firestore.rules, match /cotizaciones,
 * `allow create` solo exige `id_mecanico == auth.uid`) — y con el Admin SDK
 * fuerza `estado` sobre `reservas/{id_reserva}` sin comprobar que esa reserva
 * tenga nada que ver con la cotizacion. Encadenado al ataque de auto-
 * aceptacion de FIX 1 (una cotizacion sobre un vehiculo ajeno, aceptada por
 * el propio mecanico), un mecanico podia apuntar `id_reserva` a la reserva de
 * OTRO cliente cualquiera y voltearle el estado — sin relacion alguna con el
 * vehiculo, el propietario ni el taller de esa reserva.
 *
 * `db` se inyecta por el mismo motivo que en `aceptarCotizacion.js`: leer
 * `admin.firestore` dispara `ensureApp()`, hostil para stubbear en tests sin
 * emulador.
 */

/**
 * ¿La reserva pertenece a los MISMOS participantes que la cotizacion? Exige
 * el mismo propietario Y el mismo taller — ambos campos existen en los dos
 * modelos (`ReservaModel`/`CotizacionModel`, `id_propietario`/`id_taller`).
 *
 * @param {?object} reserva documento de `reservas/{id}` (o `null` si no existe)
 * @param {{id_propietario: string, id_taller: string}} cotizacion
 * @returns {boolean}
 */
function reservaPerteneceACotizacion(reserva, cotizacion) {
  if (!reserva) return false;
  const cot = cotizacion || {};
  return (
    !!reserva.id_propietario &&
    !!cot.id_propietario &&
    reserva.id_propietario === cot.id_propietario &&
    !!reserva.id_taller &&
    !!cot.id_taller &&
    reserva.id_taller === cot.id_taller
  );
}

/**
 * Sincroniza el estado de la reserva ligada a una cotizacion aceptada o
 * rechazada, SOLO si la reserva pertenece de verdad a esa cotizacion.
 *
 * Devuelve `true` si escribio, `false` si no habia nada que sincronizar o la
 * reserva no correspondia (se registra por consola, no se lanza: no es un
 * fallo del que valga la pena reintentar, es un intento de manipular una
 * reserva ajena, y el trigger hermano `onCotizacionAceptada` ya es el que
 * lleva la contabilidad de fallos de autorizacion).
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{cotizacionId: string, cotizacion: object, nuevoEstadoReserva: string, fechaHoraConfirmada: ?any}} args
 * @returns {Promise<boolean>}
 */
async function sincronizarReservaAlCotizar(
  db,
  { cotizacionId, cotizacion, nuevoEstadoReserva, fechaHoraConfirmada }
) {
  const reservaId = cotizacion && cotizacion.id_reserva;
  if (!reservaId) return false;

  const reservaSnap = await db.collection('reservas').doc(reservaId).get();
  const reserva = reservaSnap.exists ? reservaSnap.data() : null;

  if (!reservaPerteneceACotizacion(reserva, cotizacion)) {
    console.error(
      `sincronizarReservaYReparacionAlCotizar: la cotizacion ${cotizacionId} ` +
        `apunta a reservas/${reservaId}, pero esa reserva no pertenece al ` +
        'mismo propietario/taller que la cotizacion; no se escribe nada.'
    );
    return false;
  }

  const update = { estado: nuevoEstadoReserva };
  if (nuevoEstadoReserva === 'confirmada' && fechaHoraConfirmada) {
    update.fecha_hora_confirmada = fechaHoraConfirmada;
  }
  await db.collection('reservas').doc(reservaId).update(update);
  return true;
}

module.exports = { reservaPerteneceACotizacion, sincronizarReservaAlCotizar };
