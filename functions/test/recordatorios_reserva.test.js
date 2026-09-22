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
        // `startAfter` avanza de verdad. Con un no-op, un caso de dos paginas
        // devolveria la primera para siempre y la paginacion se quedaria sin
        // ejercer. El doble ordena por id de documento y no por
        // `fecha_hora_propuesta`, asi que los fixtures del test de paginacion
        // se nombran en el mismo orden que sus fechas.
        const conLimite = (n, desde) => ({
          startAfter: (doc) => conLimite(n, doc.id),
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
              .filter((k) => desde === undefined || k.slice(prefijo.length) > desde)
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

/**
 * `escribirNotificacion` es OBLIGATORIO desde que el recordatorio deja rastro
 * en el centro de notificaciones (mismo contrato que `notificarAlertasVencidas`).
 * Los casos de este bloque no afirman sobre las notas — eso lo hace el bloque
 * de abajo—, asi que reciben un sumidero.
 */
const sumideroDeNotas = async () => {};

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
    await enviarRecordatoriosDeReserva(db, fakeMessaging(), { ahora: AHORA, escribirNotificacion: sumideroDeNotas });

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

    const { enviados } = await enviarRecordatoriosDeReserva(db, messaging, { ahora: AHORA, escribirNotificacion: sumideroDeNotas });

    assert.strictEqual(enviados, 2);
    assert.deepStrictEqual(messaging.enviados.map((m) => m.token).sort(), ['tok-m1', 'tok-p1']);
  });

  it('no avisa de una reserva que no cae en la ventana', async () => {
    const db = fakeDb({
      'reservas/r1': reserva({ fecha_hora_propuesta: ts('2026-09-20T15:00:00Z') }),
      'usuarios/p1': { fcmToken: 'tok-p1' },
    });
    const messaging = fakeMessaging();

    const { enviados } = await enviarRecordatoriosDeReserva(db, messaging, { ahora: AHORA, escribirNotificacion: sumideroDeNotas });

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
      escribirNotificacion: sumideroDeNotas,
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
      escribirNotificacion: sumideroDeNotas,
    });

    assert.strictEqual(fallidos, 1);
    assert.strictEqual(enviados, 1);
    assert.deepStrictEqual(
      messaging.enviados.map((m) => m.token),
      ['tok-m1']
    );
  });

  it('recorre TODAS las paginas y avisa de cada reserva una sola vez', async () => {
    const docs = { 'usuarios/p1': { fcmToken: 'tok-p1' } };
    for (let i = 1; i <= 5; i += 1) {
      docs[`reservas/r${i}`] = {
        estado: 'confirmada',
        fecha_hora_propuesta: ts(`2026-09-13T1${i}:00:00Z`),
        id_propietario: 'p1',
        id_mecanico: null,
      };
    }
    const db = fakeDb(docs);
    const messaging = fakeMessaging();

    const r = await enviarRecordatoriosDeReserva(db, messaging, { ahora: AHORA, limite: 2, escribirNotificacion: sumideroDeNotas });

    assert.strictEqual(r.reservas, 5, 'se salto alguna pagina');
    assert.strictEqual(r.enviados, 5);
    assert.ok(db.consultas.length >= 3, 'no llego a paginar');
  });

  it('no relee el mismo usuario cuando se repite entre reservas', async () => {
    const db = fakeDb({
      'reservas/r1': reserva(),
      'reservas/r2': reserva(),
      'usuarios/p1': { fcmToken: 'tok-p1' },
      'usuarios/m1': { fcmToken: 'tok-m1' },
    });
    const messaging = fakeMessaging();

    const { enviados } = await enviarRecordatoriosDeReserva(db, messaging, { ahora: AHORA, escribirNotificacion: sumideroDeNotas });

    assert.strictEqual(enviados, 4);
    assert.strictEqual(db.lecturasDeUsuario, 2, 'el cache de usuarios no esta funcionando');
  });
});

/**
 * El recordatorio decia la hora y no la decia, y no dejaba rastro.
 *
 * Dos gaps de la evidencia de SEC-04/OPS-01, los dos confirmados contra el
 * codigo antes de tocar nada:
 *
 *   - El cuerpo era **«Tienes una cita programada para mañana a la hora
 *     acordada»** teniendo `fecha_hora_propuesta` en la mano. Un recordatorio
 *     que no dice la hora obliga a abrir la app para saber a que hora es la
 *     cita, que es justo lo que un recordatorio existe para ahorrar.
 *
 *   - **No escribia nada en el centro de notificaciones.** Un push es
 *     efimero: quien lo pierde —telefono apagado, notificaciones silenciadas,
 *     token muerto por una reinstalacion— no tiene NINGUNA via para enterarse.
 *     Y no es una decision: el barrido de alertas, hermano de este y del mismo
 *     OPS-01, si llama a `escribirNotificacion`. Este se quedo sin ello.
 *
 * El caso que mas vale es el cuarto: **la nota se escribe aunque el push
 * falle o no haya token**. Si se escribiera solo despues de enviar, el gap
 * seguiria abierto para exactamente las personas a las que iba dirigido.
 */
describe('recordatoriosReserva / la hora y el centro de notificaciones', () => {
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

  function fakeNotas() {
    const escritas = [];
    const fn = async (uid, nota) => {
      escritas.push({ uid, nota });
    };
    fn.escritas = escritas;
    return fn;
  }

  it('el cuerpo del push dice la hora local de la cita', async () => {
    // 15:00Z del 13 son las 10:00 en Bogota.
    const db = fakeDb({
      'reservas/r1': reserva(),
      'usuarios/p1': { fcmToken: 'tok-p1' },
      'usuarios/m1': { fcmToken: 'tok-m1' },
    });
    const messaging = fakeMessaging();

    await enviarRecordatoriosDeReserva(db, messaging, {
      ahora: AHORA,
      escribirNotificacion: fakeNotas(),
    });

    for (const mensaje of messaging.enviados) {
      assert.ok(
        mensaje.notification.body.indexOf('10:00') !== -1,
        'el cuerpo no dice la hora: ' + mensaje.notification.body
      );
      assert.ok(
        !/hora acordada/i.test(mensaje.notification.body),
        'sigue diciendo «a la hora acordada»: ' + mensaje.notification.body
      );
    }
  });

  it('la hora se rinde en hora de Bogota, no en UTC', async () => {
    // 01:00Z del 14 son las 20:00 del 13 en Bogota. Decir «01:00» seria peor
    // que no decir nada: manda a alguien al taller con diecinueve horas de
    // desfase. Es el mismo error que OPS-01 ya corrigio en la VENTANA de la
    // consulta, esperando a que alguien formateara una hora.
    const db = fakeDb({
      'reservas/r1': reserva({ fecha_hora_propuesta: ts('2026-09-14T01:00:00Z') }),
      'usuarios/p1': { fcmToken: 'tok-p1' },
      'usuarios/m1': { fcmToken: 'tok-m1' },
    });
    const messaging = fakeMessaging();

    await enviarRecordatoriosDeReserva(db, messaging, {
      ahora: AHORA,
      escribirNotificacion: fakeNotas(),
    });

    const cuerpo = messaging.enviados[0].notification.body;
    assert.ok(cuerpo.indexOf('20:00') !== -1, 'no dice la hora local: ' + cuerpo);
    assert.ok(cuerpo.indexOf('01:00') === -1, 'dice la hora UTC: ' + cuerpo);
  });

  it('escribe la nota en el centro de notificaciones de los dos', async () => {
    const db = fakeDb({
      'reservas/r1': reserva(),
      'usuarios/p1': { fcmToken: 'tok-p1' },
      'usuarios/m1': { fcmToken: 'tok-m1' },
    });
    const notas = fakeNotas();

    await enviarRecordatoriosDeReserva(db, fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: notas,
    });

    assert.deepStrictEqual(
      notas.escritas.map((e) => e.uid).sort(),
      ['m1', 'p1']
    );
    for (const { nota } of notas.escritas) {
      assert.ok(nota.titulo, 'la nota no tiene titulo');
      assert.ok(nota.body.indexOf('10:00') !== -1, 'la nota no dice la hora');
    }
  });

  it('la nota se escribe aunque el push falle o no haya token', async () => {
    // EL CASO QUE IMPORTA. El propietario reinstalo la app y su token esta
    // muerto; el mecanico nunca registro token. Los dos son exactamente las
    // personas para las que existe el centro de notificaciones, asi que
    // escribir la nota solo despues de un envio con exito dejaria el gap
    // abierto justo donde duele.
    const db = fakeDb({
      'reservas/r1': reserva(),
      'usuarios/p1': { fcmToken: 'tok-muerto' },
      'usuarios/m1': {},
    });
    const notas = fakeNotas();
    const messaging = fakeMessaging({ fallaPara: ['tok-muerto'] });

    const resumen = await enviarRecordatoriosDeReserva(db, messaging, {
      ahora: AHORA,
      escribirNotificacion: notas,
    });

    assert.strictEqual(resumen.enviados, 0);
    assert.strictEqual(resumen.fallidos, 1);
    assert.strictEqual(resumen.sinToken, 1);
    assert.deepStrictEqual(
      notas.escritas.map((e) => e.uid).sort(),
      ['m1', 'p1'],
      'se perdio la nota de quien no recibio el push, que es justo quien la necesita'
    );
  });

  it('un fallo escribiendo la nota no tumba el recordatorio del resto', async () => {
    const db = fakeDb({
      'reservas/r1': reserva(),
      'usuarios/p1': { fcmToken: 'tok-p1' },
      'usuarios/m1': { fcmToken: 'tok-m1' },
    });
    const messaging = fakeMessaging();

    const resumen = await enviarRecordatoriosDeReserva(db, messaging, {
      ahora: AHORA,
      escribirNotificacion: async (uid) => {
        if (uid === 'p1') throw new Error('firestore caido');
      },
    });

    assert.strictEqual(resumen.reservas, 1);
    assert.strictEqual(
      messaging.enviados.length,
      2,
      'un fallo de escritura se llevo por delante los dos pushes'
    );
  });

  it('sin `escribirNotificacion` falla en alto, no en silencio', async () => {
    // Mismo contrato que `notificarAlertasVencidas`. Un default vacio dejaria
    // el centro de notificaciones sin nada por un olvido de cableado, y eso no
    // lo ve ningun test ni ningun log.
    const db = fakeDb({ 'reservas/r1': reserva() });
    await assert.rejects(
      () => enviarRecordatoriosDeReserva(db, fakeMessaging(), { ahora: AHORA }),
      /escribirNotificacion/
    );
  });
});

/**
 * El contador de notas perdidas cuenta lo que pasa DE VERDAD.
 *
 * Lo levanto el gate de `functions-perf-reviewer`, y era un falso verde de
 * manual: el `writeNotification` real **se traga su error y no relanza**, asi
 * que contar solo las excepciones dejaba `notasFallidas` clavado en 0 en
 * produccion. El unico sitio donde se incrementaba era un test cuyo doble SI
 * relanzaba — un doble que no modela la implementacion que dice suplantar.
 *
 * Los dos casos de abajo son la pareja: uno con la forma REAL (devuelve
 * `false`) y otro con la forma que un consumidor futuro podria tener (lanza).
 * El que importa es el primero; sin el, el arreglo no esta probado.
 */
describe('recordatoriosReserva / las notas perdidas se cuentan', () => {
  const reserva = () => ({
    estado: 'confirmada',
    fecha_hora_propuesta: ts('2026-09-13T15:00:00Z'),
    id_propietario: 'p1',
    id_mecanico: 'm1',
  });

  const conUsuarios = () =>
    fakeDb({
      'reservas/r1': reserva(),
      'usuarios/p1': { fcmToken: 'tok-p1' },
      'usuarios/m1': { fcmToken: 'tok-m1' },
    });

  it('una nota que DEVUELVE false se cuenta como perdida', async () => {
    // Esta es la forma real de `writeNotification`: registra el error y
    // devuelve false. Si el barrido solo mirara las excepciones, este caso
    // saldria con notasFallidas: 0 y nadie sabria que se perdieron las dos.
    const resumen = await enviarRecordatoriosDeReserva(conUsuarios(), fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: async () => false,
    });

    assert.strictEqual(
      resumen.notasFallidas,
      2,
      'el contador no vio las notas perdidas: es la forma REAL del helper'
    );
    // Y el push sigue saliendo: una nota perdida no se lleva el aviso.
    assert.strictEqual(resumen.enviados, 2);
  });

  it('una nota que devuelve true no cuenta como perdida', async () => {
    // Sin este, un contador que incrementara SIEMPRE pasaria el de arriba.
    const resumen = await enviarRecordatoriosDeReserva(conUsuarios(), fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: async () => true,
    });
    assert.strictEqual(resumen.notasFallidas, 0);
  });

  it('un doble que no devuelve nada tampoco cuenta como perdida', async () => {
    // Los casos que no afirman sobre notas usan un sumidero `async () => {}`.
    // Contar `undefined` como fallo los pondria rojos por el motivo
    // equivocado, asi que solo `false` significa perdida.
    const resumen = await enviarRecordatoriosDeReserva(conUsuarios(), fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: async () => {},
    });
    assert.strictEqual(resumen.notasFallidas, 0);
  });

  it('una nota que LANZA tambien se cuenta, y no tumba el push', async () => {
    const resumen = await enviarRecordatoriosDeReserva(conUsuarios(), fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: async () => {
        throw new Error('firestore caido');
      },
    });
    assert.strictEqual(resumen.notasFallidas, 2);
    assert.strictEqual(resumen.enviados, 2);
  });
});
