const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// Vehiculo del propietario 1, vinculado UNICAMENTE al taller 1 (igual que
// mecanico-scope.test.js) — necesario porque el create de 'reparaciones'
// exige isVinculadoAlVehiculo(id_vehiculo).
const seedVehiculo = async () => {
  await seed(env, async (s) => {
    await s.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1',
      id_propietario: UIDS.owner1,
      placa: 'ABC123',
      talleres_vinculados: [UIDS.taller1],
    });
  });
};

const seedReparacion = async () => {
  await seedVehiculo();
  await seed(env, async (s) => {
    await s.collection('reparaciones').doc('rep1').set({
      id_propietario: UIDS.owner1,
      id_taller: UIDS.taller1,
      id_vehiculo: 'v1',
      placa: 'ABC123',
      estado: 'recibido',
    });
  });
};

describe('reparaciones (Tarea 5 — kanban de estado, panel mecanico)', () => {
  test('el propietario del vehiculo puede leer la reparacion', async () => {
    await seedReparacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('reparaciones').doc('rep1').get());
  });

  test('el taller asignado puede leer la reparacion', async () => {
    await seedReparacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(db.collection('reparaciones').doc('rep1').get());
  });

  test('un tercero NO puede leer la reparacion', async () => {
    await seedReparacion();
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await assertFails(db.collection('reparaciones').doc('rep1').get());
  });

  test('el taller vinculado al vehiculo puede crear una reparacion asignada a si mismo', async () => {
    await seedVehiculo();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reparaciones').doc('rep2').set({
        id_propietario: UIDS.owner1,
        id_taller: UIDS.taller1,
        id_vehiculo: 'v1',
        placa: 'ABC123',
        estado: 'recibido',
      }),
    );
  });

  test('un taller NO vinculado al vehiculo NO puede crear la reparacion (evita inyectar en vehiculo ajeno)', async () => {
    await seedVehiculo();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('reparaciones').doc('rep3').set({
        id_propietario: UIDS.owner1,
        id_taller: UIDS.taller2,
        id_vehiculo: 'v1',
        placa: 'ABC123',
        estado: 'recibido',
      }),
    );
  });

  test('un mecanico puede crear la reparacion de un vehiculo walk-in (talleres_vinculados vacio, sin cita previa)', async () => {
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v2').set({
        id_vehiculo: 'v2',
        id_propietario: UIDS.owner1,
        placa: 'XYZ999',
        talleres_vinculados: [],
      });
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reparaciones').doc('rep-walkin').set({
        id_propietario: UIDS.owner1,
        id_taller: UIDS.taller1,
        id_vehiculo: 'v2',
        placa: 'XYZ999',
        estado: 'recibido',
      }),
    );
  });

  test('un taller vinculado NO puede crear con id_propietario distinto del dueño real del vehiculo', async () => {
    await seedVehiculo();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('reparaciones').doc('rep3b').set({
        id_propietario: UIDS.owner2, // suplantacion del propietario real (owner1)
        id_taller: UIDS.taller1,
        id_vehiculo: 'v1',
        placa: 'ABC123',
        estado: 'recibido',
      }),
    );
  });

  test('el propietario NO puede crear una reparacion (solo el taller crea)', async () => {
    await seedVehiculo();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('reparaciones').doc('rep4').set({
        id_propietario: UIDS.owner1,
        id_taller: UIDS.taller1,
        id_vehiculo: 'v1',
        placa: 'ABC123',
        estado: 'recibido',
      }),
    );
  });

  test('el taller asignado SI puede actualizar el estado', async () => {
    await seedReparacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1').update({ estado: 'en_revision' }),
    );
  });

  test('un taller NO vinculado NO puede actualizar la reparacion de otro', async () => {
    await seedReparacion();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ estado: 'en_revision' }),
    );
  });

  test('el propietario NO puede actualizar el estado', async () => {
    await seedReparacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ estado: 'en_revision' }),
    );
  });

  test('el taller asignado NO puede reasignar id_taller/id_vehiculo/id_propietario via update (secuestro de doc)', async () => {
    await seedReparacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ id_taller: UIDS.taller2 }),
    );
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ id_propietario: UIDS.owner2 }),
    );
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ id_vehiculo: 'v2' }),
    );
  });

  test('solo admin puede borrar', async () => {
    await seedReparacion();
    const dbTaller = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(dbTaller.collection('reparaciones').doc('rep1').delete());

    const dbAdmin = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(dbAdmin.collection('reparaciones').doc('rep1').delete());
  });

  // --- Sub-cuentas de empleado (fix de integracion de empleados) ---
  // El cliente ya resuelve `idTaller` al uid del DUEÑO real
  // (UserModel.idTallerEfectivo) para toda cuenta de empleado, asi que
  // estas pruebas simulan exactamente eso: id_taller/request.auth.uid
  // distintos, con el empleado autenticado bajo su propio uid pero
  // escribiendo/leyendo con id_taller == taller1 (el dueño).
  test('un empleado de taller1 (id_taller_propietario == taller1) puede crear una reparacion con id_taller == taller1', async () => {
    await seedVehiculo();
    const db = await withRole(env, UIDS.empleado1, 'Taller', {
      id_taller_propietario: UIDS.taller1,
    });
    await assertSucceeds(
      db.collection('reparaciones').doc('rep-emp1').set({
        id_propietario: UIDS.owner1,
        id_taller: UIDS.taller1,
        id_vehiculo: 'v1',
        placa: 'ABC123',
        estado: 'recibido',
      }),
    );
  });

  test('un empleado de taller1 puede leer y actualizar una reparacion de taller1', async () => {
    await seedReparacion();
    const db = await withRole(env, UIDS.empleado1, 'Taller', {
      id_taller_propietario: UIDS.taller1,
    });
    await assertSucceeds(db.collection('reparaciones').doc('rep1').get());
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1').update({ estado: 'en_revision' }),
    );
  });

  test('un empleado cuyo id_taller_propietario apunta a OTRO taller NO puede crear/leer/actualizar la reparacion de taller1', async () => {
    await seedReparacion();
    // empleado2 pertenece a taller2, no a taller1.
    const db = await withRole(env, UIDS.empleado2, 'Taller', {
      id_taller_propietario: UIDS.taller2,
    });
    await assertFails(db.collection('reparaciones').doc('rep1').get());
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ estado: 'en_revision' }),
    );
    await assertFails(
      db.collection('reparaciones').doc('rep-emp2').set({
        id_propietario: UIDS.owner1,
        id_taller: UIDS.taller1,
        id_vehiculo: 'v1',
        placa: 'ABC123',
        estado: 'recibido',
      }),
    );
  });
});
