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

// Hallazgo Important (revision de la 2a ronda de Fase C, adyacente a C1): la
// regla de update de 'servicios' no restringia que campos se podian cambiar.
// Un taller podia crear un servicio legitimo en un vehiculo propio y luego,
// via update, reescribir id_vehiculo para apuntarlo al vehiculo de una
// victima, inyectando un registro de servicio falso en su historial.
describe('servicios: update (no se puede reescribir id_vehiculo/id_taller)', () => {
  const seedServicio = () => seed(env, async (s) => {
    await s.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1', talleres_vinculados: [UIDS.taller1],
    });
    await s.collection('vehiculos').doc('v2').set({
      id_vehiculo: 'v2', id_propietario: UIDS.owner2, placa: 'P-2', talleres_vinculados: [],
    });
    await s.collection('servicios').doc('s1').set({
      id_vehiculo: 'v1', id_taller: UIDS.taller1, tipo_servicio: 'Cambio de aceite', costo: 50,
    });
  });

  test('el taller dueño del servicio NO puede reescribir id_vehiculo', async () => {
    await seedServicio();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('servicios').doc('s1').update({ id_vehiculo: 'v2' }),
    );
  });

  test('el taller dueño del servicio NO puede reescribir id_taller', async () => {
    await seedServicio();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('servicios').doc('s1').update({ id_taller: UIDS.taller2 }),
    );
  });

  test('el taller dueño del servicio SI puede actualizar campos legitimos (costo, descripcion)', async () => {
    await seedServicio();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('servicios').doc('s1').update({ costo: 75, descripcion: 'Se agrego filtro' }),
    );
  });

  test('un administrador SI puede reescribir id_vehiculo', async () => {
    await seedServicio();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(
      db.collection('servicios').doc('s1').update({ id_vehiculo: 'v2' }),
    );
  });
});

// Servicio de mantenimiento registrado por el propio propietario
// (task_complete_screen.dart -> AlertProvider.userCompleteTask). Antes el
// `allow create` solo admitia admin o mecanico, asi que este flujo moria en
// permission-denied DESPUES de haber subido ya la factura a Storage, dejando
// el archivo huerfano y sin foto_factura_url en ningun documento.
describe('servicios: create manual del propietario', () => {
  const MANUAL = 'Manual (Propietario)';

  test('el propietario SI puede registrar un servicio manual sobre su vehiculo', async () => {
    await seedVehiculo('v1', UIDS.owner1);
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('servicios').add({
        id_vehiculo: 'v1', id_taller: MANUAL, tipo_servicio: 'Cambio de aceite',
        costo: 45.5, kilometraje_servicio: 82000,
      }),
    );
  });

  test('el propietario NO puede registrar un servicio manual sobre el vehiculo de otro', async () => {
    await seedVehiculo('v-ajeno', UIDS.owner2);
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('servicios').add({
        id_vehiculo: 'v-ajeno', id_taller: MANUAL, tipo_servicio: 'Cambio de aceite',
      }),
    );
  });

  test('el propietario NO puede usar la rama manual para imputar el servicio a un taller real', async () => {
    // El centinela es lo unico que autoriza esta rama: si se pudiera poner un
    // uid de taller, el propietario estaria fabricando historial ajeno (y el
    // trigger requestReviewOnServiceComplete si actua sobre esos id_taller).
    await seedVehiculo('v1', UIDS.owner1);
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('servicios').add({
        id_vehiculo: 'v1', id_taller: UIDS.taller1, tipo_servicio: 'Cambio de aceite',
      }),
    );
  });

  test('un tercero NO puede registrar un servicio manual sobre un vehiculo que no es suyo', async () => {
    await seedVehiculo('v1', UIDS.owner1);
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await assertFails(
      db.collection('servicios').add({
        id_vehiculo: 'v1', id_taller: MANUAL, tipo_servicio: 'Cambio de aceite',
      }),
    );
  });
});
