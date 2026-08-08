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

  before(() => {
    admin = require('firebase-admin');

    Object.defineProperty(admin, 'initializeApp', {
      value: () => undefined,
      configurable: true,
    });

    usuariosData = {};
    empleadosData = {};

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
                throw new Error(`Unexpected sub-collection in test fake: ${sub}`);
              },
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

    authCreateUserStub = sinon.stub().callsFake(async ({ email }) => ({
      uid: `uid-${email}`,
    }));
    const fakeAuth = {
      createUser: authCreateUserStub,
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
});
