'use strict';

/**
 * Gap 1 del §5 de `GAPS-05-drenaje.md` — el backfill que hace que la
 * denormalizacion del barrido no apague las alertas de produccion.
 *
 * Se prueba el predicado, que es lo unico que hay que acertar: el recorrido
 * paginado es el mismo patron que `backfill_ultimo_aviso.js` ya tiene probado,
 * pero decidir MAL el valor es irreversible en la practica — una alerta que
 * nazca del backfill con `false` no vuelve a salir en ninguna consulta, asi
 * que nadie vuelve a mirarla.
 */

const assert = require('assert');
const { avisosPendientesDe } = require('../backfill_avisos_pendientes');
const { ESCALONES } = require('../src/alertasVencidas');

describe('backfill_avisos_pendientes / avisosPendientesDe', () => {
  it('una alerta heredada SIN ultimo_aviso conserva sus avisos', () => {
    // El caso mayoritario en produccion, y el que mas importa: apagarlas seria
    // dejar sin avisar al parque entero.
    assert.strictEqual(avisosPendientesDe({ estado: 'Pendiente' }, ESCALONES), true);
  });

  it('una alerta en un escalon INTERMEDIO conserva sus avisos', () => {
    // Le queda `vencida` por delante, que es el aviso que mas importa.
    assert.strictEqual(avisosPendientesDe({ ultimo_aviso: 'por_vencer' }, ESCALONES), true);
  });

  it('una alerta que ya consumio el ULTIMO escalon se apaga', () => {
    // Es la que cuesta una lectura diaria para siempre sin dar nada a cambio.
    assert.strictEqual(avisosPendientesDe({ ultimo_aviso: 'vencida' }, ESCALONES), false);
  });

  it('un `ultimo_aviso` basura no apaga la alerta', () => {
    // Un valor que no sea el escalon terminal deja avisos por delante. El lado
    // seguro de un dato corrupto es avisar de mas, no callar.
    assert.strictEqual(avisosPendientesDe({ ultimo_aviso: 'quien-sabe' }, ESCALONES), true);
  });

  it('no revienta con un documento vacio o nulo', () => {
    assert.strictEqual(avisosPendientesDe({}, ESCALONES), true);
    assert.strictEqual(avisosPendientesDe(null, ESCALONES), true);
  });

  it('el terminal se DERIVA de ESCALONES, no esta escrito a pelo', () => {
    // Si manana se anade un escalon detras de `vencida`, este backfill tiene
    // que dejar encendidas las que estan en `vencida` — les quedaria uno por
    // delante. Escribir 'vencida' a pelo las apagaria antes de tiempo.
    const conUnoMas = ESCALONES.concat(['muy_vencida']);
    assert.strictEqual(avisosPendientesDe({ ultimo_aviso: 'vencida' }, conUnoMas), true);
    assert.strictEqual(avisosPendientesDe({ ultimo_aviso: 'muy_vencida' }, conUnoMas), false);
  });
});
