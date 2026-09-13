const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// La frontera Administrador -> Superusuario no tenia ni un solo test, ni por
// el lado que permite ni por el que deniega: `allow delete: if isSuperUser()`
// sobre /usuarios y la clausula que impide a un Administrador repartir el rol
// 'Administrador'/'Superusuario' se estaban dando por buenas sin ejercerlas.
// Ambos predicados son isSuperUser(), que lee usuarios/{auth.uid}.rol y por
// tanto SI depende del rol persistido — al contrario que actuaPorTaller(),
// que es propiedad pura y habria pasado con cualquier cadena.
const seedVictima = async () => {
  await seed(env, async (s) => {
    await s.collection('usuarios').doc(UIDS.owner1).set({
      id_usuario: UIDS.owner1, correo: 'v@test.com', nombre_completo: 'Victima',
      rol: 'Propietario', estado: 'activo',
    });
  });
};

describe('matriz de roles: lo que solo puede el Superusuario', () => {
  test('el Superusuario SI puede ascender a otro usuario a Administrador', async () => {
    await seedVictima();
    const db = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertSucceeds(db.collection('usuarios').doc(UIDS.owner1).update({ rol: 'Administrador' }));
  });

  test('el Superusuario SI puede borrar la cuenta de otro usuario', async () => {
    await seedVictima();
    const db = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertSucceeds(db.collection('usuarios').doc(UIDS.owner1).delete());
  });

  test('un Administrador NO puede repartir el rol de Administrador', async () => {
    await seedVictima();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(db.collection('usuarios').doc(UIDS.owner1).update({ rol: 'Administrador' }));
  });

  test('un Administrador NO puede repartir el rol de Superusuario', async () => {
    await seedVictima();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(db.collection('usuarios').doc(UIDS.owner1).update({ rol: 'Superusuario' }));
  });

  test('un Administrador SI conserva la gestion de roles no privilegiados', async () => {
    await seedVictima();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(db.collection('usuarios').doc(UIDS.owner1).update({ rol: 'Mecanico' }));
  });

  test('un Administrador NO puede borrar una cuenta (hard delete es del Superusuario)', async () => {
    await seedVictima();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(db.collection('usuarios').doc(UIDS.owner1).delete());
  });

  test('un usuario NO puede borrar ni su propia cuenta', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(db.collection('usuarios').doc(UIDS.owner1).delete());
  });

  test('un Taller NO puede borrar la cuenta de otro', async () => {
    await seedVictima();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(db.collection('usuarios').doc(UIDS.owner1).delete());
  });

  // El Superusuario hereda los permisos de Administrador (isAdmin() incluye
  // 'Superusuario' en su lista), cosa que tampoco estaba ejercida.
  test('el Superusuario SI hereda la lectura de administrador sobre usuarios ajenos', async () => {
    await seedVictima();
    const db = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertSucceeds(db.collection('usuarios').doc(UIDS.owner1).get());
  });
});
