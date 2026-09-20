'use strict';

/**
 * Centinela: el callable `asistenteAutoDoc` no reenvia al cliente el mensaje
 * de sus modulos.
 *
 * **Por que hace falta leer el fichero y no basta con probar
 * `mensajePublico`.** El defecto vivia en UNA linea de `functions/index.js`
 * —`new functions.https.HttpsError(codigo, e.message, motivo)`— y ningun test
 * de comportamiento lo veia: el filtro de mensajes puede estar perfecto y
 * bien probado mientras el entrypoint no lo usa. Es la misma clase de defecto
 * que `app_check_cobertura.test.js` vigila, y la misma leccion del incidente
 * de despliegue del 2026-09-13: las suites miraban el codigo fuente y el
 * codigo fuente estaba bien, porque el fallo estaba en como se ensamblaba.
 *
 * Lo que se filtraba no era inocuo. Los mensajes de `modeloGemini.js` estan
 * escritos para quien despliega y nombran `GEMINI_API_KEY`, `GEMINI_MODELO` y
 * `functions/spike_gemini.js`, porque su destino era el log. El `message` de
 * un `HttpsError` viaja al cliente igual de literal que `details`.
 *
 * Y el alcance era NUEVO: hasta que `clasificar` dejo subir
 * `failed-precondition`, un modelo mal configurado moria en la primera
 * llamada y se degradaba a `fuera_de_alcance`, asi que ese texto no salia
 * nunca. Cerrar un gap abrio otro; este centinela es para que no vuelva.
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const ENTRYPOINT = path.join(__dirname, '..', 'index.js');

/** El cuerpo de `exports.asistenteAutoDoc`, hasta el siguiente `exports.`. */
function bloqueDelAsistente(fuente) {
  const lineas = fuente.replace(/\r\n/g, '\n').split('\n');
  const inicio = lineas.findIndex((l) => /^exports\.asistenteAutoDoc\s*=/.test(l));
  assert.notStrictEqual(inicio, -1, 'no existe exports.asistenteAutoDoc en el entrypoint');
  let fin = lineas.length;
  for (let i = inicio + 1; i < lineas.length; i += 1) {
    if (/^exports\.\w+\s*=/.test(lineas[i])) {
      fin = i;
      break;
    }
  }
  return lineas.slice(inicio, fin).join('\n');
}

describe('IA-01 / el asistente no filtra mensajes del servidor', () => {
  const fuente = fs.readFileSync(ENTRYPOINT, 'utf8');
  const bloque = bloqueDelAsistente(fuente);

  it('el centinela esta leyendo el bloque correcto', () => {
    // Sin esto, los dos tests de abajo pasarian igual de bien sobre una
    // cadena vacia — que es como un centinela se convierte en decoracion.
    // `.https.onCall(` y no `functions.https.onCall(`: este callable encadena
    // `.runWith({...})` primero, asi que el literal completo no existe en el
    // fichero. El auto-chequeo se atrapo a si mismo la primera vez que se
    // ejecuto, que es exactamente para lo que esta.
    assert.ok(
      bloque.indexOf('.https.onCall(') !== -1,
      'el bloque recortado no contiene el callable'
    );
    assert.ok(
      bloque.indexOf('exigirAppCheck') !== -1,
      'el bloque recortado no parece el del asistente'
    );
    assert.ok(bloque.split('\n').length > 20, 'el bloque recortado es sospechosamente corto');
  });

  it('ningun HttpsError del asistente lleva `e.message` como mensaje', () => {
    // Se buscan las dos formas de escribirlo, con y sin guarda.
    const culpables = [
      /HttpsError\(\s*[^,)]+,\s*e\.message/,
      /HttpsError\(\s*[^,)]+,\s*e\s*&&\s*e\.message/,
      /HttpsError\(\s*[^,)]+,\s*error\.message/,
    ].filter((patron) => patron.test(bloque));

    assert.deepStrictEqual(
      culpables.map(String),
      [],
      'el callable reenvia al cliente el mensaje de sus modulos. Los de ' +
        'modeloGemini.js nombran GEMINI_API_KEY, GEMINI_MODELO y ' +
        'functions/spike_gemini.js: estan escritos para el log, no para una ' +
        'pantalla. Usa asistenteIA.mensajePublico(codigo).'
    );
  });

  it('el mensaje que se publica sale de la lista blanca', () => {
    assert.ok(
      /mensajePublico\(/.test(bloque),
      'el callable no usa mensajePublico: si compone el texto por su cuenta, ' +
        'la lista blanca no vigila nada'
    );
  });

  it('el mensaje real se sigue registrando en el servidor', () => {
    // Un error que no se muestra pero tampoco se registra es peor que el
    // defecto original: deja de haber pista alguna (UX-04).
    assert.ok(
      /console\.error\([^)]*e\s*&&\s*e\.message/.test(bloque) ||
        /console\.error\([^)]*e\.message/.test(bloque),
      'se dejo de ensenar el mensaje y tampoco se registra'
    );
  });
});
