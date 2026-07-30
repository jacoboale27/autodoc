const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedVehiculo = (id, propietario, vinculados = []) => async (s) => {
  await s.collection('vehiculos').doc(id).set({
    id_vehiculo: id,
    id_propietario: propietario,
    placa: 'P-' + id,
    marca: 'AUDI',
    modelo: 'A3',
    anio: 2023,
    talleres_vinculados: vinculados,
  });
};

describe('vehiculos', () => {
  test('un propietario NO puede listar todos los vehiculos', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner2));
    await assertFails(db.collection('vehiculos').get());
  });

  test('un propietario NO puede leer el vehiculo de otro', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner2));
    await assertFails(db.collection('vehiculos').doc('v-ajeno').get());
  });

  test('un propietario SI puede leer su propio vehiculo', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-mio', UIDS.owner1));
    await assertSucceeds(db.collection('vehiculos').doc('v-mio').get());
  });

  test('un propietario SI puede listar filtrando por su propio id', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-mio', UIDS.owner1));
    await assertSucceeds(
      db.collection('vehiculos').where('id_propietario', '==', UIDS.owner1).get(),
    );
  });

  test('un taller NO vinculado NO puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner1, []));
    await assertFails(db.collection('vehiculos').doc('v-ajeno').get());
  });

  test('un taller vinculado SI puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertSucceeds(db.collection('vehiculos').doc('v-vinc').get());
  });

  test('un taller vinculado solo puede actualizar kilometraje_actual', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertSucceeds(
      db.collection('vehiculos').doc('v-vinc').update({ kilometraje_actual: 5000 }),
    );
    await assertFails(db.collection('vehiculos').doc('v-vinc').update({ placa: 'ROBADA' }));
  });

  test('sin autenticar NO se puede leer vehiculos', async () => {
    await seed(env, seedVehiculo('v1', UIDS.owner1));
    await assertFails(anon(env).collection('vehiculos').get());
  });
});
