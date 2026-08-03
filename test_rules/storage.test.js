const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearStorage(); await env.clearFirestore(); });

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
