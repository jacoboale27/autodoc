const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, UIDS, limpiarStorage } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); }, 30000);
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await limpiarStorage(env); await env.clearFirestore(); }, 30000);

const imagen = (kb) => Buffer.alloc(kb * 1024, 1);
const META_JPEG = { contentType: 'image/jpeg' };

// Un taller que YA estaba vinculado a un vehiculo y despues pierde la
// habilitacion de su cuenta.
//
// `firestore.rules` lo deniega: su `isMecanico()` (linea 45-50) exige ademas
// `estado in ['aprobado','activo']`. `storage.rules` NO: su `isMecanico()`
// (linea 33-38) mira solo el `rol`, y es la que usa `isVinculadoAlVehiculo()`,
// que a su vez autoriza `facturas/{vehicleId}`.
//
// Esa asimetria esta documentada en storage.rules, pero la razon que da cubre
// el EXPEDIENTE DE VERIFICACION —que por definicion se sube con la cuenta aun
// sin aprobar— y no las facturas de un vehiculo ajeno. Para eso ya existe
// `esTallerAprobado()` en el mismo archivo.
//
// Ningun test lo veia porque `storage.test.js:17` siembra siempre
// `estado: 'activo'`.
const seedTaller = (uid, estado) => seed(env, async (db) => {
  await db.collection('usuarios').doc(uid).set({
    id_usuario: uid, rol: 'Taller', estado,
  });
});

const seedVehiculo = (id, propietario, vinculados) => seed(env, async (db) => {
  await db.collection('vehiculos').doc(id).set({
    id_vehiculo: id, id_propietario: propietario, talleres_vinculados: vinculados,
  });
});

describe('storage: un taller vinculado pero SUSPENDIDO no conserva las facturas', () => {
  test('no puede LEER las facturas del vehiculo al que seguia vinculado', async () => {
    await seedTaller(UIDS.taller1, 'suspendido');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(st.ref('facturas/v1/f.jpg').getDownloadURL());
  });

  test('no puede ESCRIBIR una factura en ese vehiculo', async () => {
    await seedTaller(UIDS.taller1, 'suspendido');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertFails(st.ref('facturas/v1/f.jpg').put(imagen(100), META_JPEG));
  });

  // Control positivo: el mismo taller, con la cuenta habilitada, SI puede.
  // Sin esto, un `hasOnly` demasiado estrecho rompe el flujo real del taller
  // y los dos negativos de arriba seguirian verdes sin probar nada.
  test('el mismo taller, aprobado, SI puede escribir la factura', async () => {
    await seedTaller(UIDS.taller1, 'aprobado');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertSucceeds(st.ref('facturas/v1/f.jpg').put(imagen(100), META_JPEG));
  });
});
