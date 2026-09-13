'use strict';

const { ticketAbierto } = require('./aceptarCotizacion');

/**
 * ¿Qué hay que escribirle a este ticket para que su `abierto` diga la verdad?
 *
 * Devuelve `{}` cuando ya la dice — el backfill recorre la coleccion entera y
 * una escritura de mas por ticket son dos invocaciones de trigger y dos
 * facturas.
 *
 * [estadoResultante] es el estado con el que el ticket QUEDA despues de las
 * pasadas 1 y 2 de la misma corrida, no el que traia el documento: un
 * `listo_para_entrega` rancio acaba en 'entregado', y mirar `data.estado`
 * escribiria `abierto: true` sobre un ticket que la propia corrida acaba de
 * cerrar.
 *
 * @param {object} data documento actual de `reparaciones`
 * @param {string} estadoResultante
 * @returns {{abierto?: boolean}}
 */
function cambioAbierto(data, estadoResultante) {
  const debeSer = ticketAbierto(estadoResultante);
  const presente = data && Object.prototype.hasOwnProperty.call(data, 'abierto');
  // Un ticket CERRADO sin el campo se comporta ya como debe: la unica consulta
  // que lo mira es `abierto == true`, y una igualdad no devuelve documentos
  // sin el campo. Escribirselo seria una escritura y dos invocaciones de
  // trigger por cada visita entregada de la historia del proyecto, a cambio de
  // nada — y con el centinela de migracion detras, que es pegajoso. Lo
  // encontro el gate de revision de esta tanda.
  if (!presente && !debeSer) return {};
  return presente && data.abierto === debeSer ? {} : { abierto: debeSer };
}

module.exports = { cambioAbierto };
