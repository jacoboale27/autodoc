// test_rules/storage_nit.test.js
//
// VER-01: reglas de Storage para el slot `nit` de `verificaciones/{tallerId}`.
//
// Archivo NUEVO y separado de `storage.test.js` a proposito (otro agente es
// dueño de ese archivo en paralelo): cubre los tres casos que pide la tarea
// -PDF valido en el NIT, PDF denegado en otro slot, MIME falsificado
// denegado- sin tocar los tests ya existentes de esa suite.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, UIDS, limpiarStorage } = require('./helpers');

let env;
// Mismo motivo que en storage.test.js: el emulador de Storage tarda mas que
// el de Firestore en aceptar la carga inicial de reglas en frio.
beforeAll(async () => { env = await makeEnv(); }, 30000);
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await limpiarStorage(env); await env.clearFirestore(); }, 30000);

const bytes = (kb) => Buffer.alloc(kb * 1024, 1);
const PDF = { contentType: 'application/pdf' };
const JPEG = { contentType: 'image/jpeg' };

const seedTaller = (uid) => seed(env, async (db) => {
  await db.collection('usuarios').doc(uid).set({ id_usuario: uid, rol: 'Taller', estado: 'pendiente' });
});

describe('storage: NIT en PDF (VER-01)', () => {
  test('un PDF real permitido: nit.pdf con contentType application/pdf', async () => {
    await seedTaller(UIDS.taller1);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertSucceeds(
      st.ref(`verificaciones/${UIDS.taller1}/nit.pdf`).put(bytes(50), PDF),
    );
  });

  test('un PDF en OTRO slot (fachada) se deniega', async () => {
    await seedTaller(UIDS.taller1);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref(`verificaciones/${UIDS.taller1}/fachada.pdf`).put(bytes(50), PDF),
    );
  });

  test('un PDF en el slot rotulo tambien se deniega', async () => {
    await seedTaller(UIDS.taller1);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref(`verificaciones/${UIDS.taller1}/rotulo.pdf`).put(bytes(50), PDF),
    );
  });

  test('MIME falsificado: nit.pdf con contentType de imagen se deniega', async () => {
    // El nombre pide PDF pero la cabecera dice otra cosa: si las reglas solo
    // miraran "es un content-type de los permitidos" (imagen O pdf) sin
    // emparejarlo con la extension, esto colaria.
    await seedTaller(UIDS.taller1);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref(`verificaciones/${UIDS.taller1}/nit.pdf`).put(bytes(50), JPEG),
    );
  });

  test('MIME falsificado: nit.jpg con contentType application/pdf se deniega', async () => {
    // El caso inverso del anterior: extension de imagen, cabecera de PDF.
    await seedTaller(UIDS.taller1);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref(`verificaciones/${UIDS.taller1}/nit.jpg`).put(bytes(50), PDF),
    );
  });

  test('MIME falsificado: nit.pdf declarado como text/html se deniega', async () => {
    await seedTaller(UIDS.taller1);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref(`verificaciones/${UIDS.taller1}/nit.pdf`).put(bytes(10), { contentType: 'text/html' }),
    );
  });

  test('un PDF de nit sigue respetando el tope de 5 MB', async () => {
    await seedTaller(UIDS.taller1);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref(`verificaciones/${UIDS.taller1}/nit.pdf`).put(bytes(6 * 1024), PDF),
    );
  });

  test('el NIT como imagen (jpg) sigue funcionando: no se rompio nada al separar el pdf', async () => {
    await seedTaller(UIDS.taller1);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertSucceeds(
      st.ref(`verificaciones/${UIDS.taller1}/nit.jpg`).put(bytes(50), JPEG),
    );
  });
});
