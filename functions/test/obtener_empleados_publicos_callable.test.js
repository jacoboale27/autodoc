'use strict';

/**
 * Cobertura del GATE de autenticacion de `exports.obtenerEmpleadosPublicos`
 * (Tarea 13, D1 — correccion de controller sobre la version original de
 * esta tarea).
 *
 * La version inicial dejaba este callable SIN `context.auth`, razonando por
 * analogia con `talleres/{uid}` (de lectura anonima): "el directorio
 * publico de un taller no depende de quien mira". Esa analogia le
 * aplicaba el consentimiento del DUEÑO al EMPLEADO — el dueño eligio
 * operar un negocio publico, su mecanico contratado no eligio que su
 * nombre fuera enumerable por cualquiera sin cuenta. Este archivo prueba
 * justo eso: que la version corregida SI exige sesion, con el mismo
 * codigo y forma de error que ya usa `obtenerPerfilPublico` (index.js) en
 * su propio gate de auth.
 *
 * `listarEmpleadosPublicos`/`subconjuntoPublicoEmpleado` (el ALLOWLIST en
 * si) ya se prueban aparte en `obtener_empleados_publicos.test.js` contra
 * dobles puros, sin admin SDK. Aqui hace falta requerir `../index.js` de
 * verdad para ejercitar el `onCall` completo, asi que se stubea
 * `admin.firestore`/`admin.auth`/etc. ANTES del require — mismo patron que
 * `test/empleados.test.js` (leer esas propiedades dispara `ensureApp()`,
 * que revienta sin una app default real).
 */

const assert = require('assert');

describe('obtenerEmpleadosPublicos (callable) / gate de autenticacion', () => {
  let myFunctions;
  let admin;

  before(() => {
    admin = require('firebase-admin');

    Object.defineProperty(admin, 'initializeApp', {
      value: () => undefined,
      configurable: true,
    });

    const fakeDb = {
      collection: () => {
        throw new Error(
          'no deberia llegar a Firestore: el gate de auth debe cortar antes'
        );
      },
    };
    Object.defineProperty(admin, 'firestore', {
      value: () => fakeDb,
      configurable: true,
    });
    admin.firestore.Timestamp = { now: () => 'FAKE_TIMESTAMP' };
    admin.firestore.FieldValue = { serverTimestamp: () => 'FAKE_SERVER_TIMESTAMP' };
    Object.defineProperty(admin, 'auth', {
      value: () => ({}),
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

  it('rechaza una llamada sin sesion con unauthenticated, sin tocar Firestore', async () => {
    await assert.rejects(
      () => myFunctions.obtenerEmpleadosPublicos.run({ idTaller: 'taller1' }, {}),
      (err) => {
        assert.strictEqual(err.code, 'unauthenticated');
        return true;
      }
    );
  });

  it('rechaza tambien cuando context.auth existe pero es null/undefined', async () => {
    await assert.rejects(
      () =>
        myFunctions.obtenerEmpleadosPublicos.run(
          { idTaller: 'taller1' },
          { auth: null }
        ),
      (err) => {
        assert.strictEqual(err.code, 'unauthenticated');
        return true;
      }
    );
  });
});
