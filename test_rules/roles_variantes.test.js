const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// ROLE-01 — firestore.rules compara `rol` contra literales EXACTOS
// (isAdmin(): rol in ['Administrador', 'admin', 'Superusuario']; isMecanico():
// rol in ['Mecanico', 'Taller'] Y estado en ['aprobado','activo']). Antes,
// `lib/core/utils/role_utils.dart` normalizaba a minusculas y sin acentos
// para decidir que ve la UI, asi que una cuenta guardada como 'mecanico' o
// 'Administrador' con otra caja/acento se veia con capacidades que estas
// mismas reglas niegan en cada lectura/escritura real.
//
// Este archivo prueba el lado de las reglas de esa divergencia: cada rol
// canonico (y el alias historico 'admin' que las reglas SI toleran) debe
// pasar, y cada variante de caja/acento que NO es un literal exacto debe
// fallar exactamente igual que un rol desconocido.
describe('ROLE-01: reglas exigen literales exactos de rol', () => {
  describe('isAdmin() — coleccion usuarios', () => {
    const CANONICOS = ['Administrador', 'admin', 'Superusuario'];
    for (const rol of CANONICOS) {
      test(`rol canonico "${rol}" SI puede listar usuarios`, async () => {
        const db = await withRole(env, UIDS.admin, rol);
        await assertSucceeds(db.collection('usuarios').get());
      });
    }

    const VARIANTES_NO_CANONICAS = [
      'administrador',
      'ADMINISTRADOR',
      'superusuario',
      'SUPERUSUARIO',
      'Súperusuario',
      'Admin',
      'ADMIN',
      ' Administrador',
      'Administrador ',
    ];
    for (const rol of VARIANTES_NO_CANONICAS) {
      test(`variante NO canonica "${rol}" NO puede listar usuarios`, async () => {
        const db = await withRole(env, UIDS.admin, rol);
        await assertFails(db.collection('usuarios').get());
      });
    }
  });

  // `catalogo_servicios` NO sirve para probar isMecanico(): su regla es
  // `isAuthenticated() && actuaPorTaller(tallerId)`, es decir propiedad pura,
  // sin mirar el rol. Un test contra esa ruta pasaria con CUALQUIER cadena de
  // rol y no probaria nada. La lectura de `vehiculos` (firestore.rules:516) SI
  // pasa por isMecanico(), y con una sola precondicion sembrable:
  // `talleres_vinculados` debe contener al taller actor.
  describe('isMecanico() — lectura de vehiculos vinculados al taller', () => {
    const sembrarVehiculoVinculado = () =>
      seed(env, async (db) => {
        await db.collection('vehiculos').doc('veh1').set({
          id_vehiculo: 'veh1',
          id_propietario: UIDS.owner1,
          placa: 'P123-456',
          talleres_vinculados: [UIDS.taller1],
        });
      });

    const leerVehiculo = (db) => db.collection('vehiculos').doc('veh1').get();

    const CANONICOS = ['Mecanico', 'Taller'];
    for (const rol of CANONICOS) {
      test(`rol canonico "${rol}" (aprobado) SI puede leer el vehiculo vinculado`, async () => {
        const db = await withRole(env, UIDS.taller1, rol, { estado: 'aprobado' });
        await sembrarVehiculoVinculado();
        await assertSucceeds(leerVehiculo(db));
      });
    }

    const VARIANTES_NO_CANONICAS = [
      'mecanico',
      'MECANICO',
      'Mecánico',
      'mecánico',
      'taller',
      'TALLER',
    ];
    for (const rol of VARIANTES_NO_CANONICAS) {
      test(`variante NO canonica "${rol}" NO puede leer el vehiculo, aunque este "aprobado"`, async () => {
        const db = await withRole(env, UIDS.taller1, rol, { estado: 'aprobado' });
        await sembrarVehiculoVinculado();
        await assertFails(leerVehiculo(db));
      });
    }

    test('un taller canonico pero SIN aprobar tampoco puede leerlo (el estado manda ademas del rol)', async () => {
      const db = await withRole(env, UIDS.taller1, 'Mecanico', { estado: 'pendiente' });
      await sembrarVehiculoVinculado();
      await assertFails(leerVehiculo(db));
    });
  });

  describe('isSuperUser() — solo el literal exacto "Superusuario"', () => {
    // No hay una regla de escritura trivial de un solo campo gateada solo por
    // isSuperUser() para probar un create/update aislado sin arrastrar otras
    // reglas (crear Administradores exige ademas el flujo de admin_logs), asi
    // que esta seccion prueba el predicado a traves de la misma coleccion
    // 'usuarios': un Superusuario SI hereda isAdmin() (ya cubierto arriba);
    // aqui solo se deja constancia de que 'superusuario' en minuscula tampoco
    // hereda isAdmin(), ya cubierto en el bloque de variantes de arriba.
    test('Superusuario exacto hereda isAdmin() (listar usuarios)', async () => {
      const db = await withRole(env, UIDS.admin, 'Superusuario');
      await assertSucceeds(db.collection('usuarios').get());
    });
  });
});
