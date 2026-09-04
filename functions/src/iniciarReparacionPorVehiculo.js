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
 * `verificarAperturaManual` replica, del lado servidor, las dos
 * comprobaciones que tenia la vieja regla `allow create` de /reparaciones
 * (ver el diff que la sustituyo por `if false`): vinculo del taller al
 * vehiculo (o walk-in si el vehiculo todavia no tiene ninguno vinculado) —
 * y ademas exige lo mismo que `ReparacionProvider.recibirVehiculo` exige del
 * lado cliente: una cotizacion aceptada para ese vehiculo+taller.
 *
 * `db` se inyecta por el mismo motivo que en aceptarCotizacion.js: leer
 * `admin.firestore` dispara `ensureApp()`, lo que hace hostil stubbearlo
 * desde los tests.
 */

/**
 * ¿El taller puede operar este vehiculo? Mismo criterio que la vieja regla
 * `allow create` de /reparaciones: o el vehiculo no tiene ningun taller
 * vinculado todavia (walk-in), o el taller que llama YA es uno de los
 * vinculados.
 *
 * @param {string[]} talleresVinculados
 * @param {string} idTaller
 * @returns {boolean}
 */
function vehiculoVinculadoOWalkIn(talleresVinculados, idTaller) {
  const lista = talleresVinculados || [];
  return lista.length === 0 || lista.includes(idTaller);
}

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

  const talleresVinculados = vehiculoDoc.data().talleres_vinculados || [];
  if (!vehiculoVinculadoOWalkIn(talleresVinculados, idTaller)) {
    return {
      ok: false,
      code: 'permission-denied',
      message: 'Este vehículo está vinculado a otro taller.',
    };
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
  vehiculoVinculadoOWalkIn,
  existeCotizacionAceptada,
  verificarAperturaManual,
};
