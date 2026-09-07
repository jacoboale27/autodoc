'use strict';

/**
 * Ronda 5 — el vinculo taller-vehiculo sigue a la POSESION del coche.
 *
 * Estas pruebas cubren la logica que ANTES vivia en
 * `ReparacionRepository.recibirVehiculo` (cliente, sobre FakeFirebaseFirestore)
 * y que se mudo al servidor al tener que escribir el vinculo en la misma
 * operacion atomica que la recepcion.
 */

const assert = require('assert');
const { FieldValue } = require('firebase-admin/firestore');

const {
  ErrorRecepcion,
  debeRevocarVinculo,
  revocarVinculo,
  recibirTicketYVincular,
} = require('../src/vinculoTaller');

const AHORA = new Date('2026-09-06T12:00:00Z');

/**
 * Doble en memoria con lo justo que usan estas funciones: `doc().get()`,
 * `doc().update()` y un `batch()` que acumula y aplica. `docs` va indexado
 * por `coleccion/id`; una clave ausente es un documento que no existe.
 */
function fakeDb(docs = {}) {
  const escrituras = [];
  const refDe = (coleccion, id) => {
    const clave = `${coleccion}/${id}`;
    return {
      id,
      clave,
      async get() {
        return {
          exists: Object.prototype.hasOwnProperty.call(docs, clave),
          data: () => docs[clave],
        };
      },
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
  return {
    docs,
    escrituras,
    collection: (coleccion) => ({ doc: (id) => refDe(coleccion, id) }),
    // El batch del doble tiene que ser ATOMICO como el de verdad: comprueba
    // TODAS las precondiciones antes de escribir ninguna. Con un bucle que
    // escribia una a una, el test de "el vehiculo ya no existe" veia el ticket
    // recibido a medias — un artefacto del doble, no del codigo.
    batch() {
      const operaciones = [];
      return {
        update(ref, data) {
          operaciones.push({ ref, data });
        },
        async commit() {
          for (const { ref } of operaciones) {
            if (!Object.prototype.hasOwnProperty.call(docs, ref.clave)) {
              const error = new Error(`No document to update: ${ref.clave}`);
              error.code = 5;
              throw error;
            }
          }
          for (const { ref, data } of operaciones) await ref.update(data);
        },
      };
    },
  };
}

const ticketPendiente = (extra = {}) =>
  Object.assign(
    {
      id_vehiculo: 'v1',
      id_taller: 't1',
      id_propietario: 'cli1',
      placa: 'ABC123',
      estado: 'pendiente_recepcion',
      historial_estados: [{ estado: 'pendiente_recepcion', timestamp: AHORA }],
    },
    extra
  );

describe('vinculoTaller / debeRevocarVinculo', () => {
  it('revoca al pasar de abierto a cerrado', () => {
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'listo_para_entrega' }, { estado: 'entregado' }),
      true
    );
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'en_revision' }, { estado: 'cancelado' }),
      true
    );
  });

  it('NO revoca si el ticket sigue abierto', () => {
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'pendiente_recepcion' }, { estado: 'recibido' }),
      false
    );
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'recibido' }, { estado: 'en_revision' }),
      false
    );
  });

  it('RONDA 6: `listo_para_entrega` NO revoca — el coche sigue en el taller', () => {
    // Este era el bug: el ultimo estado del pipeline se tomaba por el final
    // de la visita, asi que al terminar el trabajo el taller perdia el acceso
    // a la ficha del coche que todavia tenia aparcado dentro, y una
    // cotizacion aceptada nueva del mismo cliente abria un SEGUNDO ticket
    // para la misma visita.
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'en_revision' }, { estado: 'listo_para_entrega' }),
      false
    );
    // Y desde ahi si se revoca, pero solo al entregar.
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'listo_para_entrega' }, { estado: 'cancelado' }),
      true
    );
  });

  it('NO revoca dos veces: una escritura sobre un ticket YA cerrado no cuenta', () => {
    // Sin esta guarda, cualquier correccion tardia sobre un ticket viejo
    // volveria a revocar — y si el mismo coche ya habia vuelto al mismo
    // taller, le arrancaria el vinculo VIVO de la visita nueva.
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'entregado' }, { estado: 'entregado' }),
      false
    );
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'cancelado' }, { estado: 'entregado' }),
      false
    );
  });

  it('un ticket legado sin `estado` cuenta como abierto (nacia en recibido)', () => {
    assert.strictEqual(debeRevocarVinculo({}, { estado: 'cancelado' }), true);
  });
});

describe('vinculoTaller / revocarVinculo', () => {
  it('saca al taller de talleres_vinculados', async () => {
    const db = fakeDb({ 'vehiculos/v1': { talleres_vinculados: ['t1'] } });

    assert.strictEqual(
      await revocarVinculo(db, { idVehiculo: 'v1', idTaller: 't1' }),
      true
    );
    assert.deepStrictEqual(db.escrituras[0].data.talleres_vinculados, FieldValue.arrayRemove('t1'));
  });

  it('un vehiculo ya borrado no es un error que reintentar', async () => {
    const db = fakeDb({});
    assert.strictEqual(
      await revocarVinculo(db, { idVehiculo: 'fantasma', idTaller: 't1' }),
      false
    );
  });
});

describe('vinculoTaller / recibirTicketYVincular', () => {
  it('mueve el ticket a recibido Y otorga el vinculo, en el mismo lote', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente(),
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
    });

    const resultado = await recibirTicketYVincular(db, {
      idReparacion: 'r1',
      ahora: AHORA,
    });

    assert.strictEqual(resultado.recibidoAhora, true);
    assert.strictEqual(db.docs['reparaciones/r1'].estado, 'recibido');
    assert.strictEqual(db.docs['reparaciones/r1'].historial_estados.length, 2);
    // Las dos mitades: sin la segunda, el ticket queda recibido y el taller
    // sigue sin poder abrir la ficha del coche que tiene en el patio.
    assert.deepStrictEqual(
      db.escrituras.map((e) => e.clave),
      ['reparaciones/r1', 'vehiculos/v1']
    );
    assert.deepStrictEqual(
      db.escrituras[1].data.talleres_vinculados,
      FieldValue.arrayUnion('t1')
    );
    // Ronda 6: ademas del vinculo "ahora", se deja constancia permanente de
    // que este taller ha tenido este coche. Es lo unico que le permitira
    // completar o corregir su propio registro de servicio despues de
    // entregarlo, sin reabrirle la ficha ajena a todo el mundo — ver el
    // carve-out de walk-in en firestore.rules.
    assert.deepStrictEqual(
      db.escrituras[1].data.talleres_conocidos,
      FieldValue.arrayUnion('t1')
    );
  });

  it('revocar el vinculo NO borra `talleres_conocidos`', async () => {
    // La visita termina y el taller pierde el acceso a la ficha, pero no la
    // historia de que atendio el coche: si `talleres_conocidos` se borrara,
    // el taller no podria ni corregir la factura que acaba de emitir.
    const db = fakeDb({ 'vehiculos/v1': { talleres_vinculados: ['t1'] } });

    await revocarVinculo(db, { idVehiculo: 'v1', idTaller: 't1' });

    assert.strictEqual(db.escrituras.length, 1);
    assert.ok(
      !Object.prototype.hasOwnProperty.call(
        db.escrituras[0].data,
        'talleres_conocidos'
      )
    );
  });

  it('recibir dos veces no es un error, y reasegura el vinculo', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente({ estado: 'en_revision' }),
      'vehiculos/v1': { placa: 'ABC123' },
    });

    const resultado = await recibirTicketYVincular(db, {
      idReparacion: 'r1',
      ahora: AHORA,
    });

    // No-op en el estado: no se arrastra hacia atras un ticket ya avanzado.
    assert.strictEqual(resultado.recibidoAhora, false);
    assert.strictEqual(db.docs['reparaciones/r1'].estado, 'en_revision');
    // Pero el vinculo SI se reescribe: un ticket abierto antes de que
    // existiera este flujo (o uno cuyo vinculo se revoco por error) recupera
    // el acceso al reabrirlo, en vez de quedarse sin ficha para siempre.
    assert.deepStrictEqual(
      db.escrituras.map((e) => e.clave),
      ['vehiculos/v1']
    );
  });

  it('un ticket CANCELADO se rechaza y no toca nada', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente({ estado: 'cancelado' }),
      'vehiculos/v1': { placa: 'ABC123' },
    });

    await assert.rejects(
      recibirTicketYVincular(db, { idReparacion: 'r1', ahora: AHORA }),
      (error) =>
        error instanceof ErrorRecepcion &&
        error.code === 'failed-precondition' &&
        /cancelado/.test(error.message)
    );
    assert.deepStrictEqual(db.escrituras, []);
  });

  it('un ticket YA ENTREGADO se rechaza y no toca nada', async () => {
    // Recibir un ticket cerrado volveria a otorgar el vinculo al vehiculo
    // sobre una visita que ya termino — el acceso permanente que la ronda 5
    // elimino, reintroducido por la puerta de atras.
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente({ estado: 'entregado' }),
      'vehiculos/v1': { placa: 'ABC123' },
    });

    await assert.rejects(
      recibirTicketYVincular(db, { idReparacion: 'r1', ahora: AHORA }),
      (error) =>
        error instanceof ErrorRecepcion &&
        error.code === 'failed-precondition' &&
        /ya se entreg/.test(error.message)
    );
    assert.deepStrictEqual(db.escrituras, []);
  });

  it('un ticket en `listo_para_entrega` SI se puede recibir (reasegura el vinculo)', async () => {
    // El coche sigue dentro: ese ticket esta abierto, y reabrir su pantalla
    // tiene que devolverle al taller el acceso a la ficha, no rechazarlo.
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente({ estado: 'listo_para_entrega' }),
      'vehiculos/v1': { placa: 'ABC123' },
    });

    const resultado = await recibirTicketYVincular(db, {
      idReparacion: 'r1',
      ahora: AHORA,
    });

    assert.strictEqual(resultado.recibidoAhora, false);
    assert.deepStrictEqual(db.escrituras.map((x) => x.clave), ['vehiculos/v1']);
  });

  it('un ticket que no existe se rechaza con not-found', async () => {
    const db = fakeDb({});
    await assert.rejects(
      recibirTicketYVincular(db, { idReparacion: 'fantasma', ahora: AHORA }),
      (error) => error instanceof ErrorRecepcion && error.code === 'not-found'
    );
  });

  it('si el vehiculo ya no existe, NO deja el ticket recibido a medias', async () => {
    // El lote es atomico: o entran las dos escrituras o ninguna. Sin eso, el
    // ticket quedaria en `recibido` y el taller sin acceso, que es justo el
    // estado inconsistente que este diseño existe para evitar.
    const db = fakeDb({ 'reparaciones/r1': ticketPendiente() });

    await assert.rejects(
      recibirTicketYVincular(db, { idReparacion: 'r1', ahora: AHORA }),
      (error) =>
        error instanceof ErrorRecepcion &&
        error.code === 'not-found' &&
        /ya no existe/.test(error.message)
    );
    assert.strictEqual(db.docs['reparaciones/r1'].estado, 'pendiente_recepcion');
  });
});
