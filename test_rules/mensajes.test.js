const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedConversacion = async () => {
  await seed(env, async (s) => {
    await s.collection('conversaciones').doc('c1').set({
      id_propietario: UIDS.owner1,
      id_mecanico: UIDS.taller1,
    });
  });
};

const seedMensajeTexto = async (overrides = {}) => {
  await seed(env, async (s) => {
    await s
      .collection('conversaciones')
      .doc('c1')
      .collection('mensajes')
      .doc('m1')
      .set({
        id_remitente: UIDS.owner1,
        contenido: 'hola',
        tipo: 'texto',
        estado: 'enviado',
        ...overrides,
      });
  });
};

const seedMensajeReserva = async () => {
  await seed(env, async (s) => {
    await s
      .collection('conversaciones')
      .doc('c1')
      .collection('mensajes')
      .doc('res1')
      .set({
        id_remitente: UIDS.owner1,
        contenido: 'Reserva propuesta',
        tipo: 'reserva_card',
        estado: 'enviado',
        metadata: { id_reserva: 'r1', estado: 'pendiente' },
      });
  });
};

describe('mensajes: politica de borrado (Tarea 11a, C4) — solo el autor borra su mensaje', () => {
  test('el autor SI puede borrar (hard delete) su propio mensaje', async () => {
    await seedConversacion();
    await seedMensajeTexto();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('m1')
        .delete(),
    );
  });

  test('la contraparte NO puede borrar un mensaje ajeno, aunque sea participante', async () => {
    await seedConversacion();
    await seedMensajeTexto();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('m1')
        .delete(),
    );
  });

  test('el borrado logico de un mensaje ajeno tambien queda bloqueado', async () => {
    await seedConversacion();
    await seedMensajeTexto();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('m1')
        .update({ is_deleted: true, contenido: 'Este mensaje ha sido eliminado' }),
    );
  });

  test('el borrado logico (is_deleted + contenido) sigue disponible para el autor', async () => {
    await seedConversacion();
    await seedMensajeTexto();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('m1')
        .update({ is_deleted: true, contenido: 'Este mensaje ha sido eliminado' }),
    );
  });
});

describe('mensajes: el resto de escrituras que la app ya hace siguen funcionando', () => {
  test('el receptor puede marcar como visto un mensaje ajeno (marcarComoLeidos)', async () => {
    await seedConversacion();
    await seedMensajeTexto();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('m1')
        .update({ estado: 'visto' }),
    );
  });

  test('cualquier participante puede actualizar metadata de una tarjeta de reserva (aceptar/rechazar)', async () => {
    await seedConversacion();
    await seedMensajeReserva();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('res1')
        .update({ metadata: { id_reserva: 'r1', estado: 'confirmada' } }),
    );
  });
});
