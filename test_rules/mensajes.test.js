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

const seedMensajeCotizacion = async () => {
  await seed(env, async (s) => {
    await s
      .collection('conversaciones')
      .doc('c1')
      .collection('mensajes')
      .doc('cot1')
      .set({
        id_remitente: UIDS.taller1,
        contenido: 'He enviado una cotizacion',
        tipo: 'cotizacion_card',
        estado: 'enviado',
        metadata: { id_cotizacion: 'q1', estado: 'pendiente' },
      });
  });
};

describe('mensajes: edicion acotada al autor (Tarea 11b, C4)', () => {
  test('el emisor puede editar solo el contenido y la marca de editado', async () => {
    await seedConversacion();
    await seedMensajeTexto();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('m1')
        .update({ contenido: 'corregido', editado: true }),
    );
  });

  test('quien NO es el emisor no puede editar el contenido, aunque sea participante', async () => {
    await seedConversacion();
    await seedMensajeTexto();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('m1')
        .update({ contenido: 'lo cambio yo', editado: true }),
    );
  });

  test('un tercero ajeno a la conversacion no puede editar', async () => {
    await seedConversacion();
    await seedMensajeTexto();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('m1')
        .update({ contenido: 'intruso', editado: true }),
    );
  });

  test('nadie puede reescribir el emisor del mensaje', async () => {
    await seedConversacion();
    await seedMensajeTexto();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('m1')
        .update({ id_remitente: UIDS.taller1 }),
    );
  });

  test('nadie puede reescribir el tipo del mensaje', async () => {
    await seedConversacion();
    await seedMensajeTexto();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('m1')
        .update({ tipo: 'cotizacion_card' }),
    );
  });

  test('el emisor no puede colar otros campos junto a contenido/editado', async () => {
    await seedConversacion();
    await seedMensajeTexto();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('m1')
        .update({ contenido: 'corregido', editado: true, estado: 'visto' }),
    );
  });

  test('no se puede editar el texto de un mensaje de reserva, ni el propio autor', async () => {
    await seedConversacion();
    await seedMensajeReserva();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('res1')
        .update({ contenido: 'otro texto', editado: true }),
    );
  });

  test('no se puede editar el texto de una cotizacion ya enviada, ni el propio autor', async () => {
    await seedConversacion();
    await seedMensajeCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .doc('cot1')
        .update({ contenido: 'otro precio', editado: true }),
    );
  });
});

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
