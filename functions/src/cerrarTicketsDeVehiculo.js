'use strict';

const admin = require('firebase-admin');
const { ESTADOS_TICKET_CERRADO, ticketAbierto } = require('./aceptarCotizacion');
// El centinela de migracion ya vive en un solo sitio: marca las escrituras del
// mantenimiento automatico para que las notificaciones no las traten como una
// novedad que contarle al propietario.
const { CAMPO_MIGRACION } = require('./migracion');

/**
 * Cierra los tickets de `reparaciones` que sigan abiertos sobre un vehiculo
 * que acaba de borrarse.
 *
 * Vivia inline dentro de `onVehicleDelete` (index.js) y se saca aqui por la
 * misma razon por la que ya salieron `vinculoTaller` y `caducarVinculos`: un
 * cuerpo de trigger no es ejercitable, y este es el escritor server-side cuyo
 * fallo mas caro cuesta. Desde el gap 9.1 el tablero consulta
 * `abierto == true` en vez de mirar `estado`, asi que un barrido que cierre el
 * ticket sin bajar `abierto` deja la tarjeta clavada en el tablero PARA
 * SIEMPRE, apuntando a una ficha que ya no existe. Antes el `whereIn` sobre
 * `estado` lo habria descartado igualmente; ahora ya no hay esa red.
 *
 * Los tickets NO se borran: son el registro del trabajo del taller, y su
 * `id_taller` es lo que autoriza su propio historial. Se cierran como
 * 'cancelado' y no como 'entregado' porque no consta que el coche saliera del
 * taller; lo que consta es que la visita ya no puede continuar.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{vehicleId: string, ahora?: Date, fieldValue?: object}} args
 * @returns {Promise<number>} cuantos tickets se cerraron
 */
async function cerrarTicketsDeVehiculo(db, { vehicleId, ahora, fieldValue } = {}) {
  const momento = ahora || new Date();
  const FieldValue = fieldValue || admin.firestore.FieldValue;

  const abiertos = await db
    .collection('reparaciones')
    .where('id_vehiculo', '==', vehicleId)
    .get();

  const cerrables = abiertos.docs.filter(
    (d) => !ESTADOS_TICKET_CERRADO.includes((d.data().estado || 'recibido').toString())
  );

  for (let i = 0; i < cerrables.length; i += 400) {
    const lote = db.batch();
    for (const d of cerrables.slice(i, i + 400)) {
      lote.update(d.ref, {
        estado: 'cancelado',
        // Derivado del estado que queda, igual que en el cliente y en las
        // reglas. `ticketAbierto('cancelado')` es false por definicion; se
        // escribe asi, y no como literal, para que las tres copias del
        // vocabulario de estados sigan siendo una sola idea.
        abierto: ticketAbierto('cancelado'),
        [CAMPO_MIGRACION]: true,
        historial_estados: FieldValue.arrayUnion({
          estado: 'cancelado',
          timestamp: momento,
        }),
        fecha_actualizacion: momento,
      });
    }
    await lote.commit();
  }

  return cerrables.length;
}

module.exports = { cerrarTicketsDeVehiculo };
