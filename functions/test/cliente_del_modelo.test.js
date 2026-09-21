'use strict';

/**
 * La compuerta entre Gemini y el doble de emulador.
 *
 * **Es la pieza cuyo fallo seria grave y silencioso.** Si el doble se colara
 * en produccion, el asistente serviria respuestas enlatadas con toda la
 * pinta de ser buenas: nada falla, nadie ve un error, y los numeros que lee
 * la persona salen de una plantilla en vez de sus datos. Por eso la
 * compuerta se prueba en las DOS direcciones y con los valores raros, no solo
 * con el caso feliz.
 *
 * La leccion de fondo es la del incidente del 2026-09-13: alli los dos
 * candados (`_flagEmuladores && !kReleaseMode`) podian abrirse a la vez en un
 * build `--profile`, y el bundle de E2E acabo publicado. Aqui la compuerta es
 * `FUNCTIONS_EMULATOR`, que **la pone el emulador** y no existe en una
 * funcion desplegada: no es una bandera nuestra que alguien pueda encender.
 */

const assert = require('assert');

const {
  VARIABLE_EMULADOR,
  VARIABLE_MODELO_REAL,
  usaModeloFalso,
  crearClienteDelModelo,
} = require('../src/clienteDelModelo');
const {
  MODELO_FALSO,
  FALLOS,
  crearModeloFalso,
  clasificar,
  redactar,
} = require('../src/modeloFalso');
const { MODELO_POR_DEFECTO } = require('../src/modeloGemini');
const { normalizar } = require('../src/asistente');

const EN_EMULADOR = { [VARIABLE_EMULADOR]: 'true' };

describe('clienteDelModelo / la compuerta', () => {
  it('dentro del emulador se usa el doble', () => {
    assert.strictEqual(usaModeloFalso(EN_EMULADOR), true);
    assert.strictEqual(crearClienteDelModelo(EN_EMULADOR).modelo, MODELO_FALSO);
  });

  it('SIN la variable del emulador NUNCA se usa el doble', () => {
    // El caso que importa. Un entorno de produccion no tiene
    // `FUNCTIONS_EMULATOR`, asi que aqui se ejerce literalmente lo que
    // pasaria desplegado.
    const entornos = [
      {},
      { GEMINI_API_KEY: 'x' },
      { [VARIABLE_MODELO_REAL]: '0' },
      { GCLOUD_PROJECT: 'autodoc-6ef5a', K_SERVICE: 'asistenteAutoDoc' },
    ];
    entornos.forEach((env) => {
      assert.strictEqual(usaModeloFalso(env), false, JSON.stringify(env));
    });
  });

  it('un valor que no sea la cadena `true` no abre la compuerta', () => {
    // `'false'` es un valor VERDADERO en JavaScript: con un
    // `if (env.FUNCTIONS_EMULATOR)` la compuerta se abriria con «false»
    // dentro. Por eso la comparacion es con la cadena exacta.
    ['false', 'TRUE', '1', 'yes', '', ' true'].forEach((valor) => {
      assert.strictEqual(
        usaModeloFalso({ [VARIABLE_EMULADOR]: valor }),
        false,
        'la compuerta se abrio con FUNCTIONS_EMULATOR=' + JSON.stringify(valor)
      );
    });
    assert.strictEqual(usaModeloFalso({ [VARIABLE_EMULADOR]: true }), false);
  });

  it('en el emulador se puede pedir Gemini de verdad', () => {
    // La escotilla para quien quiera medir prosa real sin desplegar.
    const env = { [VARIABLE_EMULADOR]: 'true', [VARIABLE_MODELO_REAL]: '1' };
    assert.strictEqual(usaModeloFalso(env), false);
    assert.throws(() => crearClienteDelModelo(env), /GEMINI_API_KEY/);
  });

  it('fuera del emulador y con clave, sale el cliente de Gemini de verdad', () => {
    const cliente = crearClienteDelModelo({ GEMINI_API_KEY: 'clave-de-prueba' });
    assert.strictEqual(cliente.modelo, MODELO_POR_DEFECTO);
    assert.notStrictEqual(cliente.modelo, MODELO_FALSO);
  });

  it('el nombre del doble delata en un log', () => {
    // Si esto apareciera en produccion, se lee de un vistazo que lo servido
    // fue enlatado. Es la ultima red, por si la compuerta fallara.
    assert.ok(/emulador/.test(MODELO_FALSO), 'el nombre del doble no se distingue del real');
  });
});

describe('modeloFalso / respeta el contrato del cliente', () => {
  it('clasifica dentro del enum cerrado, nunca fuera', () => {
    const enum3 = ['agenda', 'explicar', 'fuera_de_alcance'];
    [
      'que alertas tengo en los proximos dias',
      'que es el SOAT',
      'cual es la capital de Francia',
      '',
      'aaaaa',
    ].forEach((p) => {
      assert.ok(enum3.indexOf(clasificar(p)) !== -1, 'etiqueta fuera del enum para: ' + p);
    });
  });

  it('clasifica EN INGLES, que es el idioma en el que corre el E2E', () => {
    // **El bundle de E2E se renderiza en ingles** (Chromium arranca con el
    // locale del sistema), asi que todas las preguntas de la suite llegan en
    // ingles. La primera version del doble solo tenia pistas en espanol:
    // «what expires in the next days» no casaba con nada y caia a
    // `fuera_de_alcance`. Los tres tests de agenda fallaban y el del RECHAZO
    // pasaba — acertando por accidente, que es el verde mas caro de todos.
    assert.strictEqual(clasificar('what expires in the next days'), 'agenda');
    assert.strictEqual(clasificar('what appointments do I have'), 'agenda');
    assert.strictEqual(clasificar('what is the soat'), 'explicar');
  });

  it('el orden agenda-antes-que-explicar decide casos reales', () => {
    // «cuando vence mi SOAT» menciona un documento pero es agenda; «que es el
    // SOAT» no lleva verbo de agenda y es explicar.
    assert.strictEqual(clasificar('cuando vence mi SOAT'), 'agenda');
    assert.strictEqual(clasificar('que es el SOAT y que pasa si se vence'), 'agenda');
    assert.strictEqual(clasificar('que es el SOAT'), 'explicar');
    assert.strictEqual(clasificar('que vence esta semana'), 'agenda');
    assert.strictEqual(clasificar('por que suena raro el motor'), 'fuera_de_alcance');
  });

  it('una pregunta de cultura general NO es `explicar`', () => {
    // Con `'que es'` / `'what is'` como pista, «what is the capital of
    // France» salia `explicar`: una pregunta de fuera del alcance
    // clasificada como buena, o sea un E2E en verde que deberia estar rojo.
    // Por eso las pistas de `explicar` son terminos del dominio.
    assert.strictEqual(clasificar('what is the capital of France'), 'fuera_de_alcance');
    assert.strictEqual(clasificar('cual es la capital de Francia'), 'fuera_de_alcance');
    assert.strictEqual(clasificar('que es la fotosintesis'), 'fuera_de_alcance');
  });

  it('la prosa SALE del envelope: un envelope distinto da texto distinto', () => {
    // Es lo que convierte el E2E en una prueba de que el dato cruzo las cinco
    // capas. Con un texto fijo, la suite pasaria igual con el envelope vacio,
    // o con el de otro usuario.
    const a = redactar({ items: [{ tipo: 'soat', placa: 'ABC123', dias_restantes: -10 }] });
    const b = redactar({ items: [{ tipo: 'soat', placa: 'XYZ789', dias_restantes: 3 }] });
    assert.notStrictEqual(a, b);
    assert.ok(a.indexOf('ABC123') !== -1 && a.indexOf('10') !== -1);
    assert.ok(b.indexOf('XYZ789') !== -1);
  });

  it('el mantenimiento viaja en KILOMETROS, nunca en dias', () => {
    // La regla dura del §1.3 del plan. El doble la respeta para que el E2E
    // pueda afirmarla: si algun dia el envelope empezara a mandar dias, este
    // test no lo ve, pero el de `agenda.test.js` si.
    const texto = redactar({
      items: [{ tipo: 'mantenimiento', nombre: 'Frenos', placa: 'ABC123', km_restantes: 200 }],
    });
    assert.ok(texto.indexOf('200 km') !== -1, texto);
    assert.ok(texto.indexOf('dias') === -1, 'el mantenimiento salio en dias: ' + texto);
  });

  it('un envelope vacio no se rellena con nada', () => {
    // El peor fallo posible de un redactor: pedirle prosa sobre una lista
    // vacia le invita a inventarla. En produccion esta rama ni siquiera llama
    // al modelo; el doble tambien se niega.
    assert.strictEqual(redactar({ items: [] }), 'No hay nada pendiente.');
    assert.strictEqual(redactar({}), 'No hay nada pendiente.');
  });

  it('los marcadores sobreviven a `normalizar`, que es el camino real', async () => {
    // **La primera version de este test estaba VERDE sobre marcadores
    // muertos.** Llamaba a `generar()` a pelo, y en el camino real la
    // pregunta pasa antes por `normalizar()` de `asistente.js`, que borra
    // todo lo que no sea letra, numero o espacio: `#fallo-proveedor` llegaba
    // al doble como `fallo proveedor` y no casaba con nada. O sea que los
    // estados que estos marcadores existen para alcanzar no se podian
    // alcanzar, y el test decia que si.
    //
    // Por eso ahora se escribe la pregunta como la escribiria una persona y
    // se pasa por `normalizar` antes de entregarla.
    const cliente = crearModeloFalso();
    const preguntar = (texto) =>
      cliente.generar({ sistema: 'x', usuario: normalizar(texto) });

    await assert.rejects(
      () => preguntar('Que vence, probar fallo proveedor'),
      (e) => e.code === 'unavailable' && e.detalle === 'proveedor'
    );
    await assert.rejects(
      () => preguntar('Probar fallo lento'),
      (e) => e.code === 'deadline-exceeded'
    );
    await assert.rejects(
      () => preguntar('Probar fallo bloqueado'),
      (e) => e.code === 'aborted'
    );
  });

  it('cada marcador esta escrito de forma que `normalizar` no lo rompe', () => {
    // Afirma la PROPIEDAD, no los tres casos: el dia que alguien anada un
    // cuarto marcador con un guion dentro, esto rompe en vez de dejar otro
    // marcador muerto pasando desapercibido.
    Object.keys(FALLOS).forEach((marcador) => {
      assert.strictEqual(
        normalizar(marcador),
        marcador,
        'el marcador "' + marcador + '" no sobrevive a normalizar(): llega como "' +
          normalizar(marcador) + '"'
      );
    });
  });

  it('una pregunta normal no dispara ningun marcador', async () => {
    const cliente = crearModeloFalso();
    const r = await cliente.generar({
      sistema: 'Clasifica la pregunta del usuario',
      usuario: 'que vence esta semana',
    });
    assert.strictEqual(r, 'agenda');
  });
});
