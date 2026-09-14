'use strict';

/**
 * Gap 5 del §5 de `GAPS-05-drenaje.md` — la siembra del agregado de
 * calificaciones de un taller.
 *
 * Los dos tests que importan miden cosas que ningun test del repo podia ver:
 * cuantas paginas pide el recuento, y que pasa cuando dos invocaciones del
 * trigger siembran a la vez. Por eso el doble de Firestore de aqui **lleva
 * contadores y puede perder la carrera**: un doble que siempre gana no puede
 * fallar, y un doble que no puede fallar no prueba nada (la cicatriz que el
 * repo ya tiene con `startAfter` como no-op).
 */

const assert = require('assert');
const {
  TAMANO_LOTE_RESENIAS,
  recontarResenias,
  sembrarAgregado,
} = require('../src/agregadoResenias');

/** Doble de Firestore con solo lo que estas dos funciones usan. */
function fakeDb(resenias) {
  const estado = { paginas: 0, mayorLimitePedido: 0 };

  function consulta(desde, tope) {
    return {
      orderBy: () => consulta(desde, tope),
      limit: (n) => {
        estado.mayorLimitePedido = Math.max(estado.mayorLimitePedido, n);
        return consulta(desde, n);
      },
      startAfter: (cursor) => {
        const i = resenias.findIndex((r) => r.id === cursor.id);
        return consulta(i + 1, tope);
      },
      get: async () => {
        estado.paginas += 1;
        const trozo = resenias.slice(desde, tope ? desde + tope : undefined);
        return {
          size: trozo.length,
          empty: trozo.length === 0,
          docs: trozo.map((r) => ({ id: r.id, data: () => r })),
          forEach: (f) => trozo.forEach((r) => f({ id: r.id, data: () => r })),
        };
      },
    };
  }

  return {
    estado,
    collection: () => ({ where: () => consulta(0, null) }),
  };
}

function reseniasDe(n, estrellas = 4) {
  return Array.from({ length: n }, (_, i) => ({
    id: `r${String(i).padStart(5, '0')}`,
    estrellas,
  }));
}

describe('agregadoResenias / recontarResenias', () => {
  it('cuenta bien un taller pequeno', async () => {
    const db = fakeDb([
      { id: 'r1', estrellas: 5 },
      { id: 'r2', estrellas: 3 },
    ]);
    assert.deepStrictEqual(await recontarResenias(db, 't1'), {
      total: 2,
      suma: 8,
    });
  });

  it('una resenia sin estrellas cuenta como documento pero suma 0', async () => {
    const db = fakeDb([{ id: 'r1' }, { id: 'r2', estrellas: 4 }]);
    assert.deepStrictEqual(await recontarResenias(db, 't1'), {
      total: 2,
      suma: 4,
    });
  });

  it('el recuento va PAGINADO, no de un solo `get()`', async () => {
    // Lo que se afirma no es el resultado —sale igual con cota y sin ella—
    // sino cuanto se pide de golpe. Sin cota, un taller grande se carga
    // entero en la memoria de la funcion.
    const db = fakeDb(reseniasDe(TAMANO_LOTE_RESENIAS * 2 + 7));

    const r = await recontarResenias(db, 't1');

    assert.strictEqual(r.total, TAMANO_LOTE_RESENIAS * 2 + 7);
    assert.ok(
      db.estado.paginas >= 3,
      `esperaba al menos 3 paginas, hubo ${db.estado.paginas}`
    );
    assert.strictEqual(db.estado.mayorLimitePedido, TAMANO_LOTE_RESENIAS);
  });

  it('un taller sin resenias no revienta ni entra en bucle', async () => {
    const db = fakeDb([]);
    assert.deepStrictEqual(await recontarResenias(db, 't1'), {
      total: 0,
      suma: 0,
    });
  });
});

describe('agregadoResenias / sembrarAgregado', () => {
  /** Doble del documento del taller con transaccion de verdad. */
  function fakeUsuario(datosIniciales) {
    const doc = { ...datosIniciales };
    const escrituras = [];
    const userRef = {
      _doc: doc,
      update: (cambios) => {
        escrituras.push(cambios);
        Object.assign(doc, cambios);
        return Promise.resolve();
      },
    };
    const db = {
      runTransaction: async (fn) =>
        fn({
          get: async (ref) => ({
            exists: true,
            data: () => ({ ...ref._doc }),
          }),
          update: (ref, cambios) => {
            escrituras.push(cambios);
            Object.assign(ref._doc, cambios);
          },
        }),
    };
    return { db, userRef, doc, escrituras };
  }

  it('siembra cuando el taller aun no tiene agregado', async () => {
    const { db, userRef, doc } = fakeUsuario({ nombre: 'Taller' });

    const sembro = await sembrarAgregado(db, userRef, { total: 4, suma: 18 });

    assert.strictEqual(sembro, true);
    assert.strictEqual(doc.total_resenias, 4);
    assert.strictEqual(doc.suma_estrellas, 18);
    assert.strictEqual(doc.calificacion_promedio, 4.5);
  });

  it('NO pisa un agregado que otra invocacion ya sembro', async () => {
    // El escenario es el borrado de cuenta: `deleteQueryBatch` borra 500
    // resenias a la vez y dispara 500 veces el trigger. Todas leen
    // `suma_estrellas === undefined` antes de que ninguna escriba. Si la
    // siembra no comprueba de nuevo DENTRO de la transaccion, las 500
    // escriben recuentos de instantes distintos y gana la ultima en llegar,
    // que no es la mas reciente. Y las que pierden descartan su delta.
    const { db, userRef, doc, escrituras } = fakeUsuario({
      total_resenias: 10,
      suma_estrellas: 45,
      calificacion_promedio: 4.5,
    });

    const sembro = await sembrarAgregado(db, userRef, { total: 3, suma: 3 });

    assert.strictEqual(
      sembro,
      false,
      'debe avisar de que perdio la carrera para que el llamador aplique su delta'
    );
    assert.strictEqual(doc.total_resenias, 10, 'no debe pisar el agregado vivo');
    assert.strictEqual(escrituras.length, 0, 'no debe escribir nada');
  });

  it('un taller borrado a media siembra no revienta', async () => {
    const userRef = { _doc: null };
    const db = {
      runTransaction: async (fn) =>
        fn({ get: async () => ({ exists: false }), update: () => {} }),
    };

    assert.strictEqual(
      await sembrarAgregado(db, userRef, { total: 1, suma: 5 }),
      false
    );
  });
});
