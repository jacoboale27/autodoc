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

// Ticket ya existente. Se siembra con las reglas desactivadas porque desde
// A4b NADIE puede crearlo desde el cliente: lo abre el trigger
// `onCotizacionAceptada` con el Admin SDK, que es exactamente lo que
// `withSecurityRulesDisabled` simula aqui.
const seedReparacion = async (extra = {}) => {
  await seedVehiculo();
  await seed(env, async (s) => {
    await s.collection('reparaciones').doc('rep1').set({
      id_propietario: UIDS.owner1,
      id_taller: UIDS.taller1,
      id_vehiculo: 'v1',
      placa: 'ABC123',
      estado: 'recibido',
      ...extra,
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

  // --- A4b: el ticket lo abre el trigger onCotizacionAceptada, nadie mas ---
  // Hasta A4b el mecanico vinculado al vehiculo SI podia crear el ticket a
  // mano (y ese era el test que vivia aqui). Esa puerta es la que permitia
  // recibir un vehiculo sin ninguna cotizacion aceptada (A3/B2), asi que la
  // regla pasa a `allow create: if false` y estos tests invierten el
  // veredicto a proposito.
  const ticketAMano = {
    id_propietario: UIDS.owner1,
    id_taller: UIDS.taller1,
    id_vehiculo: 'v1',
    placa: 'ABC123',
    estado: 'pendiente_recepcion',
  };

  test('ni el mecanico ni el cliente pueden crear un ticket a mano', async () => {
    await seedVehiculo();
    const dbMecanico = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      dbMecanico.collection('reparaciones').doc('rep2').set(ticketAMano),
    );

    const dbCliente = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      dbCliente.collection('reparaciones').doc('rep4').set(ticketAMano),
    );
  });

  test('un taller NO vinculado al vehiculo tampoco puede crear la reparacion', async () => {
    await seedVehiculo();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('reparaciones').doc('rep3').set({
        ...ticketAMano,
        id_taller: UIDS.taller2,
      }),
    );
  });

  test('el walk-in sin cotizacion aceptada ya no puede abrir ticket (A3/B2)', async () => {
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v2').set({
        id_vehiculo: 'v2',
        id_propietario: UIDS.owner1,
        placa: 'XYZ999',
        talleres_vinculados: [],
      });
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('reparaciones').doc('rep-walkin').set({
        ...ticketAMano,
        id_vehiculo: 'v2',
        placa: 'XYZ999',
      }),
    );
  });

  test('ni siquiera el admin crea tickets a mano: el unico creador es el trigger', async () => {
    await seedVehiculo();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      db.collection('reparaciones').doc('rep-admin').set(ticketAMano),
    );
  });

  test('el mecanico del taller si puede mover el ticket de pendiente_recepcion a recibido', async () => {
    // La contraparte de cerrar el create: "recibir el vehiculo" pasa a ser
    // esta transicion, asi que tiene que seguir permitida.
    await seedReparacion({ estado: 'pendiente_recepcion', id_cotizacion: 'c1' });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1').update({ estado: 'recibido' }),
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
  test('un empleado de taller1 tampoco crea tickets a mano, pero si opera los que existen', async () => {
    await seedReparacion({ estado: 'pendiente_recepcion' });
    const db = await withRole(env, UIDS.empleado1, 'Taller', {
      id_taller_propietario: UIDS.taller1,
    });
    await assertFails(
      db.collection('reparaciones').doc('rep-emp1').set(ticketAMano),
    );
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1').update({ estado: 'recibido' }),
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

  // --- Cancelar un ticket (Tarea 5 — el tablero solo ofrecia "Avanzar") ---
  test('el taller dueno del ticket puede cancelarlo', async () => {
    await seedReparacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1').update({ estado: 'cancelado' }),
    );
  });

  test('otro taller NO puede cancelarlo', async () => {
    await seedReparacion();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ estado: 'cancelado' }),
    );
  });
});
