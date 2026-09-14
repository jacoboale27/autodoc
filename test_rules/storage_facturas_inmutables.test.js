const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, UIDS, limpiarStorage } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); }, 30000);
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await limpiarStorage(env); await env.clearFirestore(); }, 30000);

const archivo = (kb) => Buffer.alloc(kb * 1024, 1);
const META_JPEG = { contentType: 'image/jpeg' };

// GAPS-05 — el P1 de facturas de la auditoria final, corregido en su premisa.
//
// EL CARGO ORIGINAL NO SE SOSTIENE, y comprobarlo era el trabajo.
// La auditoria dice: «un taller aprobado que conserve vinculo con el vehiculo
// puede subir una factura aunque no haya un ticket abierto; leer el historico
// con el vinculo es razonable, crear evidencia financiera deberia exigir
// trabajo vigente». Eso describe el significado que `talleres_vinculados`
// tenia ANTES de la ronda 5. Hoy el vinculo **es** posesion del coche:
// `vinculoTaller.js` lo otorga al RECIBIR el vehiculo y lo revoca al CERRARSE
// el ticket, y son sus dos unicos escritores. O sea que «estar vinculado» ya
// significa «tiene el coche ahora mismo», que es exactamente el «trabajo
// vigente» que el cargo pedia. La unica ventana en que se separan es una
// revocacion fallida, y desde GAPS-04 el barrido reintenta esos tickets
// PRIMERO y sin el filtro de 30 dias, asi que dura una corrida diaria.
//
// EL AGUJERO DE VERDAD ES OTRO, y estaba al lado: `allow write` cubre create,
// update Y delete. El bloque deniega el `delete` a todo el que no sea admin
// —«las facturas son el rastro documental del producto»— y a la vez deja
// SOBRESCRIBIR el archivo a cualquiera que tenga el vinculo. Sobrescribir una
// factura es borrarla con pasos extra: el rastro documental desaparece igual,
// y encima queda una factura distinta con el nombre de la vieja.
//
// Cerrarlo no rompe nada porque la app NUNCA sobrescribe: los nombres son
// `<epoch-ms><extension>` (`alert_provider.dart:441` y `:609`), asi que cada
// subida estrena ruta. Comprobar eso antes de tocar la regla es lo que
// distingue este cambio de romper el flujo de subir facturas.
const seedTaller = (uid, estado) => seed(env, async (db) => {
  await db.collection('usuarios').doc(uid).set({
    id_usuario: uid, rol: 'Taller', estado,
  });
});

const seedAdmin = (uid) => seed(env, async (db) => {
  await db.collection('usuarios').doc(uid).set({
    id_usuario: uid, rol: 'Administrador', estado: 'activo',
  });
});

const seedVehiculo = (id, propietario, vinculados) => seed(env, async (db) => {
  await db.collection('vehiculos').doc(id).set({
    id_vehiculo: id, id_propietario: propietario, talleres_vinculados: vinculados,
  });
});

/** Sube el archivo saltandose las reglas, para partir de una factura ya existente. */
const sembrarFactura = (ruta) =>
  env.withSecurityRulesDisabled(async (ctx) =>
    ctx.storage().ref(ruta).put(archivo(1), META_JPEG),
  );

describe('storage: una factura subida no se puede sobrescribir', () => {
  test('el taller vinculado SI puede crear una factura nueva', async () => {
    await seedTaller(UIDS.taller1, 'activo');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertSucceeds(
      st.ref('facturas/v1/1757800000000.jpg').put(archivo(1), META_JPEG),
    );
  });

  test('el propietario tambien', async () => {
    await seedVehiculo('v1', UIDS.owner1, []);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(
      st.ref('facturas/v1/1757800000001.jpg').put(archivo(1), META_JPEG),
    );
  });

  test('pero el taller NO puede sobrescribir una factura ya subida', async () => {
    await seedTaller(UIDS.taller1, 'activo');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    await sembrarFactura('facturas/v1/1757800000000.jpg');
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(
      st.ref('facturas/v1/1757800000000.jpg').put(archivo(1), META_JPEG),
    );
  });

  test('ni el propietario del vehiculo', async () => {
    // El dueño tampoco: el valor de la factura como prueba viene de que nadie
    // la pueda cambiar despues, y el dueño es justo quien tiene motivo para
    // maquillar el historial antes de vender el coche — el mismo razonamiento
    // que `auto_declarado` en INNO-01.
    await seedVehiculo('v1', UIDS.owner1, []);
    await sembrarFactura('facturas/v1/1757800000001.jpg');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref('facturas/v1/1757800000001.jpg').put(archivo(1), META_JPEG),
    );
  });

  test('un admin si puede reemplazarla', async () => {
    await seedAdmin(UIDS.admin);
    await seedVehiculo('v1', UIDS.owner1, []);
    await sembrarFactura('facturas/v1/1757800000002.jpg');
    const st = env.authenticatedContext(UIDS.admin).storage();
    await assertSucceeds(
      st.ref('facturas/v1/1757800000002.jpg').put(archivo(1), META_JPEG),
    );
  });

  test('un taller SIN vinculo sigue sin poder crear nada', async () => {
    await seedTaller(UIDS.taller2, 'activo');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller2).storage();
    await assertFails(
      st.ref('facturas/v1/1757800000003.jpg').put(archivo(1), META_JPEG),
    );
  });
});
