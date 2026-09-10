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

/**
 * Campo del ticket que dice si su vinculo con el vehiculo esta VIVO ahora
 * mismo.
 *
 * Existe para que la caducidad por inactividad (`src/caducarVinculos.js`,
 * residual 7.2) pueda barrer por consulta en vez de por estado del ticket: un
 * ticket abandonado sigue abandonado despues de caducarle el vinculo, asi que
 * una consulta por estado lo devolveria en cada corrida y los que se quedan
 * rancios despues no llegarian a barrerse nunca.
 *
 * Lo mantienen los dos extremos del ciclo de vida del vinculo, y si uno de los
 * dos se olvida el barrido deja de funcionar en silencio: por eso hay tests
 * que lo fijan a los dos lados.
 */
const CAMPO_VINCULO_ACTIVO = 'vinculo_activo';

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
 * en UNA sola transaccion.
 *
 * Va en el servidor —y no en el cliente, como hasta la Ronda 5— porque las dos
 * mitades tienen que pasar juntas y el cliente no puede escribir la segunda
 * (`firestore.rules` solo le deja tocar `kilometraje_actual` del vehiculo).
 * Partirlo en "el cliente mueve el ticket, un trigger otorga el vinculo"
 * tampoco vale: el trigger es asincrono, y la pantalla que recibe el vehiculo
 * necesita leer la ficha INMEDIATAMENTE despues para seguir trabajando.
 *
 * **Transaccion y no `batch` (residual 7.7 de FUNC-02).** Un `batch` es
 * atomico al escribir pero no ata la escritura a la lectura que la decidio, y
 * aqui hay dos cosas que dependen de esa lectura:
 *
 *   - `historial_estados` se reconstruye EN MEMORIA: se lee el array, se le
 *     añade la entrada y se escribe entero (`arrayUnion` no sirve, porque dos
 *     transiciones al mismo estado son objetos iguales y las deduplicaria).
 *     Con un `batch`, otra transicion escrita entre la lectura y el commit —el
 *     cliente avanzando el ticket desde el tablero, una cancelacion— quedaba
 *     PISADA por la copia vieja del array. Se perdia un estado del historial
 *     sin error y sin rastro.
 *   - la autorizacion (ver `autorizar`) decide sobre `id_taller`. Con la
 *     lectura suelta habia una ventana en la que ese campo podia cambiar entre
 *     autorizar y escribir.
 *
 * La transaccion cierra las dos: si algo de lo leido cambio, Firestore
 * reejecuta el cuerpo sobre los datos nuevos.
 *
 * **`autorizar` va DENTRO, y por eso el callable ya no lee el ticket.** Antes
 * `recibirVehiculoDelTicket` leia `reparaciones/{id}` para comprobar
 * `actuaPorTaller` y esta funcion lo volvia a leer para escribir: una lectura
 * de mas por recepcion y dos snapshots distintos decidiendo cosas distintas.
 * Ahora se lee una vez y se autoriza sobre ese mismo snapshot. Si la
 * transaccion se reintenta, `autorizar` se vuelve a llamar — correcto, porque
 * lo que autoriza es el ticket que se va a escribir, no el que se leyo la
 * primera vez.
 *
 * Idempotente: recibir dos veces no es un error. Si el ticket ya paso de
 * `pendiente_recepcion` devuelve `recibidoAhora: false` sin escribir el
 * estado, pero SI reasegura el vinculo — asi un ticket legado, abierto antes
 * de que existiera este flujo, recupera el acceso al reabrirlo en vez de
 * quedarse permanentemente sin ficha.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{idReparacion: string, ahora: Date,
 *          autorizar?: (idTaller: string) => Promise<boolean>}} args
 * @returns {Promise<{idVehiculo: string, idTaller: string, recibidoAhora: boolean}>}
 */
async function recibirTicketYVincular(db, { idReparacion, ahora, autorizar }) {
  const ref = db.collection('reparaciones').doc(idReparacion);
  try {
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new ErrorRecepcion('not-found', 'Este ticket de servicio ya no existe.');
      }

      const ticket = snap.data();
      // Los tickets anteriores a A4b no traen `estado`; nacian en 'recibido'.
      const estado = (ticket.estado || ESTADO_RECIBIDO).toString();
      const idVehiculo = (ticket.id_vehiculo || '').toString();
      const idTaller = (ticket.id_taller || '').toString();

      // Un ticket ya CERRADO no se puede recibir: la visita termino. Recibir
      // uno volveria a otorgar el vinculo al vehiculo sobre una visita que ya
      // no existe — exactamente el acceso permanente que este diseño elimina.
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

      // Corre con Admin SDK: `firestore.rules` no alcanza a esto, asi que la
      // autorizacion se replica a mano y sobre el snapshot recien leido.
      if (autorizar && !(await autorizar(idTaller))) {
        throw new ErrorRecepcion(
          'permission-denied',
          'Este ticket no es de tu taller.'
        );
      }

      const recibidoAhora = estado === ESTADO_PENDIENTE_RECEPCION;
      if (recibidoAhora) {
        const historial = Array.isArray(ticket.historial_estados)
          ? ticket.historial_estados.slice()
          : [];
        historial.push({ estado: ESTADO_RECIBIDO, timestamp: ahora });
        tx.update(ref, {
          estado: ESTADO_RECIBIDO,
          historial_estados: historial,
          fecha_actualizacion: ahora,
          [CAMPO_VINCULO_ACTIVO]: true,
        });
      } else if (ticket[CAMPO_VINCULO_ACTIVO] !== true) {
        // Recepcion idempotente: no transiciona el estado pero SI reasegura el
        // vinculo, asi que el ticket tiene que quedar marcado. Sin esto, un
        // ticket legado recuperaria el acceso sin quedar sujeto a la
        // caducidad. Solo se escribe si hacia falta, para no pagar una
        // escritura en cada "Recibir" repetido.
        tx.update(ref, { [CAMPO_VINCULO_ACTIVO]: true });
      }
      // El vinculo se reasegura siempre (ver la nota de idempotencia arriba).
      //
      // Son DOS arrays con significados distintos y ciclos de vida distintos:
      //
      //   talleres_vinculados  "este taller tiene el coche AHORA". Se revoca al
      //                        cerrarse el ticket. Autoriza LEER la ficha.
      //   talleres_conocidos   "este taller ha tenido el coche alguna vez".
      //                        Append-only, nunca se revoca. Autoriza ESCRIBIR
      //                        un `servicios`/`historial_mantenimientos` mas.
      //
      // El segundo nace de la revision adversarial de la ronda 6: el carve-out
      // de walk-in de firestore.rules preguntaba si `talleres_vinculados`
      // estaba vacio para dejar pasar al primer taller de un coche nuevo. En
      // cuanto la ronda 5 empezo a revocar ese array, "vacio" paso a significar
      // "coche ya entregado", que es el estado de reposo de casi toda la flota
      // — y con el, cualquier taller podia inyectar un servicio falso en el
      // historial de cualquier cliente. Separar el "ahora" del "alguna vez"
      // cierra el hueco sin romper el walk-in legitimo.
      tx.update(db.collection('vehiculos').doc(idVehiculo), {
        talleres_vinculados: FieldValue.arrayUnion(idTaller),
        talleres_conocidos: FieldValue.arrayUnion(idTaller),
      });

      return { idVehiculo, idTaller, recibidoAhora };
    });
  } catch (error) {
    if (error instanceof ErrorRecepcion) throw error;
    if (error && (error.code === 5 || error.code === 'not-found')) {
      throw new ErrorRecepcion(
        'not-found',
        'El vehículo de este ticket ya no existe: el propietario lo eliminó ' +
          'de su garaje.'
      );
    }
    throw error;
  }
}

/** Campo que marca "hay que revocar este vinculo y no se pudo". */
const CAMPO_REVOCACION_PENDIENTE = 'vinculo_revocacion_pendiente';

/**
 * La revocacion al cerrarse el ticket, con su fallo hecho VISIBLE.
 *
 * Vive aqui y no en el handler del trigger por el mismo motivo que el resto
 * del modulo: para poder probarla sin firebase-functions.
 *
 * **Que cambia (residual 7.9 de FUNC-02).** El trigger capturaba el error de
 * `revocarVinculo`, lo registraba y seguia. El razonamiento era correcto —el
 * ticket ya esta cerrado, el servicio registrado, y relanzar sin
 * `failurePolicy` no reintenta nada, solo ensucia las metricas— pero el
 * resultado era que el vinculo sobrevivia al `entregado` sin que nadie
 * pudiera saberlo. El taller conserva la lectura de la ficha de un coche que
 * ya devolvio, y la unica huella es una linea de log que nadie consulta.
 *
 * No es escalada de privilegios: `tallerConoceElVehiculo` le permite escribir
 * su `servicios` igualmente via `talleres_conocidos`, que es append-only por
 * diseño. Es una inconsistencia de datos — y de las que no se descubren.
 *
 * Asi que el fallo deja una MARCA en el propio ticket. Dos efectos:
 *
 *   1. Es consultable: se puede preguntar cuantos vinculos quedaron colgando,
 *      en vez de tener que leerse los logs.
 *   2. Se autorrepara sin maquinaria nueva. Este mismo trigger es un
 *      `onUpdate`, asi que cualquier escritura posterior sobre el ticket lo
 *      despierta; si ve la marca, reintenta y la limpia. No hace falta un
 *      barrido programado.
 *
 * Un reintento que vuelve a fallar NO reescribe la marca, a proposito: cada
 * reescritura volveria a despertar al trigger, y eso es un bucle facturado
 * sobre un fallo que no se va a arreglar solo.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{antes: object, despues: object, ref: FirebaseFirestore.DocumentReference}} args
 * @returns {Promise<{resultado: 'nada'|'revocado'|'pendiente', error?: Error}>}
 */
async function revocarVinculoAlCerrar(db, { antes, despues, ref }) {
  const cierra = debeRevocarVinculo(antes, despues);
  const reintento = despues[CAMPO_REVOCACION_PENDIENTE] === true;
  if (!cierra && !reintento) return { resultado: 'nada' };

  try {
    await revocarVinculo(db, {
      idVehiculo: (despues.id_vehiculo || '').toString(),
      idTaller: (despues.id_taller || '').toString(),
    });
    // Solo se escribe si hay algo que limpiar. Cada escritura sobre el ticket
    // vuelve a despertar a este mismo trigger (es un `onUpdate` sobre la
    // coleccion que escribe): termina —ni la transicion ni la marca se
    // cumplen la segunda vez— pero es una invocacion facturada, y no tiene
    // sentido pagarla por un ticket legado que nunca tuvo el campo.
    const limpieza = {};
    if (despues[CAMPO_VINCULO_ACTIVO] === true) {
      limpieza[CAMPO_VINCULO_ACTIVO] = false;
    }
    if (reintento) limpieza[CAMPO_REVOCACION_PENDIENTE] = FieldValue.delete();
    if (Object.keys(limpieza).length > 0) await ref.update(limpieza);
    return { resultado: 'revocado' };
  } catch (error) {
    if (!reintento) {
      try {
        await ref.update({ [CAMPO_REVOCACION_PENDIENTE]: true });
      } catch (errorMarca) {
        // Si ni la marca se puede escribir, no queda mas que el log: es el
        // comportamiento de antes, ya como ultimo recurso y no como norma.
        return { resultado: 'pendiente', error, errorMarca };
      }
    }
    return { resultado: 'pendiente', error };
  }
}

module.exports = {
  CAMPO_REVOCACION_PENDIENTE,
  CAMPO_VINCULO_ACTIVO,
  ESTADO_PENDIENTE_RECEPCION,
  ESTADO_RECIBIDO,
  ErrorRecepcion,
  debeRevocarVinculo,
  revocarVinculo,
  recibirTicketYVincular,
  revocarVinculoAlCerrar,
};
