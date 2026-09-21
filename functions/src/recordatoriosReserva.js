'use strict';

/**
 * OPS-01 — recordatorio diario de citas confirmadas.
 *
 * Vivia dentro de `sendReservationReminders` en `functions/index.js`, sin un
 * solo test. Se extrae aqui para poder ejercerlo con fixtures, y al hacerlo
 * se corrigen dos defectos que la version inline arrastraba:
 *
 *   - la consulta no acotaba por fecha y barria la coleccion `reservas`
 *     entera cada dia;
 *   - "manana" se calculaba en UTC, no en hora local de Colombia.
 *
 * Ver `functions/test/recordatorios_reserva.test.js` para el detalle.
 */

/**
 * Colombia es UTC-5 el ano entero: no tiene horario de verano desde 1993, asi
 * que un desfase fijo es correcto y evita arrastrar una libreria de zonas
 * horarias a un entrypoint que ya paga arranque en frio por 30 funciones.
 * Si algun dia hay usuarios fuera de Colombia, esto deja de valer y hay que
 * resolver la zona por reserva (ver los gaps de la evidencia de OPS-01).
 */
const DESFASE_MINUTOS_BOGOTA = -300;

const LIMITE_POR_PAGINA = 500;
const MS_POR_DIA = 24 * 60 * 60 * 1000;

/**
 * Ventana `[desde, hasta)` en UTC que cubre el dia natural siguiente **en
 * hora local**.
 *
 * La version anterior comparaba `fecha.toISOString().split('T')[0]` con el dia
 * UTC de manana. Para una cita a las 20:00 de Bogota eso da el dia siguiente,
 * porque en UTC ya es la 01:00 del dia de despues: el recordatorio de las
 * citas de tarde salia un dia antes de lo debido, o no salia.
 *
 * @param {Date} ahora
 * @param {number} [desfaseMinutos] desfase de la zona local respecto a UTC.
 * @returns {{desde: Date, hasta: Date}}
 */
function ventanaDeManana(ahora, desfaseMinutos = DESFASE_MINUTOS_BOGOTA) {
  const local = new Date(ahora.getTime() + desfaseMinutos * 60000);
  const inicioLocalDeManana = Date.UTC(
    local.getUTCFullYear(),
    local.getUTCMonth(),
    local.getUTCDate() + 1
  );
  const desde = new Date(inicioLocalDeManana - desfaseMinutos * 60000);
  return { desde, hasta: new Date(desde.getTime() + MS_POR_DIA) };
}

const TITULO = 'Recordatorio de Cita';

/**
 * Hora local de la cita, como `HH:MM` de 24 h.
 *
 * **La hora hay que rendirla en la zona local, y el desfase es el mismo que
 * usa la ventana de la consulta.** Decir la hora UTC seria peor que no decir
 * ninguna: una cita a las 20:00 de Bogota saldria como «01:00» y mandaria a
 * alguien al taller con diecinueve horas de desfase. OPS-01 ya corrigio este
 * error en el CALCULO de la ventana; aqui esperaba a que alguien formateara
 * una hora.
 *
 * Formato de 24 h y a mano, sin `toLocaleTimeString`: el runtime de Cloud
 * Functions no garantiza tener datos de localizacion (`Intl` completo), y un
 * ICU minimo devuelve la hora en ingles o en UTC sin fallar.
 */
function horaLocal(fecha, desfaseMinutos) {
  const local = new Date(fecha.getTime() + desfaseMinutos * 60000);
  const hh = String(local.getUTCHours()).padStart(2, '0');
  const mm = String(local.getUTCMinutes()).padStart(2, '0');
  return hh + ':' + mm;
}

/**
 * Cuerpo del recordatorio.
 *
 * Decia «mañana a la hora acordada» teniendo `fecha_hora_propuesta` en la
 * mano, o sea obligaba a abrir la app para saber a que hora es la cita — que
 * es justo lo que un recordatorio existe para ahorrar.
 */
function cuerpo(rol, hora) {
  if (!hora) {
    // Una reserva sin fecha legible no deberia pasar la consulta (el filtro es
    // por `fecha_hora_propuesta`), pero si pasa es mejor un recordatorio vago
    // que ninguno o que una hora inventada.
    return rol === 'mecanico'
      ? 'Tienes una cita mañana con el vehículo del cliente.'
      : 'Tienes una cita programada para mañana.';
  }
  return rol === 'mecanico'
    ? 'Tienes una cita mañana a las ' + hora + ' con el vehículo del cliente.'
    : 'Tienes una cita mañana a las ' + hora + '.';
}

/**
 * Envia el recordatorio a propietario y mecanico de cada reserva confirmada
 * que caiga manana.
 *
 * @param {object} db Firestore (o un doble con la misma forma)
 * @param {object} messaging FCM (o un doble con `send`)
 * @param {{ahora?: Date, desfaseMinutos?: number, limite?: number}} [opciones]
 * @returns {Promise<{reservas: number, enviados: number, fallidos: number, sinToken: number}>}
 */
async function enviarRecordatoriosDeReserva(db, messaging, opciones = {}) {
  const ahora = opciones.ahora || new Date();
  const desfase =
    opciones.desfaseMinutos === undefined ? DESFASE_MINUTOS_BOGOTA : opciones.desfaseMinutos;
  const limite = opciones.limite || LIMITE_POR_PAGINA;

  // Mismo contrato que `notificarAlertasVencidas`, y por el mismo motivo: un
  // default vacio dejaria el centro de notificaciones sin nada por un olvido
  // de cableado, y eso no lo ve ningun test ni ningun log.
  const escribirNotificacion = opciones.escribirNotificacion;
  if (typeof escribirNotificacion !== 'function') {
    throw new TypeError('enviarRecordatoriosDeReserva necesita `escribirNotificacion`');
  }

  const { desde, hasta } = ventanaDeManana(ahora, desfase);

  const usuarios = new Map();
  const resumen = { reservas: 0, enviados: 0, fallidos: 0, sinToken: 0, notasFallidas: 0 };
  let cursor = null;

  for (;;) {
    let consulta = db
      .collection('reservas')
      .where('estado', '==', 'confirmada')
      // La cota va en el servidor. Sin ella esto leia cada reserva confirmada
      // que hubiera existido jamas, todos los dias, para siempre.
      .where('fecha_hora_propuesta', '>=', desde)
      .where('fecha_hora_propuesta', '<', hasta)
      // Firestore exige ordenar por el campo de la desigualdad, y ademas es lo
      // que hace estable la paginacion.
      .orderBy('fecha_hora_propuesta')
      .limit(limite);
    if (cursor) consulta = consulta.startAfter(cursor);

    const pagina = await consulta.get();
    if (pagina.empty) break;

    for (const doc of pagina.docs) {
      resumen.reservas += 1;
      const reserva = doc.data();
      const cuando = reserva.fecha_hora_propuesta;
      const fecha = cuando && cuando.toDate ? cuando.toDate() : cuando;
      const hora = fecha instanceof Date ? horaLocal(fecha, desfase) : null;
      // En paralelo: propietario y mecanico son uids DISTINTOS, asi que no
      // compiten por la misma entrada del cache de usuarios, y entre reservas
      // se sigue yendo en serie (el cache se llena igual). El gate de
      // rendimiento midio el coste de no hacerlo: la nota anadio una segunda
      // operacion de red por persona, o sea hasta 2000 idas y vueltas
      // secuenciales en una pagina de 500 reservas, bajo un techo de 540 s.
      await Promise.all([
        avisar(reserva.id_propietario, 'propietario', hora),
        avisar(reserva.id_mecanico, 'mecanico', hora),
      ]);
    }

    // Media pagina significa que no hay mas: nos ahorramos una consulta que
    // siempre volveria vacia.
    if (pagina.size < limite) break;
    cursor = pagina.docs[pagina.docs.length - 1];
  }

  return resumen;

  async function avisar(uid, rol, hora) {
    if (!uid) return;

    const texto = cuerpo(rol, hora);

    // **La nota va ANTES y por su cuenta, no despues de un envio con exito.**
    // Escribirla solo tras enviar dejaria sin rastro a exactamente las
    // personas para las que existe el centro de notificaciones: la que
    // reinstalo la app y tiene el token muerto, y la que nunca registro uno.
    // Su try es propio para que un Firestore caido no se lleve por delante el
    // push, que es la mitad que si podria llegar.
    // Se mira el valor DEVUELTO y no solo la excepcion: el
    // `writeNotification` real se traga su error y no relanza, asi que contar
    // solo los `throw` dejaba `notasFallidas` clavado en 0 en produccion —
    // se disparaba unicamente contra un doble de test que si relanzaba, que
    // es un contador que miente. Lo levanto el gate de rendimiento.
    let escrita = false;
    try {
      escrita =
        (await escribirNotificacion(uid, {
          tipo: 'reserva',
          titulo: TITULO,
          body: texto,
          deepLink: '/appointments',
        })) !== false;
    } catch (e) {
      console.error(
        `Nota de recordatorio no escrita para ${uid} (${rol}):`,
        e && e.code ? e.code : e
      );
    }
    if (!escrita) resumen.notasFallidas += 1;

    // El try envuelve TAMBIEN la lectura del usuario. Cuando solo cubria el
    // envio, un fallo transitorio leyendo `usuarios/{uid}` subia hasta el
    // catch de fuera del bucle y abortaba el barrido entero: el resto de
    // citas del dia se quedaban sin recordatorio por una lectura que falla.
    // Es el mismo defecto que el revisor encontro en el barrido de alertas,
    // en el otro extremo de la funcion.
    try {
      if (!usuarios.has(uid)) {
        const snap = await db.collection('usuarios').doc(uid).get();
        usuarios.set(uid, snap.exists ? snap.data() : null);
      }
      const usuario = usuarios.get(uid);
      const token = usuario && usuario.fcmToken;
      if (!token) {
        resumen.sinToken += 1;
        return;
      }
      await messaging.send({ token, notification: { title: TITULO, body: texto } });
      resumen.enviados += 1;
    } catch (e) {
      // Un token muerto es lo normal (app desinstalada), no una averia del
      // barrido.
      resumen.fallidos += 1;
      console.error(`Recordatorio no entregado a ${uid} (${rol}):`, e && e.code ? e.code : e);
    }
  }
}

module.exports = {
  horaLocal,
  DESFASE_MINUTOS_BOGOTA,
  LIMITE_POR_PAGINA,
  ventanaDeManana,
  enviarRecordatoriosDeReserva,
};
