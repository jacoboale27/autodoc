'use strict';

/**
 * Cobertura de exports.crearEmpleadoTaller: valida que el campo `rol`
 * enviado por el cliente (Mecanico | Recepcionista) se persista en el
 * documento `talleres/{taller}/empleados/{id}` y que valores fuera de
 * ese vocabulario se rechacen con `invalid-argument`.
 *
 * No existe infraestructura de test previa en functions/ (sin
 * functions/test/, sin mocha/sinon en package.json): este archivo la
 * establece. Como `index.js` llama `admin.initializeApp()`,
 * `admin.firestore()` y `admin.auth()` en el top-level del módulo, el
 * SDK de admin se reemplaza ANTES del primer `require('../index')` para
 * evitar llamadas de red reales; un Firestore/Auth falso in-memory
 * respalda las operaciones que usa `crearEmpleadoTaller`.
 *
 * Nota: `admin.firestore`/`admin.auth`/etc. son accessors heredados del
 * prototipo de `FirebaseNamespace` cuyo getter invoca `ensureApp()`
 * (revisa que exista una app por default) apenas se LEE la propiedad, sin
 * necesidad de invocarla — por eso `sinon.stub(admin, 'firestore')` falla
 * con "The default Firebase app does not exist" incluso antes de terminar
 * de crear el stub (el propio sinon lee el valor original al armarlo). Se
 * usa `Object.defineProperty` para sobrescribir la propiedad directamente
 * sin pasar por ese getter.
 */

const assert = require('assert');
const sinon = require('sinon');

describe('crearEmpleadoTaller', () => {
  let myFunctions;
  let admin;
  let authCreateUserStub;
  let usuariosData;
  let empleadosData;
  let invitacionesData;
  let notificacionesData;
  let authGetUserByEmailStub;

  before(() => {
    admin = require('firebase-admin');

    Object.defineProperty(admin, 'initializeApp', {
      value: () => undefined,
      configurable: true,
    });

    usuariosData = {};
    empleadosData = {};
    invitacionesData = {};
    notificacionesData = [];

    function makeUsuariosDocRef(uid) {
      return {
        get: async () => ({
          exists: Object.prototype.hasOwnProperty.call(usuariosData, uid),
          data: () => usuariosData[uid],
        }),
        set: async (value) => {
          usuariosData[uid] = value;
        },
      };
    }

    function makeEmpleadosDocRef(uid) {
      return {
        set: async (value) => {
          empleadosData[uid] = value;
        },
      };
    }

    const fakeDb = {
      // El cupo de invitaciones y el barrido de caducadas van en transacción
      // (revisión de gate del 2026-09-19): lee al momento y aplica las
      // escrituras al final, todas o ninguna.
      runTransaction: async (fn) => {
        const ops = [];
        const tx = {
          get: (ref) => ref.get(),
          set: (ref, value, opciones) => ops.push(() => ref.set(value, opciones)),
          delete: (ref) => ops.push(() => ref.delete()),
        };
        const resultado = await fn(tx);
        for (const op of ops) await op();
        return resultado;
      },
      batch: () => {
        const ops = [];
        return {
          delete: (ref) => ops.push(() => ref.delete()),
          set: (ref, value, opciones) => ops.push(() => ref.set(value, opciones)),
          commit: async () => {
            for (const op of ops) await op();
          },
        };
      },
      collection: (name) => {
        if (name === 'usuarios') {
          return { doc: (uid) => makeUsuariosDocRef(uid) };
        }
        if (name === 'talleres') {
          return {
            doc: () => ({
              collection: (sub) => {
                if (sub === 'empleados') {
                  return { doc: (uid) => makeEmpleadosDocRef(uid) };
                }
                if (sub === 'invitaciones') {
                  const refInvitacion = (uid) => ({
                    id: uid,
                    get: async () => ({
                      exists: Boolean(invitacionesData[uid]),
                      data: () => invitacionesData[uid],
                    }),
                    set: async (value) => {
                      invitacionesData[uid] = value;
                    },
                    delete: async () => {
                      delete invitacionesData[uid];
                    },
                  });
                  return {
                    doc: refInvitacion,
                    // Cupo y barrido de caducadas (2026-09-19): la consulta
                    // sin filtro y con tope de `incorporarCuentaExistente`.
                    limit: (n) => ({
                      get: async () => ({
                        docs: Object.keys(invitacionesData)
                          .slice(0, n)
                          .map((uid) => ({
                            id: uid,
                            ref: refInvitacion(uid),
                            data: () => invitacionesData[uid],
                          })),
                      }),
                    }),
                  };
                }
                throw new Error(`Unexpected sub-collection in test fake: ${sub}`);
              },
            }),
          };
        }
        if (name === 'notificaciones') {
          return {
            doc: (uid) => ({
              collection: () => ({
                add: async (value) => {
                  notificacionesData.push({ uid, ...value });
                },
              }),
            }),
          };
        }
        throw new Error(`Unexpected collection in test fake: ${name}`);
      },
    };

    Object.defineProperty(admin, 'firestore', {
      value: () => fakeDb,
      configurable: true,
    });
    admin.firestore.Timestamp = { now: () => 'FAKE_TIMESTAMP' };
    admin.firestore.FieldValue = { serverTimestamp: () => 'FAKE_SERVER_TIMESTAMP' };

    authCreateUserStub = sinon.stub().callsFake(async ({ email }) => {
      // Un correo que ya tiene cuenta (observaciones del 2026-09-19).
      if (email === 'ya.registrado@example.com') {
        const err = new Error('The email address is already in use');
        err.code = 'auth/email-already-exists';
        throw err;
      }
      return { uid: `uid-${email}` };
    });
    authGetUserByEmailStub = sinon.stub().callsFake(async (email) => ({
      uid: 'uid-propietario-existente',
      email,
      emailVerified: true,
    }));
    const fakeAuth = {
      createUser: authCreateUserStub,
      getUserByEmail: authGetUserByEmailStub,
      deleteUser: sinon.stub().resolves(),
    };
    Object.defineProperty(admin, 'auth', {
      value: () => fakeAuth,
      configurable: true,
    });
    Object.defineProperty(admin, 'messaging', {
      value: () => ({}),
      configurable: true,
    });
    Object.defineProperty(admin, 'storage', {
      value: () => ({}),
      configurable: true,
    });

    myFunctions = require('../index.js');
  });

  after(() => {
    sinon.restore();
  });

  beforeEach(() => {
    // makeUsuariosDocRef/makeEmpleadosDocRef close over these outer
    // `usuariosData`/`empleadosData` bindings (the fakeDb closures were
    // created once in `before`), so reassigning here resets the fake
    // in-memory stores between tests.
    usuariosData = {};
    empleadosData = {};
    invitacionesData = {};
    notificacionesData = [];
    authCreateUserStub.resetHistory();
  });

  const idTallerPropietario = 'taller-owner-1';
  const context = { auth: { uid: idTallerPropietario } };

  function seedTallerAprobado() {
    usuariosData[idTallerPropietario] = {
      rol: 'Taller',
      estado: 'aprobado',
    };
  }

  it('persiste el rol enviado por el cliente en el documento del empleado', async () => {
    seedTallerAprobado();

    const result = await myFunctions.crearEmpleadoTaller.run(
      {
        correo: 'nuevo@taller.com',
        password: 'password123',
        nombreCompleto: 'Nuevo Empleado',
        rol: 'Recepcionista',
      },
      context
    );

    assert.ok(result.idEmpleado);
    const empleadoDoc = empleadosData[result.idEmpleado];
    assert.ok(empleadoDoc, 'se esperaba que el documento del empleado se creara');
    assert.strictEqual(empleadoDoc.rol, 'Recepcionista');

    // El usuario Auth-vinculado conserva el rol de permisos 'Taller' (no el
    // rol/puesto del empleado), que es el que consulta isMecanico().
    const usuarioDoc = usuariosData[result.idEmpleado];
    assert.strictEqual(usuarioDoc.rol, 'Taller');
  });

  it('crea el empleado con rol Mecanico por defecto cuando el cliente no envia `rol`', async () => {
    // Cobertura del hazard de deploy-ordering: la Cloud Function y la app
    // Flutter se despliegan por separado, asi que un cliente viejo aun en
    // produccion puede llamar este callable sin campo `rol` en absoluto.
    seedTallerAprobado();

    const result = await myFunctions.crearEmpleadoTaller.run(
      {
        correo: 'legacy@taller.com',
        password: 'password123',
        nombreCompleto: 'Cliente Viejo',
        // sin `rol`
      },
      context
    );

    assert.ok(result.idEmpleado);
    const empleadoDoc = empleadosData[result.idEmpleado];
    assert.ok(empleadoDoc, 'se esperaba que el documento del empleado se creara');
    assert.strictEqual(empleadoDoc.rol, 'Mecanico');
  });

  it('rechaza un rol fuera del vocabulario permitido con invalid-argument', async () => {
    seedTallerAprobado();

    await assert.rejects(
      myFunctions.crearEmpleadoTaller.run(
        {
          correo: 'otro@taller.com',
          password: 'password123',
          nombreCompleto: 'Otro Empleado',
          rol: 'Administrador',
        },
        context
      ),
      (err) => {
        assert.strictEqual(err.code, 'invalid-argument');
        return true;
      }
    );

    assert.strictEqual(authCreateUserStub.called, false);
  });

  // Revisión del 2026-09-19: `buscarVehiculoPorPlaca` miraba solo el rol, así
  // que un taller sin aprobar (o un empleado suspendido con el token vivo)
  // podía usar la búsqueda nueva por `idVehiculo`. Ahora exige también el
  // estado, igual que `isMecanico()`. Se para antes de leer `vehiculos`.
  for (const estado of ['pendiente', 'suspendido', 'rechazado', undefined]) {
    it(`buscarVehiculoPorPlaca rechaza a un taller con estado ${estado}`, async () => {
      usuariosData[idTallerPropietario] = { rol: 'Taller', estado };
      await assert.rejects(
        myFunctions.buscarVehiculoPorPlaca.run({ idVehiculo: 'v1' }, context),
        (err) => err.code === 'permission-denied'
      );
    });
  }

  it('con un correo que ya tiene cuenta de propietario, la invita en vez de fallar', async () => {
    // Observaciones del 2026-09-19, punto 4: antes esto era un
    // 'already-exists' que la app pintaba como «Ese dato ya existe».
    seedTallerAprobado();
    usuariosData['uid-propietario-existente'] = {
      rol: 'Propietario',
      nombre_completo: 'Oscar Isaac',
    };

    const result = await myFunctions.crearEmpleadoTaller.run(
      {
        correo: 'ya.registrado@example.com',
        password: 'password123',
        nombreCompleto: 'Oscar Isaac',
        rol: 'Mecanico',
      },
      context
    );

    assert.deepStrictEqual(result, {
      resultado: 'invitado',
      idEmpleado: 'uid-propietario-existente',
    });
    assert.strictEqual(
      usuariosData['uid-propietario-existente'].rol,
      'Propietario',
      'su cuenta no cambia hasta que acepte'
    );
    assert.strictEqual(invitacionesData['uid-propietario-existente'].estado, 'pendiente');
    assert.strictEqual(notificacionesData.length, 1);
    assert.strictEqual(notificacionesData[0].uid, 'uid-propietario-existente');
    assert.strictEqual(notificacionesData[0].tipo, 'invitacion_empleo');
  });
});
