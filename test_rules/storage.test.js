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
});
