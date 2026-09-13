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
const {
  CAMPO_MIGRACION,
  esMigracion,
  cambioNecesitaCentinela,
} = require('../src/migracion');

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

/**
 * Gate de revision de la tanda de gaps 02 (hallazgo ALTO del revisor de
 * Functions).
 *
 * El centinela es PEGAJOSO: `esMigracion` mira el documento RESULTANTE, nunca
 * el delta, y nadie lo borra jamas —la regla de update prohibe al cliente
 * tocarlo—. Asi que estamparlo sobre un ticket VIVO no silencia una escritura:
 * silencia todas las suyas para siempre. A partir de esa corrida, ese ticket
 * ya no notifica ninguna transicion al propietario y, peor,
 * `revocarVinculoAlCerrarTicket` tampoco revoca el vinculo al entregarlo — el
 * taller conserva el acceso a la ficha del coche hasta que lo caduque el
 * barrido de 30 dias.
 *
 * El backfill lo estampaba en CADA cambio, incluida la pasada 4 de `abierto`,
 * que toca la coleccion entera. Ahora solo lo lleva el cambio que de verdad
 * puede disparar un trigger: el que mueve el estado.
 */
describe('migracion / cambioNecesitaCentinela', () => {
  it('un cambio que mueve el estado lo necesita', () => {
    assert.strictEqual(cambioNecesitaCentinela({ estado: 'entregado' }), true);
  });

  it('tambien lo necesita si solo reescribe el historial', () => {
    assert.strictEqual(
      cambioNecesitaCentinela({ historial_estados: [] }),
      true
    );
  });

  it('un cambio que solo escribe `abierto` NO lo necesita', () => {
    // Los dos triggers salen solos cuando el estado no cambia
    // (`before.estado === after.estado` y `debeRevocarVinculo`), asi que
    // marcarlo no evita ninguna notificacion — solo condena al ticket.
    assert.strictEqual(cambioNecesitaCentinela({ abierto: true }), false);
  });

  it('un cambio que solo escribe la fecha tampoco', () => {
    assert.strictEqual(
      cambioNecesitaCentinela({ fecha_actualizacion: new Date() }),
      false
    );
  });
});
