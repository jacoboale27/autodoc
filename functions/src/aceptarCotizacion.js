'use strict';

const { vehiculoVinculadoOWalkIn } = require('./iniciarReparacionPorVehiculo');

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
 * Estados de `reparaciones` que cuentan como "cerrados": un vehiculo+taller
 * en uno de estos ya no tiene una visita en curso, asi que una cotizacion
 * aceptada nueva SI debe abrir un ticket propio. Cualquier otro estado
 * (incluido 'recibido' de un ticket anterior a A4b, sin `id_cotizacion') se
 * trata como abierto.
 */
const ESTADOS_TICKET_CERRADO = ['cancelado', 'listo_para_entrega'];

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
 * Revision de rama completa (hallazgo C1): `id_propietario` sale SIEMPRE del
 * vehiculo ya leido de Firestore, nunca de la cotizacion. La cotizacion es
 * dato que el mecanico que la crea controla (`cotizaciones` allow create
 * solo exige `id_mecanico == auth.uid`); tomar `id_propietario` de ahi
 * dejaba a cualquier mecanico abrir un ticket contra la victima de su
 * eleccion, con su propio uid como mecanico y el uid de un tercero como
 * "propietario" del ticket.
 *
 * @param {{cotizacionId: string, cotizacion: object, vehiculo: ?object, ahora: Date}} args
 * @returns {?object}
 */
function construirTicketReparacion({ cotizacionId, cotizacion, vehiculo, ahora }) {
  const datosVehiculo = vehiculo || {};
  const idVehiculo = cotizacion.id_vehiculo || '';
  const idTaller = cotizacion.id_taller || '';
  const idPropietario = datosVehiculo.id_propietario || '';
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
 * ¿Ya hay un ticket ABIERTO para este vehiculo+taller? (cualquier estado
 * fuera de `ESTADOS_TICKET_CERRADO`).
 *
 * Hallazgo 2 de la revision de la Tarea 4: antes de esto, el unico chequeo
 * de reuso era el id derivado `cot_<cotizacionId>` (ver
 * `idTicketDeCotizacion`), que solo detecta un REINTENTO de la MISMA
 * cotizacion. Un cliente que regresa (ticket antiguo sin `id_cotizacion`,
 * o simplemente una segunda cotizacion aceptada del mismo vehiculo en el
 * mismo taller) se colaba y terminaba con DOS tickets — uno de los cuales
 * `ReparacionRepository.buscarReparacionActiva` (sin orden ni filtro de
 * estado) podia devolver en vez del nuevo, dejando el ticket real sin tocar
 * en "Por recibir" mientras la pantalla reportaba éxito.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{idVehiculo: string, idTaller: string}} args
 * @returns {Promise<boolean>}
 */
/**
 * Tope de la query de dedup. Un vehiculo+taller legitimo nunca deberia
 * acumular mas de un puñado de tickets no cerrados (Blocker 3: la query no
 * tenia limite, asi que un vehiculo con muchos tickets historicos habria
 * escaneado la coleccion entera en cada aceptacion).
 */
const LIMITE_DEDUP_TICKETS_ABIERTOS = 20;

async function existeTicketAbiertoParaVehiculo(db, { idVehiculo, idTaller }) {
  const snap = await db
    .collection('reparaciones')
    .where('id_vehiculo', '==', idVehiculo)
    .where('id_taller', '==', idTaller)
    .limit(LIMITE_DEDUP_TICKETS_ABIERTOS)
    .get();
  return snap.docs.some((doc) => {
    const estado = (doc.data().estado || 'recibido').toString();
    return !ESTADOS_TICKET_CERRADO.includes(estado);
  });
}

/**
 * Abre el ticket de reparacion para una cotizacion recien aceptada.
 *
 * Devuelve el id del ticket creado, o `null` si no habia nada que crear
 * (el cambio no era una aceptacion, el vehiculo ya no existe, la cotizacion
 * no ancla a taller/propietario, el ticket ya estaba abierto para esta
 * cotizacion, o ya hay otro ticket abierto para el mismo vehiculo+taller).
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

  // Hallazgo 2: dedup por vehiculo+taller, no solo por cotizacion. Si ya hay
  // una visita en curso para este vehiculo en este taller, esta aceptacion
  // no abre un segundo ticket paralelo.
  if (despues.id_vehiculo && despues.id_taller) {
    const yaAbierto = await existeTicketAbiertoParaVehiculo(db, {
      idVehiculo: despues.id_vehiculo,
      idTaller: despues.id_taller,
    });
    if (yaAbierto) return null;
  }

  let vehiculo = null;
  if (despues.id_vehiculo) {
    const snap = await db.collection('vehiculos').doc(despues.id_vehiculo).get();
    if (snap.exists) vehiculo = snap.data();
  }
  if (!vehiculo) {
    console.warn(
      `onCotizacionAceptada: cotizacion ${cotizacionId} aceptada pero su ` +
        `vehiculo (${despues.id_vehiculo || 'sin id_vehiculo'}) no existe; ` +
        'no se abrio ningun ticket.'
    );
    return null;
  }

  // Revision de rama completa (hallazgo C1): este trigger es el UNICO
  // creador de `reparaciones` (allow create: if false), pero corria sin
  // ninguna de las comprobaciones que la vieja regla `allow create` hacia.
  // `cotizaciones` solo exige `id_mecanico == auth.uid` para crear (ver
  // firestore.rules, match /cotizaciones), asi que sin esto cualquier
  // mecanico podia redactar una cotizacion sobre el vehiculo de un
  // desconocido, aceptarsela a si mismo (antes de la Tarea de reglas 1a) y
  // que este trigger le abriera el ticket igual. Se reutiliza
  // `vehiculoVinculadoOWalkIn`, el mismo predicado que ya protege el
  // callable manual `iniciarReparacionPorVehiculo`, para no mantener dos
  // copias de la misma regla de autorizacion.
  if (!vehiculoVinculadoOWalkIn(vehiculo.talleres_vinculados, despues.id_taller)) {
    // No silenciar: esta NO es una cotizacion malformada, es un intento de
    // abrir un ticket sobre un vehiculo vinculado a OTRO taller. `console.error`
    // (en vez del `console.warn` de arriba) para que quede visible como fallo,
    // y el trigger relanza el error para que quede registrado como invocacion
    // fallida (ver el `catch` de `onCotizacionAceptada` en functions/index.js).
    console.error(
      `onCotizacionAceptada: cotizacion ${cotizacionId} aceptada por el ` +
        `taller ${despues.id_taller}, pero ese taller no esta vinculado al ` +
        `vehiculo ${despues.id_vehiculo}; no se abrio ningun ticket.`
    );
    throw new Error(
      `Taller ${despues.id_taller} no vinculado al vehiculo ${despues.id_vehiculo}; ` +
        `no se abre ticket para la cotizacion ${cotizacionId}.`
    );
  }

  const ticket = construirTicketReparacion({
    cotizacionId,
    cotizacion: despues,
    vehiculo,
    ahora,
  });
  if (!ticket) {
    console.warn(
      `onCotizacionAceptada: cotizacion ${cotizacionId} aceptada pero no ` +
        'ancla a vehiculo, taller y propietario a la vez; no se abrio ' +
        'ningun ticket.'
    );
    return null;
  }

  await ref.set(ticket);
  return ref.id;
}

module.exports = {
  PREFIJO_TICKET,
  ESTADOS_TICKET_CERRADO,
  idTicketDeCotizacion,
  debeAbrirTicket,
  construirTicketReparacion,
  existeTicketAbiertoParaVehiculo,
  abrirTicketDeReparacion,
};
