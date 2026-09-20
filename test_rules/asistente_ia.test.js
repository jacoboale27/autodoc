const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

/**
 * Asistente de agenda con IA (plan 2026-09-19) — sus tres colecciones estan
 * cerradas a todo cliente.
 *
 * El callable `asistenteAutoDoc` corre con Admin SDK y no pasa por estas
 * reglas; su autorizacion se prueba en `functions/test/asistente.test.js` y
 * `functions/test/agenda.test.js`. Lo que se prueba AQUI es que el cliente no
 * tiene ningun camino alternativo — que es justo la leccion de FUNC-02, donde
 * un `allow create: if false` no alcanzaba a un callable que hacia lo mismo
 * por detras.
 *
 * Cada coleccion se cierra por un motivo distinto, y los tres importan:
 *
 *   - `consultas_ia_control`: si el cliente pudiera escribirlo, pondria su
 *     contador a cero entre consulta y consulta y el limite seria decoracion.
 *     La factura la paga el free tier de Gemini. Y leerlo permitiria enumerar
 *     que uids usan el asistente y cuanto.
 *   - `explicaciones_ia`: quien pudiera escribir aqui estaria **poniendo
 *     palabras en boca del asistente para todos los demas usuarios**. Es la
 *     unica inyeccion de prompt con efecto persistente que este diseño
 *     admitiria.
 *   - `configuracion`: es el interruptor de apagado. Escribirlo es apagar (o
 *     encender) la feature para todo el mundo sin desplegar.
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

async function sembrarBase() {
  await seed(env, async (db) => {
    await db.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1',
      id_propietario: UIDS.owner1,
      placa: 'ABC123',
    });
    await db.collection('consultas_ia_control').doc(UIDS.owner1).set({
      ventana_inicio: 1700000000000,
      conteo: 7,
      expira_en: new Date(1700086400000),
    });
    await db.collection('consultas_ia_control').doc('_global').set({
      ventana_inicio: 1700000000000,
      conteo: 150,
      expira_en: new Date(1700086400000),
    });
    await db.collection('explicaciones_ia').doc('clave1').set({
      texto: 'El SOAT es el seguro obligatorio.',
      idioma: 'es',
    });
    await db.collection('configuracion').doc('asistente_ia').set({ activo: true });
  });
}

describe('consultas_ia_control: el contador de cuota es intocable', () => {
  test('el propio usuario NO puede leer su contador', async () => {
    await sembrarBase();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(db.collection('consultas_ia_control').doc(UIDS.owner1).get());
  });

  test('el propio usuario NO puede ponerlo a cero', async () => {
    // Es el ataque obvio y el unico que hace falta: sin esto, el limite de 10
    // consultas al dia se salta con un `update({conteo: 0})` entre consulta y
    // consulta.
    await sembrarBase();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('consultas_ia_control').doc(UIDS.owner1).update({ conteo: 0 }),
    );
  });

  test('tampoco puede borrarlo, que es ponerlo a cero con pasos de mas', async () => {
    await sembrarBase();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(db.collection('consultas_ia_control').doc(UIDS.owner1).delete());
  });

  test('nadie puede tocar el cubo global', async () => {
    await sembrarBase();
    const propietario = await withRole(env, UIDS.owner1, 'Propietario');
    const taller = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      propietario.collection('consultas_ia_control').doc('_global').update({ conteo: 0 }),
    );
    await assertFails(
      taller.collection('consultas_ia_control').doc('_global').update({ conteo: 0 }),
    );
  });

  test('el administrador tampoco, ni leer ni escribir', async () => {
    // En este repo `isAdmin()` abre muchas colecciones. Esta no.
    await sembrarBase();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(db.collection('consultas_ia_control').doc(UIDS.owner1).get());
    await assertFails(
      db.collection('consultas_ia_control').doc(UIDS.owner1).update({ conteo: 0 }),
    );
  });

  test('NADIE puede listar la coleccion y ver quien usa el asistente', async () => {
    await sembrarBase();
    const propietario = await withRole(env, UIDS.owner1, 'Propietario');
    const admin = await withRole(env, UIDS.admin, 'Administrador');
    const superusuario = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertFails(propietario.collection('consultas_ia_control').get());
    await assertFails(admin.collection('consultas_ia_control').get());
    await assertFails(superusuario.collection('consultas_ia_control').get());
  });

  test('un anonimo tampoco', async () => {
    await sembrarBase();
    await assertFails(anon(env).collection('consultas_ia_control').doc(UIDS.owner1).get());
  });
});

describe('explicaciones_ia: nadie pone palabras en boca del asistente', () => {
  test('un usuario no puede reescribir una explicacion cacheada', async () => {
    // Este es el caso de mas peso del archivo. La cache es GLOBAL: lo que se
    // escriba aqui se le sirve a todos los demas usuarios como si lo hubiera
    // dicho AutoDoc.
    await sembrarBase();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('explicaciones_ia').doc('clave1').update({
        texto: 'El SOAT no hace falta, puedes conducir sin el.',
      }),
    );
  });

  test('un usuario no puede sembrar una entrada nueva en la cache', async () => {
    await sembrarBase();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('explicaciones_ia').doc('inventada').set({ texto: 'lo que sea' }),
    );
  });

  test('un taller tampoco, ni el administrador', async () => {
    await sembrarBase();
    const taller = await withRole(env, UIDS.taller1, 'Taller');
    const admin = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      taller.collection('explicaciones_ia').doc('clave1').update({ texto: 'x' }),
    );
    await assertFails(admin.collection('explicaciones_ia').doc('clave1').update({ texto: 'x' }));
  });

  test('tampoco se puede leer ni listar desde el cliente', async () => {
    await sembrarBase();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(db.collection('explicaciones_ia').doc('clave1').get());
    await assertFails(db.collection('explicaciones_ia').get());
  });
});

describe('configuracion: el interruptor de apagado', () => {
  test('un usuario no puede apagar el asistente para todo el mundo', async () => {
    await sembrarBase();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('configuracion').doc('asistente_ia').update({ activo: false }),
    );
  });

  test('un administrador tampoco: el interruptor es de Superusuario', async () => {
    await sembrarBase();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      db.collection('configuracion').doc('asistente_ia').update({ activo: false }),
    );
  });

  test('el Superusuario SI puede apagarlo', async () => {
    // El positivo del interruptor. Sin el, «nadie puede escribir» seria cierto
    // tambien con la regla puesta a `if false`, y el dia que hiciera falta
    // apagar la feature no habria forma de hacerlo sin desplegar — que es
    // exactamente lo que este interruptor existe para evitar.
    await sembrarBase();
    const db = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertSucceeds(
      db.collection('configuracion').doc('asistente_ia').update({ activo: false }),
    );
  });

  test('nadie lee la configuracion desde el cliente, ni el Superusuario', async () => {
    // La lee el servidor con Admin SDK. Que la app sepa si el asistente esta
    // encendido no le compra nada: el callable ya devuelve `unavailable`.
    await sembrarBase();
    const superusuario = await withRole(env, UIDS.superusuario, 'Superusuario');
    const propietario = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(superusuario.collection('configuracion').doc('asistente_ia').get());
    await assertFails(propietario.collection('configuracion').doc('asistente_ia').get());
  });
});

describe('configuracion: la forma del ajuste, no solo quien escribe', () => {
  // Los cuatro casos de aqui los levanto el gate de reglas. El `allow write`
  // original cubria create, update Y delete sobre CUALQUIER `{ajuste}`.

  test('NADIE puede borrar el documento: borrarlo reenciende la feature', async () => {
    // `estaEncendido()` trata la ausencia como ENCENDIDO a proposito. Con
    // `delete` permitido, «apagado» era un estado que desaparecia con una
    // operacion autorizada y sin dejar ninguna huella.
    await sembrarBase();
    const db = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertFails(db.collection('configuracion').doc('asistente_ia').delete());
  });

  test('no se puede crear otro ajuste cualquiera en la coleccion', async () => {
    // `configuracion` es un nombre generico: sin pinear `{ajuste}`, la proxima
    // feature que lea de aqui hereda una superficie de escritura sin validar.
    await sembrarBase();
    const db = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertFails(
      db.collection('configuracion').doc('loquesea').set({ activo: true }),
    );
  });

  test('`activo` tiene que ser booleano, no la cadena "false"', async () => {
    // El servidor lee `activo !== false`. Un `{activo: 'false'}` escrito a
    // mano dejaba la feature ENCENDIDA mientras la consola mostraba un campo
    // que parece apagarla.
    await sembrarBase();
    const db = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertFails(
      db.collection('configuracion').doc('asistente_ia').update({ activo: 'false' }),
    );
    await assertFails(
      db.collection('configuracion').doc('asistente_ia').update({ activo: 0 }),
    );
  });

  test('no se pueden colar campos de mas junto a `activo`', async () => {
    await sembrarBase();
    const db = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertFails(
      db.collection('configuracion').doc('asistente_ia').set({ activo: false, extra: 1 }),
    );
  });

  test('el Superusuario SI puede crearlo si no existe', async () => {
    // Nadie siembra este documento: ni `functions/` ni `lib/` lo crean. Sin
    // `create`, la primera vez que hiciera falta apagar la feature no habria
    // forma de hacerlo sin desplegar — que es justo lo que el interruptor
    // existe para evitar.
    const db = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertSucceeds(
      db.collection('configuracion').doc('asistente_ia').set({ activo: false }),
    );
  });
});

describe('las otras dos colecciones no se abren por el Superusuario', () => {
  // `isSuperUser()` SI abre `configuracion`. Estos dos casos pinean que no
  // abre las otras dos: sin ellos, alguien podria «unificar» las tres reglas
  // creyendo que son equivalentes.

  test('el Superusuario no toca el contador de cuota', async () => {
    await sembrarBase();
    const db = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertFails(db.collection('consultas_ia_control').doc(UIDS.owner1).get());
    await assertFails(
      db.collection('consultas_ia_control').doc(UIDS.owner1).update({ conteo: 0 }),
    );
  });

  test('el Superusuario no reescribe la cache de explicaciones', async () => {
    await sembrarBase();
    const db = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertFails(
      db.collection('explicaciones_ia').doc('clave1').update({ texto: 'lo que sea' }),
    );
  });
});

describe('create, que es una rama distinta de update', () => {
  // La distincion create/update ya mordio en GAPS-05 con Storage: un documento
  // AUSENTE evalua otra rama, y los tests de arriba operan todos sobre
  // documentos ya sembrados. Un `set()` sobre un id inexistente es un `create`.

  test('no se puede crear un contador de cuota de la nada', async () => {
    await sembrarBase();
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await assertFails(
      db.collection('consultas_ia_control').doc(UIDS.owner2).set({ conteo: 0 }),
    );
  });

  test('no se puede crear el cubo global si alguien lo borrara', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('consultas_ia_control').doc('_global').set({ conteo: 0 }),
    );
  });

  test('no se puede sembrar una entrada de cache de la nada', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('explicaciones_ia').doc('nueva').set({ texto: 'inventado' }),
    );
  });
});

describe('subcolecciones: rules v2 no cascadea, y esto lo afirma', () => {
  test('no se puede escribir bajo una subcoleccion de estas rutas', async () => {
    // Es una propiedad implicita de rules v2 (sin `{document=**}` no hay
    // cascada). Convertirla en afirmacion cuesta un test y protege de que
    // alguien anada un comodin mas arriba sin darse cuenta.
    await sembrarBase();
    const superusuario = await withRole(env, UIDS.superusuario, 'Superusuario');
    const propietario = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      superusuario.collection('configuracion').doc('asistente_ia').collection('sub').doc('x').set({ a: 1 }),
    );
    await assertFails(
      propietario.collection('explicaciones_ia').doc('clave1').collection('sub').doc('x').set({ a: 1 }),
    );
    await assertFails(
      propietario.collection('consultas_ia_control').doc(UIDS.owner1).collection('sub').doc('x').set({ a: 1 }),
    );
  });
});

describe('control positivo: la siembra es alcanzable de verdad', () => {
  test('el mismo propietario SI lee su vehiculo', async () => {
    // Sin este caso, todos los negativos de arriba podrian estar pasando
    // porque la siembra esta rota y no porque las reglas denieguen. Es la
    // misma guarda que lleva `tokens_historial.test.js`.
    await sembrarBase();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('vehiculos').doc('v1').get());
  });
});
