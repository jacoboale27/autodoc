'use strict';

/**
 * Compuerta A3/B2 para el callable `iniciarReparacionPorVehiculo`.
 *
 * Hallazgo 1 de la revision de la Tarea 4 (A4b): ese callable corre con
 * Admin SDK, asi que `firestore.rules` (que en /reparaciones tiene desde A4b
 * `allow create: if false`) no lo alcanza. Antes de este arreglo abria un
 * ticket en 'recibido' sin exigir ni una cotizacion aceptada ni que el
 * taller estuviera vinculado al vehiculo — la unica puerta server-side que
 * quedaba abierta para recibir un vehiculo sin que nadie hubiera aceptado
 * nada, justo lo que A3 prohibe.
 *
 * `verificarAperturaManual` exige, del lado servidor, lo mismo que
 * `ReparacionProvider.recibirVehiculo` exige del lado cliente: una cotizacion
 * en estado 'aceptada' para ese vehiculo+taller.
 *
 * RONDA 3: antes exigia ADEMAS que el taller ya estuviera en
 * `talleres_vinculados` del vehiculo (o que la lista estuviera vacia). Esa
 * condicion era circular — la lista solo se escribe al TERMINAR un servicio,
 * asi que un segundo taller no podia recibir el coche jamas — y era ademas
 * redundante: `estado == 'aceptada'` solo lo puede poner el propio dueño del
 * vehiculo (firestore.rules, /cotizaciones update, invariante A1), y ese es
 * un consentimiento mas fuerte que haber sido atendido antes. Se retira aqui
 * por el mismo motivo que en `aceptarCotizacion.js`.
 *
 * `db` se inyecta por el mismo motivo que en aceptarCotizacion.js: leer
 * `admin.firestore` dispara `ensureApp()`, lo que hace hostil stubbearlo
 * desde los tests.
 */

/**
 * ¿Existe una cotizacion en estado 'aceptada' para este vehiculo+taller?
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{idVehiculo: string, idTaller: string}} args
 * @returns {Promise<boolean>}
 */
async function existeCotizacionAceptada(db, { idVehiculo, idTaller }) {
  const snap = await db
    .collection('cotizaciones')
    .where('id_vehiculo', '==', idVehiculo)
    .where('id_taller', '==', idTaller)
    .where('estado', '==', 'aceptada')
    .limit(1)
    .get();
  return !snap.empty;
}

/**
 * Verifica que el callable pueda abrir (o reutilizar) el ticket para este
 * vehiculo+taller. Se llama DESPUES de `actuaPorTaller` (que ya confirma
 * quien es el llamante), y ANTES de `crearOReutilizarTicketReparacion`.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{idVehiculo: string, idTaller: string}} args
 * @returns {Promise<{ok: true} | {ok: false, code: string, message: string}>}
 */
async function verificarAperturaManual(db, { idVehiculo, idTaller }) {
  const vehiculoDoc = await db.collection('vehiculos').doc(idVehiculo).get();
  if (!vehiculoDoc.exists) {
    return { ok: false, code: 'not-found', message: 'Vehículo no encontrado.' };
  }

  const hayAceptada = await existeCotizacionAceptada(db, { idVehiculo, idTaller });
  if (!hayAceptada) {
    return {
      ok: false,
      code: 'failed-precondition',
      message:
        'Este vehículo no tiene una cotización aceptada en tu taller, así ' +
        'que todavía no hay nada que recibir.',
    };
  }

  return { ok: true };
}

module.exports = {
  existeCotizacionAceptada,
  verificarAperturaManual,
};
