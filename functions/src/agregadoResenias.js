'use strict';

/**
 * El agregado de calificaciones de un taller (`total_resenias`,
 * `suma_estrellas`, `calificacion_promedio`), y en concreto su **siembra**.
 *
 * Gap 5 del §5 de `GAPS-05-drenaje.md`. `aggregateRatings` mantiene el
 * agregado de forma incremental, pero para un taller que todavia no tiene
 * `suma_estrellas` cae a una "migracion perezosa" que recuenta sus resenias
 * enteras. Esa rama tenia dos problemas, y el segundo no estaba anotado:
 *
 * 1. El recuento era un `.get()` **sin cota**. Un taller con muchas resenias
 *    lo carga entero en memoria de la funcion.
 * 2. **La siembra no era transaccional.** El escenario que lo vuelve grave es
 *    el borrado de cuenta: `deleteQueryBatch` borra hasta 500 resenias a la
 *    vez, cada borrado dispara el trigger, y las 500 invocaciones leen
 *    `suma_estrellas === undefined` **a la vez**. Las 500 recuentan, las 500
 *    escriben, y cada una escribe el recuento de un instante distinto: gana la
 *    ultima, que no tiene por que ser la mas reciente. Ademas las 499 que
 *    pierden la carrera **descartan su delta**, porque la rama de migracion
 *    hace `return null` — asi que el agregado queda cuadrado por casualidad o
 *    no queda cuadrado.
 */

/** Cuantas resenias se leen por pagina en el recuento. */
const TAMANO_LOTE_RESENIAS = 500;

/**
 * Recuento completo de las resenias de un taller.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} tallerId
 * @param {{tamanoLote?: number}} [opciones]
 * @returns {Promise<{total: number, suma: number}>}
 */
async function recontarResenias(db, tallerId, opciones = {}) {
  const tamanoLote = opciones.tamanoLote || TAMANO_LOTE_RESENIAS;
  const base = db
    .collection('resenias')
    .where('id_taller', '==', tallerId);

  let total = 0;
  let suma = 0;
  let cursor = null;

  // Paginado por `__name__`, que es el unico orden que no exige indice
  // compuesto sobre una igualdad. El recuento sale igual que con un `.get()`
  // suelto; lo que cambia es que la funcion nunca tiene mas de `tamanoLote`
  // documentos en memoria a la vez.
  for (;;) {
    let q = base.orderBy('__name__').limit(tamanoLote);
    if (cursor) q = q.startAfter(cursor);
    const snap = await q.get();
    if (snap.empty) break;
    snap.forEach((doc) => {
      total += 1;
      suma += doc.data().estrellas || 0;
    });
    if (snap.size < tamanoLote) break;
    cursor = snap.docs[snap.docs.length - 1];
  }

  return { total, suma };
}

/**
 * Siembra el agregado, pero **solo si nadie lo ha sembrado ya**.
 *
 * @returns {Promise<boolean>} true si esta invocacion fue la que sembro.
 */
async function sembrarAgregado(db, userRef, { total, suma }) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    // El taller pudo borrarse entre el recuento y la siembra.
    if (!snap.exists) return false;
    // **La comprobacion que cierra la carrera.** El llamador ya miro
    // `suma_estrellas` antes de recontar, pero entre aquella lectura y esta
    // transaccion caben las otras 499 invocaciones del borrado de cuenta.
    // Volver a mirarlo DENTRO de la transaccion es lo que hace que siembre
    // exactamente una, y que las demas se enteren de que perdieron —para
    // aplicar su delta en vez de descartarlo.
    if (snap.data().suma_estrellas !== undefined) return false;
    tx.update(userRef, {
      calificacion_promedio: total > 0 ? suma / total : 0,
      total_resenias: total,
      suma_estrellas: suma,
    });
    return true;
  });
}

module.exports = { TAMANO_LOTE_RESENIAS, recontarResenias, sembrarAgregado };
