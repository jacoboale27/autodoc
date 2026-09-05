'use strict';

/**
 * Cobertura server-side de D1 (Tarea 13) — la parte que de verdad importa:
 * la seccion "Empleados" del perfil publico del taller nunca puede filtrar
 * correo/telefono/id_taller_propietario de un empleado, y solo lista a los
 * que siguen activos.
 *
 * Mismo patron que `obtener_perfil_publico.test.js`: se testea contra un
 * doble de Firestore en memoria (stubbear `admin.firestore` dispara
 * `ensureApp()`, hostil sin emulador).
 */

const assert = require('assert');

const {
  subconjuntoPublicoEmpleado,
  listarEmpleadosPublicos,
} = require('../src/obtenerEmpleadosPublicos');

/**
 * Doble en memoria de Firestore con lo justo que usa este modulo:
 * `collection('talleres').doc(id).collection('empleados').get()`.
 *
 * @param {{empleadosPorTaller?: Record<string, Array<object>>}} datos
 */
function fakeDb({ empleadosPorTaller = {} } = {}) {
  return {
    collection(nombre) {
      if (nombre !== 'talleres') {
        throw new Error(`coleccion inesperada en el doble: ${nombre}`);
      }
      return {
        doc(idTaller) {
          return {
            collection(subNombre) {
              if (subNombre !== 'empleados') {
                throw new Error(`subcoleccion inesperada en el doble: ${subNombre}`);
              }
              return {
                async get() {
                  const empleados = empleadosPorTaller[idTaller] || [];
                  return {
                    docs: empleados.map((data) => ({ data: () => data })),
                  };
                },
              };
            },
          };
        },
      };
    },
  };
}

describe('obtenerEmpleadosPublicos / subconjuntoPublicoEmpleado', () => {
  it('nunca incluye correo, telefono ni id_taller_propietario, sin importar que traiga el documento', () => {
    const documentoCompleto = {
      id_taller_propietario: 'taller1',
      nombre_completo: 'Empleado Real',
      correo: 'empleado@test.com',
      telefono: '7000-0000',
      rol: 'Mecanico',
      activo: true,
      fecha_creacion: 'lo que sea',
    };

    const subconjunto = subconjuntoPublicoEmpleado(documentoCompleto);

    assert.deepStrictEqual(subconjunto, {
      nombre_completo: 'Empleado Real',
      rol: 'Mecanico',
      activo: true,
    });
    assert.strictEqual(subconjunto.correo, undefined);
    assert.strictEqual(subconjunto.telefono, undefined);
    assert.strictEqual(subconjunto.id_taller_propietario, undefined);
  });

  it('cae a valores por defecto sensatos si faltan nombre_completo/rol', () => {
    const subconjunto = subconjuntoPublicoEmpleado({});
    assert.deepStrictEqual(subconjunto, {
      nombre_completo: 'Empleado',
      rol: 'Mecanico',
      activo: true,
    });
  });

  it('activo es false solo si el documento lo fija explicitamente en false', () => {
    assert.strictEqual(
      subconjuntoPublicoEmpleado({ activo: false }).activo,
      false
    );
    assert.strictEqual(subconjuntoPublicoEmpleado({}).activo, true);
  });
});

describe('obtenerEmpleadosPublicos / listarEmpleadosPublicos', () => {
  it('lista el subconjunto publico de los empleados activos de ese taller', async () => {
    const db = fakeDb({
      empleadosPorTaller: {
        taller1: [
          { nombre_completo: 'Empleado Uno', rol: 'Mecanico', activo: true, correo: 'a@x.com' },
          { nombre_completo: 'Empleado Dos', rol: 'Recepcion', activo: true, telefono: '7000-0000' },
        ],
      },
    });

    const empleados = await listarEmpleadosPublicos(db, 'taller1');

    assert.deepStrictEqual(empleados, [
      { nombre_completo: 'Empleado Uno', rol: 'Mecanico', activo: true },
      { nombre_completo: 'Empleado Dos', rol: 'Recepcion', activo: true },
    ]);
  });

  it('excluye a los empleados desactivados', async () => {
    const db = fakeDb({
      empleadosPorTaller: {
        taller1: [
          { nombre_completo: 'Empleado Activo', rol: 'Mecanico', activo: true },
          { nombre_completo: 'Empleado Baja', rol: 'Mecanico', activo: false },
        ],
      },
    });

    const empleados = await listarEmpleadosPublicos(db, 'taller1');

    assert.deepStrictEqual(empleados, [
      { nombre_completo: 'Empleado Activo', rol: 'Mecanico', activo: true },
    ]);
  });

  it('un taller sin empleados (o inexistente) devuelve una lista vacia, no un error', async () => {
    const db = fakeDb({ empleadosPorTaller: {} });
    const empleados = await listarEmpleadosPublicos(db, 'taller-fantasma');
    assert.deepStrictEqual(empleados, []);
  });

  it('no confunde los empleados de un taller con los de otro', async () => {
    const db = fakeDb({
      empleadosPorTaller: {
        taller1: [{ nombre_completo: 'De Taller Uno', rol: 'Mecanico', activo: true }],
        taller2: [{ nombre_completo: 'De Taller Dos', rol: 'Mecanico', activo: true }],
      },
    });

    const empleados = await listarEmpleadosPublicos(db, 'taller1');

    assert.deepStrictEqual(empleados, [
      { nombre_completo: 'De Taller Uno', rol: 'Mecanico', activo: true },
    ]);
  });
});
