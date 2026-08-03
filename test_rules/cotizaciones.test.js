const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedCotizacion = async () => {
  await seed(env, async (s) => {
    await s.collection('cotizaciones').doc('c1').set({
      id_propietario: UIDS.owner1,
      id_mecanico: UIDS.taller1,
      id_taller: UIDS.taller1,
      items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
      estado: 'pendiente',
    });
  });
};

describe('cotizaciones update (hallazgo H1: campo abierto permitia alterar precio/partes)', () => {
  test('el propietario SI puede aceptar (solo estado)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });

  test('el mecanico SI puede finalizar (solo estado)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'finalizada' }),
    );
  });

  test('el propietario NO puede alterar los items (precio) al aceptar', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({
        estado: 'aceptada',
        items: [{ material: 'Aceite', cantidad: 1, costo: 1 }],
      }),
    );
  });

  test('el mecanico NO puede reasignar id_propietario', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({
        id_propietario: UIDS.owner2,
      }),
    );
  });

  test('un tercero no vinculado NO puede actualizar la cotizacion', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });
});

describe('cotizaciones/privado/margen (hallazgo H2: el beneficio no debe ser legible por el propietario)', () => {
  const seedMargen = async () => {
    await seed(env, async (s) => {
      await s.collection('cotizaciones').doc('c1').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
        estado: 'pendiente',
      });
      await s.collection('cotizaciones').doc('c1').collection('privado').doc('margen').set({
        beneficios: [8],
      });
    });
  };

  test('el mecanico dueño SI puede leer su margen', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });

  test('el propietario NO puede leer el margen del mecanico', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });

  test('un tercero no vinculado NO puede leer el margen', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });
});
