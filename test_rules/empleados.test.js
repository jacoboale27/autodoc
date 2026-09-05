const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// Cubre el gap de Tarea 8 (revision de controller): 'talleres.rules' nunca
// tuvo un 'match' para la subcoleccion 'empleados' (Tareas 6/7 no la
// tocaron), asi que EmpleadoRepository.watchEmpleados()/desactivarEmpleado()
// recibian PERMISSION_DENIED para TODOS, incluido el dueño legitimo, hasta
// este fix.
describe('talleres/{tallerId}/empleados', () => {
  test('el dueño del taller SI puede leer su propia subcoleccion de empleados', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1').set({
        id_taller_propietario: UIDS.taller1,
        nombre_completo: 'Empleado Uno',
        correo: 'emp1@x.com',
        activo: true,
      });
    });
    await assertSucceeds(
      db.collection('talleres').doc(UIDS.taller1).collection('empleados').get(),
    );
  });

  test('el dueño del taller SI puede desactivar (solo activo) a su empleado', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1').set({
        id_taller_propietario: UIDS.taller1,
        nombre_completo: 'Empleado Uno',
        correo: 'emp1@x.com',
        activo: true,
      });
    });
    await assertSucceeds(
      db.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1')
        .update({ activo: false }),
    );
  });

  test('el dueño del taller NO puede tocar otros campos ademas de activo', async () => {
    // desactivarEmpleado() solo cambia 'activo'; cualquier otro update de
    // cliente (p. ej. reasignar el nombre o el vinculo al taller) queda
    // fuera del alcance permitido por EmpleadoRepository y no debe pasar.
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1').set({
        id_taller_propietario: UIDS.taller1,
        nombre_completo: 'Empleado Uno',
        correo: 'emp1@x.com',
        activo: true,
      });
    });
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1')
        .update({ nombre_completo: 'Otro Nombre' }),
    );
  });

  test('un taller distinto NO puede leer la subcoleccion de empleados de otro taller', async () => {
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1').set({
        id_taller_propietario: UIDS.taller1,
        nombre_completo: 'Empleado Uno',
        correo: 'emp1@x.com',
        activo: true,
      });
    });
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).collection('empleados').get(),
    );
  });

  test('un taller distinto NO puede desactivar un empleado ajeno', async () => {
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1').set({
        id_taller_propietario: UIDS.taller1,
        nombre_completo: 'Empleado Uno',
        correo: 'emp1@x.com',
        activo: true,
      });
    });
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1')
        .update({ activo: false }),
    );
  });

  test('un empleado (rol Taller + id_taller_propietario) NO puede leer los empleados de OTRO taller', async () => {
    // Una sub-cuenta de empleado comparte rol == 'Taller' con el dueño real
    // (ver Tarea 7): sin este test, un bug que solo chequeara 'rol' seguiria
    // pasando el emulador. Este empleado pertenece a taller2 pero intenta
    // leer la subcoleccion de taller1 -- debe comportarse igual que
    // cualquier no-dueño (test anterior), sin trato especial por ser
    // 'Taller'.
    const db = await withRole(env, UIDS.taller2, 'Taller', {
      id_taller_propietario: UIDS.taller1 + '-dueño-inexistente',
    });
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1').set({
        id_taller_propietario: UIDS.taller1,
        nombre_completo: 'Empleado Uno',
        correo: 'emp1@x.com',
        activo: true,
      });
    });
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).collection('empleados').get(),
    );
  });

  test('un empleado NO puede desactivar a otro "compañero" de su propio taller (sin uid == tallerId)', async () => {
    // El empleado (uid propio distinto de taller1) intenta desactivar un
    // registro dentro de la subcoleccion de SU PROPIO taller dueño
    // (taller1): las reglas solo permiten el write si request.auth.uid ==
    // tallerId, es decir, solo al dueño real, nunca a un empleado aunque
    // este vinculado a ese mismo taller.
    const db = await withRole(env, 'uid-empleado-1', 'Taller', {
      id_taller_propietario: UIDS.taller1,
    });
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp2').set({
        id_taller_propietario: UIDS.taller1,
        nombre_completo: 'Empleado Dos',
        correo: 'emp2@x.com',
        activo: true,
      });
    });
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp2')
        .update({ activo: false }),
    );
  });

  test('un admin SI puede leer la subcoleccion de empleados de cualquier taller', async () => {
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1').set({
        id_taller_propietario: UIDS.taller1,
        nombre_completo: 'Empleado Uno',
        correo: 'emp1@x.com',
        activo: true,
      });
    });
    await assertSucceeds(
      db.collection('talleres').doc(UIDS.taller1).collection('empleados').get(),
    );
  });

  test('un cliente (Propietario) NO puede leer la subcoleccion de empleados de un taller, ni siquiera un doc suelto', async () => {
    // D1 (Tarea 13): la seccion "Empleados" del perfil publico del taller
    // lee estos datos por el callable `obtenerEmpleadosPublicos`, nunca
    // directo -- porque el doc real trae correo/telefono del empleado, y
    // una regla de Firestore no puede proyectar solo nombre/rol/activo (un
    // get()/list() permitido siempre trae el documento completo). Este test
    // prueba que ese atajo sigue cerrado para un cliente cualquiera,
    // sobre los campos realmente sensibles (correo, telefono), no sobre
    // campos que EmpleadoModel ni siquiera tiene.
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1').set({
        id_taller_propietario: UIDS.taller1,
        nombre_completo: 'Empleado Uno',
        correo: 'emp1@x.com',
        telefono: '7000-0000',
        rol: 'Mecanico',
        activo: true,
      });
    });
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).collection('empleados').get(),
    );
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp1').get(),
    );
  });

  test('un cliente (no admin, Admin SDK bypass excluido) NO puede crear un empleado directamente', async () => {
    // crearRegistroEmpleado() (Tarea 6) nunca se llama desde la app: el
    // unico create real pasa por crearEmpleadoTaller (Cloud Function,
    // Admin SDK, bypassea reglas). Un create de cliente, aunque sea el
    // propio dueño, debe seguir bloqueado.
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).collection('empleados').doc('emp-nuevo').set({
        id_taller_propietario: UIDS.taller1,
        nombre_completo: 'Intento Directo',
        correo: 'x@x.com',
        activo: true,
      }),
    );
  });
});
