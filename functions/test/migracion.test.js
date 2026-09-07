'use strict';

/**
 * Ronda 6 — el centinela que impide que una migracion de datos se convierta en
 * notificaciones a usuarios reales.
 *
 * Lo cubre a nivel de predicado porque es lo unico que hay que acertar: los dos
 * triggers de `reparaciones` (`notifyOnReparacionStatusChange` y
 * `revocarVinculoAlCerrarTicket`) lo consultan como primera linea, antes de
 * cualquier otra logica.
 */

const assert = require('assert');
const { CAMPO_MIGRACION, esMigracion } = require('../src/migracion');

describe('migracion / esMigracion', () => {
  it('reconoce una escritura marcada por un script de mantenimiento', () => {
    assert.strictEqual(esMigracion({ [CAMPO_MIGRACION]: true }), true);
  });

  it('una escritura normal de la app NO es migracion', () => {
    assert.strictEqual(esMigracion({ estado: 'entregado' }), false);
  });

  it('el campo ausente no es migracion', () => {
    assert.strictEqual(esMigracion({}), false);
  });

  it('un documento nulo o indefinido no revienta', () => {
    // Los triggers hacen `change.after.data() || {}`, pero un borrado
    // concurrente puede dejar esto en null segun la ruta.
    assert.strictEqual(esMigracion(null), false);
    assert.strictEqual(esMigracion(undefined), false);
  });

  it('solo el booleano `true` cuenta, no cualquier valor truthy', () => {
    // Un dato basura heredado ('1', 'true', 1) no debe silenciar las
    // notificaciones de un ticket real: la marca es deliberada o no es.
    assert.strictEqual(esMigracion({ [CAMPO_MIGRACION]: 'true' }), false);
    assert.strictEqual(esMigracion({ [CAMPO_MIGRACION]: 1 }), false);
    assert.strictEqual(esMigracion({ [CAMPO_MIGRACION]: false }), false);
  });
});
