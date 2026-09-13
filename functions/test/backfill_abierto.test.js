'use strict';

/**
 * Gap 9.1: el tablero pasa de `estado whereIn [5 estados]` a la igualdad
 * `abierto == true`, porque Firestore ejecuta un `in` como N subconsultas
 * aplicando el `limit` a cada una — leia hasta 1000 documentos para devolver
 * 200.
 *
 * Y trae la trampa de siempre, la tercera vez ya en este mismo backfill: **una
 * igualdad sobre un campo ausente no devuelve nada**. Los tickets anteriores a
 * este cambio no traen `abierto`, asi que sin esta pasada desaparecen del
 * tablero en silencio — igual que el `whereIn` sobre `estado` (ronda 6) y el
 * `orderBy('fecha_actualizacion')` (residual 7.6).
 *
 * La decision vive fuera de `backfill_entregado.js` por lo mismo que la de las
 * fechas: ese script hace `require('./serviceAccountKey.json')` al cargarse y
 * ejecuta `main()` al final, asi que no se puede requerir desde una prueba.
 */

const assert = require('assert');

const { cambioAbierto } = require('../src/backfillAbierto');

describe('backfillAbierto / cambioAbierto', () => {
  it('escribe `abierto` cuando el ticket no lo tiene', () => {
    assert.deepStrictEqual(cambioAbierto({ estado: 'recibido' }, 'recibido'), {
      abierto: true,
    });
  });

  it('NO escribe nada en un ticket cerrado que no lo tiene', () => {
    // Gate de revision: la unica consulta que mira el campo es
    // `abierto == true`, y un cerrado SIN el campo se comporta exactamente
    // igual que uno con `abierto: false` — queda fuera del tablero. Escribirlo
    // seria una escritura y dos invocaciones de trigger por cada visita
    // entregada de la historia del proyecto, a cambio de nada.
    assert.deepStrictEqual(cambioAbierto({ estado: 'entregado' }, 'entregado'), {});
  });

  it('pero SI corrige un cerrado que dice estar abierto', () => {
    assert.deepStrictEqual(
      cambioAbierto({ estado: 'entregado', abierto: true }, 'entregado'),
      { abierto: false }
    );
  });

  it('no escribe nada si ya es correcto', () => {
    assert.deepStrictEqual(
      cambioAbierto({ estado: 'recibido', abierto: true }, 'recibido'),
      {}
    );
  });

  it('corrige un `abierto` que miente', () => {
    // No deberia poder existir —las reglas lo atan y los tres escritores
    // server-side lo derivan del estado—, pero el backfill es lo unico que
    // mira TODA la coleccion: si algo lo desincronizo antes de que la regla
    // existiera, este es el sitio donde se ve.
    assert.deepStrictEqual(
      cambioAbierto({ estado: 'en_revision', abierto: false }, 'en_revision'),
      { abierto: true }
    );
  });

  it('usa el estado RESULTANTE del backfill, no el que traia el documento', () => {
    // Las pasadas 1 y 2 pueden mover el estado en la misma corrida: un
    // `listo_para_entrega` rancio acaba en 'entregado'. Si esta pasada mirara
    // `data.estado` escribiria `abierto: true` sobre un ticket que la propia
    // corrida acaba de cerrar.
    // El ticket no trae el campo, asi que por la regla de arriba no se
    // escribe nada: queda fuera del tablero por ausencia, que es lo correcto
    // para un ticket que esta corrida acaba de cerrar. Lo que NO puede pasar
    // es que se le escriba `abierto: true`.
    assert.deepStrictEqual(
      cambioAbierto({ estado: 'listo_para_entrega' }, 'entregado'),
      {}
    );
    assert.deepStrictEqual(
      cambioAbierto({ estado: 'listo_para_entrega', abierto: true }, 'entregado'),
      { abierto: false }
    );
  });

  it('un ticket legado sin estado cuenta como abierto', () => {
    assert.deepStrictEqual(cambioAbierto({}, 'recibido'), { abierto: true });
  });
});
