const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

/**
 * C3 (Tarea 10) — "ver el perfil del otro desde el chat".
 *
 * La ruta elegida para el subconjunto publico de un CLIENTE es un callable
 * (`obtenerPerfilPublico`, functions/index.js + functions/src/
 * obtenerPerfilPublico.js), no una proyeccion de `firestore.rules`: una
 * regla decide SI un `get()` se permite, nunca QUE campos vienen (RULING R5
 * de este plan) — un `get()` permitido siempre trae el documento completo.
 *
 * Por eso `firestore.rules` NO se toca para esta tarea: `usuarios/{userId}`
 * sigue exactamente como estaba (`isOwner(userId) || isAdmin()`), y este
 * archivo prueba justamente eso — que la puerta de entrada que el callable
 * evita (leer `usuarios/{cliente}` DIRECTO, sin pasar por el subconjunto)
 * sigue cerrada, incluso cuando existe una relacion real (una conversacion
 * compartida) que en la superficie podria parecer motivo para abrirla. El
 * lado del callable (el subconjunto exacto y el gate de "comparten
 * conversacion") se prueba en functions/test/obtener_perfil_publico.test.js,
 * porque un test de reglas no puede probar eso.
 */

let env;
beforeAll(async () => {
  env = await makeEnv();
});
afterAll(async () => {
  await env.cleanup();
});
beforeEach(async () => {
  await env.clearFirestore();
});

describe('perfil publico del contacto de chat — la puerta que el callable evita', () => {
  test('un mecanico NO puede leer usuarios/{cliente} directo, aunque comparta una conversacion real con el', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.owner1).set({
        id_usuario: UIDS.owner1,
        rol: 'Propietario',
        nombre_completo: 'Cliente Real',
        telefono: '7000-0000',
        dui: '01234567-8',
        correo: 'cliente@test.com',
      });
      // La conversacion existe de verdad: si la puerta se abriera "porque
      // hay relacion", esta es la relacion que la abriria.
      await s.collection('conversaciones').doc('conv1').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.owner1,
      });
    });

    await assertFails(db.collection('usuarios').doc(UIDS.owner1).get());
  });

  test('un mecanico sin ninguna conversacion con el cliente tampoco puede leer su documento', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.owner1).set({
        id_usuario: UIDS.owner1,
        rol: 'Propietario',
        nombre_completo: 'Cliente Real',
      });
    });

    await assertFails(db.collection('usuarios').doc(UIDS.owner1).get());
  });

  test('un extraño sin sesion no lee el perfil ajeno', async () => {
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.owner1).set({
        id_usuario: UIDS.owner1,
        rol: 'Propietario',
      });
    });
    await assertFails(anon(env).collection('usuarios').doc(UIDS.owner1).get());
  });

  test('el propio cliente SI sigue pudiendo leer su documento completo', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('usuarios').doc(UIDS.owner1).get());
  });

  test('el directorio publico del mecanico (talleres/{uid}) SI es legible por el cliente, sin relacion previa', async () => {
    // Este es el camino real que usa la pantalla de perfil publico y el
    // encabezado del chat cuando quien mira es un Propietario: lectura
    // directa y anonima de `talleres/{uid}`, sin callable de por medio.
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).set({
        id_taller: UIDS.taller1,
        nombre: 'Taller Uno',
        especialidad: 'Motores',
        calificacion_promedio: 4.5,
        total_resenias: 3,
      });
    });
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('talleres').doc(UIDS.taller1).get());
  });
});
