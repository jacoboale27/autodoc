'use strict';

/**
 * Residual de FUNC-01 — al ELIMINAR una resenia, sus fotos se quedaban en
 * Storage para siempre.
 *
 * FUNC-01 dejo la EDICION consistente: la lista es explicita y el huerfano se
 * borra tras confirmar la escritura en Firestore. Lo que no cubrio es el
 * borrado del documento entero, y son dos caminos:
 *
 *   1. El autor borra su resenia desde la app.
 *   2. Se borra la CUENTA: el barrido de `deleteUserData` elimina las resenias
 *      del usuario en lotes de 500, sin pasar por la app.
 *
 * No es solo coste de almacenamiento. Son fotos del coche de alguien que pidio
 * que se borraran, y el objeto sigue siendo descargable por su URL.
 *
 * **Por URL exacta, no por prefijo.** `storage.rules` obliga a que las fotos
 * de una resenia vivan bajo `resenia_fotos/{idServicio}/`, asi que borrar ese
 * prefijo parece lo natural — pero el id del documento se deriva de usuario +
 * servicio (`ReviewService._reviewDocId`), asi que dos resenias pueden
 * compartir prefijo y el borrado se llevaria las fotos de la otra.
 *
 * **Por que se valida la ruta aqui tambien.** `fotos` lo escribe el cliente.
 * Las reglas lo acotan con `fotosBajoServicio`, pero esta funcion corre con
 * Admin SDK y las reglas no la alcanzan; y las resenias anteriores a FUNC-01
 * pudieron guardar URLs que ese filtro no habria dejado pasar. Sin este
 * candado, escribir una cadena en un documento se convertiria en un borrado
 * arbitrario de cualquier objeto del bucket.
 */

/** Prefijo unico bajo el que pueden vivir las fotos de una resenia. */
const PREFIJO_FOTOS_RESENIA = 'resenia_fotos/';

// El bucket se CAPTURA, no se descarta: sin eso, una URL a otro bucket con un
// path `resenia_fotos/...` se traduciria en un borrado dentro del NUESTRO.
const RAIZ_DESCARGA =
  /^https:\/\/firebasestorage\.googleapis\.com\/v0\/b\/([^/]+)\/o\/([^?]+)/;

/**
 * Techo de objetos a borrar por resenia. `storage.rules` limita `fotos` a 3,
 * pero solo DESDE FUNC-01: una resenia anterior pudo guardar un array
 * arbitrario, y este bucle es en serie dentro de una funcion con 60 s.
 */
const MAX_FOTOS_POR_BORRADO = 10;

/**
 * Ruta del objeto dentro del bucket, o `null` si la URL no es una descarga de
 * Storage o apunta fuera de `resenia_fotos/`.
 *
 * @param {unknown} url
 * @returns {string|null}
 */
function rutaDeFotoDeResenia(url, nombreDeBucket) {
  if (typeof url !== 'string' || url === '') return null;
  const coincidencia = RAIZ_DESCARGA.exec(url);
  if (!coincidencia) return null;
  if (nombreDeBucket !== undefined && coincidencia[1] !== nombreDeBucket) {
    return null;
  }

  let ruta;
  try {
    ruta = decodeURIComponent(coincidencia[2]);
  } catch (error) {
    // Un `%` suelto revienta `decodeURIComponent`. No hay ruta que borrar.
    return null;
  }

  // `..` no puede escapar del prefijo por como se compone la ruta de Storage
  // (no hay resolucion de segmentos), pero se descarta igual: una ruta con
  // `..` no la genero esta app.
  if (!ruta.startsWith(PREFIJO_FOTOS_RESENIA) || ruta.includes('..')) return null;
  return ruta;
}

/**
 * Borra de Storage las fotos de una resenia ya eliminada.
 *
 * Un objeto que ya no existe es el caso NORMAL, no el excepcional: la edicion
 * de FUNC-01 limpia los huerfanos, asi que una foto quitada antes de borrar la
 * resenia no esta. Por eso un fallo se cuenta y se sigue, en vez de abortar.
 *
 * @param {{file: (ruta: string) => {delete: () => Promise<unknown>}}} bucket
 * @param {{fotos?: unknown}} resenia datos del documento borrado
 * @returns {Promise<{borradas: number, fallidas: number}>}
 */
async function borrarFotosDeResenia(bucket, resenia) {
  const fotos = Array.isArray(resenia && resenia.fotos) ? resenia.fotos : [];
  const rutas = fotos
    .map((url) => rutaDeFotoDeResenia(url, bucket.name))
    .filter((r) => r !== null)
    .slice(0, MAX_FOTOS_POR_BORRADO);
  if (rutas.length === 0) return { borradas: 0, fallidas: 0 };

  let borradas = 0;
  let fallidas = 0;
  // En serie y no con `Promise.all`: son como mucho MAX_FOTOS_POR_BORRADO
  // objetos, asi que no hay gran cosa que paralelizar, y en serie el orden de
  // borrado es el de la lista, que es lo que afirma el test.
  for (const ruta of rutas) {
    try {
      await bucket.file(ruta).delete();
      borradas += 1;
    } catch (error) {
      fallidas += 1;
      console.error(
        `borrarFotosDeResenia: no se pudo borrar ${ruta}:`,
        error
      );
    }
  }
  return { borradas, fallidas };
}

module.exports = {
  MAX_FOTOS_POR_BORRADO,
  PREFIJO_FOTOS_RESENIA,
  borrarFotosDeResenia,
  rutaDeFotoDeResenia,
};
