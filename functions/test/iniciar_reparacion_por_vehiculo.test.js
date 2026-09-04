'use strict';

/**
 * Cobertura del hallazgo 1 de la revision de la Tarea 4 (A4b): el callable
 * `iniciarReparacionPorVehiculo` corre con Admin SDK, asi que
 * `firestore.rules` (que cierra `allow create` de /reparaciones con `if
 * false`) no lo alcanza. Antes de este arreglo abria un ticket en 'recibido'
 * sin exigir ni vinculo del taller al vehiculo ni cotizacion aceptada — la
 * unica puerta server-side que quedaba para recibir un vehiculo sin que
 * nadie hubiera aceptado nada (A3).
 *
 * Se testea `verificarAperturaManual` (extraida a
 * functions/src/iniciarReparacionPorVehiculo.js) contra un doble de
 * Firestore en memoria, mismo patron que aceptar_cotizacion.test.js:
 * stubbear `admin.firestore` es hostil porque leer esa propiedad dispara
 * `ensureApp()`.
 */

const assert = require('assert');

const {
  vehiculoVinculadoOWalkIn,
  existeCotizacionAceptada,
  verificarAperturaManual,
} = require('../src/iniciarReparacionPorVehiculo');

/**
 * Doble en memoria de Firestore con lo justo que usa este modulo:
 * `collection(x).doc(y).get()` y `collection(x).where(...).where(...)
 * .where(...).limit(n).get()` con igualdad exacta en cada `where`.
 *
 * @param {{vehiculos?: object, cotizaciones?: Array<object>}} datos
 */
function fakeDb({ vehiculos = {}, cotizaciones = [] } = {}) {
  return {
    collection(nombre) {
      if (nombre === 'vehiculos') {
        return {
          doc(id) {
            return {
              async get() {
                return {
                  exists: Object.prototype.hasOwnProperty.call(vehiculos, id),
                  data: () => vehiculos[id],
                };
              },
            };
          },
        };
      }

      if (nombre === 'cotizaciones') {
        const filtros = [];
        const query = {
          where(campo, op, valor) {
            assert.strictEqual(op, '==', 'este doble solo soporta igualdad');
            filtros.push([campo, valor]);
            return query;
          },
          limit() {
            return query;
          },
          async get() {
            const docs = cotizaciones.filter((c) =>
              filtros.every(([campo, valor]) => c[campo] === valor)
            );
            return { empty: docs.length === 0, docs };
          },
        };
        return query;
      }

      throw new Error(`coleccion inesperada en el doble: ${nombre}`);
    },
  };
}

describe('iniciarReparacionPorVehiculo / vehiculoVinculadoOWalkIn', () => {
  it('deja pasar el walk-in: vehiculo sin ningun taller vinculado', () => {
    assert.strictEqual(vehiculoVinculadoOWalkIn([], 't1'), true);
  });

  it('deja pasar al taller que ya esta vinculado', () => {
    assert.strictEqual(vehiculoVinculadoOWalkIn(['t1', 't2'], 't1'), true);
  });

  it('bloquea a un taller distinto del vinculado', () => {
    assert.strictEqual(vehiculoVinculadoOWalkIn(['t2'], 't1'), false);
  });

  it('trata el campo ausente igual que una lista vacia', () => {
    assert.strictEqual(vehiculoVinculadoOWalkIn(undefined, 't1'), true);
  });
});

describe('iniciarReparacionPorVehiculo / existeCotizacionAceptada', () => {
  it('encuentra la cotizacion aceptada de ese vehiculo+taller', async () => {
    const db = fakeDb({
      cotizaciones: [
        { id_vehiculo: 'v1', id_taller: 't1', estado: 'aceptada' },
      ],
    });

    assert.strictEqual(
      await existeCotizacionAceptada(db, { idVehiculo: 'v1', idTaller: 't1' }),
      true
    );
  });

  it('no cuenta una cotizacion pendiente o de otro taller', async () => {
    const db = fakeDb({
      cotizaciones: [
        { id_vehiculo: 'v1', id_taller: 't1', estado: 'pendiente' },
        { id_vehiculo: 'v1', id_taller: 't2', estado: 'aceptada' },
      ],
    });

    assert.strictEqual(
      await existeCotizacionAceptada(db, { idVehiculo: 'v1', idTaller: 't1' }),
      false
    );
  });
});

describe('iniciarReparacionPorVehiculo / verificarAperturaManual', () => {
  it('falla con not-found si el vehiculo no existe', async () => {
    const db = fakeDb();

    const resultado = await verificarAperturaManual(db, {
      idVehiculo: 'fantasma',
      idTaller: 't1',
    });

    assert.deepStrictEqual(resultado.ok, false);
    assert.strictEqual(resultado.code, 'not-found');
  });

  it('falla con permission-denied si el vehiculo esta vinculado a OTRO taller', async () => {
    // Hallazgo 1: esta es exactamente la comprobacion que la vieja regla
    // `allow create` de /reparaciones hacia y que el callable, corriendo con
    // Admin SDK, se saltaba por completo.
    const db = fakeDb({
      vehiculos: { v1: { talleres_vinculados: ['t2'] } },
      cotizaciones: [
        { id_vehiculo: 'v1', id_taller: 't1', estado: 'aceptada' },
      ],
    });

    const resultado = await verificarAperturaManual(db, {
      idVehiculo: 'v1',
      idTaller: 't1',
    });

    assert.strictEqual(resultado.ok, false);
    assert.strictEqual(resultado.code, 'permission-denied');
  });

  it('falla con failed-precondition si no hay cotizacion aceptada (A3)', async () => {
    const db = fakeDb({
      vehiculos: { v1: { talleres_vinculados: [] } },
      cotizaciones: [],
    });

    const resultado = await verificarAperturaManual(db, {
      idVehiculo: 'v1',
      idTaller: 't1',
    });

    assert.strictEqual(resultado.ok, false);
    assert.strictEqual(resultado.code, 'failed-precondition');
  });

  it('deja pasar el walk-in con cotizacion aceptada', async () => {
    const db = fakeDb({
      vehiculos: { v1: {} }, // sin 'talleres_vinculados': walk-in
      cotizaciones: [
        { id_vehiculo: 'v1', id_taller: 't1', estado: 'aceptada' },
      ],
    });

    const resultado = await verificarAperturaManual(db, {
      idVehiculo: 'v1',
      idTaller: 't1',
    });

    assert.deepStrictEqual(resultado, { ok: true });
  });

  it('deja pasar al taller ya vinculado con cotizacion aceptada', async () => {
    const db = fakeDb({
      vehiculos: { v1: { talleres_vinculados: ['t1'] } },
      cotizaciones: [
        { id_vehiculo: 'v1', id_taller: 't1', estado: 'aceptada' },
      ],
    });

    const resultado = await verificarAperturaManual(db, {
      idVehiculo: 'v1',
      idTaller: 't1',
    });

    assert.deepStrictEqual(resultado, { ok: true });
  });
});
