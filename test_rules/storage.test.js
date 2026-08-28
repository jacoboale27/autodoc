const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, UIDS } = require('./helpers');

let env;
// 30 s y no los 5 s por defecto de Jest: el emulador de Storage tarda bastante
// mas que el de Firestore en aceptar la carga inicial de reglas en un arranque
// en frio, y con el default toda la suite moria en "Exceeded timeout of 5000 ms
// for a hook" antes de ejecutar un solo test.
beforeAll(async () => { env = await makeEnv(); }, 30000);
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearStorage(); await env.clearFirestore(); }, 30000);

const imagen = (kb) => Buffer.alloc(kb * 1024, 1);
const META_JPEG = { contentType: 'image/jpeg' };

const seedUsuario = (uid, rol) => seed(env, async (db) => {
  await db.collection('usuarios').doc(uid).set({ id_usuario: uid, rol, estado: 'activo' });
});

const seedVehiculo = (id, propietario, vinculados = []) => seed(env, async (db) => {
  await db.collection('vehiculos').doc(id).set({
    id_vehiculo: id, id_propietario: propietario, talleres_vinculados: vinculados,
  });
});

describe('storage: limites', () => {
  test('rechaza una subida por encima de 5 MB', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref(`perfiles/${UIDS.owner1}.jpg`).put(imagen(6 * 1024), META_JPEG),
    );
  });

  test('acepta una imagen pequena', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(
      st.ref(`perfiles/${UIDS.owner1}.jpg`).put(imagen(200), META_JPEG),
    );
  });

  test('rechaza un contentType que no sea imagen', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref(`perfiles/${UIDS.owner1}.jpg`).put(imagen(10), { contentType: 'text/html' }),
    );
    await assertFails(
      st.ref(`perfiles/${UIDS.owner1}.jpg`).put(imagen(10), { contentType: 'image/svg+xml' }),
    );
  });

  test('acepta PNG y WebP en la foto de perfil', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(
      st.ref(`perfiles/${UIDS.owner1}.png`).put(imagen(50), { contentType: 'image/png' }),
    );
    await assertSucceeds(
      st.ref(`perfiles/${UIDS.owner1}.webp`).put(imagen(50), { contentType: 'image/webp' }),
    );
  });
});

describe('storage: aislamiento de facturas', () => {
  test('un taller NO vinculado NO puede leer facturas ajenas', async () => {
    await seedUsuario(UIDS.taller2, 'Taller');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller2).storage();
    await assertFails(st.ref('facturas/v1/f.jpg').getDownloadURL());
  });

  test('un taller NO vinculado NO puede SOBRESCRIBIR facturas ajenas', async () => {
    await seedUsuario(UIDS.taller2, 'Taller');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller2).storage();
    await assertFails(st.ref('facturas/v1/f.jpg').put(imagen(10), META_JPEG));
  });

  test('el propietario del vehiculo SI puede subir su factura', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(st.ref('facturas/v1/f.jpg').put(imagen(100), META_JPEG));
  });

  test('un taller vinculado SI puede subir la factura del servicio', async () => {
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertSucceeds(st.ref('facturas/v1/f.jpg').put(imagen(100), META_JPEG));
  });

  test('un usuario cualquiera NO puede leer fotos de vehiculos ajenos', async () => {
    await seedUsuario(UIDS.owner2, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    const st = env.authenticatedContext(UIDS.owner2).storage();
    await assertFails(st.ref('vehiculos/v1/foto.jpg').getDownloadURL());
  });

  // I3: esImagenValida() (Tarea 10) bloqueaba PDF en TODA ruta, incluida
  // facturas/, pero la app soporta explicitamente adjuntar la factura como
  // PDF (invoice_upload_service.dart, initiate_service_screen.dart).
  test('el propietario del vehiculo SI puede subir una factura en PDF', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(
      st.ref('facturas/v1/f.pdf').put(imagen(100), { contentType: 'application/pdf' }),
    );
  });

  test('un taller vinculado SI puede subir la factura del servicio en PDF', async () => {
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertSucceeds(
      st.ref('facturas/v1/f.pdf').put(imagen(100), { contentType: 'application/pdf' }),
    );
  });

  test('sigue rechazando tipos peligrosos en facturas (SVG/HTML)', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref('facturas/v1/f.svg').put(imagen(10), { contentType: 'image/svg+xml' }),
    );
    await assertFails(
      st.ref('facturas/v1/f.html').put(imagen(10), { contentType: 'text/html' }),
    );
  });
});

describe('storage: fotos de resenias', () => {
  const seedServicio = (id, vehiculoId, tallerId) => seed(env, async (db) => {
    await db.collection('servicios').doc(id).set({
      id_vehiculo: vehiculoId,
      id_taller: tallerId,
      estado: 'finalizado',
    });
  });

  test('el propietario del vehiculo del servicio SI puede subir una foto valida', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    await seedServicio('s1', 'v1', UIDS.taller1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(
      st.ref('resenia_fotos/s1/foto1.jpg').put(imagen(200), META_JPEG),
    );
  });

  test('un usuario que NO es propietario del vehiculo del servicio NO puede subir fotos', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.owner2, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    await seedServicio('s1', 'v1', UIDS.taller1);
    const st = env.authenticatedContext(UIDS.owner2).storage();
    await assertFails(
      st.ref('resenia_fotos/s1/foto1.jpg').put(imagen(200), META_JPEG),
    );
  });

  test('rechaza subir fotos a un servicio inexistente', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref('resenia_fotos/no-existe/foto1.jpg').put(imagen(200), META_JPEG),
    );
  });

  test('rechaza tipos peligrosos en fotos de resenias (SVG/HTML)', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    await seedServicio('s1', 'v1', UIDS.taller1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref('resenia_fotos/s1/foto1.svg').put(imagen(10), { contentType: 'image/svg+xml' }),
    );
  });

  test('cualquier usuario autenticado puede leer fotos de resenias', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.owner2, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    await seedServicio('s1', 'v1', UIDS.taller1);
    await seed(env, async () => {
      await env.authenticatedContext(UIDS.owner1).storage()
        .ref('resenia_fotos/s1/foto1.jpg').put(imagen(200), META_JPEG);
    });
    const st = env.authenticatedContext(UIDS.owner2).storage();
    await assertSucceeds(st.ref('resenia_fotos/s1/foto1.jpg').getDownloadURL());
  });

  test('un usuario NO admin no puede borrar fotos de resenias', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    await seedServicio('s1', 'v1', UIDS.taller1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await st.ref('resenia_fotos/s1/foto1.jpg').put(imagen(200), META_JPEG);
    await assertFails(st.ref('resenia_fotos/s1/foto1.jpg').delete());
  });

  test('el admin SI puede borrar fotos de resenias', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.admin, 'Administrador');
    await seedVehiculo('v1', UIDS.owner1);
    await seedServicio('s1', 'v1', UIDS.taller1);
    const owner = env.authenticatedContext(UIDS.owner1).storage();
    await owner.ref('resenia_fotos/s1/foto1.jpg').put(imagen(200), META_JPEG);
    const admin = env.authenticatedContext(UIDS.admin).storage();
    await assertSucceeds(admin.ref('resenia_fotos/s1/foto1.jpg').delete());
  });
});

describe('storage: notas de voz de chat (chat_audios)', () => {
  const META_AUDIO = { contentType: 'audio/aac' };

  const seedConversacion = (id, propietario, mecanico) => seed(env, async (db) => {
    await db.collection('conversaciones').doc(id).set({
      id,
      id_propietario: propietario,
      id_mecanico: mecanico,
    });
  });

  test('un participante (propietario) SI puede subir una nota de voz valida', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedConversacion('c1', UIDS.owner1, UIDS.taller1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(
      st.ref('chat_audios/c1/audio1.m4a').put(imagen(100), META_AUDIO),
    );
  });

  test('un participante (mecanico) SI puede subir una nota de voz valida', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedConversacion('c1', UIDS.owner1, UIDS.taller1);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertSucceeds(
      st.ref('chat_audios/c1/audio1.m4a').put(imagen(100), META_AUDIO),
    );
  });

  test('un usuario que NO es participante de la conversacion NO puede subir', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedUsuario(UIDS.owner2, 'Propietario');
    await seedConversacion('c1', UIDS.owner1, UIDS.taller1);
    const st = env.authenticatedContext(UIDS.owner2).storage();
    await assertFails(
      st.ref('chat_audios/c1/audio1.m4a').put(imagen(100), META_AUDIO),
    );
  });

  test('rechaza subir audio a una conversacion inexistente', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref('chat_audios/no-existe/audio1.m4a').put(imagen(100), META_AUDIO),
    );
  });

  test('rechaza un contentType que no sea de audio', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedConversacion('c1', UIDS.owner1, UIDS.taller1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref('chat_audios/c1/audio1.m4a').put(imagen(100), { contentType: 'text/html' }),
    );
  });

  test('rechaza una nota de voz por encima de 10 MB', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedConversacion('c1', UIDS.owner1, UIDS.taller1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref('chat_audios/c1/audio1.m4a').put(imagen(11 * 1024), META_AUDIO),
    );
  });

  test('un participante SI puede leer la nota de voz', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedConversacion('c1', UIDS.owner1, UIDS.taller1);
    await seed(env, async () => {
      await env.authenticatedContext(UIDS.owner1).storage()
        .ref('chat_audios/c1/audio1.m4a').put(imagen(100), META_AUDIO);
    });
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertSucceeds(st.ref('chat_audios/c1/audio1.m4a').getDownloadURL());
  });

  test('un usuario que NO es participante NO puede leer la nota de voz', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedUsuario(UIDS.owner2, 'Propietario');
    await seedConversacion('c1', UIDS.owner1, UIDS.taller1);
    await seed(env, async () => {
      await env.authenticatedContext(UIDS.owner1).storage()
        .ref('chat_audios/c1/audio1.m4a').put(imagen(100), META_AUDIO);
    });
    const st = env.authenticatedContext(UIDS.owner2).storage();
    await assertFails(st.ref('chat_audios/c1/audio1.m4a').getDownloadURL());
  });

  test('el admin SI puede leer la nota de voz aunque no sea participante', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedUsuario(UIDS.admin, 'Administrador');
    await seedConversacion('c1', UIDS.owner1, UIDS.taller1);
    await seed(env, async () => {
      await env.authenticatedContext(UIDS.owner1).storage()
        .ref('chat_audios/c1/audio1.m4a').put(imagen(100), META_AUDIO);
    });
    const st = env.authenticatedContext(UIDS.admin).storage();
    await assertSucceeds(st.ref('chat_audios/c1/audio1.m4a').getDownloadURL());
  });
});

// Galeria de fotos del vehiculo: VehiclePhotoService.addPhoto sube a
// `vehiculos/{vehicleId}/fotos/{uuid}.jpg`, DOS segmentos bajo el vehiculo.
// El match usaba {fileName} (un solo segmento), asi que esa ruta no casaba
// con ninguna regla y toda subida moria en permission-denied.
describe('storage: galeria de fotos del vehiculo (ruta anidada)', () => {
  test('el propietario SI puede subir a vehiculos/{id}/fotos/{archivo}', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(st.ref('vehiculos/v1/fotos/abc.jpg').put(imagen(120), META_JPEG));
  });

  test('el propietario SI sigue pudiendo subir a la raiz del vehiculo', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(st.ref('vehiculos/v1/portada.jpg').put(imagen(120), META_JPEG));
  });

  test('un tercero NO puede subir a la galeria de un vehiculo ajeno', async () => {
    await seedUsuario(UIDS.owner2, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    const st = env.authenticatedContext(UIDS.owner2).storage();
    await assertFails(st.ref('vehiculos/v1/fotos/abc.jpg').put(imagen(120), META_JPEG));
  });

  test('la galeria sigue rechazando ficheros que no son imagen', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref('vehiculos/v1/fotos/abc.html').put(imagen(10), { contentType: 'text/html' }),
    );
  });

  test('la galeria sigue rechazando subidas por encima de 5 MB', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(st.ref('vehiculos/v1/fotos/big.jpg').put(imagen(6 * 1024), META_JPEG));
  });
});

describe('storage: evidencia de verificacion de taller', () => {
  const PDF = { contentType: 'application/pdf' };

  test('un taller sube su fachada aunque NO este aprobado', async () => {
    // Es el punto entero del bloque: el expediente se sube precisamente cuando
    // la cuenta sigue pendiente. Exigir aprobacion aqui haria imposible
    // llegar nunca a estar aprobado.
    await seedUsuario(UIDS.taller1, 'Taller');
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertSucceeds(
      st.ref(`verificaciones/${UIDS.taller1}/fachada.jpg`).put(imagen(100), META_JPEG),
    );
  });

  test('el PDF vale para el NIT pero no para una foto', async () => {
    await seedUsuario(UIDS.taller1, 'Taller');
    const st = env.authenticatedContext(UIDS.taller1).storage();

    await assertSucceeds(
      st.ref(`verificaciones/${UIDS.taller1}/nit.pdf`).put(imagen(50), PDF),
    );
    await assertFails(
      st.ref(`verificaciones/${UIDS.taller1}/fachada.pdf`).put(imagen(50), PDF),
    );
  });

  test('solo pasan los tres nombres de slot', async () => {
    // Las reglas de Storage no pueden CONTAR archivos: el whitelist de
    // nombres es lo unico que impide que una cuenta ni siquiera aprobada
    // suba objetos ilimitados de 5 MB al bucket.
    await seedUsuario(UIDS.taller1, 'Taller');
    const st = env.authenticatedContext(UIDS.taller1).storage();

    for (const nombre of ['otra.jpg', 'fachada2.jpg', 'fachada.jpg.exe', 'nit.svg']) {
      await assertFails(
        st.ref(`verificaciones/${UIDS.taller1}/${nombre}`).put(imagen(10), META_JPEG),
      );
    }
  });

  test('un SVG disfrazado de foto no pasa', async () => {
    await seedUsuario(UIDS.taller1, 'Taller');
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref(`verificaciones/${UIDS.taller1}/fachada.jpg`)
        .put(imagen(10), { contentType: 'image/svg+xml' }),
    );
  });

  test('no se sube al expediente de otro taller', async () => {
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedUsuario(UIDS.taller2, 'Taller');
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref(`verificaciones/${UIDS.taller2}/fachada.jpg`).put(imagen(10), META_JPEG),
    );
  });

  test('un propietario cualquiera no se inventa un expediente', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref(`verificaciones/${UIDS.owner1}/fachada.jpg`).put(imagen(10), META_JPEG),
    );
  });

  test('la evidencia no es legible por terceros ni por anonimos', async () => {
    // A diferencia de perfiles/ o resenia_fotos/, aqui NO vale "cualquier
    // autenticado": un NIT identifica al negocio.
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedUsuario(UIDS.taller2, 'Taller');
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedUsuario(UIDS.admin, 'Administrador');

    const ruta = `verificaciones/${UIDS.taller1}/nit.jpg`;
    await env.authenticatedContext(UIDS.taller1).storage()
      .ref(ruta).put(imagen(10), META_JPEG);

    await assertSucceeds(
      env.authenticatedContext(UIDS.taller1).storage().ref(ruta).getDownloadURL(),
    );
    await assertSucceeds(
      env.authenticatedContext(UIDS.admin).storage().ref(ruta).getDownloadURL(),
    );
    for (const uid of [UIDS.taller2, UIDS.owner1]) {
      await assertFails(
        env.authenticatedContext(uid).storage().ref(ruta).getDownloadURL(),
      );
    }
    await assertFails(
      env.unauthenticatedContext().storage().ref(ruta).getDownloadURL(),
    );
  });

  test('solo un admin borra la evidencia; el taller corrige sobrescribiendo', async () => {
    // La evidencia es el rastro de por que se aprobo un taller. Si el propio
    // taller pudiera borrarla, bastaria con aprobarse y limpiar detras.
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedUsuario(UIDS.admin, 'Administrador');
    const ruta = `verificaciones/${UIDS.taller1}/fachada.jpg`;
    const st = env.authenticatedContext(UIDS.taller1).storage();

    await st.ref(ruta).put(imagen(10), META_JPEG);
    await assertSucceeds(st.ref(ruta).put(imagen(20), META_JPEG));
    await assertFails(st.ref(ruta).delete());
    await assertSucceeds(
      env.authenticatedContext(UIDS.admin).storage().ref(ruta).delete(),
    );
  });
});

describe('storage: galeria comercial del taller', () => {
  test('un taller APROBADO publica su logo y fotos del local', async () => {
    await seedUsuario(UIDS.taller1, 'Taller');
    const st = env.authenticatedContext(UIDS.taller1).storage();

    await assertSucceeds(
      st.ref(`talleres_fotos/${UIDS.taller1}/logo.jpg`).put(imagen(100), META_JPEG),
    );
    await assertSucceeds(
      st.ref(`talleres_fotos/${UIDS.taller1}/local-3.webp`)
        .put(imagen(100), { contentType: 'image/webp' }),
    );
  });

  test('un taller PENDIENTE no publica nada', async () => {
    // isMecanico() de storage.rules mira `rol` pero no `estado`. Esa asimetria
    // es correcta para el expediente de verificacion; aqui seria un agujero:
    // cualquiera que se registre como taller publicaria imagenes en una ruta
    // de lectura publica sin que nadie lo hubiera mirado.
    await seed(env, async (db) => {
      await db.collection('usuarios').doc(UIDS.taller1).set({
        id_usuario: UIDS.taller1, rol: 'Taller', estado: 'pendiente',
      });
    });
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref(`talleres_fotos/${UIDS.taller1}/logo.jpg`).put(imagen(10), META_JPEG),
    );
  });

  test('un taller suspendido tampoco', async () => {
    await seed(env, async (db) => {
      await db.collection('usuarios').doc(UIDS.taller1).set({
        id_usuario: UIDS.taller1, rol: 'Taller', estado: 'suspendido',
      });
    });
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref(`talleres_fotos/${UIDS.taller1}/logo.jpg`).put(imagen(10), META_JPEG),
    );
  });

  test('solo pasan los seis huecos: 1 logo + 5 fotos del local', async () => {
    await seedUsuario(UIDS.taller1, 'Taller');
    const st = env.authenticatedContext(UIDS.taller1).storage();

    for (const nombre of ['local-0.jpg', 'local-6.jpg', 'local-10.jpg', 'otra.jpg', 'logo.pdf', 'logo.jpg.exe']) {
      await assertFails(
        st.ref(`talleres_fotos/${UIDS.taller1}/${nombre}`).put(imagen(10), META_JPEG),
      );
    }
  });

  test('no se publica en la galeria de otro taller', async () => {
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedUsuario(UIDS.taller2, 'Taller');
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref(`talleres_fotos/${UIDS.taller2}/logo.jpg`).put(imagen(10), META_JPEG),
    );
  });

  test('la galeria SI es de lectura anonima, al reves que la evidencia', async () => {
    // Es escaparate: el directorio de talleres es publico (`talleres` es
    // `allow read: if true`), y unas fotos que exigieran login no se verian
    // en el sitio donde tienen sentido.
    await seedUsuario(UIDS.taller1, 'Taller');
    const ruta = `talleres_fotos/${UIDS.taller1}/logo.jpg`;
    await env.authenticatedContext(UIDS.taller1).storage()
      .ref(ruta).put(imagen(10), META_JPEG);

    await assertSucceeds(
      env.unauthenticatedContext().storage().ref(ruta).getDownloadURL(),
    );
  });

  test('el taller borra sus propias fotos, pero no las de otro', async () => {
    // A diferencia de la evidencia de verificacion, quitar la foto de un local
    // que ya no existe es gestion normal del negocio, no destruir un rastro.
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedUsuario(UIDS.taller2, 'Taller');
    const ruta1 = `talleres_fotos/${UIDS.taller1}/logo.jpg`;
    const ruta2 = `talleres_fotos/${UIDS.taller2}/logo.jpg`;
    await env.authenticatedContext(UIDS.taller1).storage().ref(ruta1).put(imagen(10), META_JPEG);
    await env.authenticatedContext(UIDS.taller2).storage().ref(ruta2).put(imagen(10), META_JPEG);

    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(st.ref(ruta2).delete());
    await assertSucceeds(st.ref(ruta1).delete());
  });
});
