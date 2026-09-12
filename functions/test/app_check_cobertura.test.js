'use strict';

/**
 * SEC-04 — centinela de cobertura de App Check.
 *
 * El enforcement de App Check en Functions v1 no es declarativo: es una linea
 * de codigo dentro de cada `onCall`. Eso significa que **un callable nuevo
 * nace sin proteccion por defecto** y nadie se entera — que es exactamente
 * como se llego al estado que arregla SEC-04, con el cliente firmando desde
 * hacia meses y doce callables aceptando cualquier llamada.
 *
 * Este test recorre el entrypoint, corta un bloque por `exports.` y exige que
 * todo bloque que declare un `onCall` contenga tambien su `exigirAppCheck`.
 *
 * **Se cortan bloques y no se cuentan ocurrencias a proposito.** Contar
 * `onCall` y contar `exigirAppCheck` y compararlos daria el mismo numero
 * aunque un callable llevara dos comprobaciones y otro ninguna. Es el mismo
 * error que ya cometio la primera version del centinela de FUNC-02, que miraba
 * solo el cuerpo de cada `exports.` y pasaba por casualidad.
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const ENTRYPOINT = path.join(__dirname, '..', 'index.js');

/**
 * Callables que a proposito NO exigen App Check, cada uno con su razon.
 * Vacio a proposito: lo que entre aqui, entra con su justificacion escrita.
 */
const EXENTOS = {};

/** Corta el archivo en un bloque por cada `exports.<algo> =`. */
function bloquesPorExport(fuente) {
  const lineas = fuente.split('\n');
  const bloques = [];
  let actual = null;
  for (const linea of lineas) {
    const m = /^exports\.(\w+)\s*=/.exec(linea);
    if (m) {
      if (actual) bloques.push(actual);
      actual = { nombre: m[1], lineas: [] };
    }
    if (actual) actual.lineas.push(linea);
  }
  if (actual) bloques.push(actual);
  return bloques.map((b) => ({ nombre: b.nombre, cuerpo: b.lineas.join('\n') }));
}

describe('SEC-04 / cobertura de App Check en el entrypoint', () => {
  const fuente = fs.readFileSync(ENTRYPOINT, 'utf8');
  const bloques = bloquesPorExport(fuente);
  const callables = bloques.filter((b) => b.cuerpo.includes('functions.https.onCall('));

  it('el corte por export encuentra los callables que hay', () => {
    // Si este test falla, los otros dos de este archivo no significan nada:
    // estarian recorriendo una lista vacia y pasando por eso.
    const enElArchivo = (fuente.match(/functions\.https\.onCall\(/g) || []).length;
    assert.ok(callables.length > 0, 'no se encontro ni un callable');
    assert.strictEqual(
      callables.length,
      enElArchivo,
      'hay onCall que el corte por `exports.` no esta viendo'
    );
  });

  it('todo callable exige App Check', () => {
    const sinProteger = callables
      .filter((c) => !Object.prototype.hasOwnProperty.call(EXENTOS, c.nombre))
      .filter((c) => !c.cuerpo.includes('exigirAppCheck(context,'))
      .map((c) => c.nombre);

    assert.deepStrictEqual(
      sinProteger,
      [],
      'Estos callables no comprueban App Check. En Functions v1 el enforcement ' +
        'no existe como ajuste de consola: si la linea no esta en el codigo, la ' +
        'funcion acepta cualquier llamada aunque App Check este activado en la ' +
        'consola de Firebase. Anade `exigirAppCheck(context, "<nombre>")` como ' +
        'primera linea, o apunta el callable en EXENTOS con su razon.'
    );
  });

  it('cada callable lo exige con su propio nombre, y una sola vez', () => {
    // Un copiar-pegar que deje el nombre del callable anterior no rompe la
    // seguridad, pero envenena el log justo cuando hay que usarlo: en la fase
    // de monitorizacion, el registro dice que callable esta perdiendo tokens.
    const mal = [];
    for (const c of callables) {
      if (Object.prototype.hasOwnProperty.call(EXENTOS, c.nombre)) continue;
      const encontrados = c.cuerpo.match(/exigirAppCheck\(context, '([^']+)'\)/g) || [];
      if (encontrados.length !== 1) {
        mal.push(`${c.nombre}: ${encontrados.length} comprobaciones`);
      } else if (!encontrados[0].includes(`'${c.nombre}'`)) {
        mal.push(`${c.nombre}: registra ${encontrados[0]}`);
      }
    }
    assert.deepStrictEqual(mal, []);
  });
});
