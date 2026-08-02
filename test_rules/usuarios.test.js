const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

describe('usuarios', () => {
  test('un propietario NO puede listar toda la coleccion de usuarios', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.owner2).set({
        id_usuario: UIDS.owner2, correo: 'victima@x.com', nombre_completo: 'Victima', rol: 'Propietario',
      });
    });
    await assertFails(db.collection('usuarios').get());
  });

  test('un taller NO puede listar toda la coleccion de usuarios', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(db.collection('usuarios').get());
  });

  test('un propietario NO puede leer el documento de otro usuario', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.owner2).set({ id_usuario: UIDS.owner2, rol: 'Propietario' });
    });
    await assertFails(db.collection('usuarios').doc(UIDS.owner2).get());
  });

  test('un usuario SI puede leer su propio documento', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('usuarios').doc(UIDS.owner1).get());
  });

  test('un administrador SI puede listar usuarios', async () => {
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(db.collection('usuarios').get());
  });

  test('un usuario NO puede elevar su propio rol', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('usuarios').doc(UIDS.owner1).update({ rol: 'Administrador' }),
    );
  });

  test('un usuario NO puede escribir sus metricas de reputacion', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('usuarios').doc(UIDS.taller1).update({ calificacion_promedio: 5 }),
    );
  });

  test('un usuario NO puede autoaprobarse cambiando su propio estado', async () => {
    // I2: 'estado' se proyecta a 'talleres' y el directorio publico filtra
    // por estado == 'aprobado' (workshop_service.dart). Sin esta exclusion,
    // cualquier mecanico podia aparecer como verificado sin pasar por
    // admin_service.dart.
    const db = await withRole(env, UIDS.taller1, 'Taller', { estado: 'pendiente' });
    await assertFails(
      db.collection('usuarios').doc(UIDS.taller1).update({ estado: 'aprobado' }),
    );
  });

  test('un usuario NO puede plantar id_taller_propietario en el create inicial (self-registro)', async () => {
    // Sin este guard en 'create', el usuario podia saltarse el bloqueo de
    // 'update' plantando el campo desde el registro inicial. Se autentica
    // como el propio UID que intenta crear (isOwner) para probar realmente
    // la rama de self-registro, no un intento de escribir el doc ajeno.
    const newUid = 'uid-self-register-1';
    const db = env.authenticatedContext(newUid).firestore();
    await assertFails(
      db.collection('usuarios').doc(newUid).set({
        id_usuario: newUid,
        rol: 'Propietario',
        id_taller_propietario: UIDS.taller1,
      }),
    );
  });

  test('un usuario NO puede plantar estado/calificacion_promedio/total_resenias en el create inicial', async () => {
    const uidA = 'uid-self-register-2';
    const uidB = 'uid-self-register-3';
    const uidC = 'uid-self-register-4';
    await assertFails(
      env.authenticatedContext(uidA).firestore().collection('usuarios').doc(uidA).set({
        id_usuario: uidA, rol: 'Propietario', estado: 'aprobado',
      }),
    );
    await assertFails(
      env.authenticatedContext(uidB).firestore().collection('usuarios').doc(uidB).set({
        id_usuario: uidB, rol: 'Propietario', calificacion_promedio: 5,
      }),
    );
    await assertFails(
      env.authenticatedContext(uidC).firestore().collection('usuarios').doc(uidC).set({
        id_usuario: uidC, rol: 'Propietario', total_resenias: 10,
      }),
    );
  });

  test('un usuario SI puede crear su propio perfil sin los campos protegidos', async () => {
    const newUid = 'uid-self-register-5';
    const db = env.authenticatedContext(newUid).firestore();
    await assertSucceeds(
      db.collection('usuarios').doc(newUid).set({
        id_usuario: newUid, rol: 'Propietario', nombre_completo: 'Nuevo',
      }),
    );
  });

  test('un usuario NO puede auto-asignarse un taller propietario (id_taller_propietario)', async () => {
    // Tarea 7: solo la Cloud Function crearEmpleadoTaller (Admin SDK) puede
    // fijar este campo. Sin esta exclusion, cualquier usuario podria
    // vincularse como empleado de un taller ajeno con un solo update.
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('usuarios').doc(UIDS.owner1).update({ id_taller_propietario: UIDS.taller1 }),
    );
  });

  test('un usuario SI puede editar su nombre', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('usuarios').doc(UIDS.owner1).update({ nombre_completo: 'Nuevo Nombre' }),
    );
  });

  test('sin autenticar NO se puede leer usuarios', async () => {
    await assertFails(anon(env).collection('usuarios').get());
  });
});
