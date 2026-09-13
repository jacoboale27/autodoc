'use strict';

/**
 * Residual 7.6 de FUNC-02: el tablero Kanban pasa a ordenar por
 * `fecha_actualizacion` para poder acotarse con un `limit` que no recorte al
 * azar. Ese `orderBy` trae la trampa de siempre en Firestore —**excluye los
 * documentos que no tienen el campo**— y los tickets anteriores a A4b pueden
 * no tenerlo: desaparecerian del tablero en silencio, exactamente el mismo
 * fallo que el `whereIn` sobre `estado` ya obligo a cubrir con este backfill.
 *
 * La decision de que fecha escribir vive aqui, fuera de `backfill_entregado.js`,
 * porque ese script hace `require('./serviceAccountKey.json')` y
 * `admin.initializeApp()` al cargarse y ejecuta `main()` al final: no se puede
 * requerir desde una prueba. La parte que decide si, y con que valor, no
 * necesita nada de eso.
 */

const assert = require('assert');
const { Timestamp } = require('firebase-admin/firestore');

const {
  fechaActualizacionTolerante,
  cambioFechaActualizacion,
} = require('../src/backfillFechas');

const AYER = new Date('2026-09-09T10:00:00Z');
const ANTEAYER = new Date('2026-09-08T10:00:00Z');

describe('backfillFechas / fechaActualizacionTolerante', () => {
  it('prefiere `fecha_actualizacion` cuando esta', () => {
    assert.deepStrictEqual(
      fechaActualizacionTolerante({
        fecha_actualizacion: Timestamp.fromDate(AYER),
        fecha_creacion: Timestamp.fromDate(ANTEAYER),
      }),
      AYER
    );
  });

  it('cae a `fecha_creacion` si no hay actualizacion', () => {
    assert.deepStrictEqual(
      fechaActualizacionTolerante({ fecha_creacion: Timestamp.fromDate(ANTEAYER) }),
      ANTEAYER
    );
  });

  it('sin ninguna fecha, se trata como muy antiguo', () => {
    assert.deepStrictEqual(fechaActualizacionTolerante({}), new Date(0));
  });

  it('acepta un Date crudo, no solo un Timestamp', () => {
    assert.deepStrictEqual(
      fechaActualizacionTolerante({ fecha_actualizacion: AYER }),
      AYER
    );
  });
});

describe('backfillFechas / cambioFechaActualizacion', () => {
  it('no toca un ticket que ya tiene el campo', () => {
    assert.deepStrictEqual(
      cambioFechaActualizacion({
        fecha_actualizacion: Timestamp.fromDate(AYER),
      }),
      {}
    );
  });

  it('le escribe su ultima actividad REAL, no la fecha de la migracion', () => {
    // El mismo criterio que ya sigue `marcarEntregado`: `fecha_actualizacion`
    // es el unico registro de cuando el coche salio. Poner `new Date()` aqui
    // haria que todo ticket historico dijera que se movio el dia del backfill,
    // y ademas los pondria todos los primeros del tablero.
    assert.deepStrictEqual(
      cambioFechaActualizacion({ fecha_creacion: Timestamp.fromDate(ANTEAYER) }),
      { fecha_actualizacion: ANTEAYER }
    );
  });

  it('a un ticket sin ninguna fecha le pone la epoca, no la de hoy', () => {
    // Se ordena el ultimo, que es lo correcto: es el ticket del que menos se
    // sabe, y ordenar por actividad significa que lo mas rancio cae primero
    // fuera del tope.
    assert.deepStrictEqual(cambioFechaActualizacion({}), {
      fecha_actualizacion: new Date(0),
    });
  });
});
