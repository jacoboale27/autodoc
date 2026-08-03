const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedVehiculo = (id, propietario, vinculados = [], sharedWith = []) => async (s) => {
  await s.collection('vehiculos').doc(id).set({
    id_vehiculo: id,
    id_propietario: propietario,
    placa: 'P-' + id,
    marca: 'AUDI',
    modelo: 'A3',
    anio: 2023,
    talleres_vinculados: vinculados,
    shared_with: sharedWith,
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

  // Cierre C1: confirmacion del propietario para talleres_vinculados/taller_pendiente_confirmacion
  test('un taller vinculado NO puede escribir talleres_vinculados directamente', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertFails(
      db.collection('vehiculos').doc('v-vinc').update({
        talleres_vinculados: [UIDS.taller1, UIDS.taller2],
      }),
    );
  });

  test('un taller vinculado NO puede escribir taller_pendiente_confirmacion directamente', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertFails(
      db.collection('vehiculos').doc('v-vinc').update({
        taller_pendiente_confirmacion: UIDS.taller1,
      }),
    );
  });

  test('el propietario SI puede confirmar el vinculo de un taller pendiente', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-pend').set({
        id_vehiculo: 'v-pend',
        id_propietario: UIDS.owner1,
        placa: 'P-v-pend',
        talleres_vinculados: [],
        taller_pendiente_confirmacion: UIDS.taller1,
      });
    });
    await assertSucceeds(
      db.collection('vehiculos').doc('v-pend').update({
        talleres_vinculados: [UIDS.taller1],
        taller_pendiente_confirmacion: null,
      }),
    );
  });

  test('el propietario SI puede rechazar el vinculo de un taller pendiente', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-pend').set({
        id_vehiculo: 'v-pend',
        id_propietario: UIDS.owner1,
        placa: 'P-v-pend',
        talleres_vinculados: [],
        taller_pendiente_confirmacion: UIDS.taller1,
      });
    });
    await assertSucceeds(
      db.collection('vehiculos').doc('v-pend').update({
        taller_pendiente_confirmacion: null,
      }),
    );
  });

  // Cierre I-1 (revision adversarial de la tarea C1): talleres_rechazados
  // debe tener la misma proteccion de escritura que talleres_vinculados/
  // taller_pendiente_confirmacion -- el mecanico no puede manipularlo (por
  // ejemplo, para borrarse a si mismo de la lista de rechazados y forzar
  // un reintento), solo el propietario.
  test('un taller vinculado NO puede escribir talleres_rechazados directamente', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertFails(
      db.collection('vehiculos').doc('v-vinc').update({
        talleres_rechazados: [],
      }),
    );
  });

  test('el propietario SI puede registrar un taller como rechazado', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-pend').set({
        id_vehiculo: 'v-pend',
        id_propietario: UIDS.owner1,
        placa: 'P-v-pend',
        talleres_vinculados: [],
        taller_pendiente_confirmacion: UIDS.taller1,
        taller_pendiente_nombre: 'Taller Uno',
        taller_pendiente_servicio_id: 'serv-1',
        talleres_rechazados: [],
      });
    });
    await assertSucceeds(
      db.collection('vehiculos').doc('v-pend').update({
        taller_pendiente_confirmacion: null,
        taller_pendiente_nombre: null,
        taller_pendiente_servicio_id: null,
        talleres_rechazados: [UIDS.taller1],
      }),
    );
  });

  test('un usuario en shared_with SI puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, seedVehiculo('v-compartido', UIDS.owner1, [], [UIDS.owner2]));
    await assertSucceeds(db.collection('vehiculos').doc('v-compartido').get());
  });

  test('un usuario que NO esta en shared_with NO puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, seedVehiculo('v-no-compartido', UIDS.owner1, [], []));
    await assertFails(db.collection('vehiculos').doc('v-no-compartido').get());
  });

  test('un usuario en shared_with NO puede actualizar el vehiculo', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, seedVehiculo('v-compartido', UIDS.owner1, [], [UIDS.owner2]));
    await assertFails(
      db.collection('vehiculos').doc('v-compartido').update({ placa: 'ROBADA' }),
    );
  });
});
