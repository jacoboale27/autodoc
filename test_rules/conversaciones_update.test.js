const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

/**
 * Revision adversarial (Ronda 3): `conversaciones.update` era la unica regla
 * de la rama que quedo sin acotar. Cualquiera de los dos participantes podia
 * reescribir CUALQUIER campo del documento — y la Tarea 9 (C1) acababa de
 * desnormalizar ahi el nombre y la foto que la bandeja y la cabecera del chat
 * pintan, asi que lo que quedaba abierto era identidad renderizada en
 * pantalla.
 *
 * Cinco ataques pasaban contra las reglas de la propia rama, y encadenados
 * con el `create` de mensajes (que si esta bien atado a `id_remitente`) el
 * atacante seguia siendo participante despues de redirigir el hilo: podia
 * escribir en la bandeja de la victima con el nombre y el avatar que
 * eligiera. `conversaciones.test.js` cubria solo `create`; no habia ni un
 * caso de `update`.
 *
 * Los cinco ataques estan abajo, mas los tres flujos legitimos que la app si
 * hace (`ChatRepository` es el unico escritor de esta coleccion en lib/).
 */

let env;
beforeAll(async () => {
  env = await makeEnv();
}, 60000);
afterAll(async () => {
  await env.cleanup();
});
beforeEach(async () => {
  await env.clearFirestore();
});

const seedConversacion = async (overrides = {}) => {
  await seed(env, async (s) => {
    await s.collection('conversaciones').doc('c1').set({
      id_propietario: UIDS.owner1,
      id_mecanico: UIDS.taller1,
      id_taller: UIDS.taller1,
      nombre_propietario: 'Cliente Real',
      nombre_mecanico: 'Taller Real',
      foto_mecanico: 'https://example.com/real.jpg',
      ultimo_mensaje: 'hola',
      no_leidos_propietario: 0,
      no_leidos_mecanico: 0,
      ...overrides,
    });
  });
};

const conv = (db) => db.collection('conversaciones').doc('c1');

describe('conversaciones update: los cinco ataques que pasaban', () => {
  test('ATAQUE 1: mover id_propietario al uid de una victima inyecta el hilo en SU bandeja', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(conv(db).update({ id_propietario: UIDS.owner2 }));
  });

  test('ATAQUE 2: endosar id_mecanico a un tercero', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(conv(db).update({ id_mecanico: UIDS.taller2 }));
  });

  test('ATAQUE 3: suplantacion visual reescribiendo el nombre y la foto denormalizados (C1)', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      conv(db).update({
        nombre_mecanico: 'Taller Oficial Verificado',
        foto_mecanico: 'https://example.com/suplantada.jpg',
      }),
    );
  });

  test('ATAQUE 4: apuntar id_taller a un taller ajeno', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(conv(db).update({ id_taller: UIDS.taller2 }));
  });

  test('ATAQUE 5: inflar el contador de no leidos DEL OTRO sin enviar nada... se permite (es la direccion legitima), pero bajar el ajeno no', async () => {
    // Subir el contador del otro es exactamente lo que hace `enviarMensaje`,
    // asi que la regla no puede distinguirlo y no lo intenta. Lo que si se
    // cierra es la direccion contraria: marcar como leido el buzon AJENO,
    // que borraria de la vista del otro los mensajes que no ha visto.
    await seedConversacion({ no_leidos_propietario: 7 });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(conv(db).update({ no_leidos_propietario: 0 }));
  });

  test('ATAQUE 6: fingir que la contraparte esta escribiendo', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(conv(db).update({ typing_id: UIDS.owner1 }));
  });

  test('un tercero que no participa no puede tocar nada', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await assertFails(conv(db).update({ ultimo_mensaje: 'mio' }));
  });
});

describe('conversaciones update: los tres flujos que la app si hace', () => {
  test('enviarMensaje: cola del ultimo mensaje + incremento del contador del OTRO', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      conv(db).update({
        ultimo_mensaje: 'nuevo',
        ultimo_mensaje_ts: new Date(),
        no_leidos_mecanico: 1,
      }),
    );
  });

  test('marcarComoLeidos: cada participante resetea a 0 su PROPIO contador', async () => {
    await seedConversacion({ no_leidos_mecanico: 4 });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(conv(db).update({ no_leidos_mecanico: 0 }));
  });

  test('setTypingStatus: marcarse a uno mismo, y volver a null', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(conv(db).update({ typing_id: UIDS.taller1 }));
    await assertSucceeds(conv(db).update({ typing_id: null }));
  });
});
