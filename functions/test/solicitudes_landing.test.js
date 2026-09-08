'use strict';

/**
 * Cobertura del endpoint que recibe los formularios de la landing.
 *
 * Por que existe: la landing es un export estatico (`output: "export"` en
 * next.config.ts), asi que no tiene servidor propio. Los dos formularios que
 * habia resolvian eso de dos maneras, y las dos mentian al usuario:
 *
 *  - contact/page.tsx: `<form action="#">`. Pulsar "Enviar" recarga la pagina
 *    y no manda nada a ningun sitio.
 *  - WorkshopsSection.tsx: POST sin autenticar a la REST API de Firestore de
 *    PRODUCCION contra /talleres. La regla de esa coleccion es
 *    `allow create: if isAdmin()`, asi que la solicitud SIEMPRE se deniega y
 *    el taller ve el error generico. Un formulario completo, con estados de
 *    carga y de exito que nunca se alcanzan.
 *
 * El contrato unico es este endpoint: valida, limita y persiste con el Admin
 * SDK en una coleccion cerrada a los clientes.
 *
 * Se prueba la logica pura (`validarSolicitud`) y el manejador con dobles de
 * `req`/`res` y un Firestore inyectado, igual que publishTallerProfile.test.js:
 * tocar `admin.firestore` dispara `ensureApp()` y obliga a montar credenciales.
 */

const assert = require('assert');

// Fuera del emulador la sal es obligatoria (ver salDeIp): se fija antes de
// requerir el modulo para que los tests ejerzan el mismo camino que produccion
// y no el atajo del emulador.
process.env.SOLICITUDES_LANDING_SALT = 'sal-de-pruebas';

const {
  validarSolicitud,
  crearManejador,
  origenPermitido,
  LIMITE_POR_VENTANA,
} = require('../src/solicitudesLanding');

// --- dobles -----------------------------------------------------------------

function fakeRes() {
  const res = {
    codigo: 200,
    cuerpo: null,
    cabeceras: {},
    set(k, v) {
      res.cabeceras[k] = v;
      return res;
    },
    status(c) {
      res.codigo = c;
      return res;
    },
    json(b) {
      res.cuerpo = b;
      return res;
    },
    send(b) {
      res.cuerpo = b;
      return res;
    },
  };
  return res;
}

function fakeReq(extra) {
  return Object.assign(
    {
      method: 'POST',
      headers: { origin: 'https://autodoc.app' },
      ip: '203.0.113.9',
      body: {
        tipo: 'contacto',
        nombre: 'Ana Perez',
        correo: 'ana@example.com',
        mensaje: 'Quiero saber si cubren Santa Ana.',
      },
    },
    extra
  );
}

/**
 * Firestore minimo: guarda documentos en memoria y ejecuta la transaccion del
 * limitador de forma secuencial, que es lo unico que el manejador necesita.
 */
function fakeDb() {
  const docs = new Map();
  const db = {
    escritos: [],
    collection(nombre) {
      return {
        doc(id) {
          return { ruta: nombre + '/' + (id || 'auto') };
        },
        add(datos) {
          db.escritos.push({ coleccion: nombre, datos });
          return Promise.resolve({ id: 'doc-' + db.escritos.length });
        },
      };
    },
    runTransaction(fn) {
      const tx = {
        get(ref) {
          const d = docs.get(ref.ruta);
          return Promise.resolve({ exists: d !== undefined, data: () => d });
        },
        set(ref, datos) {
          docs.set(ref.ruta, datos);
        },
      };
      return Promise.resolve(fn(tx));
    },
  };
  return db;
}

function opciones(db, ahora) {
  return {
    db,
    ahora: () => ahora || 1757000000000,
    timestamp: () => 'SERVER_TIMESTAMP',
  };
}

// --- validacion -------------------------------------------------------------

describe('solicitudesLanding / validarSolicitud', () => {
  it('acepta una solicitud de contacto completa y devuelve los campos recortados', () => {
    const r = validarSolicitud({
      tipo: 'contacto',
      nombre: '  Ana Perez  ',
      correo: ' ANA@example.com ',
      mensaje: '  Hola  ',
    });

    assert.strictEqual(r.ok, true);
    assert.strictEqual(r.datos.nombre, 'Ana Perez');
    assert.strictEqual(r.datos.correo, 'ana@example.com', 'el correo se normaliza a minusculas');
    assert.strictEqual(r.datos.mensaje, 'Hola');
  });

  it('rechaza un tipo que no existe', () => {
    const r = validarSolicitud({ tipo: 'lo-que-sea', nombre: 'A', correo: 'a@b.co', mensaje: 'x' });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.motivo, 'tipo');
  });

  it('rechaza el contacto sin mensaje: es el unico campo que da sentido al envio', () => {
    const r = validarSolicitud({ tipo: 'contacto', nombre: 'Ana', correo: 'a@b.co', mensaje: '   ' });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.motivo, 'campos');
  });

  it('rechaza un correo sin forma de correo', () => {
    const r = validarSolicitud({ tipo: 'contacto', nombre: 'Ana', correo: 'ana(arroba)b', mensaje: 'x' });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.motivo, 'correo');
  });

  it('rechaza un mensaje desmesurado en vez de guardarlo', () => {
    const r = validarSolicitud({
      tipo: 'contacto',
      nombre: 'Ana',
      correo: 'a@b.co',
      mensaje: 'x'.repeat(5000),
    });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.motivo, 'largo');
  });

  it('la afiliacion exige taller, telefono y ubicacion, no mensaje', () => {
    const completa = validarSolicitud({
      tipo: 'afiliacion',
      nombre: 'AutoFix',
      correo: 'a@b.co',
      telefono: '+503 7777-8888',
      ubicacion: 'San Salvador',
      especialidad: 'Mecanica General',
    });
    assert.strictEqual(completa.ok, true);
    assert.strictEqual(completa.datos.telefono, '+503 7777-8888');

    const sinTelefono = validarSolicitud({
      tipo: 'afiliacion',
      nombre: 'AutoFix',
      correo: 'a@b.co',
      ubicacion: 'San Salvador',
    });
    assert.strictEqual(sinTelefono.ok, false);
    assert.strictEqual(sinTelefono.motivo, 'campos');
  });

  it('no deja colar campos ajenos al contrato', () => {
    const r = validarSolicitud({
      tipo: 'contacto',
      nombre: 'Ana',
      correo: 'a@b.co',
      mensaje: 'x',
      rol: 'Superusuario',
      estado: 'aprobado',
    });
    assert.strictEqual(r.ok, true);
    assert.strictEqual(r.datos.rol, undefined, 'un campo no declarado no puede viajar al documento');
    assert.strictEqual(r.datos.estado, undefined);
  });

  it('marca como trampa el honeypot relleno, sin delatar que se detecto', () => {
    const r = validarSolicitud({
      tipo: 'contacto',
      nombre: 'Ana',
      correo: 'a@b.co',
      mensaje: 'x',
      sitio_web: 'http://spam.example',
    });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.motivo, 'honeypot');
    assert.strictEqual(r.silencioso, true, 'al bot se le responde exito para no ensenarle el filtro');
  });
});

// --- origen -----------------------------------------------------------------

describe('solicitudesLanding / origenPermitido', () => {
  it('acepta el dominio de la landing y el localhost del desarrollo', () => {
    assert.strictEqual(origenPermitido('https://autodoc.app'), true);
    assert.strictEqual(origenPermitido('http://localhost:3000'), true);
  });

  it('no acepta un origen cualquiera', () => {
    assert.strictEqual(origenPermitido('https://phishing.example'), false);
  });
});

// --- manejador --------------------------------------------------------------

describe('solicitudesLanding / manejador HTTP', () => {
  it('persiste la solicitud valida y responde ok', async () => {
    const db = fakeDb();
    const res = fakeRes();
    await crearManejador(opciones(db))(fakeReq(), res);

    assert.strictEqual(res.codigo, 200);
    assert.deepStrictEqual(res.cuerpo, { ok: true });
    assert.strictEqual(db.escritos.length, 1);

    const doc = db.escritos[0].datos;
    assert.strictEqual(db.escritos[0].coleccion, 'solicitudes_landing');
    assert.strictEqual(doc.tipo, 'contacto');
    assert.strictEqual(doc.correo, 'ana@example.com');
    assert.strictEqual(doc.estado, 'nueva');
    assert.strictEqual(doc.origen, 'landing_web');
  });

  it('guarda la IP hasheada, nunca la IP', async () => {
    const db = fakeDb();
    await crearManejador(opciones(db))(fakeReq(), fakeRes());

    const doc = db.escritos[0].datos;
    assert.ok(doc.ip_hash, 'hace falta un identificador para el limitador');
    assert.ok(!JSON.stringify(doc).includes('203.0.113.9'), 'la IP en claro no se persiste');
  });

  it('responde 405 a un metodo que no sea POST', async () => {
    const db = fakeDb();
    const res = fakeRes();
    await crearManejador(opciones(db))(fakeReq({ method: 'GET' }), res);

    assert.strictEqual(res.codigo, 405);
    assert.strictEqual(db.escritos.length, 0);
  });

  it('contesta el preflight sin tocar la base', async () => {
    const db = fakeDb();
    const res = fakeRes();
    await crearManejador(opciones(db))(fakeReq({ method: 'OPTIONS' }), res);

    assert.strictEqual(res.codigo, 204);
    assert.strictEqual(res.cabeceras['Access-Control-Allow-Origin'], 'https://autodoc.app');
    assert.strictEqual(db.escritos.length, 0);
  });

  it('no responde CORS a un origen ajeno', async () => {
    const db = fakeDb();
    const res = fakeRes();
    await crearManejador(opciones(db))(
      fakeReq({ headers: { origin: 'https://phishing.example' } }),
      res
    );

    assert.strictEqual(res.cabeceras['Access-Control-Allow-Origin'], undefined);
    assert.strictEqual(res.codigo, 403);
    assert.strictEqual(db.escritos.length, 0);
  });

  it('devuelve 400 generico ante datos invalidos, sin decir que campo fallo', async () => {
    const db = fakeDb();
    const res = fakeRes();
    await crearManejador(opciones(db))(
      fakeReq({ body: { tipo: 'contacto', nombre: '', correo: 'no-es-correo', mensaje: '' } }),
      res
    );

    assert.strictEqual(res.codigo, 400);
    assert.deepStrictEqual(res.cuerpo, { ok: false, error: 'datos_invalidos' });
    assert.strictEqual(db.escritos.length, 0);
  });

  it('al bot del honeypot le responde exito y no guarda nada', async () => {
    const db = fakeDb();
    const res = fakeRes();
    await crearManejador(opciones(db))(
      fakeReq({
        body: {
          tipo: 'contacto',
          nombre: 'Bot',
          correo: 'bot@spam.example',
          mensaje: 'compra esto',
          sitio_web: 'http://spam.example',
        },
      }),
      res
    );

    assert.strictEqual(res.codigo, 200);
    assert.deepStrictEqual(res.cuerpo, { ok: true }, 'misma respuesta que un envio bueno');
    assert.strictEqual(db.escritos.length, 0, 'pero no llega a la coleccion');
  });

  it('corta al superar el limite por ventana desde la misma IP', async () => {
    const db = fakeDb();
    const manejador = crearManejador(opciones(db));

    for (let i = 0; i < LIMITE_POR_VENTANA; i++) {
      const res = fakeRes();
      await manejador(fakeReq(), res);
      assert.strictEqual(res.codigo, 200, 'el envio ' + (i + 1) + ' debia pasar');
    }

    const res = fakeRes();
    await manejador(fakeReq(), res);
    assert.strictEqual(res.codigo, 429);
    assert.deepStrictEqual(res.cuerpo, { ok: false, error: 'demasiadas_solicitudes' });
    assert.strictEqual(db.escritos.length, LIMITE_POR_VENTANA, 'el excedente no se persiste');
  });

  it('otra IP no arrastra el limite de la primera', async () => {
    const db = fakeDb();
    const manejador = crearManejador(opciones(db));

    for (let i = 0; i < LIMITE_POR_VENTANA; i++) {
      await manejador(fakeReq(), fakeRes());
    }

    const res = fakeRes();
    await manejador(fakeReq({ ip: '198.51.100.4' }), res);
    assert.strictEqual(res.codigo, 200);
  });

  // El hallazgo que levantaron los dos revisores: con `X-Forwarded-For` leido
  // por el primer elemento, quien llama elige su propio cubo y el cupo no se
  // toca jamas. Es el test que convierte el limitador en algo real.
  it('falsificar X-Forwarded-For no da un cupo nuevo', async () => {
    const db = fakeDb();
    const manejador = crearManejador(opciones(db));

    // La cabecera llega como `<lo que mando el cliente>, <IP real>, <GFE>`.
    const conIpFalsa = (n) =>
      fakeReq({
        headers: {
          origin: 'https://autodoc.app',
          'x-forwarded-for': `10.0.0.${n}, 203.0.113.9, 130.211.0.1`,
        },
      });

    for (let i = 0; i < LIMITE_POR_VENTANA; i++) {
      const res = fakeRes();
      await manejador(conIpFalsa(i), res);
      assert.strictEqual(res.codigo, 200);
    }

    const res = fakeRes();
    await manejador(conIpFalsa(999), res);
    assert.strictEqual(
      res.codigo,
      429,
      'el cupo lo fija la IP real, no la que el cliente escribe delante'
    );
  });

  it('con la cadena de un solo elemento, ese elemento es la IP', async () => {
    const db = fakeDb();
    const manejador = crearManejador(opciones(db));
    const req = (ip) =>
      fakeReq({ headers: { origin: 'https://autodoc.app', 'x-forwarded-for': ip } });

    for (let i = 0; i < LIMITE_POR_VENTANA; i++) {
      await manejador(req('198.51.100.7'), fakeRes());
    }

    const mismaIp = fakeRes();
    await manejador(req('198.51.100.7'), mismaIp);
    assert.strictEqual(mismaIp.codigo, 429);

    const otraIp = fakeRes();
    await manejador(req('198.51.100.8'), otraIp);
    assert.strictEqual(otraIp.codigo, 200);
  });

  it('un fallo de Firestore responde 503 con CORS, no tumba la instancia', async () => {
    const db = fakeDb();
    db.runTransaction = () => Promise.reject(new Error('UNAVAILABLE'));

    const res = fakeRes();
    // La promesa NO debe rechazar: un rechazo suelto aqui es lo que el runtime
    // convierte en "unhandled rejection" y hace que mate el contenedor,
    // escribiendo ademas su error sobre la respuesta de otra peticion.
    await crearManejador(opciones(db))(fakeReq(), res);

    assert.strictEqual(res.codigo, 503);
    assert.deepStrictEqual(res.cuerpo, { ok: false, error: 'no_disponible' });
    assert.strictEqual(
      res.cabeceras['Access-Control-Allow-Origin'],
      'https://autodoc.app',
      'sin CORS el navegador ve un error opaco en vez del fallo real'
    );
  });

  it('pasada la ventana, la misma IP vuelve a poder escribir', async () => {
    const db = fakeDb();
    const inicio = 1757000000000;
    const manejador = crearManejador(opciones(db, inicio));

    for (let i = 0; i < LIMITE_POR_VENTANA; i++) {
      await manejador(fakeReq(), fakeRes());
    }

    let ahora = inicio;
    const conReloj = crearManejador({
      db,
      ahora: () => ahora,
      timestamp: () => 'SERVER_TIMESTAMP',
    });
    ahora = inicio + 61 * 60 * 1000;

    const res = fakeRes();
    await conReloj(fakeReq(), res);
    assert.strictEqual(res.codigo, 200);
  });
});
