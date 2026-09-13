'use strict';

/**
 * Marca de "esta escritura la hizo un script de mantenimiento, no una persona".
 *
 * Los triggers `onUpdate` de `reparaciones` no pueden distinguir por si solos
 * una transicion real de una reescritura masiva de datos historicos: los dos
 * casos llegan como "el campo `estado` cambio". La revision adversarial de la
 * ronda 6 encontro la consecuencia: `backfill_entregado.js` habria mandado al
 * propietario un push Y una fila permanente en su centro de notificaciones por
 * CADA ticket historico que reescribe — "PLACA: Entregado" sobre un coche que
 * se llevo hace meses, "PLACA: Recibido" sobre uno que nunca volvio.
 *
 * Se comprobo contra produccion que el mecanismo funciona tal cual: una sola
 * entrega de prueba subio el contador de notificaciones del propietario de 7 a
 * 10 filas, una por cambio de estado.
 *
 * El campo lo escriben los scripts de mantenimiento (Admin SDK, que no pasa
 * por `firestore.rules`) y las limpiezas automaticas del servidor. Un cliente
 * NO puede escribirlo: la regla de update de `/reparaciones` lo prohibe
 * explicitamente, porque si no un taller podria entregar coches sin que el
 * propietario se enterase nunca.
 */
const CAMPO_MIGRACION = 'migracion_ronda6';

/**
 * @param {object} data documento resultante de la escritura
 * @returns {boolean} `true` si la escritura viene de una migracion
 */
function esMigracion(data) {
  return !!(data && data[CAMPO_MIGRACION] === true);
}

/**
 * ¿Este conjunto de cambios necesita llevar el centinela?
 *
 * Solo lo necesita el cambio que puede disparar un trigger de `reparaciones`,
 * y los dos que hay salen por su cuenta cuando el estado no se mueve:
 * `notifyOnReparacionStatusChange` compara `before.estado === after.estado` y
 * `debeRevocarVinculo` devuelve `false` si no hubo transicion.
 *
 * Que importe es consecuencia de que el centinela sea PEGAJOSO: `esMigracion`
 * mira el documento resultante, no el delta, y nadie lo borra nunca. Marcar un
 * ticket VIVO no silencia una escritura, lo silencia para siempre — deja de
 * notificarle al propietario cada transicion futura y deja de revocar el
 * vinculo al entregarlo. `backfill_entregado.js` lo estampaba en cada cambio,
 * y su pasada de `abierto` toca la coleccion entera: lo encontro el gate de
 * revision de la tanda de gaps 02.
 *
 * @param {object} cambio campos que la escritura va a aplicar
 * @returns {boolean}
 */
function cambioNecesitaCentinela(cambio) {
  if (!cambio) return false;
  return (
    Object.prototype.hasOwnProperty.call(cambio, 'estado') ||
    Object.prototype.hasOwnProperty.call(cambio, 'historial_estados')
  );
}

module.exports = { CAMPO_MIGRACION, esMigracion, cambioNecesitaCentinela };
