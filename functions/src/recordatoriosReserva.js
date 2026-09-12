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

const TEXTOS = {
  propietario: {
    title: 'Recordatorio de Cita',
    body: 'Tienes una cita programada para mañana a la hora acordada.',
  },
  mecanico: {
    title: 'Recordatorio de Cita',
    body: 'Tienes una cita programada para mañana con el vehículo del cliente.',
  },
};

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
  const { desde, hasta } = ventanaDeManana(ahora, desfase);

  const usuarios = new Map();
  const resumen = { reservas: 0, enviados: 0, fallidos: 0, sinToken: 0 };
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
      await avisar(reserva.id_propietario, 'propietario');
      await avisar(reserva.id_mecanico, 'mecanico');
    }

    // Media pagina significa que no hay mas: nos ahorramos una consulta que
    // siempre volveria vacia.
    if (pagina.size < limite) break;
    cursor = pagina.docs[pagina.docs.length - 1];
  }

  return resumen;

  async function avisar(uid, rol) {
    if (!uid) return;
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
      await messaging.send({ token, notification: TEXTOS[rol] });
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
  DESFASE_MINUTOS_BOGOTA,
  LIMITE_POR_PAGINA,
  ventanaDeManana,
  enviarRecordatoriosDeReserva,
};
