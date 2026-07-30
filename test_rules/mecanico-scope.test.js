const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// Vehiculo del propietario 1, vinculado UNICAMENTE al taller 1.
const seedEscenario = async () => {
  await seed(env, async (s) => {
    await s.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
      talleres_vinculados: [UIDS.taller1],
    });
    await s.collection('mantenimientos').doc('m1').set({
      id_vehiculo: 'v1', nombre: 'Pastillas de Freno', frecuencia_km: 20000,
    });
    await s.collection('historial_mantenimientos').doc('h1').set({
      id_vehiculo: 'v1', id_taller: UIDS.taller1, nombre_tarea: 'Filtro de Aceite',
    });
    await s.collection('alertas').doc('a1').set({ id_vehiculo: 'v1', tipo: 'soat' });
  });
};

describe('alcance del rol mecanico (regresion de la fuga verificada)', () => {
  test('un taller NO vinculado NO lee mantenimientos ajenos', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(db.collection('mantenimientos').get());
    await assertFails(db.collection('mantenimientos').doc('m1').get());
  });

  test('un taller NO vinculado NO lee historial_mantenimientos ajeno', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(db.collection('historial_mantenimientos').get());
    await assertFails(db.collection('historial_mantenimientos').doc('h1').get());
  });

  test('un taller NO vinculado NO puede MODIFICAR historial ajeno', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('historial_mantenimientos').doc('h1').update({ descripcion: 'falsificado' }),
    );
  });

  test('un taller NO vinculado NO puede CREAR historial sobre un vehiculo ajeno', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('historial_mantenimientos').add({
        id_vehiculo: 'v1', id_taller: UIDS.taller2, nombre_tarea: 'inventado',
      }),
    );
  });

  test('un taller NO vinculado NO lee alertas ajenas', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(db.collection('alertas').get());
  });

  test('un taller vinculado SI lee el historial del vehiculo vinculado', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(db.collection('historial_mantenimientos').doc('h1').get());
  });

  test('el propietario SI lee el historial de su vehiculo', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('historial_mantenimientos').doc('h1').get());
  });

  test('un taller NO puede actualizar un taller ajeno', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller2).set({
        id_taller: UIDS.taller2, nombre: 'Taller Ajeno', especialidad: 'General',
      });
    });
    await assertFails(
      db.collection('talleres').doc(UIDS.taller2).update({ nombre: 'Secuestrado' }),
    );
  });
});

describe('estado de aprobacion del mecanico', () => {
  test('un mecanico PENDIENTE no accede a datos aunque este vinculado', async () => {
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.taller1).set({
        id_usuario: UIDS.taller1, rol: 'Taller', estado: 'pendiente',
      });
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1,
        talleres_vinculados: [UIDS.taller1],
      });
      await s.collection('historial_mantenimientos').doc('h1').set({
        id_vehiculo: 'v1', id_taller: UIDS.taller1,
      });
    });
    const db = env.authenticatedContext(UIDS.taller1).firestore();
    await assertFails(db.collection('vehiculos').doc('v1').get());
    await assertFails(db.collection('historial_mantenimientos').doc('h1').get());
  });

  test('un mecanico SIN campo estado tampoco accede (fail-closed)', async () => {
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.taller1).set({
        id_usuario: UIDS.taller1, rol: 'Taller',
      });
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1,
        talleres_vinculados: [UIDS.taller1],
      });
    });
    const db = env.authenticatedContext(UIDS.taller1).firestore();
    await assertFails(db.collection('vehiculos').doc('v1').get());
  });
});
