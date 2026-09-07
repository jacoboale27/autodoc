// Ronda 6 — el carve-out de walk-in mira `talleres_conocidos` ("ha tenido este
// coche alguna vez", append-only), no `talleres_vinculados` ("lo tiene ahora",
// que la ronda 5 empezo a revocar).
//
// El hallazgo: la mitigacion del hallazgo critico C1 dejaba pasar a cualquier
// mecanico cuando `talleres_vinculados` estaba VACIO, bajo la premisa de que
// eso significaba "coche que nadie ha atendido nunca". Al empezar a revocar el
// vinculo al entregar, "vacio" paso a ser el estado de reposo de todo coche ya
// entregado — es decir, casi toda la flota casi todo el tiempo — y con el,
// cualquier taller podia inyectar un `servicios` falso (con costo, materiales y
// factura) en el historial de cualquier cliente, y dispararle el banner de
// `taller_pendiente_confirmacion`.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); }, 60000);
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedVehiculo = (extra) => seed(env, async (s) => {
  await s.collection('vehiculos').doc('v1').set({
    id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'ABC123',
    ...extra,
  });
});

const crearServicio = (db, taller) =>
  db.collection('servicios').add({
    id_vehiculo: 'v1', id_taller: taller, tipo_servicio: 'Cambio de aceite',
  });

const crearHistorial = (db, taller) =>
  db.collection('historial_mantenimientos').add({
    id_vehiculo: 'v1', id_taller: taller, descripcion: 'Cambio de aceite',
  });

describe('servicios: quien puede escribir en el historial de un vehiculo', () => {
  test('walk-in real: nadie ha atendido nunca este coche', async () => {
    await seedVehiculo({ talleres_vinculados: [], talleres_conocidos: [] });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(crearServicio(db, UIDS.taller1));
  });

  test('walk-in real tambien vale para un vehiculo sin ninguno de los dos campos', async () => {
    await seedVehiculo({});
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(crearServicio(db, UIDS.taller1));
  });

  test('el taller que TIENE el coche ahora puede escribir', async () => {
    await seedVehiculo({
      talleres_vinculados: [UIDS.taller1], talleres_conocidos: [UIDS.taller1],
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(crearServicio(db, UIDS.taller1));
  });

  test('el taller que YA atendio el coche sigue pudiendo, aunque ya lo entrego', async () => {
    // Es el caso que el carve-out original queria cubrir: cerrar la visita no
    // debe impedirle al taller corregir o completar su propio registro.
    await seedVehiculo({
      talleres_vinculados: [], talleres_conocidos: [UIDS.taller1],
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(crearServicio(db, UIDS.taller1));
  });

  test('EL HUECO: un taller ajeno NO puede escribir sobre un coche ya entregado', async () => {
    await seedVehiculo({
      talleres_vinculados: [], talleres_conocidos: [UIDS.taller1],
    });
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(crearServicio(db, UIDS.taller2));
  });

  test('un taller ajeno NO puede escribir sobre un coche que otro tiene ahora', async () => {
    await seedVehiculo({
      talleres_vinculados: [UIDS.taller1], talleres_conocidos: [UIDS.taller1],
    });
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(crearServicio(db, UIDS.taller2));
  });

  test('vehiculo legado: vinculo vivo pero sin `talleres_conocidos` todavia', async () => {
    // Estado real de produccion antes de correr el backfill de la ronda 6. El
    // coche esta siendo atendido por taller1, asi que taller2 no entra por la
    // puerta del walk-in: exige los DOS arrays vacios.
    await seedVehiculo({ talleres_vinculados: [UIDS.taller1] });
    const ajeno = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(crearServicio(ajeno, UIDS.taller2));
    const propio = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(crearServicio(propio, UIDS.taller1));
  });
});

describe('historial_mantenimientos: la misma puerta', () => {
  test('el taller que ya atendio el coche puede escribir', async () => {
    await seedVehiculo({
      talleres_vinculados: [], talleres_conocidos: [UIDS.taller1],
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(crearHistorial(db, UIDS.taller1));
  });

  test('un taller ajeno NO puede escribir sobre un coche ya entregado', async () => {
    await seedVehiculo({
      talleres_vinculados: [], talleres_conocidos: [UIDS.taller1],
    });
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(crearHistorial(db, UIDS.taller2));
  });
});

describe('vehiculos: `talleres_conocidos` es server-owned', () => {
  test('un taller NO puede autoañadirse a `talleres_conocidos`', async () => {
    await seedVehiculo({ talleres_vinculados: [], talleres_conocidos: [] });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('vehiculos').doc('v1')
        .update({ talleres_conocidos: [UIDS.taller1] })
    );
  });

  test('un mecanico vinculado solo puede tocar el kilometraje', async () => {
    await seedVehiculo({
      talleres_vinculados: [UIDS.taller1], talleres_conocidos: [UIDS.taller1],
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('vehiculos').doc('v1').update({ kilometraje_actual: 1234 })
    );
    await assertFails(
      db.collection('vehiculos').doc('v1')
        .update({ kilometraje_actual: 1235, talleres_conocidos: [UIDS.taller2] })
    );
  });
});
