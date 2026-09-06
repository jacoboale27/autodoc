'use strict';

/**
 * Cobertura de FIX 4 (Ronda 2): `sincronizarReservaYReparacionAlCotizar`
 * tomaba `after.id_reserva` (dato que escribe quien crea la cotizacion,
 * nunca validado) y forzaba `estado` sobre esa reserva con Admin SDK sin
 * comprobar que la reserva perteneciera a los mismos participantes.
 * Encadenado a la auto-aceptacion de FIX 1, un mecanico podia voltear
 * cualquier reserva de la base de datos.
 *
 * Mismo patron que aceptar_cotizacion.test.js: `db` inyectado, doble en
 * memoria, sin emulador.
 */

const assert = require('assert');

const {
  reservaPerteneceACotizacion,
  sincronizarReservaAlCotizar,
} = require('../src/sincronizarReservaAlCotizar');

function fakeDb(docs = {}) {
  const escrituras = [];
  return {
    docs,
    escrituras,
    collection(coleccion) {
      return {
        doc(id) {
          const clave = `${coleccion}/${id}`;
          return {
            id,
            async get() {
              return {
                exists: Object.prototype.hasOwnProperty.call(docs, clave),
                data: () => docs[clave],
              };
            },
            async update(data) {
              escrituras.push({ clave, data });
              if (!Object.prototype.hasOwnProperty.call(docs, clave)) {
                throw new Error(`NOT_FOUND: ${clave}`);
              }
              docs[clave] = Object.assign({}, docs[clave], data);
            },
          };
        },
      };
    },
  };
}

describe('sincronizarReservaAlCotizar / reservaPerteneceACotizacion', () => {
  it('coincide si mismo id_propietario y mismo id_taller', () => {
    assert.strictEqual(
      reservaPerteneceACotizacion(
        { id_propietario: 'cli1', id_taller: 't1' },
        { id_propietario: 'cli1', id_taller: 't1' }
      ),
      true
    );
  });

  it('NO coincide si el propietario difiere (ataque: reserva de otro cliente)', () => {
    assert.strictEqual(
      reservaPerteneceACotizacion(
        { id_propietario: 'victima', id_taller: 't1' },
        { id_propietario: 'cli1', id_taller: 't1' }
      ),
      false
    );
  });

  it('NO coincide si el taller difiere', () => {
    assert.strictEqual(
      reservaPerteneceACotizacion(
        { id_propietario: 'cli1', id_taller: 't-otro' },
        { id_propietario: 'cli1', id_taller: 't1' }
      ),
      false
    );
  });

  it('NO coincide si la reserva es null (no existe)', () => {
    assert.strictEqual(
      reservaPerteneceACotizacion(null, { id_propietario: 'cli1', id_taller: 't1' }),
      false
    );
  });
});

describe('sincronizarReservaAlCotizar / sincronizarReservaAlCotizar', () => {
  it('LEGITIMO: escribe el estado cuando la reserva pertenece a la misma cotizacion', async () => {
    const db = fakeDb({
      'reservas/r1': { id_propietario: 'cli1', id_taller: 't1', estado: 'pendiente' },
    });

    const escrito = await sincronizarReservaAlCotizar(db, {
      cotizacionId: 'c1',
      cotizacion: { id_propietario: 'cli1', id_taller: 't1', id_reserva: 'r1' },
      nuevoEstadoReserva: 'confirmada',
      fechaHoraConfirmada: null,
    });

    assert.strictEqual(escrito, true);
    assert.strictEqual(db.docs['reservas/r1'].estado, 'confirmada');
  });

  it('ATAQUE: NO escribe si la reserva pertenece a otro propietario (mecanico apunta id_reserva a la victima)', async () => {
    const db = fakeDb({
      'reservas/r-victima': {
        id_propietario: 'victima',
        id_taller: 't-otro',
        estado: 'pendiente',
      },
    });
    const error = require('sinon').stub(console, 'error');
    try {
      const escrito = await sincronizarReservaAlCotizar(db, {
        cotizacionId: 'c-ataque',
        cotizacion: { id_propietario: 'mec1', id_taller: 'mec1', id_reserva: 'r-victima' },
        nuevoEstadoReserva: 'confirmada',
        fechaHoraConfirmada: null,
      });

      assert.strictEqual(escrito, false);
      assert.deepStrictEqual(db.escrituras, []);
      assert.strictEqual(
        db.docs['reservas/r-victima'].estado,
        'pendiente',
        'la reserva de la victima no debe cambiar de estado'
      );
    } finally {
      error.restore();
    }
  });

  it('no hace nada si la cotizacion no trae id_reserva', async () => {
    const db = fakeDb();
    const escrito = await sincronizarReservaAlCotizar(db, {
      cotizacionId: 'c1',
      cotizacion: { id_propietario: 'cli1', id_taller: 't1' },
      nuevoEstadoReserva: 'confirmada',
      fechaHoraConfirmada: null,
    });
    assert.strictEqual(escrito, false);
    assert.deepStrictEqual(db.escrituras, []);
  });

  it('no hace nada si la reserva referida no existe', async () => {
    const db = fakeDb();
    const error = require('sinon').stub(console, 'error');
    try {
      const escrito = await sincronizarReservaAlCotizar(db, {
        cotizacionId: 'c1',
        cotizacion: { id_propietario: 'cli1', id_taller: 't1', id_reserva: 'fantasma' },
        nuevoEstadoReserva: 'confirmada',
        fechaHoraConfirmada: null,
      });
      assert.strictEqual(escrito, false);
      assert.deepStrictEqual(db.escrituras, []);
    } finally {
      error.restore();
    }
  });

  it('incluye fecha_hora_confirmada solo cuando el estado nuevo es confirmada y hay fecha', async () => {
    const db = fakeDb({
      'reservas/r1': { id_propietario: 'cli1', id_taller: 't1', estado: 'pendiente' },
    });
    await sincronizarReservaAlCotizar(db, {
      cotizacionId: 'c1',
      cotizacion: { id_propietario: 'cli1', id_taller: 't1', id_reserva: 'r1' },
      nuevoEstadoReserva: 'confirmada',
      fechaHoraConfirmada: 'FECHA-X',
    });
    assert.strictEqual(db.docs['reservas/r1'].fecha_hora_confirmada, 'FECHA-X');
  });
});
