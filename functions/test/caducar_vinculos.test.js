'use strict';

/**
 * Residual 7.2 de FUNC-02: el vinculo taller-vehiculo sigue a la POSESION del
 * coche, pero **nadie caduca la posesion**.
 *
 * El vinculo se otorga al recibir el vehiculo y se revoca al cerrarse el
 * ticket. Un taller que simplemente nunca mueva el ticket a `entregado`
 * conserva `talleres_vinculados` —y con el la ficha, la galeria, las alertas y
 * el historial que escribieron OTROS talleres— indefinidamente. El cierre
 * dependia por completo de la buena voluntad del taller, y no hay nada en el
 * sistema que se lo exija.
 *
 * Lo que caduca es el ACCESO, no el ticket: el ticket sigue abierto y el taller
 * lo recupera con volver a "Recibir vehiculo" (el callable reasegura el vinculo
 * mientras el ticket no este cerrado, y la pantalla ya ofrece ese reintento).
 * Una reparacion larga de verdad se arregla sola en un toque; una abandonada
 * deja de dar acceso a la ficha de un desconocido.
 */

const assert = require('assert');
const { Timestamp } = require('firebase-admin/firestore');

const {
  DIAS_CADUCIDAD_VINCULO,
  caducarVinculosInactivos,
} = require('../src/caducarVinculos');

const AHORA = new Date('2026-09-10T12:00:00Z');
const hace = (dias) =>
  Timestamp.fromDate(new Date(AHORA.getTime() - dias * 24 * 60 * 60 * 1000));

/**
 * Doble en memoria con lo que usa el barrido: una consulta de dos `where`
 * (igualdad y desigualdad) con `limit`, y `update` sobre documentos sueltos.
 */
function fakeDb(docs = {}) {
  const escrituras = [];
  const refDe = (coleccion, id) => {
    const clave = `${coleccion}/${id}`;
    return {
      id,
      clave,
      async update(data) {
        if (!Object.prototype.hasOwnProperty.call(docs, clave)) {
          const error = new Error(`No document to update: ${clave}`);
          error.code = 5;
          throw error;
        }
        escrituras.push({ clave, data });
        docs[clave] = Object.assign({}, docs[clave], data);
      },
    };
  };
  const cumple = (data, campo, op, valor) => {
    if (!Object.prototype.hasOwnProperty.call(data, campo)) return false;
    const propio = data[campo];
    if (op === '==') return propio === valor;
    if (op === '<') {
      const fecha = propio && propio.toDate ? propio.toDate() : propio;
      return fecha < valor;
    }
    throw new Error(`operador no modelado: ${op}`);
  };
  return {
    docs,
    escrituras,
    collection(coleccion) {
      const consulta = (filtros) => ({
        where: (c, o, v) => consulta([...filtros, [c, o, v]]),
        limit: (n) => ({
          async get() {
            const prefijo = `${coleccion}/`;
            const claves = Object.keys(docs)
              .filter((k) => k.startsWith(prefijo))
              .sort()
              .filter((k) => filtros.every(([c, o, v]) => cumple(docs[k], c, o, v)))
              .slice(0, n);
            return {
              size: claves.length,
              docs: claves.map((k) => ({
                id: k.slice(prefijo.length),
                ref: refDe(coleccion, k.slice(prefijo.length)),
                data: () => docs[k],
              })),
            };
          },
        }),
      });
      return { doc: (id) => refDe(coleccion, id), where: (c, o, v) => consulta([[c, o, v]]) };
    },
  };
}

const ticketVivo = (dias, extra = {}) =>
  Object.assign(
    {
      id_vehiculo: 'v1',
      id_taller: 't1',
      estado: 'esperando_repuestos',
      vinculo_activo: true,
      fecha_actualizacion: hace(dias),
    },
    extra
  );

describe('caducarVinculos / caducarVinculosInactivos', () => {
  it('revoca el vinculo de un ticket abandonado y NO cierra el ticket', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketVivo(DIAS_CADUCIDAD_VINCULO + 1),
      'vehiculos/v1': { talleres_vinculados: ['t1'], talleres_conocidos: ['t1'] },
    });

    const { caducados } = await caducarVinculosInactivos(db, { ahora: AHORA });

    assert.strictEqual(caducados, 1);
    // El ticket sigue abierto y en su estado: lo que caduca es el acceso.
    assert.strictEqual(db.docs['reparaciones/r1'].estado, 'esperando_repuestos');
    assert.strictEqual(db.docs['reparaciones/r1'].vinculo_activo, false);
  });

  it('no toca un ticket con actividad reciente', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketVivo(DIAS_CADUCIDAD_VINCULO - 1),
      'vehiculos/v1': { talleres_vinculados: ['t1'] },
    });

    const { caducados } = await caducarVinculosInactivos(db, { ahora: AHORA });

    assert.strictEqual(caducados, 0);
    assert.deepStrictEqual(db.escrituras, []);
  });

  it('no vuelve a barrer lo que ya caduco', async () => {
    // Sin esto, cada corrida reprocesaria los mismos tickets abandonados para
    // siempre: la ventana se llenaria de tickets ya caducados y los que se
    // quedan rancios DESPUES no llegarian a barrerse nunca. Por eso la
    // consulta filtra por `vinculo_activo` y no por el estado del ticket.
    const db = fakeDb({
      'reparaciones/r1': ticketVivo(DIAS_CADUCIDAD_VINCULO + 99, {
        vinculo_activo: false,
      }),
      'vehiculos/v1': { talleres_vinculados: [] },
    });

    const { revisados, caducados } = await caducarVinculosInactivos(db, {
      ahora: AHORA,
    });

    assert.strictEqual(revisados, 0);
    assert.strictEqual(caducados, 0);
  });

  it('un vehiculo ya borrado no rompe el barrido, y el ticket se marca igual', async () => {
    // `revocarVinculo` trata el not-found como caso normal: si el dueño borro
    // el coche no hay vinculo que revocar. Lo que no puede pasar es que el
    // ticket se quede marcado como vinculado para siempre y el barrido lo
    // reintente en cada corrida.
    const db = fakeDb({
      'reparaciones/r1': ticketVivo(DIAS_CADUCIDAD_VINCULO + 1),
    });

    const { caducados } = await caducarVinculosInactivos(db, { ahora: AHORA });

    assert.strictEqual(caducados, 1);
    assert.strictEqual(db.docs['reparaciones/r1'].vinculo_activo, false);
  });

  // Gap 9.6 de GAPS-FUNC-02, que se remitio a OPS-01 y OPS-01 cerro sin
  // recogerlo.
  //
  // Cuando `revocarVinculoAlCerrar` falla, deja `vinculo_revocacion_pendiente`
  // en el ticket y el vinculo VIVO. La evidencia decia que nadie recoge esa
  // marca; al abrirlo resulta ser mas fino y menos tranquilizador de lo que
  // parece: el ticket conserva `vinculo_activo: true`, asi que este barrido SI
  // acaba viendolo — pero solo cuando pasen los 30 dias de inactividad, y ese
  // reloj arranca en el cierre. O sea que un fallo de revocacion regala **un
  // mes de acceso a la ficha de un coche que ya se devolvio**, que es
  // exactamente el estado que el cierre del ticket queria terminar.
  //
  // La marca dice "esto habia que revocarlo YA". El barrido tiene que tratarla
  // como tal y no esperar a que el ticket se ponga rancio.
  it('recoge de inmediato un ticket con revocacion pendiente, sin esperar al plazo', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketVivo(1, {
        estado: 'entregado',
        vinculo_revocacion_pendiente: true,
      }),
      'vehiculos/v1': { talleres_vinculados: ['t1'], talleres_conocidos: ['t1'] },
    });

    const { caducados } = await caducarVinculosInactivos(db, { ahora: AHORA });

    assert.strictEqual(caducados, 1);
    // El doble no ejecuta las transformaciones de Firestore, asi que
    // `talleres_vinculados` guarda el `arrayRemove` sin aplicar. Se afirma lo
    // que si es observable —que la revocacion se intento contra el vehiculo— y
    // no el resultado, que aqui solo probaria el doble.
    assert.ok(
      db.escrituras.some((e) => e.clave === 'vehiculos/v1'),
      'tiene que intentar revocar el vinculo en el vehiculo'
    );
    assert.strictEqual(db.docs['reparaciones/r1'].vinculo_activo, false);
  });

  // Sin esto la marca se queda puesta para siempre y miente: el vinculo ya no
  // existe, pero "cuantos vinculos quedaron colgando" —que es para lo que se
  // invento la marca— sigue contandolo.
  it('limpia la marca cuando consigue revocar', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketVivo(1, {
        estado: 'entregado',
        vinculo_revocacion_pendiente: true,
      }),
      'vehiculos/v1': { talleres_vinculados: ['t1'] },
    });

    await caducarVinculosInactivos(db, { ahora: AHORA });

    const escritura = db.escrituras.find((e) => e.clave === 'reparaciones/r1');
    assert.ok(escritura, 'el barrido tiene que escribir en el ticket');
    assert.ok(
      'vinculo_revocacion_pendiente' in escritura.data,
      'la marca tiene que limpiarse en la misma escritura'
    );
  });

  // Un ticket rancio Y marcado cae en las dos consultas. Procesarlo dos veces
  // seria una revocacion redundante y un contador inflado.
  it('no cuenta dos veces un ticket que es rancio y ademas esta marcado', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketVivo(DIAS_CADUCIDAD_VINCULO + 1, {
        vinculo_revocacion_pendiente: true,
      }),
      'vehiculos/v1': { talleres_vinculados: ['t1'] },
    });

    const { revisados, caducados } = await caducarVinculosInactivos(db, {
      ahora: AHORA,
    });

    assert.strictEqual(revisados, 1);
    assert.strictEqual(caducados, 1);
  });

  it('el plazo es configurable, para poder barrer mas agresivo si hace falta', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketVivo(10),
      'vehiculos/v1': { talleres_vinculados: ['t1'] },
    });

    const { caducados } = await caducarVinculosInactivos(db, {
      ahora: AHORA,
      dias: 7,
    });

    assert.strictEqual(caducados, 1);
  });
});
