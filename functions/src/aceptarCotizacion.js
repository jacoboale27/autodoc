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
 * Fallo PERMANENTE de autorizacion: el taller de la cotizacion no esta
 * vinculado al vehiculo. Reintentar esta invocacion nunca la va a arreglar —
 * los datos no cambian solos — asi que se distingue de un error transitorio
 * (indice faltante, servicio no disponible) con una clase propia.
 *
 * FIX 5 (Ronda 2): antes de esto, `onCotizacionAceptada` relanzaba TODOS los
 * errores por igual. Eso resolvia el problema original (la invocacion fallida
 * quedaba visible) pero, en cuanto se activara `failurePolicy` para que ese
 * relanzamiento sirviera para algo (v1 no reintenta sin el), un rechazo
 * PERMANENTE se habria reintentado durante 7 dias facturando en cada intento
 * sin que ningun reintento pudiera tener exito. El handler del trigger
 * (`functions/index.js`) usa `instanceof` para no reintentar esto: registra
 * el fallo en el propio documento de la cotizacion (para que la pantalla del
 * mecanico lo muestre) y devuelve exito a Cloud Functions.
 */
class ErrorAutorizacionPermanente extends Error {}

/**
 * La cotizacion aceptada NUNCA va a poder abrir un ticket: no ancla a un
 * vehiculo (la via comun del cliente que contacta al taller desde el
 * directorio, sin coche seleccionado), o el vehiculo al que ancla ya no
 * existe. No es un ataque —a diferencia de `ErrorAutorizacionPermanente`— y
 * tampoco es transitorio.
 *
 * Antes estos dos casos hacian `console.warn` y devolvian `null`: el cliente
 * veia su cotizacion en "aceptada", la tarjeta le pedia al taller que
 * recibiera el vehiculo, y no habia ticket ni forma de que lo hubiera. La
 * revision adversarial lo encontro asi, sin nadie avisando. Ahora se lanza,
 * el handler lo registra en `error_apertura_ticket` igual que el permanente,
 * y la tarjeta de la cotizacion lo muestra.
 */
class ErrorTicketNoAplicable extends Error {}

/**
 * Estados de `reparaciones` que cuentan como "cerrados": un vehiculo+taller
 * en uno de estos ya no tiene una visita en curso, asi que una cotizacion
 * aceptada nueva SI debe abrir un ticket propio. Cualquier otro estado
 * (incluido 'recibido' de un ticket anterior a A4b, sin `id_cotizacion') se
 * trata como abierto.
 *
 * RONDA 6: `listo_para_entrega` SALE de esta lista y entra 'entregado'.
 * `listo_para_entrega` cerraba la visita solo porque era el ultimo estado del
 * pipeline, pero ahi el coche sigue fisicamente en el taller esperando a que
 * lo recojan. Tratarlo como cerrado tenia dos consecuencias, las dos malas:
 * una cotizacion aceptada con el coche todavia en el patio abria un SEGUNDO
 * ticket para la misma visita, y `revocarVinculoAlCerrarTicket` le quitaba al
 * taller el acceso a la ficha del coche que aun tenia dentro. La visita se
 * cierra cuando el coche SALE, y para eso existe 'entregado'.
 *
 * Espejo en el cliente: `estadosReparacionCerrados`
 * (`lib/core/models/reparacion_model.dart`). Las dos listas tienen que decir
 * lo mismo.
 *
 * OJO al desplegar: los tickets que ya estan en `listo_para_entrega` en
 * produccion pasan a contar como ABIERTOS con este cambio. Hay que correr
 * `functions/backfill_entregado.js` para moverlos a 'entregado'.
 */
const ESTADOS_TICKET_CERRADO = ['cancelado', 'entregado'];

/**
 * Estados en los que el coche esta FISICAMENTE en el taller: los unicos en
 * los que el vinculo `vehiculos.talleres_vinculados` esta justificado.
 *
 * No es el complemento de `ESTADOS_TICKET_CERRADO`: 'pendiente_recepcion'
 * no esta cerrado (la visita esta en curso) pero el coche todavia no ha
 * llegado. Espejo de `estadosVehiculoEnTaller` en el cliente.
 */
const ESTADOS_VEHICULO_EN_TALLER = [
  'recibido',
  'en_revision',
  'esperando_repuestos',
  'listo_para_entrega',
];

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
 * RONDA 4: `idTaller` llega YA RESUELTO al uid del dueño del taller y ya no se
 * lee de `cotizacion.id_taller`. La ronda anterior resolvia el id solo para
 * comprobar el vinculo y escribia el CRUDO en el ticket, con lo que una
 * cotizacion legacy creada por un EMPLEADO (uid de sesion en `id_taller`,
 * antes del FIX 2 de la Ronda 2) abria un ticket con el uid del empleado. Todo
 * el cliente consulta `reparaciones` por `idTallerEfectivo` — el uid del DUEÑO
 * — (`watchReparacionesActivas`, `buscarReparacionActiva`,
 * `ReparacionesKanbanScreen`), asi que ese ticket no aparecia en ninguna
 * pantalla, y `firestore.rules` (`actuaPorTaller(resource.data.id_taller)`) se
 * lo negaba al dueño del taller. Un ticket que nadie ve ni puede leer.
 *
 * @param {{cotizacionId: string, cotizacion: object, vehiculo: ?object, idTaller: string, ahora: Date}} args
 * @returns {?object}
 */
function construirTicketReparacion({ cotizacionId, cotizacion, vehiculo, idTaller, ahora }) {
  const datosVehiculo = vehiculo || {};
  const idVehiculo = cotizacion.id_vehiculo || '';
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

/**
 * Resuelve el `id_taller` de una cotizacion al uid del DUEÑO del taller.
 *
 * Ronda 2 (FIX 2, regresion introducida en la revision de rama anterior):
 * los tres creadores de `cotizaciones` en el cliente escriben
 * `idTaller: userId` — el uid de la SESION, que para un empleado es su
 * propio uid, nunca el del dueño — mientras que `vehiculos.talleres_vinculados`
 * guarda SIEMPRE el uid del dueño (ver `firestore.rules:64-69`,
 * `idTallerActor()`). Sin esta resolucion, una cotizacion enviada por un
 * EMPLEADO de un taller vinculado al vehiculo fallaba
 * `vehiculoVinculadoOWalkIn` (comparaba el uid del empleado contra la lista
 * de uids de dueños) y el trigger relanzaba sin abrir ticket: el cliente
 * veia "aceptada", el Kanban se quedaba vacio, y nada lo recuperaba.
 *
 * Se lee `usuarios/{idTaller}.id_taller_propietario`: si existe, ese es el
 * dueño real; si el documento no existe o el campo esta ausente (dueño
 * operando con su propio uid, o dato legacy), se devuelve `idTaller` tal
 * cual — mismo criterio de fallback que `actuaPorTaller()`/`idTallerActor()`
 * en las reglas.
 *
 * RONDA 4: el valor resuelto es ahora el que se usa en TODO el flujo de
 * apertura — el dedup por vehiculo+taller, el `id_taller` del ticket y el
 * `talleres_vinculados` del vehiculo. Antes solo se usaba para la
 * comprobacion de vinculo y el ticket guardaba el crudo, lo que dejaba
 * tickets invisibles para el cliente entero (ver
 * `construirTicketReparacion`).
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} idTaller
 * @returns {Promise<string>}
 */
async function resolverIdTallerPropietario(db, idTaller) {
  if (!idTaller) return idTaller;
  const snap = await db.collection('usuarios').doc(idTaller).get();
  if (!snap.exists) return idTaller;
  const propietario = snap.data().id_taller_propietario;
  return propietario || idTaller;
}

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
 * ¿El vehiculo de la cotizacion es del cliente al que la cotizacion va
 * dirigida?
 *
 * Es la unica autorizacion que hace falta para abrir el ticket, porque el
 * trigger ya solo corre cuando `estado` paso a 'aceptada' y `firestore.rules`
 * reserva ese cambio al propio `id_propietario`: si esto es cierto, el dueño
 * del coche acepto en persona una cotizacion de este taller.
 *
 * Sustituye a `vehiculoVinculadoOWalkIn`, que era circular (ver el comentario
 * en `abrirTicketDeReparacion`).
 *
 * @param {?object} vehiculo
 * @param {object} cotizacion
 * @returns {boolean}
 */
function vehiculoDelClienteDeLaCotizacion(vehiculo, cotizacion) {
  const duenoVehiculo = (vehiculo && vehiculo.id_propietario) || '';
  const clienteCotizacion = cotizacion.id_propietario || '';
  return duenoVehiculo !== '' && duenoVehiculo === clienteCotizacion;
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

  // FIX 2 (Ronda 2): resolver id_taller al uid del DUEÑO. Los creadores de
  // `cotizaciones` anteriores a ese fix escribian el uid de la SESION, que
  // para un empleado es el suyo propio, mientras que todo lo demas
  // (`talleres_vinculados`, las consultas de `reparaciones`, `actuaPorTaller`)
  // habla en uids de dueño.
  //
  // RONDA 4: se resuelve AQUI, antes del dedup, y no justo antes de construir
  // el ticket. El dedup preguntaba por el id crudo, asi que una cotizacion
  // legacy con uid de empleado no veia el ticket que el taller ya tenia
  // abierto para ese mismo coche y abria un segundo ticket paralelo — el caso
  // exacto que `existeTicketAbiertoParaVehiculo` existe para impedir.
  const idTallerResuelto = await resolverIdTallerPropietario(db, despues.id_taller);

  // Hallazgo 2: dedup por vehiculo+taller, no solo por cotizacion. Si ya hay
  // una visita en curso para este vehiculo en este taller, esta aceptacion
  // no abre un segundo ticket paralelo.
  if (despues.id_vehiculo && idTallerResuelto) {
    const yaAbierto = await existeTicketAbiertoParaVehiculo(db, {
      idVehiculo: despues.id_vehiculo,
      idTaller: idTallerResuelto,
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
    throw new ErrorTicketNoAplicable(
      despues.id_vehiculo
        ? 'El vehículo de esta cotización ya no existe, así que no se pudo ' +
          'abrir el ticket de servicio.'
        : 'Esta cotización no está asociada a ningún vehículo, así que no ' +
          'puede abrir un ticket de servicio. Pídele al cliente una ' +
          'cotización nueva desde su vehículo.'
    );
  }

  // Revision de rama completa (hallazgo C1): este trigger es el UNICO
  // creador de `reparaciones` (allow create: if false), pero corria sin
  // ninguna de las comprobaciones que la vieja regla `allow create` hacia.
  // `cotizaciones` solo exige `id_mecanico == auth.uid` para crear (ver
  // firestore.rules, match /cotizaciones), asi que sin esto cualquier
  // mecanico podia redactar una cotizacion sobre el vehiculo de un
  // desconocido, aceptarsela a si mismo (antes de la Tarea de reglas 1a) y
  // que este trigger le abriera el ticket igual.
  //
  // RONDA 3 — lo que autoriza es el CONSENTIMIENTO DEL DUEÑO, no
  // `talleres_vinculados`. Este bloque exigia `vehiculoVinculadoOWalkIn`, y
  // esa lista solo la escribe `requestReviewOnServiceComplete`, es decir al
  // TERMINAR un servicio. La condicion era circular: para poder trabajar
  // habia que haber trabajado ya. Solo pasaba el caso walk-in (lista vacia,
  // el primer taller de la vida del coche); cualquier segundo taller lanzaba
  // ErrorAutorizacionPermanente y no abria ticket JAMAS, mientras el cliente
  // veia su cotizacion en "aceptada" y la tarjeta le decia al mecanico que
  // recibiera el vehiculo. El flujo central del negocio quedaba cerrado.
  //
  // El chequeo que lo sustituye cubre el mismo ataque sin la circularidad: el
  // vehiculo tiene que pertenecer al cliente al que va dirigida la cotizacion,
  // y solo ese cliente puede moverla a 'aceptada' (firestore.rules,
  // /cotizaciones update — invariante A1 quien-propone-no-resuelve). Se abre
  // ticket si y solo si el dueño del coche acepto una cotizacion de este
  // taller, que es una autorizacion mas fuerte que haber sido atendido antes.
  if (!vehiculoDelClienteDeLaCotizacion(vehiculo, despues)) {
    // No silenciar: esta NO es una cotizacion malformada, es un intento de
    // abrir un ticket sobre el vehiculo de un tercero. `console.error` (en vez
    // del `console.warn` de arriba) para que quede visible como fallo, y el
    // trigger no reintenta (ver ErrorAutorizacionPermanente).
    console.error(
      `onCotizacionAceptada: la cotizacion ${cotizacionId} dice ser del ` +
        `cliente ${despues.id_propietario || 'sin id_propietario'}, pero el ` +
        `vehiculo ${despues.id_vehiculo} es de ${vehiculo.id_propietario || 'nadie'}; ` +
        'no se abrio ningun ticket.'
    );
    throw new ErrorAutorizacionPermanente(
      `La cotizacion ${cotizacionId} no corresponde al dueño del vehiculo ` +
        `${despues.id_vehiculo}; no se abre ticket.`
    );
  }

  const ticket = construirTicketReparacion({
    cotizacionId,
    cotizacion: despues,
    vehiculo,
    idTaller: idTallerResuelto,
    ahora,
  });
  if (!ticket) {
    console.warn(
      `onCotizacionAceptada: cotizacion ${cotizacionId} aceptada pero no ` +
        'ancla a vehiculo, taller y propietario a la vez; no se abrio ' +
        'ningun ticket.'
    );
    throw new ErrorTicketNoAplicable(
      'A esta cotización le faltan datos para abrir el ticket de servicio ' +
        '(vehículo, taller o propietario). Pídele al cliente una cotización ' +
        'nueva desde su vehículo.'
    );
  }

  // RONDA 5: aceptar la cotizacion abre el ticket y NADA MAS. Hasta aqui
  // tambien escribia `vehiculos.talleres_vinculados`, es decir le daba al
  // taller acceso permanente e irrevocable a la ficha del coche, su galeria,
  // sus alertas y su historial de mantenimientos — desde antes de que el coche
  // llegara y para siempre despues de que se fuera. El vinculo pasa a seguir a
  // la POSESION del vehiculo: se otorga al recibirlo y se revoca al cerrar el
  // ticket (ver `src/vinculoTaller.js`).
  //
  // El ticket nace por tanto SIN que el taller pueda leer todavia el vehiculo.
  // Es intencionado y esta cubierto: la tarjeta del Kanban se pinta solo con
  // datos del propio ticket (la placa va denormalizada aqui abajo), y recibir
  // el vehiculo es un callable server-side que otorga el vinculo en la misma
  // escritura atomica.
  await ref.set(ticket);
  return ref.id;
}

module.exports = {
  PREFIJO_TICKET,
  ESTADOS_TICKET_CERRADO,
  ESTADOS_VEHICULO_EN_TALLER,
  ErrorAutorizacionPermanente,
  ErrorTicketNoAplicable,
  idTicketDeCotizacion,
  debeAbrirTicket,
  construirTicketReparacion,
  vehiculoDelClienteDeLaCotizacion,
  existeTicketAbiertoParaVehiculo,
  resolverIdTallerPropietario,
  abrirTicketDeReparacion,
};
