'use strict';

/**
 * OPS-01 — `sendReservationReminders` no tenia ni un test, y la extraccion
 * destapo dos defectos que la version inline lleva desde que se escribio.
 *
 * 1. **La consulta no tenia cota de fecha.** Filtraba `estado == 'confirmada'`
 *    y paginaba la coleccion ENTERA, descartando en memoria las reservas que
 *    no eran de manana. Una reserva confirmada de hace dos anos se sigue
 *    leyendo cada dia, para siempre: el coste del recordatorio diario crece
 *    con la vida del proyecto y nunca baja.
 *
 * 2. **"Manana" se calculaba en UTC.** `toISOString().split('T')[0]` da el dia
 *    UTC, y Colombia es UTC-5 todo el ano (no tiene horario de verano). Una
 *    cita a las 20:00 hora de Bogota cae al dia SIGUIENTE en UTC, asi que su
 *    recordatorio no salia la vispera. Justo las citas de tarde, que son la
 *    mayoria.
 *
 * El doble de este archivo **registra los filtros** que recibe la consulta a
 * proposito. Sin eso, un barrido sin cota devuelve exactamente los mismos
 * documentos que una consulta acotada y el test daria verde sobre el defecto
 * que dice cubrir — que es la cicatriz que ya dejo el drenaje de FUNC-02.
 */

const assert = require('assert');
const { Timestamp } = require('firebase-admin/firestore');

const {
  DESFASE_MINUTOS_BOGOTA,
  ventanaDeManana,
  enviarRecordatoriosDeReserva,
} = require('../src/recordatoriosReserva');

// 2026-09-12T18:00:00Z son las 13:00 del 12 en Bogota: "manana" local es el 13.
const AHORA = new Date('2026-09-12T18:00:00Z');
const ts = (iso) => Timestamp.fromDate(new Date(iso));

function fakeDb(docs = {}) {
  const consultas = [];
  let lecturasDeUsuario = 0;
  const cumple = (data, campo, op, valor) => {
    if (!Object.prototype.hasOwnProperty.call(data, campo)) return false;
    const val = (x) => (x && x.toDate ? x.toDate().getTime() : x);
    const propio = data[campo];
    if (op === '==') return propio === valor;
    if (op === '>=') return val(propio) >= val(valor);
    if (op === '<') return val(propio) < val(valor);
    if (op === '>') return val(propio) > val(valor);
    throw new Error('operador no modelado: ' + op);
  };
  const docRef = (coleccion, id) => ({
    id,
    async get() {
      const clave = coleccion + '/' + id;
      if (coleccion === 'usuarios') lecturasDeUsuario += 1;
      const existe = Object.prototype.hasOwnProperty.call(docs, clave);
      return {
        exists: existe,
        id,
        data: () => (existe ? Object.assign({}, docs[clave]) : undefined),
      };
    },
  });
  const api = {
    docs,
    consultas,
    get lecturasDeUsuario() {
      return lecturasDeUsuario;
    },
    collection(coleccion) {
      const consulta = (filtros, orden) => {
        const conLimite = (n) => ({
          startAfter: () => conLimite(n),
          async get() {
            consultas.push({
              coleccion,
              filtros: filtros.map((f) => f[0] + ' ' + f[1]),
              limite: n,
            });
            const prefijo = coleccion + '/';
            const claves = Object.keys(docs)
              .filter((k) => k.startsWith(prefijo))
              .sort()
              .filter((k) => filtros.every((f) => cumple(docs[k], f[0], f[1], f[2])))
              .slice(0, n);
            return {
              empty: claves.length === 0,
              size: claves.length,
              docs: claves.map((k) => ({
                id: k.slice(prefijo.length),
                data: () => docs[k],
              })),
            };
          },
        });
        return {
          where: (c, o, v) => consulta(filtros.concat([[c, o, v]]), orden),
          orderBy: (c) => consulta(filtros, c),
          limit: conLimite,
        };
      };
      return {
        doc: (id) => docRef(coleccion, id),
        where: (c, o, v) => consulta([[c, o, v]], null),
      };
    },
  };
  return api;
}

function fakeMessaging(opciones) {
  const fallaPara = (opciones && opciones.fallaPara) || [];
  const enviados = [];
  return {
    enviados,
    async send(mensaje) {
      if (fallaPara.indexOf(mensaje.token) !== -1) {
        const e = new Error('registration-token-not-registered');
        e.code = 'messaging/registration-token-not-registered';
        throw e;
      }
      enviados.push(mensaje);
      return 'ok';
    },
  };
}

describe('recordatoriosReserva / ventanaDeManana', () => {
  it('calcula el dia siguiente en hora de Bogota, no en UTC', () => {
    const { desde, hasta } = ventanaDeManana(AHORA);
    // 13 de septiembre 00:00 en Bogota == 05:00Z del 13.
    assert.strictEqual(desde.toISOString(), '2026-09-13T05:00:00.000Z');
    assert.strictEqual(hasta.toISOString(), '2026-09-14T05:00:00.000Z');
  });

  it('una cita de tarde no se escapa al dia siguiente por el desfase', () => {
    // 20:00 del 13 en Bogota es 01:00Z del 14: en UTC parece pasado manana.
    const cita = new Date('2026-09-14T01:00:00.000Z');
    const { desde, hasta } = ventanaDeManana(AHORA);
    assert.ok(cita >= desde && cita < hasta);
  });

  it('cerca de medianoche local no adelanta la ventana un dia', () => {
    // 2026-09-13T04:00Z son las 23:00 del 12 en Bogota: manana sigue siendo el 13.
    const { desde } = ventanaDeManana(new Date('2026-09-13T04:00:00.000Z'));
    assert.strictEqual(desde.toISOString(), '2026-09-13T05:00:00.000Z');
  });

  it('expone el desfase como constante y no como numero suelto', () => {
    assert.strictEqual(DESFASE_MINUTOS_BOGOTA, -300);
  });
});

describe('recordatoriosReserva / enviarRecordatoriosDeReserva', () => {
  const reserva = (extra) =>
    Object.assign(
      {
        estado: 'confirmada',
        fecha_hora_propuesta: ts('2026-09-13T15:00:00Z'),
        id_propietario: 'p1',
        id_mecanico: 'm1',
      },
      extra || {}
    );

  it('acota la consulta por fecha en el servidor, no en memoria', async () => {
    const db = fakeDb({ 'reservas/r1': reserva() });
    await enviarRecordatoriosDeReserva(db, fakeMessaging(), { ahora: AHORA });

    assert.ok(db.consultas.length > 0, 'no se consulto nada');
    const filtros = db.consultas[0].filtros;
    assert.ok(filtros.indexOf('estado ==') !== -1, 'falta el filtro de estado: ' + filtros);
    assert.ok(
      filtros.indexOf('fecha_hora_propuesta >=') !== -1 &&
        filtros.indexOf('fecha_hora_propuesta <') !== -1,
      'la consulta no acota por fecha, barre la coleccion entera: ' + filtros
    );
  });

  it('avisa al propietario y al mecanico de una reserva de manana', async () => {
    const db = fakeDb({
      'reservas/r1': reserva(),
      'usuarios/p1': { fcmToken: 'tok-p1' },
      'usuarios/m1': { fcmToken: 'tok-m1' },
    });
    const messaging = fakeMessaging();

    const { enviados } = await enviarRecordatoriosDeReserva(db, messaging, { ahora: AHORA });

    assert.strictEqual(enviados, 2);
    assert.deepStrictEqual(messaging.enviados.map((m) => m.token).sort(), ['tok-m1', 'tok-p1']);
  });

  it('no avisa de una reserva que no cae en la ventana', async () => {
    const db = fakeDb({
      'reservas/r1': reserva({ fecha_hora_propuesta: ts('2026-09-20T15:00:00Z') }),
      'usuarios/p1': { fcmToken: 'tok-p1' },
    });
    const messaging = fakeMessaging();

    const { enviados } = await enviarRecordatoriosDeReserva(db, messaging, { ahora: AHORA });

    assert.strictEqual(enviados, 0);
    assert.deepStrictEqual(messaging.enviados, []);
  });

  it('un usuario sin fcmToken no rompe el barrido', async () => {
    const db = fakeDb({
      'reservas/r1': reserva(),
      'usuarios/p1': {},
      'usuarios/m1': { fcmToken: 'tok-m1' },
    });
    const messaging = fakeMessaging();

    const { enviados, sinToken } = await enviarRecordatoriosDeReserva(db, messaging, {
      ahora: AHORA,
    });

    assert.strictEqual(enviados, 1);
    assert.strictEqual(sinToken, 1);
  });

  it('un token muerto no impide el aviso al otro destinatario', async () => {
    // El caso real: el propietario desinstalo la app y su token ya no existe;
    // el mecanico sigue esperando su recordatorio. En la version inline el
    // error subia hasta el catch de FUERA del bucle y abortaba el barrido
    // entero — un token muerto dejaba sin recordatorio a todo el resto del dia.
    const db = fakeDb({
      'reservas/r1': reserva(),
      'usuarios/p1': { fcmToken: 'tok-muerto' },
      'usuarios/m1': { fcmToken: 'tok-m1' },
    });
    const messaging = fakeMessaging({ fallaPara: ['tok-muerto'] });

    const { enviados, fallidos } = await enviarRecordatoriosDeReserva(db, messaging, {
      ahora: AHORA,
    });

    assert.strictEqual(fallidos, 1);
    assert.strictEqual(enviados, 1);
    assert.deepStrictEqual(
      messaging.enviados.map((m) => m.token),
      ['tok-m1']
    );
  });

  it('no relee el mismo usuario cuando se repite entre reservas', async () => {
    const db = fakeDb({
      'reservas/r1': reserva(),
      'reservas/r2': reserva(),
      'usuarios/p1': { fcmToken: 'tok-p1' },
      'usuarios/m1': { fcmToken: 'tok-m1' },
    });
    const messaging = fakeMessaging();

    const { enviados } = await enviarRecordatoriosDeReserva(db, messaging, { ahora: AHORA });

    assert.strictEqual(enviados, 4);
    assert.strictEqual(db.lecturasDeUsuario, 2, 'el cache de usuarios no esta funcionando');
  });
});
