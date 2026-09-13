'use strict';

/**
 * Residual de FUNC-01: **nadie borra las fotos al ELIMINAR una resenia**.
 *
 * FUNC-01 cerro la edicion —conservar, anadir, quitar y reemplazar fotos, con
 * el borrado del huerfano tras la escritura— y dejo anotado que el borrado de
 * la resenia entera no limpia nada. Se remitio a OPS-01; OPS-01 cerro sin
 * recogerlo.
 *
 * Son DOS caminos, no uno, y el segundo no estaba anotado:
 *
 *   1. El autor borra su resenia.
 *   2. Se borra la CUENTA: `functions/index.js:1066` barre las resenias del
 *      usuario en lotes de 500. Ese camino no pasa por la app siquiera.
 *
 * En los dos las fotos se quedan en Storage para siempre. No es solo coste:
 * son fotos del coche de alguien que pidio que se borraran, y el objeto sigue
 * siendo descargable por URL.
 *
 * Se borra por URL EXACTA y no por prefijo `resenia_fotos/{idServicio}/`,
 * aunque esa sea la ruta que fija `storage.rules`. El id del documento se
 * deriva de usuario + servicio (`_reviewDocId`), asi que dos resenias pueden
 * compartir prefijo; borrar por prefijo se llevaria por delante las fotos de
 * la otra.
 */

const assert = require('assert');

const {
  MAX_FOTOS_POR_BORRADO,
  rutaDeFotoDeResenia,
  borrarFotosDeResenia,
} = require('../src/fotosDeResenia');

const BUCKET = 'autodoc.appspot.com';
const URL_BASE = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/`;
const urlDe = (ruta) => `${URL_BASE}${encodeURIComponent(ruta)}?alt=media&token=abc`;

/** Doble del bucket con solo lo que se usa: `file(ruta).delete()`. */
function fakeBucket({ fallan = [] } = {}) {
  const borrados = [];
  return {
    borrados,
    name: BUCKET,
    file(ruta) {
      return {
        async delete() {
          if (fallan.includes(ruta)) {
            const error = new Error(`No such object: ${ruta}`);
            error.code = 404;
            throw error;
          }
          borrados.push(ruta);
        },
      };
    },
  };
}

describe('fotosDeResenia / rutaDeFotoDeResenia', () => {
  it('saca la ruta del objeto de una URL de descarga', () => {
    assert.strictEqual(
      rutaDeFotoDeResenia(urlDe('resenia_fotos/s1/foto.jpg')),
      'resenia_fotos/s1/foto.jpg'
    );
  });

  // El cliente escribe `fotos` y las reglas lo acotan, pero esta funcion corre
  // con Admin SDK y las reglas no la alcanzan. Una URL que apunte fuera de
  // `resenia_fotos/` no puede convertirse en un borrado: seria un borrado
  // arbitrario de Storage disparado escribiendo una cadena en un documento.
  it('rechaza una URL que apunta fuera de resenia_fotos/', () => {
    assert.strictEqual(rutaDeFotoDeResenia(urlDe('perfiles/uid-1/avatar.jpg')), null);
  });

  // Sin comparar el bucket, una URL a OTRO proyecto con un path
  // `resenia_fotos/...` se traduciria en un borrado dentro del nuestro. Lo
  // encontro el gate de revision de Functions.
  it('rechaza una URL de otro bucket', () => {
    const ajena =
      'https://firebasestorage.googleapis.com/v0/b/otro-proyecto.appspot.com/o/' +
      encodeURIComponent('resenia_fotos/s1/foto.jpg');
    assert.strictEqual(rutaDeFotoDeResenia(ajena, BUCKET), null);
  });

  it('rechaza lo que no es una URL de Storage', () => {
    assert.strictEqual(rutaDeFotoDeResenia('https://evil.example/foto.jpg'), null);
    assert.strictEqual(rutaDeFotoDeResenia(''), null);
    assert.strictEqual(rutaDeFotoDeResenia(null), null);
  });
});

describe('fotosDeResenia / borrarFotosDeResenia', () => {
  it('borra las fotos de la resenia eliminada', async () => {
    const bucket = fakeBucket();

    const { borradas } = await borrarFotosDeResenia(bucket, {
      fotos: [urlDe('resenia_fotos/s1/a.jpg'), urlDe('resenia_fotos/s1/b.jpg')],
    });

    assert.strictEqual(borradas, 2);
    assert.deepStrictEqual(bucket.borrados, [
      'resenia_fotos/s1/a.jpg',
      'resenia_fotos/s1/b.jpg',
    ]);
  });

  it('una resenia sin fotos no toca Storage', async () => {
    const bucket = fakeBucket();

    const { borradas } = await borrarFotosDeResenia(bucket, { fotos: [] });

    assert.strictEqual(borradas, 0);
    assert.deepStrictEqual(bucket.borrados, []);
  });

  // Un documento legado puede no tener el campo siquiera.
  it('una resenia sin el campo fotos no rompe', async () => {
    const bucket = fakeBucket();
    const { borradas } = await borrarFotosDeResenia(bucket, {});
    assert.strictEqual(borradas, 0);
  });

  // El objeto ya borrado es el caso NORMAL, no el excepcional: la edicion de
  // FUNC-01 ya limpia los huerfanos, asi que una foto quitada antes de borrar
  // la resenia no esta. No puede impedir que se borren las demas.
  it('un objeto que ya no existe no impide borrar el resto', async () => {
    const bucket = fakeBucket({ fallan: ['resenia_fotos/s1/a.jpg'] });

    const { borradas, fallidas } = await borrarFotosDeResenia(bucket, {
      fotos: [urlDe('resenia_fotos/s1/a.jpg'), urlDe('resenia_fotos/s1/b.jpg')],
    });

    assert.strictEqual(borradas, 1);
    assert.strictEqual(fallidas, 1);
    assert.deepStrictEqual(bucket.borrados, ['resenia_fotos/s1/b.jpg']);
  });

  // `storage.rules` limita `fotos` a 3, pero solo DESDE FUNC-01: una resenia
  // anterior pudo guardar un array arbitrario, y el bucle es en serie dentro de
  // una funcion con 60 s por defecto. Tambien del gate de revision.
  it('no intenta borrar mas de MAX_FOTOS_POR_BORRADO objetos', async () => {
    const bucket = fakeBucket();
    const muchas = Array.from({ length: MAX_FOTOS_POR_BORRADO + 7 }, (_, i) =>
      urlDe(`resenia_fotos/s1/f${i}.jpg`)
    );

    const { borradas } = await borrarFotosDeResenia(bucket, { fotos: muchas });

    assert.strictEqual(borradas, MAX_FOTOS_POR_BORRADO);
  });

  it('ignora las URLs que no apuntan a resenia_fotos/', async () => {
    const bucket = fakeBucket();

    const { borradas } = await borrarFotosDeResenia(bucket, {
      fotos: [urlDe('perfiles/uid-1/avatar.jpg'), urlDe('resenia_fotos/s1/a.jpg')],
    });

    assert.strictEqual(borradas, 1);
    assert.deepStrictEqual(bucket.borrados, ['resenia_fotos/s1/a.jpg']);
  });
});
