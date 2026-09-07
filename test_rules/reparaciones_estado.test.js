// Ronda 6 — las invariantes de la maquina de estados de `reparaciones` viven
// tambien en firestore.rules, no solo en ReparacionRepository.cambiarEstado.
//
// Estos tests nacen de una revision adversarial que comprobo contra el
// emulador que un taller podia saltarse las tres guardas del cliente
// escribiendo `estado` a mano. Los 298 tests de reglas que ya existian pasaban
// porque ninguno modelaba estas transiciones.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); }, 60000);
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedTicket = async (estado) => {
  await seed(env, async (s) => {
    await s.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'ABC123',
      talleres_vinculados: [UIDS.taller1], talleres_conocidos: [UIDS.taller1],
    });
    await s.collection('reparaciones').doc('rep1').set({
      id_propietario: UIDS.owner1, id_taller: UIDS.taller1,
      id_vehiculo: 'v1', placa: 'ABC123', estado,
      historial_estados: [],
    });
  });
};

const comoTaller1 = () => withRole(env, UIDS.taller1, 'Taller');

describe('reparaciones: el pipeline avanza normalmente', () => {
  test('el taller avanza una columna', async () => {
    await seedTicket('recibido');
    const db = await comoTaller1();
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1').update({ estado: 'en_revision' })
    );
  });

  test('el taller entrega desde `listo_para_entrega`', async () => {
    await seedTicket('listo_para_entrega');
    const db = await comoTaller1();
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1').update({ estado: 'entregado' })
    );
  });

  test('el taller puede cancelar desde cualquier estado abierto', async () => {
    await seedTicket('esperando_repuestos');
    const db = await comoTaller1();
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1').update({ estado: 'cancelado' })
    );
  });

  test('un ticket legado sin `estado` sigue siendo editable', async () => {
    // Los tickets anteriores a A4b no traen el campo. La regla les aplica el
    // mismo defecto que el cliente y las functions: 'recibido'.
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'ABC123',
        talleres_vinculados: [UIDS.taller1],
      });
      await s.collection('reparaciones').doc('rep1').set({
        id_propietario: UIDS.owner1, id_taller: UIDS.taller1,
        id_vehiculo: 'v1', placa: 'ABC123', historial_estados: [],
      });
    });
    const db = await comoTaller1();
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1').update({ estado: 'en_revision' })
    );
  });
});

describe('reparaciones: las invariantes que el cliente ya imponia', () => {
  test('NO se puede entregar un coche que nunca llego al taller', async () => {
    // 'pendiente_recepcion' es un coche que todavia no ha aparecido. Eso se
    // cancela, no se entrega — y entregar revoca el vinculo y saca el ticket
    // del tablero sin vuelta atras.
    await seedTicket('pendiente_recepcion');
    const db = await comoTaller1();
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ estado: 'entregado' })
    );
  });

  test('NO se puede RESUCITAR un ticket entregado', async () => {
    // La grave. `recibirTicketYVincular` solo rechaza estados cerrados, asi
    // que un ticket devuelto a 'recibido' pasa su control y el `arrayUnion` le
    // devuelve al taller el acceso a la ficha del coche sin ninguna cotizacion
    // aceptada nueva.
    await seedTicket('entregado');
    const db = await comoTaller1();
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ estado: 'recibido' })
    );
  });

  test('NO se puede reabrir un ticket cancelado', async () => {
    await seedTicket('cancelado');
    const db = await comoTaller1();
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ estado: 'recibido' })
    );
  });

  test('un ticket cerrado es inmutable incluso en campos inocuos', async () => {
    await seedTicket('entregado');
    const db = await comoTaller1();
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ placa: 'OTRA-999' })
    );
  });

  test('NO se puede escribir un `estado` fuera de la lista blanca', async () => {
    // Un estado inventado esconde el ticket para siempre: el tablero filtra
    // con `whereIn` sobre las cinco columnas.
    await seedTicket('recibido');
    const db = await comoTaller1();
    await assertFails(
      db.collection('reparaciones').doc('rep1')
        .update({ estado: 'inventado_por_el_taller' })
    );
  });

  test('NO se puede escribir el centinela de migracion', async () => {
    // `migracion_ronda6` silencia los triggers de notificacion y revocacion.
    // Es de los scripts de mantenimiento (Admin SDK); un taller que pudiera
    // escribirlo entregaria coches sin que el propietario se entere.
    await seedTicket('listo_para_entrega');
    const db = await comoTaller1();
    await assertFails(
      db.collection('reparaciones').doc('rep1')
        .update({ estado: 'entregado', migracion_ronda6: true })
    );
  });

  test('el admin SI puede corregir un ticket cerrado', async () => {
    await seedTicket('entregado');
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1').update({ estado: 'recibido' })
    );
  });

  test('CONTROL: un taller ajeno no toca el ticket', async () => {
    await seedTicket('recibido');
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ estado: 'entregado' })
    );
  });
});
