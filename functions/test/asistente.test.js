'use strict';

/**
 * Tests-gate del callable `asistenteAutoDoc` (§5.6 del plan).
 *
 * **Ninguno afirma sobre la prosa del modelo.** Afirman sobre la peticion que
 * se construye, sobre el manejo de la respuesta y sobre QUE SE CORTA ANTES DE
 * LLAMAR. Es la unica parte determinista, y ademas es donde viven los riesgos:
 * la prosa fea cuesta una queja, un envelope con los datos de otro cuesta una
 * brecha.
 *
 * El cliente del modelo va inyectado, que es el patron de VER-01
 * (`FilePickerPlatform.instance`) y de FUNC-02 — donde inyectar Firestore puso
 * 13 tests en rojo de golpe, porque llevaban ejerciendo el camino de fallo sin
 * que nadie lo supiera.
 */

const assert = require('assert');

const {
  INTENCIONES,
  MAX_TOKENS_ETIQUETA,
  CODIGOS_QUE_SUBEN,
  CODIGOS_SIN_CARGO_GLOBAL,
  DEVOLUCIONES_POR_VENTANA,
  VENTANA_MS,
  FUERA_DE_ALCANCE,
  COLECCION_CUOTA,
  COLECCION_CACHE,
  DOC_CUOTA_GLOBAL,
  LIMITE_POR_USUARIO,
  LIMITE_GLOBAL,
  MOTIVOS,
  motivoPublico,
  MENSAJES_PUBLICOS,
  mensajePublico,
  TEXTO_FUERA_DE_ALCANCE,
  normalizar,
  idiomaValido,
  crearAsistente,
} = require('../src/asistente');

const AHORA = new Date('2026-09-19T15:00:00Z');

/** Firestore de mentira con transacciones de verdad (secuenciales). */
function fakeDb(docs = {}) {
  const escrituras = [];
  const lecturas = [];
  const opcionesDeTransaccion = [];
  const ref = (coleccion, id) => ({
    clave: coleccion + '/' + id,
    id,
    async get() {
      return leer(coleccion + '/' + id);
    },
    async set(datos) {
      escribir(coleccion + '/' + id, datos);
    },
  });
  const leer = (clave) => {
    lecturas.push(clave);
    const existe = Object.prototype.hasOwnProperty.call(docs, clave);
    return {
      exists: existe,
      data: () => (existe ? Object.assign({}, docs[clave]) : undefined),
    };
  };
  const escribir = (clave, datos) => {
    escrituras.push({ clave, datos });
    docs[clave] = Object.assign({}, datos);
  };

  return {
    docs,
    escrituras,
    lecturas,
    opcionesDeTransaccion,
    collection: (coleccion) => ({
      doc: (id) => ref(coleccion, id),
      where: () => {
        throw new Error('el asistente no debe consultar colecciones aqui');
      },
    }),
    async runTransaction(fn, opciones) {
      opcionesDeTransaccion.push(opciones);
      return fn({
        async get(r) {
          return leer(r.clave);
        },
        set(r, datos) {
          escribir(r.clave, datos);
        },
      });
    },
  };
}

/** Cliente de modelo de mentira: guarda cada peticion que recibe. */
function fakeCliente(respuestas) {
  const cola = Array.isArray(respuestas) ? respuestas.slice() : [respuestas];
  const peticiones = [];
  return {
    peticiones,
    async generar(peticion) {
      peticiones.push(peticion);
      const siguiente = cola.length > 1 ? cola.shift() : cola[0];
      if (siguiente instanceof Error) throw siguiente;
      if (typeof siguiente === 'function') return siguiente();
      return siguiente;
    },
  };
}

const agendaVacia = async () => ({ rol: 'propietario', ventana_dias: 30, items: [] });
const agendaCon = (items) => async () => ({ rol: 'propietario', ventana_dias: 30, items });

function crear(opciones = {}) {
  const db = opciones.db || fakeDb();
  const cliente = opciones.cliente || fakeCliente('agenda');
  const asistente = crearAsistente({
    db,
    cliente,
    ahora: () => opciones.ahora || AHORA,
    construirAgenda: opciones.construirAgenda || agendaVacia,
  });
  return { db, cliente, asistente };
}

const preguntar = (asistente, extra) =>
  asistente.responder(Object.assign({ uid: 'u1', pregunta: 'que tengo pendiente' }, extra));

describe('asistente / el enum es cerrado', () => {
  it('solo existen las intenciones implementadas', () => {
    assert.deepStrictEqual(INTENCIONES, ['agenda', 'explicar', 'fuera_de_alcance']);
  });

  it('3. una etiqueta inventada por el modelo cae a fuera_de_alcance', async () => {
    // Sin esto, un modelo que responde «consultar_base_de_datos» abre una
    // rama que nadie escribio.
    //
    // Ojo con lo que este test NO dice. La decoracion se limpia antes de
    // comparar (minusculas y fuera todo lo que no sea [a-z_]), asi que
    // «Agenda.» y «agenda!!» SI se resuelven como `agenda`. Eso no es
    // interpretar la respuesta: el valor final sigue siendo siempre una de
    // las tres constantes del enum, y rechazar una etiqueta correcta porque
    // el modelo le puso un punto es negarle la respuesta al usuario a cambio
    // de nada. Lo que la limpieza NO hace es unir palabras: «AGENDA Y ESTADO»
    // se queda en `agendayestado`, que no esta en el enum — y ese es el caso
    // que de verdad importa, porque es el que podria abrir dos ramas a la vez.
    const fuera = ['borrar_todo', 'AGENDA Y ESTADO', '', '{"i":"agenda"}', 'agenda; estado'];
    for (const inventada of fuera) {
      const { asistente, cliente } = crear({ cliente: fakeCliente(inventada) });
      const r = await preguntar(asistente);
      assert.strictEqual(r.intencion, FUERA_DE_ALCANCE, 'paso: ' + JSON.stringify(inventada));
      assert.strictEqual(cliente.peticiones.length, 1, 'llamo al redactor tras no entender');
    }
  });

  it('la decoracion de una etiqueta correcta no la tira a la basura', async () => {
    for (const decorada of ['agenda', 'Agenda.', ' AGENDA\n', 'agenda!!']) {
      const cliente = fakeCliente([decorada, 'prosa']);
      const { asistente } = crear({
        cliente,
        construirAgenda: agendaCon([{ tipo: 'soat', placa: 'ABC123', dias_restantes: 3 }]),
      });
      const r = await preguntar(asistente);
      assert.strictEqual(r.intencion, 'agenda', 'se rechazo: ' + JSON.stringify(decorada));
    }
  });

  it('fuera_de_alcance responde texto fijo y NO llama al redactor', async () => {
    const { asistente, cliente } = crear({ cliente: fakeCliente(FUERA_DE_ALCANCE) });
    const r = await preguntar(asistente, { pregunta: 'por que suena el motor' });
    assert.strictEqual(r.texto, TEXTO_FUERA_DE_ALCANCE.es);
    assert.strictEqual(cliente.peticiones.length, 1, 'gasto una llamada en redactar una negativa');
  });

  it('el rechazo se localiza por parametro, no por adivinanza', async () => {
    const { asistente } = crear({ cliente: fakeCliente(FUERA_DE_ALCANCE) });
    const r = await preguntar(asistente, { idioma: 'en' });
    assert.strictEqual(r.texto, TEXTO_FUERA_DE_ALCANCE.en);
  });

  it('una respuesta ININTELIGIBLE del clasificador no abre ninguna rama', async () => {
    // Lo que se traga es lo que NO es accionable: un error sin codigo, o el
    // filtro del proveedor negandose a mirar la pregunta. Ahi «fuera de
    // alcance» es la lectura honesta.
    const roto = new Error('se cayo');
    const { asistente } = crear({ cliente: fakeCliente(roto) });
    assert.strictEqual((await preguntar(asistente)).intencion, FUERA_DE_ALCANCE);

    const bloqueado = new Error('SAFETY');
    bloqueado.code = 'aborted';
    const otro = crear({ cliente: fakeCliente(bloqueado) });
    assert.strictEqual((await preguntar(otro.asistente)).intencion, FUERA_DE_ALCANCE);
  });

  it('una AVERIA al clasificar SUBE, no se disfraza de fuera de alcance', async () => {
    // **Este test cubre un defecto que encontro el cierre del gap del motivo.**
    // Clasificar es la PRIMERA llamada al modelo, asi que con Gemini caido o
    // mal configurado siempre fallaba aqui — y el `catch` lo convertia en
    // «solo puedo ayudarte con los vencimientos». La persona recibia una
    // negativa segura de si misma en vez de un error: sin reintento, sin
    // aviso, y con los logs diciendo que la consulta se atendio. De paso,
    // hacia inalcanzable el motivo `proveedor` que acaba de anadirse.
    for (const codigo of CODIGOS_QUE_SUBEN) {
      const roto = new Error('averia');
      roto.code = codigo;
      if (codigo === 'unavailable') roto.detalle = 'proveedor';
      const { asistente } = crear({ cliente: fakeCliente(roto) });
      await assert.rejects(
        () => preguntar(asistente),
        (e) => e.code === codigo,
        'un ' + codigo + ' al clasificar se sirvio como un rechazo'
      );
    }
  });
});

describe('asistente / el prompt del redactor', () => {
  it('1 y 2. lleva el envelope y NADA mas: ni uid, ni ids, ni texto ajeno', async () => {
    const cliente = fakeCliente(['agenda', 'prosa']);
    const { asistente } = crear({
      cliente,
      construirAgenda: agendaCon([{ tipo: 'soat', placa: 'ABC123', dias_restantes: 3 }]),
    });
    await preguntar(asistente, { uid: 'uid-secreto-123', pregunta: 'que tengo' });

    const redactor = cliente.peticiones[1];
    assert.ok(redactor, 'no se llamo al redactor');
    const todo = redactor.sistema + '|' + redactor.usuario;
    assert.strictEqual(todo.indexOf('uid-secreto-123'), -1, 'FUGA: el uid va en el prompt');
  });

  it('2. el prompt no contiene NINGUNA fecha de mantenimiento', async () => {
    // El cliente fabrica `fechaLimite: now + 15 dias` con el comentario
    // «Aproximado para la UI». Un modelo la afirma como un hecho: «tu cambio
    // de aceite vence el 4 de octubre». El envelope de mantenimiento no lleva
    // fecha de ninguna clase, y esto lo vigila.
    const cliente = fakeCliente(['agenda', 'prosa']);
    const { asistente } = crear({
      cliente,
      construirAgenda: agendaCon([
        { tipo: 'mantenimiento', placa: 'ABC123', nombre: 'Frenos', km_restantes: 200 },
      ]),
    });
    await preguntar(asistente);

    const enviado = cliente.peticiones[1].usuario;
    assert.ok(!/\d{4}-\d{2}-\d{2}/.test(enviado), 'hay una fecha ISO en el prompt: ' + enviado);
    assert.ok(enviado.indexOf('km_restantes') !== -1);
    assert.ok(
      cliente.peticiones[1].sistema.toLowerCase().indexOf('kilometros') !== -1,
      'las instrucciones no dicen que el mantenimiento va en km'
    );
  });

  it('una agenda vacia no gasta llamada al redactor', async () => {
    // Pedirle a un modelo que redacte sobre una lista vacia es invitarlo a
    // rellenarla.
    const cliente = fakeCliente(['agenda', 'prosa']);
    const { asistente } = crear({ cliente, construirAgenda: agendaVacia });
    const r = await preguntar(asistente);
    assert.strictEqual(r.items, 0);
    assert.strictEqual(cliente.peticiones.length, 1);
  });
});

describe('asistente / la cuota', () => {
  it('5. la consulta n+1 del dia se corta ANTES de llamar al modelo', async () => {
    const db = fakeDb();
    const cliente = fakeCliente(['agenda', 'prosa']);
    const { asistente } = crear({ db, cliente });

    for (let i = 0; i < LIMITE_POR_USUARIO; i += 1) {
      await preguntar(asistente);
    }
    const llamadasAntes = cliente.peticiones.length;

    await assert.rejects(
      () => preguntar(asistente),
      (e) => e.code === 'resource-exhausted' && e.detalle === 'cupo_usuario'
    );
    assert.strictEqual(
      cliente.peticiones.length,
      llamadasAntes,
      'gasto cuota del proveedor en una consulta que ya estaba cortada'
    );
  });

  it('el cupo global corta aunque el usuario tenga margen', async () => {
    const db = fakeDb({
      [COLECCION_CUOTA + '/' + DOC_CUOTA_GLOBAL]: {
        ventana_inicio: AHORA.getTime(),
        conteo: LIMITE_GLOBAL,
      },
    });
    const { asistente } = crear({ db });
    await assert.rejects(
      () => preguntar(asistente),
      (e) => e.code === 'resource-exhausted' && e.detalle === 'cupo_global'
    );
  });

  it('el usuario y el global se cuentan en la MISMA transaccion', async () => {
    const db = fakeDb();
    const { asistente } = crear({ db });
    await preguntar(asistente);

    const claves = db.escrituras.map((e) => e.clave);
    assert.ok(claves.indexOf(COLECCION_CUOTA + '/u1') !== -1);
    assert.ok(claves.indexOf(COLECCION_CUOTA + '/' + DOC_CUOTA_GLOBAL) !== -1);
  });

  it('la ventana caduca: pasadas 24 h el contador arranca de cero', async () => {
    const ayer = AHORA.getTime() - 25 * 60 * 60 * 1000;
    const db = fakeDb({
      [COLECCION_CUOTA + '/u1']: { ventana_inicio: ayer, conteo: LIMITE_POR_USUARIO },
    });
    const { asistente } = crear({ db });
    await assert.doesNotReject(() => preguntar(asistente));
  });

  it('cada contador lleva `expira_en` como fecha, para la politica TTL', async () => {
    // Sin TTL la coleccion crece un documento por usuario y no se vacia nunca.
    // Y tiene que ser Date/Timestamp: con milisegundos, la politica no lo mira.
    const db = fakeDb();
    const { asistente } = crear({ db });
    await preguntar(asistente);
    for (const escritura of db.escrituras.filter((e) => e.clave.startsWith(COLECCION_CUOTA))) {
      assert.ok(escritura.datos.expira_en instanceof Date, 'expira_en no es una fecha');
    }
  });
});

describe('asistente / el kill switch', () => {
  it('6. apagado corta antes de todo, sin llamar al modelo ni gastar cuota', async () => {
    const db = fakeDb({ 'configuracion/asistente_ia': { activo: false } });
    const cliente = fakeCliente(['agenda', 'prosa']);
    const { asistente } = crear({ db, cliente });

    await assert.rejects(
      () => preguntar(asistente),
      // El motivo es la mitad del arreglo: `unavailable` a secas lo comparte
      // con el proveedor caido, y las dos situaciones no se parecen — de una
      // se sale reintentando y de la otra solo encendiendo el interruptor.
      (e) => e.code === 'unavailable' && e.detalle === 'apagado'
    );
    assert.strictEqual(cliente.peticiones.length, 0);
    assert.strictEqual(db.escrituras.length, 0, 'gasto cuota de una consulta que no atendio');
  });

  it('sin documento de configuracion la feature esta ENCENDIDA', async () => {
    // Si no, desplegar sin sembrar el documento apaga la feature en silencio.
    const { asistente } = crear();
    await assert.doesNotReject(() => preguntar(asistente));
  });
});

describe('asistente / la cache de explicaciones', () => {
  it('7. la misma explicacion dos veces llama al modelo UNA vez', async () => {
    const db = fakeDb();
    const cliente = fakeCliente(['explicar', 'El SOAT es...']);
    const { asistente } = crear({ db, cliente });

    const a = await preguntar(asistente, { pregunta: 'que es el SOAT' });
    const llamadasTrasLaPrimera = cliente.peticiones.length;
    const b = await preguntar(asistente, { pregunta: '¿Que es el SOAT?' });

    assert.strictEqual(a.texto, b.texto);
    assert.strictEqual(b.cacheada, true);
    assert.strictEqual(
      cliente.peticiones.length,
      llamadasTrasLaPrimera,
      'la segunda consulta volvio a pagar dos llamadas al proveedor'
    );
  });

  it('la cache cobra cupo igual: un acierto no es gratis del todo', async () => {
    const db = fakeDb();
    const cliente = fakeCliente(['explicar', 'El SOAT es...']);
    const { asistente } = crear({ db, cliente });
    await preguntar(asistente, { pregunta: 'que es el SOAT' });
    await preguntar(asistente, { pregunta: 'que es el SOAT' });
    assert.strictEqual(db.docs[COLECCION_CUOTA + '/u1'].conteo, 2);
  });

  it('NUNCA se cachea la agenda: seria servirle a uno los datos de otro', async () => {
    const db = fakeDb();
    const cliente = fakeCliente(['agenda', 'prosa']);
    const { asistente } = crear({
      db,
      cliente,
      construirAgenda: agendaCon([{ tipo: 'soat', placa: 'ABC123', dias_restantes: 3 }]),
    });
    await preguntar(asistente);
    const enCache = Object.keys(db.docs).filter((k) => k.startsWith(COLECCION_CACHE));
    assert.deepStrictEqual(enCache, [], 'FUGA: la agenda de un usuario quedo en cache global');
  });

  it('la cache separa por idioma', async () => {
    const db = fakeDb();
    const cliente = fakeCliente(['explicar', 'texto es', 'explicar', 'texto en']);
    const { asistente } = crear({ db, cliente });
    const es = await preguntar(asistente, { pregunta: 'que es el SOAT', idioma: 'es' });
    const en = await preguntar(asistente, { pregunta: 'que es el SOAT', idioma: 'en' });
    assert.notStrictEqual(es.texto, en.texto, 'el ingles recibio la respuesta cacheada en espanol');
  });
});

describe('asistente / errores y entradas', () => {
  it('4. un 429 del proveedor sube como resource-exhausted', async () => {
    const agotado = new Error('sin cuota');
    agotado.code = 'resource-exhausted';
    const { asistente } = crear({ cliente: fakeCliente(agotado) });
    await assert.rejects(() => preguntar(asistente), (e) => e.code === 'resource-exhausted');
  });

  it('8. la autorizacion del taller se decide dentro de construirAgenda', async () => {
    // El callable corre con Admin SDK: si la denegacion no viaja, un taller
    // pendiente recibe agenda. Aqui se comprueba que el error SUBE y que el
    // redactor no llega a llamarse.
    const denegado = new Error('Taller pendiente de aprobacion: agenda denegada.');
    denegado.code = 'permission-denied';
    const cliente = fakeCliente(['agenda', 'prosa']);
    const { asistente } = crear({
      cliente,
      construirAgenda: async () => {
        throw denegado;
      },
    });
    await assert.rejects(() => preguntar(asistente), (e) => e.code === 'permission-denied');
    assert.strictEqual(cliente.peticiones.length, 1, 'redacto sobre una agenda denegada');
  });

  it('sin uid no se atiende', async () => {
    const { asistente } = crear();
    await assert.rejects(
      () => asistente.responder({ pregunta: 'hola' }),
      (e) => e.code === 'unauthenticated'
    );
  });

  it('una pregunta vacia o de puros simbolos se rechaza sin gastar nada', async () => {
    const cliente = fakeCliente(['agenda', 'prosa']);
    const { asistente, db } = crear({ cliente });
    for (const basura of ['', '   ', '!!!???', null]) {
      await assert.rejects(
        () => preguntar(asistente, { pregunta: basura }),
        (e) => e.code === 'invalid-argument'
      );
    }
    assert.strictEqual(cliente.peticiones.length, 0);
    assert.strictEqual(db.escrituras.length, 0);
  });

  it('una pregunta larguisima se recorta antes de salir', async () => {
    const cliente = fakeCliente([FUERA_DE_ALCANCE]);
    const { asistente } = crear({ cliente });
    await preguntar(asistente, { pregunta: 'a'.repeat(50000) });
    assert.ok(cliente.peticiones[0].usuario.length <= 500);
  });
});

describe('asistente / normalizacion', () => {
  it('tildes, mayusculas y signos no crean entradas de cache distintas', () => {
    assert.strictEqual(normalizar('¿Qué es el SOAT?'), normalizar('que es el soat'));
    assert.strictEqual(normalizar('  QUE   ES  el   SOAT  '), 'que es el soat');
  });

  it('el idioma se sanea y cae a espanol, nunca a undefined', () => {
    assert.strictEqual(idiomaValido('en-US'), 'en');
    assert.strictEqual(idiomaValido('ES'), 'es');
    assert.strictEqual(idiomaValido('fr'), 'es');
    assert.strictEqual(idiomaValido(undefined), 'es');
  });
});

describe('asistente / lo que levanto el gate de revision', () => {
  it('la transaccion de cuota reintenta de verdad: `_global` es un doc caliente', async () => {
    // Toda peticion escribe el MISMO documento `_global`, y Firestore admite
    // ~1 escritura sostenida por documento y segundo. Con los dos intentos que
    // hereda de `solicitudes_landing_control`, una sola colision agotaba los
    // reintentos y el usuario recibia `aborted` — un codigo que ademas viaja
    // hasta la UI. Alli los dos intentos son correctos porque quien se pisa es
    // un atacante; aqui el cubo compartido es el camino normal de todo el
    // mundo.
    const db = fakeDb();
    const { asistente } = crear({ db });
    await preguntar(asistente);
    const opciones = db.opcionesDeTransaccion[0] || {};
    assert.ok(
      opciones.maxAttempts >= 5,
      'maxAttempts vale ' + opciones.maxAttempts + ': una colision agota los reintentos'
    );
  });

  it('la cache escribe `expira_en`, o no es candidata a politica TTL', async () => {
    // Sin este campo la coleccion crece un documento por pregunta distinta y
    // no se vacia nunca, y una entrada mala se queda para siempre sin ningun
    // camino de servidor para retirarla: el cliente no puede borrarla (bien) y
    // no hay barrido.
    const db = fakeDb();
    const cliente = fakeCliente(['explicar', 'El SOAT es...']);
    const { asistente } = crear({ db, cliente });
    await preguntar(asistente, { pregunta: 'que es el SOAT' });

    const enCache = db.escrituras.filter((e) => e.clave.startsWith(COLECCION_CACHE));
    assert.strictEqual(enCache.length, 1);
    assert.ok(
      enCache[0].datos.expira_en instanceof Date,
      'la entrada de cache no lleva `expira_en` como fecha'
    );
    assert.ok(
      enCache[0].datos.expira_en.getTime() > AHORA.getTime(),
      '`expira_en` no esta en el futuro'
    );
  });
});

describe('asistente / el mensaje que llega al cliente', () => {
  // Lo levanto el gate de rendimiento al revisar el cierre del gap, y el
  // alcance era NUEVO: hasta que `clasificar` empezo a dejar subir
  // `failed-precondition`, un modelo mal configurado moria en la primera
  // llamada y se degradaba a `fuera_de_alcance`, asi que este texto no salia
  // del servidor jamas.

  it('NINGUN mensaje publicable nombra un secreto ni una herramienta interna', () => {
    const prohibido = /GEMINI_API_KEY|GEMINI_MODELO|spike_gemini|firebase functions:secrets|\.env/i;
    Object.keys(MENSAJES_PUBLICOS).forEach((codigo) => {
      assert.ok(
        !prohibido.test(MENSAJES_PUBLICOS[codigo]),
        'el mensaje de ' + codigo + ' publica algo interno: ' + MENSAJES_PUBLICOS[codigo]
      );
    });
  });

  it('el texto de operador de modeloGemini NO es publicable', () => {
    // Es el caso concreto: un 404 de Gemini —nombre de modelo caducado, el
    // fallo mas probable de todos— traia consigo el nombre del secreto y el
    // del script del spike.
    const real =
      'El modelo no existe para esta clave o para esta version del endpoint. ' +
      'Lista los disponibles con `node functions/spike_gemini.js --listar` y ' +
      'fija el que corresponda en GEMINI_MODELO.';
    assert.notStrictEqual(mensajePublico('failed-precondition'), real);
    assert.strictEqual(mensajePublico('failed-precondition'), MENSAJES_PUBLICOS['failed-precondition']);
  });

  it('un codigo heredado del prototipo no publica codigo fuente', () => {
    // Con `MENSAJES_PUBLICOS[codigo]` a secas, `constructor` devuelve una
    // funcion y `toString` otra: lo que se publicaria seria codigo fuente.
    ['constructor', 'toString', '__proto__', 'hasOwnProperty'].forEach((codigo) => {
      assert.strictEqual(mensajePublico(codigo), 'No se pudo responder.');
    });
  });

  it('los ocho codigos conocidos del callable tienen mensaje propio', () => {
    // Espejo de la lista `conocidos` de functions/index.js. Si alli se anade
    // uno y aqui no, cae al generico en silencio.
    [
      'unauthenticated',
      'invalid-argument',
      'permission-denied',
      'resource-exhausted',
      'unavailable',
      'deadline-exceeded',
      'failed-precondition',
      'aborted',
    ].forEach((codigo) => {
      assert.notStrictEqual(
        mensajePublico(codigo),
        'No se pudo responder.',
        'el codigo ' + codigo + ' no tiene mensaje propio'
      );
    });
  });
});

describe('asistente / el motivo que llega al cliente', () => {
  // **El cliente no puede deshacer la ambiguedad solo.** Dos codigos cubren
  // cuatro situaciones: `resource-exhausted` es tu cupo o el del asistente
  // entero, y `unavailable` es el interruptor o el proveedor. Sin un motivo,
  // la pantalla elige un texto que miente en la mitad de los casos y ofrece
  // un boton que sobra en la otra mitad.

  it('deja pasar los cuatro motivos del vocabulario', () => {
    assert.deepStrictEqual(MOTIVOS, [
      'cupo_usuario',
      'cupo_global',
      'apagado',
      'proveedor',
    ]);
    MOTIVOS.forEach((motivo) => {
      assert.strictEqual(motivoPublico({ detalle: motivo }), motivo);
    });
  });

  it('NO reenvia el blockReason de Google, que es texto de un tercero', () => {
    // `textoDeRespuesta()` de modeloGemini.js pone ahi el `blockReason` y el
    // `finishReason` que devuelve el proveedor, y `details` de un HttpsError
    // viaja al cliente literal. Reenviar `e.detalle` tal cual abriria un
    // canal por el que alguien de fuera escribe en la app.
    ['SAFETY', 'MAX_TOKENS', 'sin_candidatos', 'sin_texto'].forEach((ajeno) => {
      assert.strictEqual(
        motivoPublico({ detalle: ajeno }),
        undefined,
        'se filtro al cliente el motivo ajeno "' + ajeno + '"'
      );
    });
  });

  it('un proveedor caido llega marcado, y NO se confunde con el apagado', async () => {
    // Este es el camino que el kill switch no cubre: el interruptor esta
    // encendido, la cuota alcanza, y lo que falla es Gemini. Los dos son
    // `unavailable`; solo el motivo los separa, y de eso depende si la
    // pantalla ofrece reintentar.
    const caido = new Error('El modelo respondio 500.');
    caido.code = 'unavailable';
    caido.detalle = 'proveedor';
    const { asistente } = crear({
      cliente: fakeCliente(['agenda', caido]),
      construirAgenda: agendaCon([
        { tipo: 'documento', documento: 'soat', dias_restantes: 5 },
      ]),
    });

    await assert.rejects(
      () => preguntar(asistente),
      (e) => e.code === 'unavailable' && motivoPublico(e) === 'proveedor'
    );
  });

  it('un error sin detalle, o con uno que no es cadena, no publica nada', () => {
    [undefined, null, {}, { detalle: undefined }, { detalle: 42 }, { detalle: {} }].forEach(
      (entrada) => {
        assert.strictEqual(motivoPublico(entrada), undefined);
      }
    );
  });
});

describe('asistente / el cupo global no paga lo que el proveedor no atendio', () => {
  // **Lo levanto el gate de rendimiento, y es consecuencia de dejar subir los
  // fallos de infraestructura.** Antes, un Gemini caido devolvia 200 con un
  // texto plausible y la persona paraba. Ahora devuelve error y la pantalla
  // pinta un boton de reintentar: durante una caida los reintentos se comen
  // `LIMITE_GLOBAL`, y cuando Gemini se recupera el asistente sigue muerto
  // hasta que ruede la ventana de 24 h. La caida sobrevive a la caida, y el
  // interruptor no ayuda porque solo apaga.

  const conteoDe = (db, clave) => {
    const escritas = db.escrituras.filter((e) => e.clave === clave);
    return escritas.length ? escritas[escritas.length - 1].datos.conteo : null;
  };
  const CLAVE_GLOBAL = COLECCION_CUOTA + '/' + DOC_CUOTA_GLOBAL;

  function averia(codigo) {
    const e = new Error('averia');
    e.code = codigo;
    if (codigo === 'unavailable') e.detalle = 'proveedor';
    return e;
  }

  const campoDe = (db, clave, campo) => {
    const escritas = db.escrituras.filter((e) => e.clave === clave);
    return escritas.length ? escritas[escritas.length - 1].datos[campo] : null;
  };

  it('una averia devuelve LOS DOS cupos, el global y el del usuario', async () => {
    // **Politica cambiada al cerrar el gap 9.** Antes el cargo del usuario se
    // quedaba, con la razon de que era «el freno que impide reintentar sin
    // limite contra un proveedor roto». La razon era correcta y el efecto
    // injusto: a alguien que no recibio ninguna respuesta se le comia una de
    // sus diez consultas del dia por una averia ajena.
    //
    // El freno no desaparece, cambia de sitio: ahora es el tope de
    // `DEVOLUCIONES_POR_VENTANA`, que se prueba en el caso siguiente.
    for (const codigo of CODIGOS_SIN_CARGO_GLOBAL) {
      const db = fakeDb();
      const { asistente } = crear({ db, cliente: fakeCliente(averia(codigo)) });

      await assert.rejects(() => preguntar(asistente), (e) => e.code === codigo);

      assert.strictEqual(
        conteoDe(db, CLAVE_GLOBAL),
        0,
        codigo + ': se cobro al cubo global una consulta que el proveedor no atendio'
      );
      assert.strictEqual(
        conteoDe(db, COLECCION_CUOTA + '/u1'),
        0,
        codigo + ': se le cobro al usuario una consulta que nadie le respondio'
      );
      assert.strictEqual(
        campoDe(db, COLECCION_CUOTA + '/u1', 'devoluciones'),
        1,
        codigo + ': la devolucion no quedo contada, asi que el tope no puede aplicarse'
      );
    }
  });

  it('el tope corta las devoluciones del usuario, no el global', async () => {
    // El abuso que la politica vieja cerraba negandose a devolver: quien
    // encuentre una entrada que haga fallar al proveedor de forma fiable
    // tendria consultas infinitas, y con ellas el cubo GLOBAL a coste cero —
    // que es el que tumba la feature para todos.
    //
    // Se ejerce una vez MAS que el tope, con el estado acumulandose entre
    // vueltas como en produccion.
    const db = fakeDb();
    const { asistente } = crear({ db, cliente: fakeCliente(averia('unavailable')) });

    for (let i = 0; i < DEVOLUCIONES_POR_VENTANA + 1; i += 1) {
      await assert.rejects(() => preguntar(asistente), (e) => e.code === 'unavailable');
    }

    assert.strictEqual(
      campoDe(db, COLECCION_CUOTA + '/u1', 'devoluciones'),
      DEVOLUCIONES_POR_VENTANA,
      'el tope no corto: se devolvieron mas consultas de las permitidas por ventana'
    );
    assert.strictEqual(
      conteoDe(db, COLECCION_CUOTA + '/u1'),
      1,
      'pasado el tope, la consulta fallida SI se cobra: es lo que frena el bucle'
    );
  });

  it('el contador de devoluciones sobrevive a la consulta siguiente', async () => {
    // Sin esto el tope no valdria nada, y el defecto es facil de reintroducir:
    // `dentroDelCupo` escribe con `tx.set`, que REEMPLAZA el documento. Si no
    // arrastrara `devoluciones`, cada consulta nueva lo borraria y el limite
    // se reiniciaria a cada vuelta — devoluciones infinitas otra vez.
    const db = fakeDb();
    const { asistente } = crear({ db, cliente: fakeCliente(averia('unavailable')) });
    await assert.rejects(() => preguntar(asistente), (e) => e.code === 'unavailable');

    // Una consulta que SI funciona, entre medias.
    const { asistente: bueno } = crear({
      db,
      cliente: fakeCliente(['explicar', 'El SOAT es...']),
    });
    await preguntar(bueno, { pregunta: 'que es el SOAT' });

    assert.strictEqual(
      campoDe(db, COLECCION_CUOTA + '/u1', 'devoluciones'),
      1,
      'la consulta siguiente borro el contador de devoluciones'
    );
  });

  it('un 429 del PROVEEDOR no se devuelve: insistirle seria el error', async () => {
    // Dentro del flujo, `resource-exhausted` solo puede venir del proveedor:
    // el cupo propio se corta antes de incrementar nada.
    const db = fakeDb();
    const { asistente } = crear({ db, cliente: fakeCliente(averia('resource-exhausted')) });

    await assert.rejects(() => preguntar(asistente), (e) => e.code === 'resource-exhausted');
    assert.strictEqual(conteoDe(db, CLAVE_GLOBAL), 1);
  });

  it('una respuesta normal no devuelve nada', async () => {
    const db = fakeDb();
    const { asistente } = crear({ db });
    await preguntar(asistente);
    assert.strictEqual(conteoDe(db, CLAVE_GLOBAL), 1);
  });

  it('con la ventana ya rodada no se resta: no hay contador negativo', async () => {
    // Restar ahi seria descontar una consulta de ayer del presupuesto de hoy.
    const viejo = AHORA.getTime() - VENTANA_MS - 1;
    const db = fakeDb({
      [CLAVE_GLOBAL]: { ventana_inicio: viejo, conteo: 0 },
    });
    const { asistente } = crear({ db, cliente: fakeCliente(averia('unavailable')) });

    await assert.rejects(() => preguntar(asistente), (e) => e.code === 'unavailable');

    const conteos = db.escrituras
      .filter((e) => e.clave === CLAVE_GLOBAL)
      .map((e) => e.datos.conteo);
    assert.ok(
      conteos.every((c) => c >= 0),
      'el contador global se quedo en negativo: ' + JSON.stringify(conteos)
    );
  });
});

describe('asistente / el clasificador cabe en su presupuesto', () => {
  // **El spike lo midio en produccion del proveedor, no en teoria:** con
  // `maxTokens: 10` los dos modelos probados devolvieron `fuera_de_alc`, doce
  // de los dieciseis caracteres de `fuera_de_alcance`, en las dos preguntas
  // que debian rechazarse.

  it('el presupuesto da para la etiqueta mas larga del enum', () => {
    const masLarga = INTENCIONES.reduce((a, b) => (a.length >= b.length ? a : b));
    assert.ok(
      MAX_TOKENS_ETIQUETA >= masLarga.length,
      'con ' + MAX_TOKENS_ETIQUETA + ' tokens no cabe "' + masLarga + '" (' + masLarga.length + ' caracteres)'
    );
    assert.ok(MAX_TOKENS_ETIQUETA > 10, 'sigue en el presupuesto que el spike demostro corto');
  });

  it('se deriva del enum: una etiqueta nueva y mas larga lo acompaña', () => {
    // Si fuera un numero fijo, anadir una etiqueta volveria a cortarla y el
    // fail-safe volveria a tapar el defecto.
    const esperado = 4 * INTENCIONES.reduce((m, e) => Math.max(m, e.length), 0);
    assert.strictEqual(MAX_TOKENS_ETIQUETA, esperado);
  });

  it('el clasificador pide ese presupuesto, no uno suyo', () => {
    // Sin esto los dos de arriba vigilan una constante que nadie usa.
    const cliente = fakeCliente('agenda');
    const { asistente } = crear({ cliente });
    return preguntar(asistente).then(() => {
      assert.strictEqual(cliente.peticiones[0].maxTokens, MAX_TOKENS_ETIQUETA);
      assert.strictEqual(cliente.peticiones[0].temperatura, 0);
    });
  });

  it('una etiqueta CORTADA sigue cayendo al lado seguro', () => {
    // El fail-safe se queda: subir el presupuesto hace que el corte no ocurra,
    // no que deje de importar si ocurriera.
    const cliente = fakeCliente('fuera_de_alc');
    const { asistente } = crear({ cliente });
    return preguntar(asistente).then((r) => {
      assert.strictEqual(r.intencion, FUERA_DE_ALCANCE);
    });
  });
});

/**
 * El interruptor se lee UNA vez por peticion, y eso es una decision cerrada.
 *
 * El gap 5 preguntaba si cachearlo. La respuesta es no: un interruptor de
 * emergencia cacheado deja de ser un interruptor de emergencia — con 60 s de
 * cache, apagarlo tarda hasta un minuto, y ese minuto es justo aquello para lo
 * que existe. Con cache por instancia es peor: cada instancia caliente expira
 * cuando le toca, asi que el apagado seria parcial y sin forma de saber cuando
 * acabo.
 *
 * Lo que estos casos fijan es el precio de esa decision, para que no se
 * convierta en otro sin que nadie lo note: **exactamente una** lectura, y
 * **en cada** peticion.
 */
describe('asistente / el coste del interruptor esta clavado', () => {
  const CLAVE = 'configuracion/asistente_ia';

  it('estaEncendido cuesta UNA lectura, no dos', async () => {
    const db = fakeDb();
    const { asistente } = crear({ db, cliente: fakeCliente(FUERA_DE_ALCANCE) });
    await preguntar(asistente);

    const delInterruptor = db.lecturas.filter((c) => c === CLAVE);
    assert.strictEqual(
      delInterruptor.length,
      1,
      'el interruptor se leyo ' + delInterruptor.length + ' veces en una sola consulta'
    );
  });

  it('se relee en CADA peticion: apagarlo surte efecto en la siguiente', async () => {
    // La propiedad que hace del interruptor un interruptor. Si alguien lo
    // cachea entre llamadas, este caso se pone rojo — y no hay ningun otro
    // test que pueda verlo.
    const db = fakeDb();
    const { asistente } = crear({ db, cliente: fakeCliente(FUERA_DE_ALCANCE) });

    await preguntar(asistente);
    db.docs[CLAVE] = { activo: false };

    await assert.rejects(
      () => preguntar(asistente),
      (e) => e.code === 'unavailable' && e.detalle === 'apagado',
      'apagar el interruptor no surtio efecto en la consulta siguiente'
    );

    assert.strictEqual(
      db.lecturas.filter((c) => c === CLAVE).length,
      2,
      'no se releyo: el interruptor quedo cacheado entre peticiones'
    );
  });
});

/**
 * El clasificador pide la etiqueta con un ESQUEMA, y sobrevive si el
 * proveedor no lo admite.
 *
 * Cierra el gap 3. `maxOutputTokens` no protege frente a un modelo que piensa:
 * los tokens de razonamiento se comen el presupuesto y la etiqueta sale
 * truncada o vacia — medido con `gemini-3.5-flash`, que devolvia respuestas
 * VACIAS al clasificar. La instruccion en prosa PIDE una etiqueta del enum;
 * el esquema OBLIGA, porque restringe la decodificacion.
 *
 * Y la caida blanda es la mitad que evita cambiar un gap por una averia:
 * `responseSchema` y `thinkingConfig` son superficie del proveedor que este
 * repositorio **no puede verificar sin gastar cuota**. Si Gemini rechazara el
 * mimetype, sin reintento toda clasificacion fallaria y el asistente moriria
 * entero.
 */
describe('asistente / la etiqueta se pide con esquema', () => {
  it('la peticion del clasificador lleva el enum y apaga el razonamiento', async () => {
    const { asistente, cliente } = crear({ cliente: fakeCliente(FUERA_DE_ALCANCE) });
    await preguntar(asistente);

    const clasificador = cliente.peticiones[0];
    assert.deepStrictEqual(
      clasificador.enumeracion,
      INTENCIONES,
      'el clasificador no restringe la salida al enum'
    );
    assert.strictEqual(clasificador.sinRazonar, true);
    assert.strictEqual(clasificador.temperatura, 0);
  });

  it('el REDACTOR no lleva esquema: ese si escribe prosa', async () => {
    // Sin esta red, restringir la salida del redactor a un enum le daria una
    // respuesta de tres palabras a la persona.
    const cliente = fakeCliente(['agenda', 'prosa']);
    const { asistente } = crear({
      cliente,
      construirAgenda: agendaCon([{ tipo: 'soat', placa: 'ABC123', dias_restantes: 3 }]),
    });
    await preguntar(asistente);

    const redactor = cliente.peticiones[1];
    assert.strictEqual(redactor.enumeracion, undefined);
    assert.strictEqual(redactor.sinRazonar, undefined);
  });

  it('si el proveedor RECHAZA el esquema, se reintenta sin el', async () => {
    const rechazo = new Error('mimetype no soportado');
    rechazo.code = 'failed-precondition';

    let llamadas = 0;
    const cliente = {
      peticiones: [],
      async generar(peticion) {
        this.peticiones.push(peticion);
        llamadas += 1;
        if (llamadas === 1) throw rechazo;
        return 'agenda';
      },
    };
    const { asistente } = crear({ cliente, construirAgenda: agendaVacia });

    const r = await preguntar(asistente);

    assert.strictEqual(r.intencion, 'agenda', 'el rechazo del esquema tumbo la clasificacion');
    assert.strictEqual(cliente.peticiones.length, 2);
    assert.deepStrictEqual(cliente.peticiones[0].enumeracion, INTENCIONES);
    assert.strictEqual(
      cliente.peticiones[1].enumeracion,
      undefined,
      'el reintento volvio a mandar el esquema que acababan de rechazar'
    );
  });

  it('una caida del proveedor NO se reintenta: seria pagar dos veces', async () => {
    // El reintento es solo para la configuracion rechazada. Un `unavailable`
    // o un timeout repetido gasta cuota dos veces para el mismo fallo.
    for (const codigo of ['unavailable', 'deadline-exceeded', 'resource-exhausted']) {
      const averia = new Error('averia');
      averia.code = codigo;
      const cliente = fakeCliente(averia);
      const { asistente } = crear({ cliente });

      await assert.rejects(() => preguntar(asistente), (e) => e.code === codigo);
      assert.strictEqual(
        cliente.peticiones.length,
        1,
        codigo + ': se reintento una averia que no era de configuracion'
      );
    }
  });
});
