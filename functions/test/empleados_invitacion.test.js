'use strict';

/**
 * Observaciones del 2026-09-19, punto 4: «Al mecánico no le deja invitar a
 * una persona como mecánico». Con un correo que ya tenía cuenta,
 * `crearEmpleadoTaller` respondía `already-exists` y la app decía «Ese dato
 * ya existe». Ver `src/empleadosTaller.js`.
 */

const assert = require('assert');
const {
  ErrorEmpleado,
  incorporarCuentaExistente,
  responderInvitacion,
} = require('../src/empleadosTaller');

/**
 * Firestore en memoria, indexado por ruta completa (`a/b/c/d`), con lo que
 * usan los dos helpers: `doc().get/set(merge)/delete`, subcolecciones,
 * `batch()` y una consulta de igualdad con `limit`.
 */
function fakeDb(docs = {}) {
  function docRef(ruta) {
    return {
      ruta,
      collection: (sub) => coleccion(`${ruta}/${sub}`),
      async get() {
        const existe = Object.prototype.hasOwnProperty.call(docs, ruta);
        return { exists: existe, data: () => docs[ruta] };
      },
      async set(data, opciones) {
        docs[ruta] =
          opciones && opciones.merge ? Object.assign({}, docs[ruta], data) : Object.assign({}, data);
      },
      async delete() {
        delete docs[ruta];
      },
    };
  }
  let autoId = 0;
  function hijos(ruta) {
    return Object.keys(docs).filter(
      (k) => k.startsWith(`${ruta}/`) && k.split('/').length === ruta.split('/').length + 1
    );
  }
  function coleccion(ruta) {
    return {
      doc: (id) => docRef(`${ruta}/${id || `auto${++autoId}`}`),
      // Consulta sin filtro y con tope: el barrido de invitaciones caducadas.
      limit(n) {
        return {
          async get() {
            return {
              docs: hijos(ruta)
                .slice(0, n)
                .map((k) => ({
                  id: k.split('/').pop(),
                  ref: docRef(k),
                  data: () => docs[k],
                })),
            };
          },
        };
      },
      where(campo, op, valor) {
        let tope = Infinity;
        const q = {
          limit(n) {
            tope = n;
            return q;
          },
          async get() {
            // Gancho para simular una escritura concurrente justo antes de
            // la transacción (la última lectura previa es esta consulta).
            if (typeof docs.__alConsultar === 'function') await docs.__alConsultar();
            const encontrados = Object.keys(docs)
              .filter((k) => k.startsWith(`${ruta}/`) && k.split('/').length === ruta.split('/').length + 1)
              .filter((k) => docs[k][campo] === valor)
              .slice(0, tope);
            return { empty: encontrados.length === 0, docs: encontrados };
          },
        };
        return q;
      },
    };
  }
  return {
    docs,
    collection: (nombre) => coleccion(nombre),
    // Transacción mínima: lee al momento y aplica las escrituras al final,
    // todas o ninguna (si la función lanza, no se aplica nada).
    async runTransaction(fn) {
      const ops = [];
      const tx = {
        get: (ref) => ref.get(),
        set: (ref, data, opciones) => ops.push(() => ref.set(data, opciones)),
        delete: (ref) => ops.push(() => ref.delete()),
      };
      const resultado = await fn(tx);
      for (const op of ops) await op();
      return resultado;
    },
    batch() {
      const ops = [];
      return {
        set: (ref, data, opciones) => ops.push(() => ref.set(data, opciones)),
        delete: (ref) => ops.push(() => ref.delete()),
        async commit() {
          for (const op of ops) await op();
        },
      };
    },
  };
}

function fakeAuth(cuentas) {
  const actualizaciones = [];
  return {
    actualizaciones,
    async getUserByEmail(correo) {
      const c = Object.values(cuentas).find((x) => x.email === correo);
      if (!c) {
        const e = new Error('no existe');
        e.code = 'auth/user-not-found';
        throw e;
      }
      return c;
    },
    async getUser(uid) {
      if (typeof cuentas.alLeer === 'function') await cuentas.alLeer(uid);
      return cuentas[uid];
    },
    async updateUser(uid, cambios) {
      actualizaciones.push({ uid, cambios });
      Object.assign(cuentas[uid], cambios);
    },
  };
}

const AHORA = new Date('2026-09-19T12:00:00Z');
const TALLER = 'taller1';

function base() {
  return {
    'usuarios/taller1': {
      rol: 'Taller',
      estado: 'aprobado',
      nombre_completo: 'Taller Escobar',
    },
  };
}

function avisos() {
  const lista = [];
  const escribir = async (uid, n) => lista.push({ uid, ...n });
  return { lista, escribir };
}

function datosAlta(db, auth, extra = {}) {
  return Object.assign(
    {
      db,
      auth,
      idTaller: TALLER,
      nombreTaller: 'Taller Escobar',
      correo: 'oscar@example.com',
      nombreCompleto: 'Oscar Isaac',
      telefono: '00001111',
      rolEmpleado: 'Mecanico',
      password: 'temporal123',
      ahora: AHORA,
    },
    extra
  );
}

describe('empleados: correo que ya tiene cuenta (2026-09-19)', () => {
  it('a un PROPIETARIO se le invita; su cuenta no se toca hasta que acepte', async () => {
    const docs = base();
    docs['usuarios/p1'] = { rol: 'Propietario', nombre_completo: 'Oscar Isaac' };
    const db = fakeDb(docs);
    const auth = fakeAuth({ p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: true } });
    const { lista, escribir } = avisos();

    const r = await incorporarCuentaExistente(
      datosAlta(db, auth, { escribirNotificacion: escribir })
    );

    assert.deepStrictEqual(r, { resultado: 'invitado', idEmpleado: 'p1' });
    assert.strictEqual(docs['usuarios/p1'].rol, 'Propietario', 'sin aceptar no cambia nada');
    const inv = docs['talleres/taller1/invitaciones/p1'];
    assert.strictEqual(inv.estado, 'pendiente');
    assert.strictEqual(inv.rol, 'Mecanico');
    assert.ok(inv.expira.getTime() > AHORA.getTime());
    assert.strictEqual(lista.length, 1);
    assert.strictEqual(lista[0].uid, 'p1');
    assert.strictEqual(lista[0].tipo, 'invitacion_empleo');
    assert.strictEqual(lista[0].metadata.id_taller, TALLER);
    assert.strictEqual(auth.actualizaciones.length, 0, 'ni su contraseña');
  });

  it('un taller no puede tener más de 20 invitaciones vivas a la vez', async () => {
    // Sin cupo, el alta servía de lista de difusión: cada correo nuevo que
    // acertara con una cuenta verificada recibía una notificación.
    const docs = base();
    for (let i = 0; i < 20; i += 1) {
      docs[`talleres/taller1/invitaciones/x${i}`] = {
        estado: 'pendiente',
        expira: new Date(AHORA.getTime() + 86400000),
      };
    }
    docs['usuarios/p1'] = { rol: 'Propietario' };
    const db = fakeDb(docs);
    const auth = fakeAuth({ p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: true } });
    const { lista, escribir } = avisos();

    await assert.rejects(
      incorporarCuentaExistente(datosAlta(db, auth, { escribirNotificacion: escribir })),
      (e) => e instanceof ErrorEmpleado && e.codigo === 'resource-exhausted'
    );
    assert.strictEqual(docs['talleres/taller1/invitaciones/p1'], undefined);
    assert.strictEqual(lista.length, 0, 'ni se le avisa a la persona');
  });

  it('al invitar se barren las invitaciones caducadas, y esas no gastan cupo', async () => {
    // Nadie las borraba: la pantalla del taller solo las escondía. Así, con
    // esperar a que caducaran se seguía invitando sin límite.
    const docs = base();
    for (let i = 0; i < 20; i += 1) {
      docs[`talleres/taller1/invitaciones/x${i}`] = {
        estado: 'pendiente',
        expira: new Date(AHORA.getTime() - 86400000),
      };
    }
    docs['usuarios/p1'] = { rol: 'Propietario' };
    const db = fakeDb(docs);
    const auth = fakeAuth({ p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: true } });
    const { lista, escribir } = avisos();

    const r = await incorporarCuentaExistente(
      datosAlta(db, auth, { escribirNotificacion: escribir })
    );

    assert.deepStrictEqual(r, { resultado: 'invitado', idEmpleado: 'p1' });
    assert.strictEqual(docs['talleres/taller1/invitaciones/x0'], undefined);
    assert.strictEqual(
      Object.keys(docs).filter((k) => k.startsWith('talleres/taller1/invitaciones/')).length,
      1,
      'solo queda la que se acaba de crear'
    );
    assert.strictEqual(lista.length, 1);
  });

  it('con más invitaciones que la ventana del barrido, se drena en varias altas', async () => {
    // El barrido mira INVITACIONES_BARRIDO_MAX (60) documentos, y una consulta
    // sin `orderBy` los da por nombre ascendente: siempre drena desde el
    // frente, así que la basura se acaba vaciando en ceil(N/60) altas. Sin
    // este caso, subir la ventana a 10000 seguiría en verde.
    const docs = base();
    const caducada = { estado: 'pendiente', expira: new Date(AHORA.getTime() - 86400000) };
    for (let i = 0; i < 80; i += 1) {
      docs[`talleres/taller1/invitaciones/x${String(i).padStart(2, '0')}`] = { ...caducada };
    }
    docs['usuarios/p1'] = { rol: 'Propietario' };
    docs['usuarios/p2'] = { rol: 'Propietario' };
    const db = fakeDb(docs);
    const auth = fakeAuth({
      p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: true },
      p2: { uid: 'p2', email: 'otro@example.com', emailVerified: true },
    });
    const restantes = () =>
      Object.keys(docs).filter((k) => k.startsWith('talleres/taller1/invitaciones/')).length;

    await incorporarCuentaExistente(datosAlta(db, auth, { escribirNotificacion: async () => {} }));
    assert.strictEqual(restantes(), 21, '60 barridas + la nueva');

    await incorporarCuentaExistente(
      datosAlta(db, auth, {
        escribirNotificacion: async () => {},
        correo: 'otro@example.com',
      })
    );
    assert.strictEqual(restantes(), 2, 'se drenó el resto; quedan las dos vivas');
  });

  it('un `expira` ilegible no se barre: cuenta como viva y se queda', async () => {
    // `aMilisegundos` devuelve 0 cuando el campo falta o es una cadena ISO.
    // Eso NO es "caducada": borrar por no saber leer la fecha es el defecto
    // que GAPS-06 documenta con `fecha_limite`. Una atascada se ve y se
    // arregla; una viva borrada en silencio, no.
    const docs = base();
    for (let i = 0; i < 19; i += 1) {
      docs[`talleres/taller1/invitaciones/v${i}`] = {
        estado: 'pendiente',
        expira: new Date(AHORA.getTime() + 86400000),
      };
    }
    docs['talleres/taller1/invitaciones/rara'] = {
      estado: 'pendiente',
      expira: '2026-09-30T00:00:00Z',
    };
    docs['usuarios/p1'] = { rol: 'Propietario' };
    const db = fakeDb(docs);
    const auth = fakeAuth({ p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: true } });

    await assert.rejects(
      incorporarCuentaExistente(datosAlta(db, auth, { escribirNotificacion: async () => {} })),
      (e) => e instanceof ErrorEmpleado && e.codigo === 'resource-exhausted'
    );
    assert.ok(docs['talleres/taller1/invitaciones/rara'], 'no se barrió');
  });

  it('la invitación no le enseña al taller el nombre real de la cuenta', async () => {
    // El taller lee sus invitaciones. Guardar ahí el nombre del perfil
    // dejaría averiguar cómo se llama el dueño de cualquier correo.
    const docs = base();
    docs['usuarios/p1'] = { rol: 'Propietario', nombre_completo: 'Nombre Real Privado' };
    const db = fakeDb(docs);
    const auth = fakeAuth({ p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: true } });
    const { escribir } = avisos();

    await incorporarCuentaExistente(
      datosAlta(db, auth, { escribirNotificacion: escribir, nombreCompleto: 'Lo que tecleó el taller' })
    );

    const inv = docs['talleres/taller1/invitaciones/p1'];
    assert.strictEqual(inv.nombre_completo, 'Lo que tecleó el taller');
    assert.ok(!JSON.stringify(inv).includes('Nombre Real Privado'));
  });

  it('a un ex empleado de ESTE taller se le reactiva con la contraseña nueva', async () => {
    const docs = base();
    docs['usuarios/e1'] = {
      rol: 'Taller',
      id_taller_propietario: TALLER,
      estado: 'suspendido',
      nombre_completo: 'Viejo',
    };
    docs['talleres/taller1/empleados/e1'] = { activo: false, rol: 'Mecanico' };
    const db = fakeDb(docs);
    const auth = fakeAuth({ e1: { uid: 'e1', email: 'oscar@example.com', disabled: true } });

    const r = await incorporarCuentaExistente(
      datosAlta(db, auth, { escribirNotificacion: async () => {} })
    );

    assert.deepStrictEqual(r, { resultado: 'reactivado', idEmpleado: 'e1' });
    assert.strictEqual(docs['usuarios/e1'].estado, 'activo');
    assert.strictEqual(docs['talleres/taller1/empleados/e1'].activo, true);
    assert.deepStrictEqual(auth.actualizaciones[0].cambios, {
      disabled: false,
      password: 'temporal123',
      displayName: 'Oscar Isaac',
    });
  });

  it('un empleado ACTIVO del taller no se da de alta dos veces', async () => {
    const docs = base();
    docs['usuarios/e1'] = {
      rol: 'Taller',
      id_taller_propietario: TALLER,
      estado: 'activo',
      nombre_completo: 'Ana',
    };
    const db = fakeDb(docs);
    const auth = fakeAuth({ e1: { uid: 'e1', email: 'oscar@example.com', disabled: false } });

    await assert.rejects(
      incorporarCuentaExistente(datosAlta(db, auth, { escribirNotificacion: async () => {} })),
      (e) => e instanceof ErrorEmpleado && e.codigo === 'already-exists' && /Ana ya es empleado/.test(e.message)
    );
  });

  // El mensaje es el MISMO para los tres: distinguirlos le diría a cualquier
  // taller qué tipo de cuenta hay detrás de un correo.
  const noPuede = /no puede unirse como empleado de tu taller/;
  for (const [nombre, perfil, texto] of [
    ['empleado de OTRO taller', { rol: 'Taller', id_taller_propietario: 'otro', estado: 'activo' }, noPuede],
    ['cuenta de taller', { rol: 'Mecanico', estado: 'aprobado' }, noPuede],
    ['cuenta de administración', { rol: 'Administrador' }, noPuede],
  ]) {
    it(`${nombre}: no se puede, sin decir qué cuenta es`, async () => {
      const docs = base();
      docs['usuarios/x1'] = perfil;
      const db = fakeDb(docs);
      const auth = fakeAuth({ x1: { uid: 'x1', email: 'oscar@example.com' } });
      await assert.rejects(
        incorporarCuentaExistente(datosAlta(db, auth, { escribirNotificacion: async () => {} })),
        (e) => e instanceof ErrorEmpleado && e.codigo === 'already-exists' && texto.test(e.message)
      );
      assert.strictEqual(docs['talleres/taller1/invitaciones/x1'], undefined);
    });
  }

  it('el correo propio del taller no se puede invitar', async () => {
    const db = fakeDb(base());
    const auth = fakeAuth({ taller1: { uid: 'taller1', email: 'oscar@example.com' } });
    await assert.rejects(
      incorporarCuentaExistente(datosAlta(db, auth, { escribirNotificacion: async () => {} })),
      (e) => e instanceof ErrorEmpleado && /propia cuenta/.test(e.message)
    );
  });
});

describe('empleados: responder la invitación (2026-09-19)', () => {
  function conInvitacion(extraDocs = {}, cuenta = {}) {
    const docs = Object.assign(base(), {
      'usuarios/p1': { rol: 'Propietario', nombre_completo: 'Oscar Isaac' },
      'talleres/taller1/invitaciones/p1': {
        id_taller: TALLER,
        id_invitado: 'p1',
        nombre_completo: 'Oscar Isaac',
        correo: 'oscar@example.com',
        rol: 'Mecanico',
        estado: 'pendiente',
        expira: new Date(AHORA.getTime() + 86400000),
      },
    }, extraDocs);
    const db = fakeDb(docs);
    const auth = fakeAuth({
      p1: Object.assign({ uid: 'p1', email: 'oscar@example.com', emailVerified: true }, cuenta),
    });
    return { docs, db, auth };
  }

  it('al aceptar, la cuenta pasa a ser empleada del taller', async () => {
    const { docs, db, auth } = conInvitacion();
    const { lista, escribir } = avisos();

    const r = await responderInvitacion({
      db, auth, uid: 'p1', idTaller: TALLER, aceptar: true, ahora: AHORA, escribirNotificacion: escribir,
    });

    assert.deepStrictEqual(r, { resultado: 'aceptada' });
    assert.strictEqual(docs['usuarios/p1'].rol, 'Taller');
    assert.strictEqual(docs['usuarios/p1'].id_taller_propietario, TALLER);
    assert.strictEqual(docs['usuarios/p1'].estado, 'activo');
    assert.strictEqual(docs['talleres/taller1/empleados/p1'].activo, true);
    assert.strictEqual(docs['talleres/taller1/invitaciones/p1'], undefined);
    assert.strictEqual(lista[0].uid, TALLER, 'se le avisa al taller');
  });

  it('al rechazar, la invitación desaparece y la cuenta no cambia', async () => {
    const { docs, db, auth } = conInvitacion();
    const r = await responderInvitacion({
      db, auth, uid: 'p1', idTaller: TALLER, aceptar: false, ahora: AHORA, escribirNotificacion: async () => {},
    });
    assert.deepStrictEqual(r, { resultado: 'rechazada' });
    assert.strictEqual(docs['usuarios/p1'].rol, 'Propietario');
    assert.strictEqual(docs['talleres/taller1/invitaciones/p1'], undefined);
  });

  it('con vehículos registrados no se puede aceptar: los perdería de vista', async () => {
    const { docs, db, auth } = conInvitacion({ 'vehiculos/v1': { id_propietario: 'p1' } });
    await assert.rejects(
      responderInvitacion({
        db, auth, uid: 'p1', idTaller: TALLER, aceptar: true, ahora: AHORA, escribirNotificacion: async () => {},
      }),
      (e) => e instanceof ErrorEmpleado && /vehículos registrados/.test(e.message)
    );
    assert.strictEqual(docs['usuarios/p1'].rol, 'Propietario');
    assert.ok(docs['talleres/taller1/invitaciones/p1'], 'la invitación sigue para cuando pueda');
  });

  it('sin correo verificado no se acepta', async () => {
    const { docs, db, auth } = conInvitacion({}, { emailVerified: false });
    await assert.rejects(
      responderInvitacion({
        db, auth, uid: 'p1', idTaller: TALLER, aceptar: true, ahora: AHORA, escribirNotificacion: async () => {},
      }),
      (e) => e instanceof ErrorEmpleado && /Verifica tu correo/.test(e.message)
    );
    assert.strictEqual(docs['usuarios/p1'].rol, 'Propietario');
  });

  it('una invitación caducada no sirve', async () => {
    const { docs, db, auth } = conInvitacion();
    docs['talleres/taller1/invitaciones/p1'].expira = new Date(AHORA.getTime() - 1);
    await assert.rejects(
      responderInvitacion({
        db, auth, uid: 'p1', idTaller: TALLER, aceptar: true, ahora: AHORA, escribirNotificacion: async () => {},
      }),
      (e) => e instanceof ErrorEmpleado && /caducó/.test(e.message)
    );
    assert.strictEqual(docs['usuarios/p1'].rol, 'Propietario');
  });

  it('sin invitación a SU nombre no hay nada que aceptar', async () => {
    const { db, auth } = conInvitacion();
    await assert.rejects(
      responderInvitacion({
        db, auth, uid: 'otro', idTaller: TALLER, aceptar: true, ahora: AHORA, escribirNotificacion: async () => {},
      }),
      (e) => e instanceof ErrorEmpleado && /ya no está disponible/.test(e.message)
    );
  });

  it('si el taller dejó de estar aprobado, la invitación ya no vale', async () => {
    const { docs, db, auth } = conInvitacion({
      'usuarios/taller1': { rol: 'Taller', estado: 'suspendido' },
    });
    await assert.rejects(
      responderInvitacion({
        db, auth, uid: 'p1', idTaller: TALLER, aceptar: true, ahora: AHORA, escribirNotificacion: async () => {},
      }),
      (e) => e instanceof ErrorEmpleado && /ya no puede sumar empleados/.test(e.message)
    );
    assert.strictEqual(docs['usuarios/p1'].rol, 'Propietario');
  });
});

describe('empleados: lo que encontraron los revisores (2026-09-19)', () => {
  function cuentaInvitadaDesactivada() {
    const docs = base();
    docs['usuarios/p1'] = {
      rol: 'Taller',
      id_taller_propietario: TALLER,
      estado: 'suspendido',
      nombre_completo: 'Oscar Isaac',
    };
    docs['talleres/taller1/empleados/p1'] = {
      activo: false,
      origen: 'invitacion',
      nombre_completo: 'Oscar Isaac',
    };
    return docs;
  }

  it('reactivar a quien entró por invitación NO le cambia la contraseña', async () => {
    // Sin esto: el taller desactiva la cuenta, la "vuelve a dar de alta" con
    // una contraseña suya y entra en la cuenta personal de esa persona.
    const docs = cuentaInvitadaDesactivada();
    const db = fakeDb(docs);
    const auth = fakeAuth({
      p1: { uid: 'p1', email: 'oscar@example.com', disabled: true, emailVerified: true },
    });

    const r = await incorporarCuentaExistente(
      datosAlta(db, auth, { escribirNotificacion: async () => {}, nombreCompleto: 'Otro Nombre' })
    );

    assert.deepStrictEqual(r, { resultado: 'reactivado_con_su_contrasena', idEmpleado: 'p1' });
    assert.deepStrictEqual(auth.actualizaciones, [{ uid: 'p1', cambios: { disabled: false } }]);
    assert.strictEqual(docs['usuarios/p1'].nombre_completo, 'Oscar Isaac', 'ni su nombre');
    assert.strictEqual(docs['talleres/taller1/empleados/p1'].activo, true);
  });

  it('una suspensión de administración no la levanta el taller', async () => {
    const docs = base();
    docs['usuarios/e1'] = { rol: 'Taller', id_taller_propietario: TALLER, estado: 'suspendido' };
    // El taller nunca lo desactivó: `activo` sigue en true.
    docs['talleres/taller1/empleados/e1'] = { activo: true };
    const db = fakeDb(docs);
    const auth = fakeAuth({ e1: { uid: 'e1', email: 'oscar@example.com', disabled: false } });

    await assert.rejects(
      incorporarCuentaExistente(datosAlta(db, auth, { escribirNotificacion: async () => {} })),
      (e) => e instanceof ErrorEmpleado && /administración/.test(e.message)
    );
    assert.strictEqual(docs['usuarios/e1'].estado, 'suspendido');
    assert.strictEqual(auth.actualizaciones.length, 0);
  });

  it('a una cuenta sin verificar no se le invita (ni ve lo que tecleó el taller)', async () => {
    const docs = base();
    docs['usuarios/p1'] = { rol: 'Propietario' };
    const db = fakeDb(docs);
    const auth = fakeAuth({ p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: false } });
    const { lista, escribir } = avisos();

    await assert.rejects(
      incorporarCuentaExistente(datosAlta(db, auth, { escribirNotificacion: escribir })),
      (e) => e instanceof ErrorEmpleado && /sin verificar/.test(e.message)
    );
    assert.strictEqual(docs['talleres/taller1/invitaciones/p1'], undefined);
    assert.strictEqual(lista.length, 0);
  });

  it('repetir el alta con una invitación viva no vuelve a avisar', async () => {
    const docs = base();
    docs['usuarios/p1'] = { rol: 'Propietario' };
    const db = fakeDb(docs);
    const auth = fakeAuth({ p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: true } });
    const { lista, escribir } = avisos();

    for (let i = 0; i < 3; i++) {
      const r = await incorporarCuentaExistente(datosAlta(db, auth, { escribirNotificacion: escribir }));
      assert.strictEqual(r.resultado, 'invitado');
    }
    assert.strictEqual(lista.length, 1, 'un solo aviso por invitación viva');
  });

  function conInvitacion() {
    const docs = base();
    docs['usuarios/p1'] = { rol: 'Propietario', nombre_completo: 'Oscar Isaac' };
    docs['talleres/taller1/invitaciones/p1'] = {
      estado: 'pendiente',
      expira: new Date(AHORA.getTime() + 86400000),
      correo: 'oscar@example.com',
      rol: 'Mecanico',
    };
    return docs;
  }

  function datosRespuesta(db, auth, aceptar = true) {
    return {
      db,
      auth,
      uid: 'p1',
      idTaller: TALLER,
      aceptar,
      ahora: AHORA,
      escribirNotificacion: async () => {},
    };
  }

  it('si el taller retira la invitación mientras se acepta, la cuenta no cambia', async () => {
    const docs = conInvitacion();
    const db = fakeDb(docs);
    const cuentas = {
      p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: true },
      // El taller la borra justo después de las comprobaciones.
      alLeer: async () => {
        delete docs['talleres/taller1/invitaciones/p1'];
      },
    };
    await assert.rejects(
      responderInvitacion(datosRespuesta(db, fakeAuth(cuentas))),
      (e) => e instanceof ErrorEmpleado && /ya no está disponible/.test(e.message)
    );
    assert.strictEqual(docs['usuarios/p1'].rol, 'Propietario');
    assert.strictEqual(docs['talleres/taller1/empleados/p1'], undefined);
  });

  it('aceptar a la vez la invitación de otro taller no deja la cuenta en dos', async () => {
    const docs = conInvitacion();
    const db = fakeDb(docs);
    const cuentas = { p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: true } };
    // La otra aceptación se confirma DESPUÉS de las comprobaciones previas y
    // antes de escribir: solo la relectura de la transacción puede verla.
    Object.defineProperty(docs, '__alConsultar', {
      enumerable: false,
      value: async () => {
        Object.assign(docs['usuarios/p1'], { rol: 'Taller', id_taller_propietario: 'otro' });
      },
    });
    await assert.rejects(
      responderInvitacion(datosRespuesta(db, fakeAuth(cuentas))),
      (e) => e instanceof ErrorEmpleado && /ya es de un taller/.test(e.message)
    );
    assert.strictEqual(docs['talleres/taller1/empleados/p1'], undefined);
    assert.strictEqual(docs['usuarios/p1'].id_taller_propietario, 'otro');
  });

  it('al aceptar queda el origen de la cuenta y el rastro del cambio de rol', async () => {
    const docs = conInvitacion();
    const db = fakeDb(docs);
    const auth = fakeAuth({ p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: true } });

    await responderInvitacion(datosRespuesta(db, auth));

    assert.strictEqual(docs['talleres/taller1/empleados/p1'].origen, 'invitacion');
    const logs = Object.keys(docs).filter((k) => k.startsWith('admin_logs/'));
    assert.strictEqual(logs.length, 1);
    assert.strictEqual(docs[logs[0]].accion, 'cambio_rol_por_invitacion');
    assert.strictEqual(docs[logs[0]].referencia_id, 'p1');
  });

  it('rechazar una invitación caducada la limpia, sin error', async () => {
    const docs = conInvitacion();
    docs['talleres/taller1/invitaciones/p1'].expira = new Date(AHORA.getTime() - 1000);
    const db = fakeDb(docs);
    const auth = fakeAuth({ p1: { uid: 'p1', email: 'oscar@example.com', emailVerified: true } });

    const r = await responderInvitacion(datosRespuesta(db, auth, false));
    assert.deepStrictEqual(r, { resultado: 'rechazada' });
    assert.strictEqual(docs['talleres/taller1/invitaciones/p1'], undefined);
  });
});
