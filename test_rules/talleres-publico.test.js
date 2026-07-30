const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

describe('datos legitimamente publicos', () => {
  test('el directorio de talleres SI es legible sin autenticar', async () => {
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).set({
        id_taller: UIDS.taller1, nombre: 'Taller Uno', especialidad: 'Motores',
        calificacion_promedio: 4.5, total_resenias: 2,
      });
    });
    await assertSucceeds(anon(env).collection('talleres').get());
  });

  test('talleres NO expone correo ni telefono personal', async () => {
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).set({
        id_taller: UIDS.taller1, nombre: 'Taller Uno', especialidad: 'Motores',
      });
    });
    const snap = await anon(env).collection('talleres').get();
    const campos = Object.keys(snap.docs[0].data());
    expect(campos).not.toContain('correo');
    expect(campos).not.toContain('telefono');
  });

  test('las resenias NO son legibles sin autenticar', async () => {
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1,
        estrellas: 5, comentario: 'Excelente',
      });
    });
    await assertFails(anon(env).collection('resenias').get());
  });

  test('un usuario autenticado SI puede leer resenias', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner2, id_taller: UIDS.taller1, estrellas: 4,
      });
    });
    await assertSucceeds(db.collection('resenias').get());
  });

  test('un usuario NO puede resenar un taller sin servicio previo', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('resenias').add({
        id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 1,
        comentario: 'resena falsa', id_servicio: 'no-existe',
      }),
    );
  });

  test('el autor NO puede reapuntar su resenia a otro taller', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 5,
      });
    });
    await assertFails(db.collection('resenias').doc('r1').update({ id_taller: UIDS.taller2 }));
  });
});
