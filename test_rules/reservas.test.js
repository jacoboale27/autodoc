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
      id_proponente: UIDS.owner1,
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

  test('el mecanico asignado a la reserva SI puede actualizarla si no es el proponente', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reservas').doc('r1').update({ estado: 'confirmada' }),
    );
  });

  test('el propietario de la reserva SI puede actualizarla con cancelacion', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('reservas').doc('r1').update({ estado: 'cancelada' }),
    );
  });
});

describe('reservas update field scoping (hallazgo M1: cualquier campo era escribible)', () => {
  test('el propietario NO puede reasignar id_mecanico', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('reservas').doc('r1').update({ id_mecanico: UIDS.taller2 }),
    );
  });

  test('el mecanico NO puede reasignar id_vehiculo', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('reservas').doc('r1').update({ id_vehiculo: 'v2' }),
    );
  });
});

describe('reservas: transiciones seguras e invariante de proponente (hallazgo #4)', () => {
  test('el proponente NO puede confirmar su propia propuesta', async () => {
    await seed(env, async (s) => {
      await s.collection('reservas').doc('r1').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        id_vehiculo: 'v1',
        id_proponente: UIDS.owner1,
        estado: 'pendiente',
      });
    });
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('reservas').doc('r1').update({ estado: 'confirmada' }),
    );
  });

  test('la contraparte SI puede confirmar la propuesta', async () => {
    await seed(env, async (s) => {
      await s.collection('reservas').doc('r1').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        id_vehiculo: 'v1',
        id_proponente: UIDS.owner1,
        estado: 'pendiente',
      });
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reservas').doc('r1').update({ estado: 'confirmada' }),
    );
  });

  test('si el mecanico propone, el mecanico NO puede confirmar pero el propietario SI', async () => {
    await seed(env, async (s) => {
      await s.collection('reservas').doc('r1').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        id_vehiculo: 'v1',
        id_proponente: UIDS.taller1,
        estado: 'pendiente',
      });
    });
    const dbMecanico = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      dbMecanico.collection('reservas').doc('r1').update({ estado: 'confirmada' }),
    );

    const dbPropietario = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      dbPropietario.collection('reservas').doc('r1').update({ estado: 'confirmada' }),
    );
  });

  test('propietario puede cancelar con su propio sufijo pero NO con el del taller', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('reservas').doc('r1').update({ estado: 'cancelada_por_propietario' }),
    );
    await assertFails(
      db.collection('reservas').doc('r1').update({ estado: 'cancelada_por_taller' }),
    );
  });

  test('taller puede cancelar con su propio sufijo pero NO con el del propietario', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reservas').doc('r1').update({ estado: 'cancelada_por_taller' }),
    );
    await assertFails(
      db.collection('reservas').doc('r1').update({ estado: 'cancelada_por_propietario' }),
    );
  });

  test('reprogramar exige reescribir id_proponente con el uid propio', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    // Sin id_proponente falla
    await assertFails(
      db.collection('reservas').doc('r1').update({
        fecha_hora_propuesta: new Date(),
        estado: 'pendiente',
      }),
    );
    // Con id_proponente ajeno falla
    await assertFails(
      db.collection('reservas').doc('r1').update({
        fecha_hora_propuesta: new Date(),
        estado: 'pendiente',
        id_proponente: UIDS.owner1,
      }),
    );
    // Con id_proponente propio tiene éxito
    await assertSucceeds(
      db.collection('reservas').doc('r1').update({
        fecha_hora_propuesta: new Date(),
        estado: 'pendiente',
        id_proponente: UIDS.taller1,
      }),
    );
  });
});
