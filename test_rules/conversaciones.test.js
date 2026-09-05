const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

/**
 * Revision de rama completa — hallazgo C2: `conversaciones.create` dejaba
 * crear una conversacion nombrandose a si mismo como `id_mecanico` y a
 * CUALQUIER otro uid como `id_propietario`, sin relacion previa ni
 * comprobacion de rol. Eso fabricaba, para quien llamara, exactamente la
 * relacion en la que confia el callable `obtenerPerfilPublico`
 * (compartenConversacion): cualquier cuenta autenticada — incluida una
 * cuenta de CLIENTE — podia crear la conversacion y luego leer el
 * subconjunto publico de cualquier cliente por uid.
 *
 * Cobertura de functions/src/publishTallerProfile.js:esMecanico +
 * functions/src/obtenerPerfilPublico.js:llamanteEsMecanico (segunda barrera,
 * en el callable) vive en functions/test/obtener_perfil_publico.test.js: un
 * test de reglas no puede probar ese lado. Este archivo prueba solo la regla.
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

describe('conversaciones create (hallazgo C2: la relacion que el callable confia era auto-fabricable)', () => {
  test('el propietario SI puede crear una conversacion sobre si mismo (inicia el chat desde el directorio)', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('conversaciones').doc('conv1').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
      }),
    );
  });

  test('el mecanico SI puede crear una conversacion en nombre de SU PROPIO taller', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('conversaciones').doc('conv1').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
      }),
    );
  });

  test('una CUENTA DE CLIENTE (rol Propietario) NO puede crear una conversacion nombrandose id_mecanico de una victima (hallazgo C2, el ataque central)', async () => {
    // Este es exactamente el ataque: cli2 (un cliente cualquiera, sin rol de
    // mecanico ni relacion previa) se nombra id_mecanico y designa a owner1
    // como la victima id_propietario, para luego poder invocar
    // obtenerPerfilPublico contra ella.
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await assertFails(
      db.collection('conversaciones').doc('conv-ataque').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.owner2,
        id_taller: UIDS.owner2,
      }),
    );
  });

  test('un mecanico NO puede crear una conversacion en nombre de un taller AJENO', async () => {
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('conversaciones').doc('conv-ajeno').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller2,
        id_taller: UIDS.taller1, // taller ajeno
      }),
    );
  });

  test('un empleado SI puede crear la conversacion en nombre del taller de su dueño (actuaPorTaller)', async () => {
    const db = await withRole(env, UIDS.empleado1, 'Mecanico', {
      id_taller_propietario: UIDS.taller1,
    });
    await assertSucceeds(
      db.collection('conversaciones').doc('conv-empleado').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.empleado1,
        id_taller: UIDS.taller1,
      }),
    );
  });

  test('sin sesion no se puede crear ninguna conversacion', async () => {
    const { anon } = require('./helpers');
    await assertFails(
      anon(env).collection('conversaciones').doc('conv-anon').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
      }),
    );
  });
});
