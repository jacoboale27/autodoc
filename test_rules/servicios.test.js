const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedVehiculo = (id, propietario, vinculados = []) => seed(env, async (s) => {
  await s.collection('vehiculos').doc(id).set({
    id_vehiculo: id, id_propietario: propietario, placa: 'P-1',
    talleres_vinculados: vinculados,
  });
});

// Hallazgo CRITICO C1 (revision adversarial de Fase C): la regla de create
// de 'servicios' no comprobaba ninguna relacion con id_vehiculo, permitiendo
// a cualquier mecanico autovincularse a cualquier vehiculo (el trigger
// requestReviewOnServiceComplete traduce la creacion en un
// talleres_vinculados permanente). La mitigacion aplicada aqui NO exige una
// reserva/cotizacion aceptada (no existe ese vinculo en el modelo de datos
// actual, ver informe de la Fase C) pero SI evita que un vehiculo YA
// vinculado a un taller pueda ser secuestrado por uno distinto.
describe('servicios: create (mitigacion parcial C1)', () => {
  test('un taller SI puede crear el primer servicio de un vehiculo sin vincular (walk-in)', async () => {
    await seedVehiculo('v1', UIDS.owner1);
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('servicios').add({
        id_vehiculo: 'v1', id_taller: UIDS.taller1, tipo_servicio: 'Cambio de aceite',
      }),
    );
  });

  test('un taller vinculado SI puede seguir registrando servicios sobre el mismo vehiculo', async () => {
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('servicios').add({
        id_vehiculo: 'v1', id_taller: UIDS.taller1, tipo_servicio: 'Revision',
      }),
    );
  });

  test('un taller NO puede autovincularse a un vehiculo YA vinculado a otro taller', async () => {
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('servicios').add({
        id_vehiculo: 'v1', id_taller: UIDS.taller2, tipo_servicio: 'Servicio no autorizado',
      }),
    );
  });

  test('un taller NO puede crear un servicio suplantando el id_taller de otro', async () => {
    await seedVehiculo('v1', UIDS.owner1);
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('servicios').add({
        id_vehiculo: 'v1', id_taller: UIDS.taller2, tipo_servicio: 'Cambio de aceite',
      }),
    );
  });

  test('un taller NO puede crear un servicio para un vehiculo inexistente', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('servicios').add({
        id_vehiculo: 'no-existe', id_taller: UIDS.taller1, tipo_servicio: 'Cambio de aceite',
      }),
    );
  });

  test('un administrador SI puede crear un servicio para cualquier vehiculo', async () => {
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(
      db.collection('servicios').add({
        id_vehiculo: 'v1', id_taller: UIDS.taller2, tipo_servicio: 'Ajuste administrativo',
      }),
    );
  });
});
