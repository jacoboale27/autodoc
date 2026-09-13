const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

/**
 * INNO-01 — `tokens_historial` esta cerrada a TODO cliente.
 *
 * Un pase es un secreto portador: quien lo tiene, ve el historial. Por eso el
 * riesgo no es solo que alguien fabrique un pase, sino que pueda LISTAR la
 * coleccion y cosechar los pases vivos de otros. Las dos mitades se ejercen
 * aqui, y con el administrador incluido: en este repo `isAdmin()` abre muchas
 * colecciones y esta no debe ser una de ellas.
 *
 * Los tres callables corren con Admin SDK y no pasan por estas reglas. Su
 * autorizacion se prueba en `functions/test/historial_compartido.test.js`;
 * aqui se prueba que el cliente no tiene ningun camino alternativo.
 */

let env;
beforeAll(async () => {
  env = await makeEnv();
}, 30000);
afterAll(async () => {
  await env.cleanup();
});
beforeEach(async () => {
  await env.clearFirestore();
}, 30000);

const PASE = {
  id_vehiculo: 'v1',
  id_propietario: UIDS.owner1,
  creado_en: 1700000000000,
  expira_en: 1700000900000,
  revocado: false,
};

async function sembrarBase() {
  await seed(env, async (db) => {
    await db.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1',
      id_propietario: UIDS.owner1,
      placa: 'ABC123',
    });
    await db.collection('tokens_historial').doc('pase1').set(PASE);
  });
}

describe('tokens_historial: cerrada a los clientes por los dos lados', () => {
  describe('lectura', () => {
    test('el propio propietario NO puede leer su pase', async () => {
      // Ni siquiera el emisor: la app no necesita releerlo —el callable ya le
      // devolvio el token— y permitirlo abriria el `list` por la puerta de al
      // lado.
      await sembrarBase();
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await assertFails(db.collection('tokens_historial').doc('pase1').get());
    });

    test('un taller no puede leer un pase', async () => {
      await sembrarBase();
      const db = await withRole(env, UIDS.taller1, 'Taller');
      await assertFails(db.collection('tokens_historial').doc('pase1').get());
    });

    test('el administrador tampoco', async () => {
      await sembrarBase();
      const db = await withRole(env, UIDS.admin, 'Administrador');
      await assertFails(db.collection('tokens_historial').doc('pase1').get());
    });

    test('un anonimo tampoco', async () => {
      await sembrarBase();
      await assertFails(anon(env).collection('tokens_historial').doc('pase1').get());
    });

    test('NADIE puede listar la coleccion y cosechar pases vivos', async () => {
      await sembrarBase();
      const propietario = await withRole(env, UIDS.owner1, 'Propietario');
      const taller = await withRole(env, UIDS.taller1, 'Taller');
      const admin = await withRole(env, UIDS.admin, 'Administrador');

      await assertFails(propietario.collection('tokens_historial').get());
      await assertFails(taller.collection('tokens_historial').get());
      await assertFails(admin.collection('tokens_historial').get());
    });
  });

  describe('escritura', () => {
    test('nadie puede fabricarse un pase para un vehiculo ajeno', async () => {
      await sembrarBase();
      const db = await withRole(env, UIDS.taller1, 'Taller');
      await assertFails(
        db.collection('tokens_historial').doc('inventado').set({
          ...PASE,
          id_propietario: UIDS.taller1,
        }),
      );
    });

    test('el propietario no puede fabricarse un pase saltandose el callable', async () => {
      await sembrarBase();
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await assertFails(
        db.collection('tokens_historial').doc('inventado').set(PASE),
      );
    });

    test('no se puede estirar el vencimiento de un pase', async () => {
      await sembrarBase();
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await assertFails(
        db
          .collection('tokens_historial')
          .doc('pase1')
          .update({ expira_en: 9999999999999 }),
      );
    });

    test('no se puede des-revocar un pase que el propietario anulo', async () => {
      await sembrarBase();
      await seed(env, async (db) => {
        await db
          .collection('tokens_historial')
          .doc('pase2')
          .set({ ...PASE, revocado: true });
      });
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await assertFails(
        db.collection('tokens_historial').doc('pase2').update({ revocado: false }),
      );
    });

    test('no se puede borrar un pase desde el cliente', async () => {
      await sembrarBase();
      const propietario = await withRole(env, UIDS.owner1, 'Propietario');
      const admin = await withRole(env, UIDS.admin, 'Administrador');
      await assertFails(
        propietario.collection('tokens_historial').doc('pase1').delete(),
      );
      await assertFails(admin.collection('tokens_historial').doc('pase1').delete());
    });
  });

  describe('control positivo: la siembra es alcanzable de verdad', () => {
    test('el mismo propietario SI lee su vehiculo', async () => {
      // Sin este caso, los negativos de arriba no probarian nada sobre
      // `tokens_historial`: probarian que la siembra esta rota.
      await sembrarBase();
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await assertSucceeds(db.collection('vehiculos').doc('v1').get());
    });
  });
});
