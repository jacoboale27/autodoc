'use strict';

/**
 * A4b — la aceptacion de la cotizacion es lo que abre el ticket de
 * `reparaciones`.
 *
 * Antes el ticket nacia cuando el mecanico pulsaba "Recibir vehiculo"
 * (InitiateServiceScreen -> ReparacionRepository.iniciarReparacion). A3/B2
 * prohibe recibir un vehiculo sin una cotizacion aceptada, asi que si el
 * ticket siguiera naciendo ahi no naceria nunca: el ticket pasa a nacer aqui,
 * en el estado inicial `pendiente_recepcion` (el vehiculo ya esta comprometido
 * pero todavia no ha llegado al taller), y "recibir el vehiculo" queda
 * reducido a la transicion `pendiente_recepcion` -> `recibido`.
 *
 * La creacion vive en una Cloud Function con Admin SDK, nunca en el cliente:
 * necesita leer `vehiculos/{id}` completo (placa y propietario) sin las
 * restricciones de `talleres_vinculados` que aplican al mecanico, y ademas
 * permite cerrar `allow create` de `reparaciones` en firestore.rules.
 *
 * Todo lo testeable vive aqui, fuera del handler del trigger, y `db` se
 * inyecta: leer `admin.firestore` dispara `ensureApp()`, lo que hace hostil
 * stubbearlo desde los tests (ver la nota de functions/test/empleados.test.js).
 */

/** Prefijo del id derivado; ver `idTicketDeCotizacion`. */
const PREFIJO_TICKET = 'cot_';

/**
 * Id del ticket que corresponde a una cotizacion. Derivarlo del id de la
 * cotizacion (en vez de usar un id automatico) es lo que hace idempotente al
 * trigger: `onUpdate` no garantiza exactly-once, y un reintento escribe
 * entonces el MISMO documento en vez de abrir un segundo ticket.
 *
 * @param {string} cotizacionId
 * @returns {string}
 */
function idTicketDeCotizacion(cotizacionId) {
  return `${PREFIJO_TICKET}${cotizacionId}`;
}

/**
 * ¿Este cambio en `cotizaciones/{id}` es la aceptacion que abre el ticket?
 *
 * @param {object} antes documento previo
 * @param {object} despues documento resultante
 * @returns {boolean}
 */
function debeAbrirTicket(antes, despues) {
  const estadoDespues = despues && despues.estado;
  const estadoAntes = antes && antes.estado;
  if (estadoDespues !== 'aceptada') return false;
  // Ya estaba aceptada: es otra edicion del documento (o un reintento del
  // propio trigger), no la transicion que nos interesa.
  if (estadoAntes === 'aceptada') return false;
  return true;
}

/**
 * Documento a escribir en `reparaciones/{cot_<cotizacionId>}`. Funcion pura.
 *
 * Devuelve `null` cuando la cotizacion no ancla a un vehiculo, un taller y un
 * propietario concretos: sin esos tres campos el ticket no seria legible ni
 * por el taller ni por el dueño (ver firestore.rules, match /reparaciones).
 *
 * @param {{cotizacionId: string, cotizacion: object, vehiculo: ?object, ahora: Date}} args
 * @returns {?object}
 */
function construirTicketReparacion({ cotizacionId, cotizacion, vehiculo, ahora }) {
  const datosVehiculo = vehiculo || {};
  const idVehiculo = cotizacion.id_vehiculo || '';
  const idTaller = cotizacion.id_taller || '';
  // Las cotizaciones creadas desde el chat traen `id_propietario`; se cae al
  // dueño real del vehiculo por si alguna via no lo hubiera escrito.
  const idPropietario = cotizacion.id_propietario || datosVehiculo.id_propietario || '';
  if (!idVehiculo || !idTaller || !idPropietario) return null;

  return {
    id_reparacion: idTicketDeCotizacion(cotizacionId),
    id_cotizacion: cotizacionId,
    id_vehiculo: idVehiculo,
    id_taller: idTaller,
    id_propietario: idPropietario,
    placa: datosVehiculo.placa || cotizacion.placa || '',
    estado: 'pendiente_recepcion',
    historial_estados: [{ estado: 'pendiente_recepcion', timestamp: ahora }],
    fecha_creacion: ahora,
    fecha_actualizacion: ahora,
  };
}

/**
 * Abre el ticket de reparacion para una cotizacion recien aceptada.
 *
 * Devuelve el id del ticket creado, o `null` si no habia nada que crear
 * (el cambio no era una aceptacion, el vehiculo ya no existe, la cotizacion
 * no ancla a taller/propietario, o el ticket ya estaba abierto).
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{cotizacionId: string, antes: object, despues: object, ahora: Date}} evento
 * @returns {Promise<?string>}
 */
async function abrirTicketDeReparacion(db, { cotizacionId, antes, despues, ahora }) {
  if (!debeAbrirTicket(antes, despues)) return null;

  const ref = db.collection('reparaciones').doc(idTicketDeCotizacion(cotizacionId));
  // Idempotencia: el id ya garantiza que un reintento no duplica el ticket,
  // pero ademas no se reescribe si existe, para no arrastrar de vuelta a
  // `pendiente_recepcion` un ticket que el taller ya haya movido.
  const existente = await ref.get();
  if (existente.exists) return null;

  let vehiculo = null;
  if (despues.id_vehiculo) {
    const snap = await db.collection('vehiculos').doc(despues.id_vehiculo).get();
    if (snap.exists) vehiculo = snap.data();
  }
  if (!vehiculo) return null;

  const ticket = construirTicketReparacion({
    cotizacionId,
    cotizacion: despues,
    vehiculo,
    ahora,
  });
  if (!ticket) return null;

  await ref.set(ticket);
  return ref.id;
}

module.exports = {
  PREFIJO_TICKET,
  idTicketDeCotizacion,
  debeAbrirTicket,
  construirTicketReparacion,
  abrirTicketDeReparacion,
};
