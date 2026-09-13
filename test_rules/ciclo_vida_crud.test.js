const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// Matriz de ciclo de vida que pide QA-01: por entidad,
// create -> releer -> update -> releer -> delete -> releer.
//
// El "releer" no es decorativo. Un assertSucceeds sobre la escritura solo
// prueba que la regla dejo pasar el write; leer el documento despues y
// comprobar el VALOR es lo que prueba que persistio lo que se pidio, que es
// justo lo que la auditoria marco como no demostrado. Y el ultimo releer,
// tras el delete, distingue "el borrado se autorizo" de "el documento ya no
// esta".
//
// Donde la regla NO concede delete a nadie (conversaciones, reservas) el
// ciclo se cierra afirmando esa denegacion, no omitiendola: un hueco en la
// matriz y una prohibicion deliberada no se ven igual si solo se listan las
// filas verdes.

describe('ciclo de vida: vehiculos', () => {
  test('propietario: create, relectura, update, relectura, delete, relectura', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    const ref = db.collection('vehiculos').doc('v1');

    await assertSucceeds(ref.set({
      id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1', kilometraje_actual: 1000,
    }));
    let snap = await assertSucceeds(ref.get());
    expect(snap.data().placa).toBe('P-1');

    await assertSucceeds(ref.update({ kilometraje_actual: 2500 }));
    snap = await assertSucceeds(ref.get());
    expect(snap.data().kilometraje_actual).toBe(2500);

    await assertSucceeds(ref.delete());
    snap = await assertSucceeds(ref.get());
    expect(snap.exists).toBe(false);
  });

  test('un segundo propietario no puede leer ni borrar ese vehiculo', async () => {
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
      });
    });
    const ajeno = await withRole(env, UIDS.owner2, 'Propietario');
    await assertFails(ajeno.collection('vehiculos').doc('v1').get());
    await assertFails(ajeno.collection('vehiculos').doc('v1').delete());
  });
});

describe('ciclo de vida: conversaciones y mensajes (el chat)', () => {
  // El taller tiene que existir y estar aprobado: desde H-01, abrir chat como
  // propietario exige que el `id_mecanico` nombrado sea un taller de verdad
  // (antes valia cualquier uid, y por ahi entraba el ataque en dos pasos
  // contra /reservas). El chat se inicia desde el directorio, que solo lista
  // talleres aprobados, asi que esto es la forma real y no un apano.
  const sembrarTallerAprobado = () => seed(env, async (s) => {
    await s.collection('usuarios').doc(UIDS.taller1).set({
      id_usuario: UIDS.taller1, rol: 'Taller', estado: 'aprobado',
    });
  });

  const abrirChat = async () => {
    await sembrarTallerAprobado();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('conversaciones').doc('c1').set({
      id_propietario: UIDS.owner1, id_mecanico: UIDS.taller1, id_taller: UIDS.taller1,
      ultimo_mensaje: '', no_leidos_propietario: 0, no_leidos_mecanico: 0,
    }));
    return db;
  };

  test('conversacion: create, relectura, update acotado, relectura; delete denegado a todos', async () => {
    const db = await abrirChat();
    const ref = db.collection('conversaciones').doc('c1');

    let snap = await assertSucceeds(ref.get());
    expect(snap.data().id_mecanico).toBe(UIDS.taller1);

    await assertSucceeds(ref.update({ ultimo_mensaje: 'hola', no_leidos_mecanico: 1 }));
    snap = await assertSucceeds(ref.get());
    expect(snap.data().ultimo_mensaje).toBe('hola');

    // Nadie borra conversaciones: no hay `allow delete` en la regla.
    await assertFails(ref.delete());
    const admin = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(admin.collection('conversaciones').doc('c1').delete());
  });

  test('mensaje: create, relectura, edicion, relectura, delete del autor, relectura', async () => {
    const db = await abrirChat();
    const ref = db.collection('conversaciones').doc('c1').collection('mensajes').doc('m1');

    // `tipo` viaja siempre en el payload real (MensajeModel.toMap()), y la
    // regla de edicion lo exige: omitirlo aqui probaria una forma de
    // documento que el cliente nunca produce.
    await assertSucceeds(ref.set({
      id_remitente: UIDS.owner1, contenido: 'hola', estado: 'enviado', tipo: 'texto',
    }));
    let snap = await assertSucceeds(ref.get());
    expect(snap.data().contenido).toBe('hola');

    await assertSucceeds(ref.update({ contenido: 'hola corregido', editado: true }));
    snap = await assertSucceeds(ref.get());
    expect(snap.data().contenido).toBe('hola corregido');

    await assertSucceeds(ref.delete());
    snap = await assertSucceeds(ref.get());
    expect(snap.exists).toBe(false);
  });

  test('un mensaje heredado sin campo tipo sigue siendo editable por su autor', async () => {
    await abrirChat();
    await seed(env, async (s) => {
      await s.collection('conversaciones').doc('c1').collection('mensajes').doc('viejo')
        .set({ id_remitente: UIDS.owner1, contenido: 'antiguo', estado: 'visto' });
    });
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('conversaciones').doc('c1').collection('mensajes').doc('viejo')
        .update({ contenido: 'antiguo corregido', editado: true }),
    );
  });

  test('un tercero no participante no lee la conversacion ni sus mensajes', async () => {
    await abrirChat();
    const ajeno = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(ajeno.collection('conversaciones').doc('c1').get());
    await assertFails(
      ajeno.collection('conversaciones').doc('c1').collection('mensajes').doc('m1').get(),
    );
  });
});

describe('ciclo de vida: cotizaciones', () => {
  const seedVehiculo = () => seed(env, async (s) => {
    await s.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
    });
  });

  test('borrador: create, relectura y delete del creador', async () => {
    await seedVehiculo();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    const ref = db.collection('cotizaciones').doc('q1');

    await assertSucceeds(ref.set({
      id_mecanico: UIDS.taller1, id_taller: UIDS.taller1, id_propietario: UIDS.owner1,
      id_vehiculo: 'v1', estado: 'draft', items: [{ nombre: 'aceite', precio: 100 }],
    }));
    let snap = await assertSucceeds(ref.get());
    expect(snap.data().estado).toBe('draft');

    await assertSucceeds(ref.delete());
    snap = await assertSucceeds(ref.get());
    expect(snap.exists).toBe(false);
  });

  test('publicar el borrador exige el margen privado, y tras publicar se relee', async () => {
    await seedVehiculo();
    await seed(env, async (s) => {
      await s.collection('cotizaciones').doc('q1').set({
        id_mecanico: UIDS.taller1, id_taller: UIDS.taller1, id_propietario: UIDS.owner1,
        id_vehiculo: 'v1', estado: 'draft', items: [{ nombre: 'aceite', precio: 100 }],
      });
      await s.collection('cotizaciones').doc('q1').collection('privado').doc('margen')
        .set({ beneficios: [20] });
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    const ref = db.collection('cotizaciones').doc('q1');

    await assertSucceeds(ref.update({ estado: 'pendiente' }));
    let snap = await assertSucceeds(ref.get());
    expect(snap.data().estado).toBe('pendiente');

    // El propietario decide sobre la cotizacion ya publicada.
    const duenio = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(duenio.collection('cotizaciones').doc('q1').update({ estado: 'aceptada' }));
    snap = await assertSucceeds(duenio.collection('cotizaciones').doc('q1').get());
    expect(snap.data().estado).toBe('aceptada');
  });

  test('un taller ajeno no lee ni decide sobre la cotizacion', async () => {
    await seedVehiculo();
    await seed(env, async (s) => {
      await s.collection('cotizaciones').doc('q1').set({
        id_mecanico: UIDS.taller1, id_taller: UIDS.taller1, id_propietario: UIDS.owner1,
        id_vehiculo: 'v1', estado: 'pendiente', items: [{ nombre: 'aceite', precio: 100 }],
      });
    });
    const ajeno = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(ajeno.collection('cotizaciones').doc('q1').get());
    await assertFails(ajeno.collection('cotizaciones').doc('q1').update({ estado: 'aceptada' }));
  });
});

describe('ciclo de vida: reservas', () => {
  test('create, relectura, reprogramacion, relectura; delete denegado a todos', async () => {
    // Una cita nace DENTRO de una conversacion (H-01): la regla exige que la
    // conversacion exista y que sus dos participantes sean los mismos que
    // nombra la cita. Esta siembra no lo hacia, o sea modelaba una forma que
    // `ReservaModel.toMap()` no genera nunca — siempre escribe
    // `id_conversacion`, y en `lib/` solo hay un creador de reservas. Se
    // corrige la siembra, no la regla.
    await seed(env, async (s) => {
      await s.collection('conversaciones').doc('c1').set({
        id_conversacion: 'c1',
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        ultimo_mensaje_ts: new Date(),
      });
    });
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    const ref = db.collection('reservas').doc('r1');

    await assertSucceeds(ref.set({
      id_conversacion: 'c1',
      id_propietario: UIDS.owner1, id_mecanico: UIDS.taller1, id_vehiculo: 'v1',
      estado: 'pendiente', id_proponente: UIDS.owner1, fecha_hora_propuesta: 'lunes 10:00',
    }));
    let snap = await assertSucceeds(ref.get());
    expect(snap.data().estado).toBe('pendiente');

    await assertSucceeds(ref.update({
      fecha_hora_propuesta: 'martes 09:00', estado: 'pendiente', id_proponente: UIDS.owner1,
    }));
    snap = await assertSucceeds(ref.get());
    expect(snap.data().fecha_hora_propuesta).toBe('martes 09:00');

    await assertFails(ref.delete());
    const admin = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(admin.collection('reservas').doc('r1').delete());
  });

  test('quien no participa en la reserva no la lee ni la decide', async () => {
    await seed(env, async (s) => {
      await s.collection('reservas').doc('r1').set({
        id_propietario: UIDS.owner1, id_mecanico: UIDS.taller1, estado: 'pendiente',
        id_proponente: UIDS.owner1,
      });
    });
    const ajeno = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(ajeno.collection('reservas').doc('r1').get());
    await assertFails(ajeno.collection('reservas').doc('r1').update({ estado: 'confirmada' }));
  });
});

describe('ciclo de vida: reparaciones (el ticket del taller)', () => {
  const seedTicket = () => seed(env, async (s) => {
    await s.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
      talleres_vinculados: [UIDS.taller1],
    });
    await s.collection('reparaciones').doc('t1').set({
      id_vehiculo: 'v1', id_taller: UIDS.taller1, id_propietario: UIDS.owner1,
      estado: 'recibido',
    });
  });

  test('ningun cliente puede abrir un ticket a mano: el create es exclusivo del backend', async () => {
    const taller = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(taller.collection('reparaciones').doc('t9').set({
      id_vehiculo: 'v1', id_taller: UIDS.taller1, id_propietario: UIDS.owner1, estado: 'recibido',
    }));
    const admin = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(admin.collection('reparaciones').doc('t9').set({
      id_vehiculo: 'v1', id_taller: UIDS.taller1, id_propietario: UIDS.owner1, estado: 'recibido',
    }));
  });

  test('el taller lee, avanza el estado y relee; el delete es del admin', async () => {
    await seedTicket();
    const taller = await withRole(env, UIDS.taller1, 'Taller');
    const ref = taller.collection('reparaciones').doc('t1');

    let snap = await assertSucceeds(ref.get());
    expect(snap.data().estado).toBe('recibido');

    await assertSucceeds(ref.update({ estado: 'en_revision' }));
    snap = await assertSucceeds(ref.get());
    expect(snap.data().estado).toBe('en_revision');

    await assertFails(ref.delete());
    const admin = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(admin.collection('reparaciones').doc('t1').delete());
    snap = await assertSucceeds(admin.collection('reparaciones').doc('t1').get());
    expect(snap.exists).toBe(false);
  });
});

describe('ciclo de vida: resenias', () => {
  const seedServicio = () => seed(env, async (s) => {
    await s.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
    });
    await s.collection('servicios').doc('s1').set({
      id_vehiculo: 'v1', id_taller: UIDS.taller1, tipo_servicio: 'Cambio de aceite',
    });
  });

  test('autor: create sobre un servicio propio, relectura, edicion, relectura, delete, relectura', async () => {
    await seedServicio();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    const ref = db.collection('resenias').doc('re1');

    await assertSucceeds(ref.set({
      id_usuario: UIDS.owner1, id_servicio: 's1', id_taller: UIDS.taller1,
      estrellas: 5, comentario: 'bien',
    }));
    let snap = await assertSucceeds(ref.get());
    expect(snap.data().comentario).toBe('bien');

    await assertSucceeds(ref.update({ comentario: 'muy bien', estrellas: 4 }));
    snap = await assertSucceeds(ref.get());
    expect(snap.data().comentario).toBe('muy bien');

    await assertSucceeds(ref.delete());
    snap = await assertSucceeds(ref.get());
    expect(snap.exists).toBe(false);
  });

  test('no se puede reseñar un servicio que no es de un vehiculo propio', async () => {
    await seedServicio();
    const ajeno = await withRole(env, UIDS.owner2, 'Propietario');
    await assertFails(ajeno.collection('resenias').doc('re2').set({
      id_usuario: UIDS.owner2, id_servicio: 's1', id_taller: UIDS.taller1,
      estrellas: 1, comentario: 'inventada',
    }));
  });

  test('el taller solo puede responder, no reescribir la resenia', async () => {
    await seedServicio();
    await seed(env, async (s) => {
      await s.collection('resenias').doc('re1').set({
        id_usuario: UIDS.owner1, id_servicio: 's1', id_taller: UIDS.taller1,
        estrellas: 1, comentario: 'mal',
      });
    });
    const taller = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      taller.collection('resenias').doc('re1').update({ respuesta_taller: 'lo sentimos' }),
    );
    await assertFails(
      taller.collection('resenias').doc('re1').update({ estrellas: 5, comentario: 'excelente' }),
    );
  });
});

describe('ciclo de vida: talleres (perfil publico)', () => {
  test('admin: create, relectura publica, update, relectura, delete, relectura', async () => {
    const admin = await withRole(env, UIDS.admin, 'Administrador');
    const ref = admin.collection('talleres').doc(UIDS.taller1);

    await assertSucceeds(ref.set({
      id_taller: UIDS.taller1, nombre_taller: 'Taller Uno', estado: 'aprobado',
    }));
    let snap = await assertSucceeds(ref.get());
    expect(snap.data().nombre_taller).toBe('Taller Uno');

    await assertSucceeds(ref.update({ nombre_taller: 'Taller Uno S.A.' }));
    snap = await assertSucceeds(ref.get());
    expect(snap.data().nombre_taller).toBe('Taller Uno S.A.');

    await assertSucceeds(ref.delete());
    snap = await assertSucceeds(ref.get());
    expect(snap.exists).toBe(false);
  });

  test('el propio taller no puede editar ni borrar su ficha publica (la proyecta el backend)', async () => {
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).set({
        id_taller: UIDS.taller1, nombre_taller: 'Taller Uno', estado: 'aprobado',
      });
    });
    const taller = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      taller.collection('talleres').doc(UIDS.taller1).update({ nombre_taller: 'auto-ascenso' }),
    );
    await assertFails(taller.collection('talleres').doc(UIDS.taller1).delete());
  });
});
