'use strict';

/**
 * Centinela: el doble de emulador tiene **una sola** puerta de entrada.
 *
 * `crearModeloFalso()` es un export publico sin ninguna condicion de entorno
 * dentro, y su modulo se carga siempre — viaja en el bundle desplegado. Hoy
 * la compuerta de `clienteDelModelo.js` es la unica via, y eso es lo que hace
 * que la propiedad «en produccion nunca se sirven respuestas enlatadas» sea
 * cierta. Pero es una propiedad de QUIEN LLAMA, no del modulo, asi que nada
 * la sostiene salvo la costumbre: el dia que alguien anada un callable de
 * pruebas, un script de siembra que «ensaye la prosa» o un segundo
 * asistente, la compuerta se esquiva y **no falla nada** — simplemente se
 * empiezan a servir respuestas de plantilla con pinta de buenas.
 *
 * Se cuenta **por archivo** y no por ocurrencias totales, que es la leccion
 * del centinela de FUNC-02: contar `require` y contar llamadas daria el mismo
 * numero aunque un archivo llevara dos y otro ninguno.
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const RAIZ = path.join(__dirname, '..');

/** El unico fichero de produccion autorizado a tocar el doble. */
const PUERTA = path.join('src', 'clienteDelModelo.js');

/** Ficheros `.js` de `functions/`, sin `node_modules` ni los propios tests. */
function ficherosDeProduccion(dir, acumulado) {
  const salida = acumulado || [];
  for (const entrada of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entrada.name === 'node_modules' || entrada.name === 'test') continue;
    if (entrada.name.startsWith('.')) continue;
    const completo = path.join(dir, entrada.name);
    if (entrada.isDirectory()) {
      ficherosDeProduccion(completo, salida);
    } else if (entrada.name.endsWith('.js')) {
      salida.push(completo);
    }
  }
  return salida;
}

describe('IA-01 / el doble de emulador esta aislado', () => {
  const ficheros = ficherosDeProduccion(RAIZ);

  it('el centinela esta mirando el arbol correcto', () => {
    // Sin esto, el test de abajo pasaria igual de bien sobre una lista vacia
    // — que es como un centinela se convierte en decoracion.
    assert.ok(ficheros.length > 10, 'solo se ven ' + ficheros.length + ' ficheros de produccion');
    assert.ok(
      ficheros.some((f) => f.endsWith(path.join('functions', 'index.js'))),
      'el entrypoint no esta en la lista'
    );
    assert.ok(
      ficheros.some((f) => f.endsWith(PUERTA)),
      'la puerta autorizada no esta en la lista'
    );
  });

  it('solo `clienteDelModelo.js` requiere el doble', () => {
    const culpables = ficheros.filter((f) => {
      if (f.endsWith(PUERTA)) return false;
      return /require\(['"][^'"]*modeloFalso['"]\)/.test(fs.readFileSync(f, 'utf8'));
    });

    assert.deepStrictEqual(
      culpables.map((f) => path.relative(RAIZ, f)),
      [],
      'estos ficheros construyen el doble sin pasar por la compuerta de ' +
        'clienteDelModelo.js. Si se colara en produccion, el asistente ' +
        'serviria respuestas enlatadas sin que fallara nada.'
    );
  });

  it('la puerta autorizada sigue comprobando el entorno', () => {
    // Que sea la unica via no sirve de nada si la via deja de mirar.
    const fuente = fs.readFileSync(path.join(RAIZ, PUERTA), 'utf8');
    assert.ok(/usaModeloFalso/.test(fuente), 'la puerta ya no consulta la compuerta');
    assert.ok(
      /FUNCTIONS_EMULATOR/.test(fuente),
      'la puerta ya no menciona la variable que pone el emulador'
    );
  });
});
