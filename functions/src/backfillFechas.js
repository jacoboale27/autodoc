'use strict';

/**
 * La parte decidible del backfill de `fecha_actualizacion`, fuera del script.
 *
 * `backfill_entregado.js` hace `require('./serviceAccountKey.json')` y
 * `admin.initializeApp()` al cargarse, y ejecuta `main()` al final: no se puede
 * requerir desde una prueba. Lo que decide QUE escribir no necesita nada de
 * eso, asi que vive aqui — mismo criterio que `aceptarCotizacion.js` y
 * `vinculoTaller.js` siguen respecto de los handlers de sus triggers.
 *
 * **Por que hace falta (residual 7.6 de FUNC-02).** El tablero Kanban pasa a
 * ordenar por `fecha_actualizacion` para poder acotarse con un `limit` que no
 * recorte al azar. Un `orderBy` en Firestore EXCLUYE los documentos que no
 * tienen el campo, y los tickets anteriores a A4b pueden no tenerlo: sin este
 * backfill desaparecerian del tablero en silencio, que es exactamente el fallo
 * que el `whereIn` sobre `estado` ya obligo a cubrir en la ronda 6.
 */

/**
 * `fecha_actualizacion` tolerante: cae a `fecha_creacion`, y sin ninguna de
 * las dos trata el documento como muy antiguo.
 *
 * @param {object} data documento de `reparaciones`
 * @returns {Date}
 */
function fechaActualizacionTolerante(data) {
  const valor = data.fecha_actualizacion || data.fecha_creacion;
  if (valor && typeof valor.toDate === 'function') return valor.toDate();
  if (valor instanceof Date) return valor;
  return new Date(0);
}

/**
 * Que escribirle a un ticket para que tenga `fecha_actualizacion`, o `{}` si
 * ya la tiene.
 *
 * El valor es su ultima actividad REAL, nunca `new Date()`: `fecha_actualizacion`
 * es el unico registro de cuando se movio el ticket por ultima vez, y sellarlos
 * todos con el dia de la migracion los pondria ademas a todos los primeros del
 * tablero, empujando fuera del tope a los tickets vivos de verdad.
 *
 * @param {object} data documento de `reparaciones`
 * @returns {object} campos a fusionar, posiblemente vacio
 */
function cambioFechaActualizacion(data) {
  if (data.fecha_actualizacion) return {};
  return { fecha_actualizacion: fechaActualizacionTolerante(data) };
}

module.exports = { fechaActualizacionTolerante, cambioFechaActualizacion };
