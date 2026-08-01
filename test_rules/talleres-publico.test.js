const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

describe('datos legitimamente publicos', () => {
  test('el directorio de talleres SI es legible sin autenticar', async () => {
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).set({
        id_taller: UIDS.taller1, nombre: 'Taller Uno', especialidad: 'Motores',
        calificacion_promedio: 4.5, total_resenias: 2,
      });
    });
    await assertSucceeds(anon(env).collection('talleres').get());
  });

  test('las resenias NO son legibles sin autenticar', async () => {
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1,
        estrellas: 5, comentario: 'Excelente',
      });
    });
    await assertFails(anon(env).collection('resenias').get());
  });

  test('un usuario autenticado SI puede leer resenias', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner2, id_taller: UIDS.taller1, estrellas: 4,
      });
    });
    await assertSucceeds(db.collection('resenias').get());
  });

  test('un usuario NO puede resenar un taller sin servicio previo', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('resenias').add({
        id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 1,
        comentario: 'resena falsa', id_servicio: 'no-existe',
      }),
    );
  });

  test('el autor NO puede reapuntar su resenia a otro taller', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 5,
      });
    });
    await assertFails(db.collection('resenias').doc('r1').update({ id_taller: UIDS.taller2 }));
  });

  test('un usuario NO puede resenar con un id_taller distinto al del servicio real', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1, marca: 'Test',
      });
      await s.collection('servicios').doc('s1').set({
        id_servicio: 's1', id_vehiculo: 'v1', id_taller: UIDS.taller1,
      });
    });
    await assertFails(
      db.collection('resenias').add({
        id_usuario: UIDS.owner1, id_taller: UIDS.taller2, estrellas: 5,
        comentario: 'sabotaje de reputacion', id_servicio: 's1',
      }),
    );
  });

  test('un usuario SI puede resenar con el id_taller correcto del servicio real', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1, marca: 'Test',
      });
      await s.collection('servicios').doc('s1').set({
        id_servicio: 's1', id_vehiculo: 'v1', id_taller: UIDS.taller1,
      });
    });
    await assertSucceeds(
      db.collection('resenias').add({
        id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 5,
        comentario: 'buen servicio', id_servicio: 's1',
      }),
    );
  });

  test('el autor SI puede actualizar comentario, estrellas y fecha_resenia (flujo real de la app)', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial',
      });
    });
    await assertSucceeds(
      db.collection('resenias').doc('r1').update({
        comentario: 'editado', estrellas: 5, fecha_resenia: new Date(),
      }),
    );
  });

  test('el autor NO puede modificar campos fuera de comentario/estrellas/fecha_resenia', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial',
      });
    });
    await assertFails(
      db.collection('resenias').doc('r1').update({ id_usuario: UIDS.owner2 }),
    );
  });

  test('el taller dueño de la resenia SI puede escribir respuesta_taller', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial',
      });
    });
    await assertSucceeds(
      db.collection('resenias').doc('r1').update({ respuesta_taller: 'Gracias por su comentario' }),
    );
  });

  test('el taller NO puede tocar el contenido original vía respuesta_taller', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial',
      });
    });
    await assertFails(
      db.collection('resenias').doc('r1').update({
        respuesta_taller: 'Gracias', estrellas: 5,
      }),
    );
  });

  test('un taller que NO es dueño de la resenia NO puede escribir respuesta_taller', async () => {
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial',
      });
    });
    await assertFails(
      db.collection('resenias').doc('r1').update({ respuesta_taller: 'Intento ajeno' }),
    );
  });

  test('cualquier usuario autenticado SI puede marcar is_reported=true (bug de reportReview corregido)', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller2, estrellas: 3,
        comentario: 'inicial', is_reported: false,
      });
    });
    await assertSucceeds(
      db.collection('resenias').doc('r1').update({ is_reported: true }),
    );
  });

  test('un usuario NO puede des-reportar (is_reported=false) via update', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial', is_reported: true,
      });
    });
    await assertFails(
      db.collection('resenias').doc('r1').update({ is_reported: false }),
    );
  });

  test('un usuario NO puede combinar is_reported=true con otro campo en el mismo update', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial', is_reported: false,
      });
    });
    await assertFails(
      db.collection('resenias').doc('r1').update({ is_reported: true, estrellas: 1 }),
    );
  });

  test('el autor SI puede actualizar fotos', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial',
      });
    });
    await assertSucceeds(
      db.collection('resenias').doc('r1').update({ fotos: ['https://example.com/foto.jpg'] }),
    );
  });

  test('el admin SI puede actualizar una resenia aunque no sea autor ni taller', async () => {
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial',
      });
    });
    await assertSucceeds(
      db.collection('resenias').doc('r1').update({ comentario: 'moderado' }),
    );
  });

  test('el admin NO puede reasignar id_taller vía update (el override de moderación no es un bypass total)', async () => {
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial',
      });
    });
    await assertFails(
      db.collection('resenias').doc('r1').update({ id_taller: UIDS.taller2 }),
    );
  });

  test('el admin NO puede reasignar id_usuario vía update', async () => {
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial',
      });
    });
    await assertFails(
      db.collection('resenias').doc('r1').update({ id_usuario: UIDS.owner2 }),
    );
  });

  test('el admin NO puede reasignar id_servicio vía update', async () => {
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial', id_servicio: 's1',
      });
    });
    await assertFails(
      db.collection('resenias').doc('r1').update({ id_servicio: 's2' }),
    );
  });

  test('el admin NO puede reasignar id_taller aunque lo combine con un campo de moderación legítimo', async () => {
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 3,
        comentario: 'inicial',
      });
    });
    await assertFails(
      db.collection('resenias').doc('r1').update({ comentario: 'moderado', id_taller: UIDS.taller2 }),
    );
  });
});

describe('proyeccion de perfil publico', () => {
  test('un mecanico NO puede escribir directamente en talleres', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).set({
        id_taller: UIDS.taller1, nombre: 'Autoproclamado',
      }),
    );
  });
});
