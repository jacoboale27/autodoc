const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// Cubre la subcoleccion 'talleres/{tallerId}/catalogo_servicios' (Tarea 9,
// CatalogoRepository). Igual que 'empleados' en la Tarea 8, esta
// subcoleccion necesita su propio match dentro de 'talleres/{tallerId}':
// sin el, CatalogoRepository.watchCatalogo()/agregarItem()/eliminarItem()
// recibirian PERMISSION_DENIED para todos.
describe('talleres/{tallerId}/catalogo_servicios', () => {
  test('cualquiera (incluso no autenticado) puede leer el catalogo publico de un taller', async () => {
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('catalogo_servicios').doc('item1').set({
        id_taller: UIDS.taller1,
        nombre: 'Cambio de aceite',
        precio: 25.0,
      });
    });
    const db = anon(env);
    await assertSucceeds(
      db.collection('talleres').doc(UIDS.taller1).collection('catalogo_servicios').get(),
    );
  });

  test('el dueño del taller SI puede crear un item en su propio catalogo', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('talleres').doc(UIDS.taller1).collection('catalogo_servicios').doc('item1').set({
        id_taller: UIDS.taller1,
        nombre: 'Cambio de aceite',
        precio: 25.0,
      }),
    );
  });

  test('el dueño del taller SI puede actualizar un item de su propio catalogo', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('catalogo_servicios').doc('item1').set({
        id_taller: UIDS.taller1,
        nombre: 'Cambio de aceite',
        precio: 25.0,
      });
    });
    await assertSucceeds(
      db.collection('talleres').doc(UIDS.taller1).collection('catalogo_servicios').doc('item1')
        .update({ precio: 30.0 }),
    );
  });

  test('el dueño del taller SI puede eliminar un item de su propio catalogo', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('catalogo_servicios').doc('item1').set({
        id_taller: UIDS.taller1,
        nombre: 'Cambio de aceite',
        precio: 25.0,
      });
    });
    await assertSucceeds(
      db.collection('talleres').doc(UIDS.taller1).collection('catalogo_servicios').doc('item1').delete(),
    );
  });

  test('un taller distinto NO puede crear un item en el catalogo de otro taller', async () => {
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).collection('catalogo_servicios').doc('item1').set({
        id_taller: UIDS.taller1,
        nombre: 'Intento ajeno',
        precio: 10.0,
      }),
    );
  });

  test('un taller distinto NO puede eliminar un item del catalogo de otro taller', async () => {
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('catalogo_servicios').doc('item1').set({
        id_taller: UIDS.taller1,
        nombre: 'Cambio de aceite',
        precio: 25.0,
      });
    });
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).collection('catalogo_servicios').doc('item1').delete(),
    );
  });

  test('un usuario no autenticado NO puede crear un item', async () => {
    const db = anon(env);
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).collection('catalogo_servicios').doc('item1').set({
        id_taller: UIDS.taller1,
        nombre: 'Intento anonimo',
        precio: 10.0,
      }),
    );
  });
});
