'use strict';

/**
 * Tests del cliente de Gemini. Ninguno llama a Gemini.
 *
 * Afirman sobre **la peticion que se construye y el manejo de la respuesta**,
 * que es lo unico determinista que hay aqui. La prosa del modelo no se afirma
 * jamas: un test que compare texto generado es un test que se pone rojo solo
 * el dia que Google cambia una version, y entonces nadie sabe si se rompio el
 * codigo o el modelo cambio de humor.
 */

const assert = require('assert');

const {
  PUNTO_FINAL,
  MODELO_POR_DEFECTO,
  CODIGOS,
  claveDelEntorno,
  crearClienteGemini,
  deEstadoHttp,
} = require('../src/modeloGemini');

const CLAVE = 'AIza-clave-de-prueba-que-no-existe';

/** `fetch` de mentira que guarda lo que recibe. */
function fakeFetch(respuestas) {
  const cola = Array.isArray(respuestas) ? respuestas.slice() : [respuestas];
  const llamadas = [];
  const hacer = async (url, opciones) => {
    llamadas.push({ url, opciones });
    const siguiente = cola.length > 1 ? cola.shift() : cola[0];
    if (typeof siguiente === 'function') return siguiente();
    return siguiente;
  };
  hacer.llamadas = llamadas;
  return hacer;
}

const respuestaOk = (texto) => ({
  ok: true,
  status: 200,
  json: async () => ({ candidates: [{ content: { parts: [{ text: texto }] } }] }),
});

const respuestaHttp = (status) => ({
  ok: false,
  status,
  json: async () => ({ error: { message: 'lo que sea' } }),
});

const cliente = (fetch, extra) =>
  crearClienteGemini(Object.assign({ apiKey: CLAVE, fetch }, extra));

describe('modeloGemini / la clave', () => {
  it('viaja en la cabecera y NUNCA en la URL', async () => {
    const fetch = fakeFetch(respuestaOk('hola'));
    await cliente(fetch).generar({ sistema: 's', usuario: 'u' });

    const { url, opciones } = fetch.llamadas[0];
    assert.strictEqual(
      url.indexOf(CLAVE),
      -1,
      'FUGA: la clave va en la URL, y las URLs acaban en los logs: ' + url
    );
    assert.strictEqual(opciones.headers['x-goog-api-key'], CLAVE);
    assert.ok(url.startsWith(PUNTO_FINAL), 'la URL no apunta al endpoint esperado');
    assert.ok(url.indexOf(MODELO_POR_DEFECTO) !== -1);
  });

  it('un error de HTTP no repite la clave en su mensaje', async () => {
    const fetch = fakeFetch(respuestaHttp(403));
    await assert.rejects(
      () => cliente(fetch).generar({ sistema: 's', usuario: 'u' }),
      (e) => {
        assert.strictEqual(e.code, CODIGOS.configuracion);
        assert.strictEqual(e.message.indexOf(CLAVE), -1, 'FUGA: la clave sale en el error');
        return true;
      }
    );
  });

  it('del cuerpo de un 400 solo sale `error.status`, nunca `error.message`', async () => {
    // El `message` de un 400 de Gemini puede traer de vuelta parte de la
    // peticion, y la peticion lleva la pregunta del usuario. El `status` es un
    // enum cerrado de la API y por eso si puede viajar al log. Sin este
    // centinela, manana alguien «mejora» el diagnostico anadiendo el mensaje
    // del proveedor y ninguna suite se entera.
    const PRIVADO = 'cuando vence el SOAT de mi placa P123-456';
    const fetch = fakeFetch({
      ok: false,
      status: 400,
      json: async () => ({
        error: {
          status: 'INVALID_ARGUMENT',
          message: 'Invalid value at generationConfig: ' + PRIVADO,
        },
      }),
    });
    await assert.rejects(
      () => cliente(fetch).generar({ sistema: 's', usuario: PRIVADO }),
      (e) => {
        assert.strictEqual(e.code, CODIGOS.configuracion);
        assert.ok(
          e.message.indexOf('INVALID_ARGUMENT') !== -1,
          'el diagnostico no dice QUE rechazo el proveedor: ' + e.message
        );
        assert.strictEqual(
          e.message.indexOf(PRIVADO),
          -1,
          'FUGA: la pregunta del usuario sale en el error del proveedor'
        );
        return true;
      }
    );
  });

  it('un `status` que no es del enum se descarta en vez de propagarse', async () => {
    const SOSPECHOSO = 'correo del usuario: alguien@ejemplo.com';
    const fetch = fakeFetch({
      ok: false,
      status: 400,
      json: async () => ({ error: { status: SOSPECHOSO } }),
    });
    await assert.rejects(
      () => cliente(fetch).generar({ sistema: 's', usuario: 'u' }),
      (e) => {
        assert.strictEqual(e.message.indexOf(SOSPECHOSO), -1, 'FUGA: paso el filtro');
        assert.strictEqual(e.message.indexOf('alguien@'), -1);
        return true;
      }
    );
  });

  it('un 500 no se pone a bufferizar el cuerpo: no hay nada que rescatar', async () => {
    // Solo 400/401/403 consumen `estadoProveedor`. Para el resto, leer el
    // cuerpo es bufferizar sin cota —la pagina HTML de un proxy, por
    // ejemplo— a cambio de ningun diagnostico.
    let leido = false;
    const fetch = fakeFetch({
      ok: false,
      status: 500,
      json: async () => {
        leido = true;
        return { error: { status: 'INTERNAL' } };
      },
    });
    await assert.rejects(() => cliente(fetch).generar({ sistema: 's', usuario: 'u' }));
    assert.strictEqual(leido, false, 'se leyo el cuerpo de un 500 sin necesidad');
  });

  it('claveDelEntorno falla con instrucciones, no con `undefined`', () => {
    assert.throws(() => claveDelEntorno({}), /GEMINI_API_KEY/);
    assert.strictEqual(claveDelEntorno({ GEMINI_API_KEY: 'x' }), 'x');
  });

  it('crear un cliente sin clave falla al arrancar, no al primer usuario', () => {
    assert.throws(() => crearClienteGemini({ fetch: fakeFetch(respuestaOk('x')) }), /apiKey/);
  });
});

describe('modeloGemini / la peticion', () => {
  it('manda el sistema y el usuario por separado', async () => {
    const fetch = fakeFetch(respuestaOk('hola'));
    await cliente(fetch).generar({ sistema: 'INSTRUCCIONES', usuario: 'PREGUNTA' });

    const cuerpo = JSON.parse(fetch.llamadas[0].opciones.body);
    assert.strictEqual(cuerpo.system_instruction.parts[0].text, 'INSTRUCCIONES');
    assert.strictEqual(cuerpo.contents[0].parts[0].text, 'PREGUNTA');
    assert.strictEqual(cuerpo.contents[0].role, 'user');
  });

  it('la temperatura por defecto es baja: esto reformula, no inventa', async () => {
    const fetch = fakeFetch(respuestaOk('hola'));
    await cliente(fetch).generar({ sistema: 's', usuario: 'u' });
    const cuerpo = JSON.parse(fetch.llamadas[0].opciones.body);
    assert.ok(cuerpo.generationConfig.temperature <= 0.3);
    assert.ok(cuerpo.generationConfig.maxOutputTokens > 0);
  });
});

describe('modeloGemini / los fallos', () => {
  it('un 429 es `resource-exhausted`, no un error generico', async () => {
    // Importa: el generico manda al usuario a «revisa tu conexion», que es
    // justo el mapeo equivocado que UX-04 dejo y que INNO-01 tuvo que
    // corregir para el pase de historial.
    const fetch = fakeFetch(respuestaHttp(429));
    await assert.rejects(
      () => cliente(fetch).generar({ sistema: 's', usuario: 'u' }),
      (e) => e.code === CODIGOS.cuotaDelProveedor
    );
  });

  it('un 404 es CONFIGURACION, no «el proveedor esta caido»', async () => {
    // El primer spike murio con 404 en las cinco llamadas y el mensaje decia
    // «El modelo respondio 404», mapeado a `unavailable`. Eso manda a mirar el
    // estado del proveedor cuando lo que pasa es que el nombre del modelo no
    // existe para esa clave o esa version del endpoint — el mismo defecto de
    // mapeo que UX-04 documento y que INNO-01 tuvo que corregir aparte.
    const fetch = fakeFetch(respuestaHttp(404));
    await assert.rejects(
      () => cliente(fetch).generar({ sistema: 's', usuario: 'u' }),
      (e) => {
        assert.strictEqual(e.code, CODIGOS.configuracion);
        assert.ok(
          e.message.indexOf('--listar') !== -1,
          'el mensaje no dice como averiguar el nombre correcto'
        );
        return true;
      }
    );
  });

  it('un 402 es «hace falta facturacion», no «se agoto la cuota»', async () => {
    // Los tres se parecen y no significan lo mismo: 429 es «vuelve mañana»,
    // 402 es «este modelo no esta en el free tier y no hay nada que esperar»,
    // 404 es «ese nombre no sirve». El spike los produjo los tres con la
    // misma clave y modelos distintos, lo que es la prueba de que estar en el
    // catalogo no significa poder usarlo.
    const fetch = fakeFetch(respuestaHttp(402));
    await assert.rejects(
      () => cliente(fetch).generar({ sistema: 's', usuario: 'u' }),
      (e) => {
        assert.strictEqual(e.code, CODIGOS.configuracion);
        assert.notStrictEqual(
          e.code,
          CODIGOS.cuotaDelProveedor,
          'un 402 no debe leerse como cuota agotada: esperar no lo arregla'
        );
        return true;
      }
    );
  });

  it('un 500 del proveedor es `unavailable` y va MARCADO como del proveedor', async () => {
    // El motivo no es decoracion: `unavailable` tambien lo lanza el kill
    // switch del asistente, y las dos situaciones no se parecen en nada —
    // de un 500 se sale reintentando y del interruptor apagado no. Sin esta
    // marca la pantalla tiene que elegir un texto que miente en la mitad de
    // los casos.
    const fetch = fakeFetch(respuestaHttp(500));
    await assert.rejects(
      () => cliente(fetch).generar({ sistema: 's', usuario: 'u' }),
      (e) => e.code === CODIGOS.proveedor && e.detalle === 'proveedor'
    );
  });

  it('el estado HTTP NO viaja en el motivo, solo en el mensaje', () => {
    // El motivo llega al cliente en `details`; el mensaje no. Meter el 500
    // ahi seria empezar a publicar lo que responde un tercero.
    const e = deEstadoHttp(503);
    assert.strictEqual(e.detalle, 'proveedor');
    assert.ok(e.message.indexOf('503') !== -1);
  });

  it('un abort por timeout es `deadline-exceeded`, no `unavailable`', async () => {
    const fetch = fakeFetch(() => {
      const e = new Error('abortado');
      e.name = 'AbortError';
      return Promise.reject(e);
    });
    await assert.rejects(
      () => cliente(fetch, { timeoutMs: 5 }).generar({ sistema: 's', usuario: 'u' }),
      (e) => e.code === CODIGOS.timeout
    );
  });

  it('una respuesta sin candidatos es `aborted` y dice por que', async () => {
    // El filtro de seguridad de Google devuelve 200 con cero candidatos. Si
    // esto se tratara como fallo de red, el cliente reintentaria para siempre
    // algo que no va a funcionar nunca.
    const fetch = fakeFetch({
      ok: true,
      status: 200,
      json: async () => ({ candidates: [], promptFeedback: { blockReason: 'SAFETY' } }),
    });
    await assert.rejects(
      () => cliente(fetch).generar({ sistema: 's', usuario: 'u' }),
      (e) => e.code === CODIGOS.bloqueado && e.detalle === 'SAFETY'
    );
  });

  it('MAX_TOKENS es CONFIGURACION, no un bloqueo del filtro', async () => {
    // **La distincion tiene una consecuencia silenciosa.** `aborted` no sube
    // desde `clasificar` —a proposito: ahi significa que el filtro del
    // proveedor se nego—, asi que un modelo que razona y agota el
    // presupuesto sin escribir nada haria caer TODA pregunta a
    // `fuera_de_alcance`: sin error, sin boton de reintentar, y con los logs
    // diciendo que se atendio. El spike lo produjo de verdad con
    // `gemini-3.5-flash`, y ahora `GEMINI_MODELO` se lee en la funcion
    // desplegada, o sea que basta un `.env` para provocarlo.
    const fetch = fakeFetch({
      ok: true,
      status: 200,
      json: async () => ({ candidates: [{ content: { parts: [] }, finishReason: 'MAX_TOKENS' }] }),
    });
    await assert.rejects(
      () => cliente(fetch).generar({ sistema: 's', usuario: 'u' }),
      (e) => {
        assert.strictEqual(e.code, CODIGOS.configuracion);
        assert.notStrictEqual(
          e.code,
          CODIGOS.bloqueado,
          'un presupuesto agotado se sirve como un rechazo y nadie se entera'
        );
        assert.ok(/maxOutputTokens|GEMINI_MODELO/.test(e.message), e.message);
        return true;
      }
    );
  });

  it('un bloqueo de verdad del filtro SIGUE siendo `aborted`', async () => {
    // La otra mitad: sin esto, el arreglo de arriba podria haber mandado los
    // dos casos a `failed-precondition` y el test seguiria verde.
    const fetch = fakeFetch({
      ok: true,
      status: 200,
      json: async () => ({ candidates: [{ content: { parts: [] }, finishReason: 'SAFETY' }] }),
    });
    await assert.rejects(
      () => cliente(fetch).generar({ sistema: 's', usuario: 'u' }),
      (e) => e.code === CODIGOS.bloqueado && e.detalle === 'SAFETY'
    );
  });

  it('un cuerpo que no es JSON no revienta con un TypeError crudo', async () => {
    const fetch = fakeFetch({
      ok: true,
      status: 200,
      json: async () => {
        throw new Error('Unexpected token < in JSON');
      },
    });
    await assert.rejects(
      () => cliente(fetch).generar({ sistema: 's', usuario: 'u' }),
      (e) => e.code === CODIGOS.proveedor && e.detalle === 'proveedor'
    );
  });
});

describe('modeloGemini / la respuesta', () => {
  it('une las partes y recorta', async () => {
    const fetch = fakeFetch({
      ok: true,
      status: 200,
      json: async () => ({
        candidates: [{ content: { parts: [{ text: '  Tu SOAT ' }, { text: 'vence.  ' }] } }],
      }),
    });
    const texto = await cliente(fetch).generar({ sistema: 's', usuario: 'u' });
    assert.strictEqual(texto, 'Tu SOAT vence.');
  });
});

describe('modeloGemini / que modelo se usa', () => {
  it('el defecto esta FIJADO, no es un alias movil', () => {
    // Un `*-latest` cambia bajo los pies sin que nadie despliegue: con el
    // cambian latencia, precio y la prosa a la vez. Es la leccion del
    // incidente del 2026-09-13 — el fuente estaba bien y lo que cambio fue el
    // artefacto — aplicada a un proveedor externo.
    assert.ok(
      !/-latest$/.test(MODELO_POR_DEFECTO),
      'el modelo por defecto es un alias movil: ' + MODELO_POR_DEFECTO
    );
  });

  it('no es el `gemini-2.5-flash` que el spike probo que da 404', () => {
    // Valia la pena escribirlo: con ese nombre la feature no funcionaba en
    // ninguna de las dos versiones del endpoint, y el fallo se leia como «el
    // proveedor esta caido».
    assert.notStrictEqual(MODELO_POR_DEFECTO, 'gemini-2.5-flash');
  });

  it('GEMINI_MODELO pisa el defecto, que es lo que dice el error del 404', () => {
    // La incoherencia que cierra este test: el mensaje del 404 manda a fijar
    // esa variable, y hasta ahora solo la leia el spike. El consejo era falso
    // justo cuando mas falta hacia.
    const fetch = fakeFetch(respuestaOk('hola'));
    const c = crearClienteGemini({
      apiKey: CLAVE,
      fetch,
      env: { GEMINI_MODELO: 'gemini-de-prueba' },
    });
    assert.strictEqual(c.modelo, 'gemini-de-prueba');
  });

  it('un `modelo` explicito gana a la variable de entorno', () => {
    // El spike pasa el modelo a mano; si el entorno lo pisara, `--probar` no
    // podria recorrer candidatos.
    const c = crearClienteGemini({
      apiKey: CLAVE,
      fetch: fakeFetch(respuestaOk('hola')),
      modelo: 'explicito',
      env: { GEMINI_MODELO: 'del-entorno' },
    });
    assert.strictEqual(c.modelo, 'explicito');
  });

  it('sin variable ni parametro cae al defecto', () => {
    const c = crearClienteGemini({
      apiKey: CLAVE,
      fetch: fakeFetch(respuestaOk('hola')),
      env: {},
    });
    assert.strictEqual(c.modelo, MODELO_POR_DEFECTO);
  });
});
