const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedReserva = async () => {
  await seed(env, async (s) => {
    await s.collection('reservas').doc('r1').set({
      id_propietario: UIDS.owner1,
      id_mecanico: UIDS.taller1,
      id_taller: UIDS.taller1,
      id_vehiculo: 'v1',
      estado: 'pendiente',
    });
  });
};

describe('reservas (hallazgo I6: mismo patron de bug que Tarea 9 corrigio en otros bloques)', () => {
  test('un mecanico NO vinculado NO puede actualizar la reserva de otro', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('reservas').doc('r1').update({ estado: 'confirmada' }),
    );
  });

  test('el mecanico asignado a la reserva SI puede actualizarla', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reservas').doc('r1').update({ estado: 'confirmada' }),
    );
  });

  test('el propietario de la reserva SI puede actualizarla', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('reservas').doc('r1').update({ estado: 'cancelada' }),
    );
  });
});
