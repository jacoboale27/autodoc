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

describe('cotizaciones update (revision de rama completa, hallazgo C1: el mecanico se auto-emitia el gate del trigger)', () => {
  // Antes de esta ronda, `update` solo comprobaba QUIEN escribia, nunca QUE
  // valor de `estado` escribia cada uno. Un mecanico podia aceptar su propia
  // cotizacion sobre un vehiculo ajeno y con eso disparar el unico requisito
  // que `onCotizacionAceptada` exige para abrir un ticket de `reparaciones`.
  test('el mecanico NO puede auto-aceptar su propia cotizacion', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });

  test('el mecanico NO puede auto-rechazar la cotizacion tampoco (solo el propietario resuelve pendiente/aceptada/rechazada)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'rechazada' }),
    );
  });

  test('el propietario SI puede aceptar la cotizacion (camino legitimo)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });

  test('el mecanico SI puede marcar finalizada (camino legitimo)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'finalizada' }),
    );
  });

  test('el propietario NO puede marcar finalizada', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'finalizada' }),
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

  test('el mecanico SI puede crear la cotizacion y su margen privado en dos pasos (flujo real de ChatRepository.crearCotizacion)', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c2').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
        estado: 'pendiente',
      }),
    );
    await assertSucceeds(
      db.collection('cotizaciones').doc('c2').collection('privado').doc('margen').set({
        beneficios: [8],
      }),
    );
  });
});
