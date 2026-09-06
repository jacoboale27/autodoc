'use strict';

/**
 * Cobertura server-side de C3 (Tarea 10) — la parte que de verdad importa:
 * un mecanico NO puede obtener telefono/dui/correo/vehiculos de un cliente
 * a traves del callable `obtenerPerfilPublico`, y solo puede ver el
 * subconjunto acordado cuando comparte una conversacion real con ese
 * cliente.
 *
 * R5 de este plan ya descarto probar esto con un test de reglas que espere
 * `doc.data().telefono` undefined tras un `get()` permitido: una regla de
 * Firestore decide SI se puede leer el documento, nunca QUE campos vienen —
 * un `get()` permitido siempre trae el documento completo. Como el
 * mecanismo elegido es un callable (Admin SDK, fuera del alcance de
 * firestore.rules), la prueba real de la frontera de privacidad vive aqui:
 * contra `subconjuntoPublicoCliente` (que el ALLOWLIST nunca incluya esos
 * campos, sin importar que traiga el documento) y contra
 * `compartenConversacion` (que sin una conversacion real el acceso se
 * niegue).
 *
 * Se testea contra un doble de Firestore en memoria, mismo patron que
 * iniciar_reparacion_por_vehiculo.test.js: stubbear `admin.firestore` es
 * hostil porque leer esa propiedad dispara `ensureApp()`.
 */

const assert = require('assert');

const {
  subconjuntoPublicoCliente,
  compartenConversacion,
  llamanteEsMecanico,
} = require('../src/obtenerPerfilPublico');

/**
 * Doble en memoria de Firestore con lo justo que usa este modulo:
 * `collection('conversaciones').where(...).where(...).limit(n).get()` con
 * igualdad exacta en cada `where`, y ademas
 * `collection('conversaciones').doc(id).collection('mensajes').where(...).limit(n).get()`
 * (FIX 3, Ronda 2: `compartenConversacion` ahora exige al menos un mensaje
 * del cliente en esa conversacion).
 *
 * @param {{conversaciones?: Array<object>}} datos cada conversacion puede
 *   traer `id` (para direccionar su subcoleccion) y `mensajes` (array de
 *   `{id_remitente}`).
 */
function fakeDb({ conversaciones = [] } = {}) {
  function coleccionMensajes(mensajes) {
    const filtros = [];
    const query = {
      where(campo, op, valor) {
        assert.strictEqual(op, '==', 'este doble solo soporta igualdad');
        filtros.push([campo, valor]);
        return query;
      },
      limit() {
        return query;
      },
      async get() {
        const docs = mensajes.filter((m) =>
          filtros.every(([campo, valor]) => m[campo] === valor)
        );
        return { empty: docs.length === 0, docs };
      },
    };
    return query;
  }

  return {
    collection(nombre) {
      if (nombre !== 'conversaciones') {
        throw new Error(`coleccion inesperada en el doble: ${nombre}`);
      }
      const filtros = [];
      const query = {
        where(campo, op, valor) {
          assert.strictEqual(op, '==', 'este doble solo soporta igualdad');
          filtros.push([campo, valor]);
          return query;
        },
        limit() {
          return query;
        },
        async get() {
          const docs = conversaciones
            .filter((c) => filtros.every(([campo, valor]) => c[campo] === valor))
            .map((c) => ({ ...c, id: c.id || 'conv-sin-id' }));
          return { empty: docs.length === 0, docs };
        },
        doc(id) {
          const conv = conversaciones.find((c) => (c.id || 'conv-sin-id') === id);
          return {
            collection(sub) {
              assert.strictEqual(sub, 'mensajes');
              return coleccionMensajes((conv && conv.mensajes) || []);
            },
          };
        },
      };
      return query;
    },
  };
}

describe('obtenerPerfilPublico / subconjuntoPublicoCliente', () => {
  it('nunca incluye telefono, dui, correo ni vehiculos, sin importar que traiga el documento', () => {
    const documentoCompleto = {
      nombre_completo: 'Cliente Real',
      foto_perfil_url: 'https://x/foto.jpg',
      municipio: 'San Salvador',
      telefono: '7000-0000',
      dui: '01234567-8',
      correo: 'cliente@test.com',
      vehiculos: ['v1', 'v2'],
      fcmToken: 'token-secreto',
    };

    const subconjunto = subconjuntoPublicoCliente(documentoCompleto);

    assert.deepStrictEqual(subconjunto, {
      nombre: 'Cliente Real',
      foto_perfil_url: 'https://x/foto.jpg',
      municipio: 'San Salvador',
    });
    // Ademas de la igualdad exacta de arriba (que ya prueba que NO hay
    // campos de mas), se deja explicito el motivo del test.
    assert.strictEqual(subconjunto.telefono, undefined);
    assert.strictEqual(subconjunto.dui, undefined);
    assert.strictEqual(subconjunto.correo, undefined);
    assert.strictEqual(subconjunto.vehiculos, undefined);
  });

  it('cae al alias heredado foto_url si falta foto_perfil_url', () => {
    const subconjunto = subconjuntoPublicoCliente({
      nombre_completo: 'Cliente Viejo',
      foto_url: 'https://x/vieja.jpg',
    });
    assert.strictEqual(subconjunto.foto_perfil_url, 'https://x/vieja.jpg');
  });

  it('renderiza sensatamente un documento sin foto ni municipio (datos anteriores a esta tarea)', () => {
    const subconjunto = subconjuntoPublicoCliente({ nombre_completo: 'Cliente Sin Datos' });
    assert.deepStrictEqual(subconjunto, {
      nombre: 'Cliente Sin Datos',
      foto_perfil_url: null,
      municipio: null,
    });
  });

  it('cae a un nombre por defecto si el documento no trae nombre_completo', () => {
    const subconjunto = subconjuntoPublicoCliente({});
    assert.strictEqual(subconjunto.nombre, 'Cliente');
  });
});

describe('obtenerPerfilPublico / compartenConversacion', () => {
  it('encuentra la conversacion real Y el cliente ya escribio un mensaje', async () => {
    const db = fakeDb({
      conversaciones: [
        {
          id: 'conv1',
          id_mecanico: 'mec1',
          id_propietario: 'cli1',
          mensajes: [{ id_remitente: 'cli1' }],
        },
      ],
    });
    assert.strictEqual(
      await compartenConversacion(db, { mecanicoId: 'mec1', clienteId: 'cli1' }),
      true
    );
  });

  it('un mecanico sin conversacion con ese cliente NO pasa (hallazgo del brief: extrano sin relacion)', async () => {
    const db = fakeDb({
      conversaciones: [{ id_mecanico: 'mec2', id_propietario: 'cli2' }],
    });
    assert.strictEqual(
      await compartenConversacion(db, { mecanicoId: 'mec1', clienteId: 'cli1' }),
      false
    );
  });

  it('una conversacion donde el cliente es el mecanico de OTRA conversacion no cuenta (no confunde los roles)', async () => {
    const db = fakeDb({
      // cli1 es el MECANICO aqui, no el propietario: mec1 no deberia colarse.
      conversaciones: [{ id_mecanico: 'cli1', id_propietario: 'mec1' }],
    });
    assert.strictEqual(
      await compartenConversacion(db, { mecanicoId: 'mec1', clienteId: 'cli1' }),
      false
    );
  });

  // FIX 3 (Ronda 2): el hallazgo C2 de la revision de rama completa. Subir
  // la barra de `conversaciones.create` a "solo un taller aprobado" no
  // cerraba el hueco: un mecanico se nombra `id_mecanico == id_taller ==
  // su propio uid` sobre CUALQUIER `id_propietario` (victima), sin que la
  // victima haya participado nunca. `compartenConversacion` confiaba en que
  // "existe la conversacion" implicara una relacion real; el mecanico podia
  // fabricar esa "relacion" el solo.
  it('conversacion existe pero el cliente NUNCA ha escrito nada: NO pasa (hallazgo C2)', async () => {
    const db = fakeDb({
      conversaciones: [
        {
          id: 'conv1',
          id_mecanico: 'mec1',
          id_propietario: 'cli1',
          mensajes: [],
        },
      ],
    });
    assert.strictEqual(
      await compartenConversacion(db, { mecanicoId: 'mec1', clienteId: 'cli1' }),
      false
    );
  });

  it('conversacion existe con solo mensajes DEL MECANICO: NO pasa (el mecanico no puede fabricar la relacion escribiendose a si mismo)', async () => {
    const db = fakeDb({
      conversaciones: [
        {
          id: 'conv1',
          id_mecanico: 'mec1',
          id_propietario: 'cli1',
          mensajes: [{ id_remitente: 'mec1' }, { id_remitente: 'mec1' }],
        },
      ],
    });
    assert.strictEqual(
      await compartenConversacion(db, { mecanicoId: 'mec1', clienteId: 'cli1' }),
      false
    );
  });

  it('el cliente SI ha escrito (entre mensajes del mecanico tambien): pasa', async () => {
    const db = fakeDb({
      conversaciones: [
        {
          id: 'conv1',
          id_mecanico: 'mec1',
          id_propietario: 'cli1',
          mensajes: [{ id_remitente: 'mec1' }, { id_remitente: 'cli1' }],
        },
      ],
    });
    assert.strictEqual(
      await compartenConversacion(db, { mecanicoId: 'mec1', clienteId: 'cli1' }),
      true
    );
  });
});

/**
 * Doble en memoria de `usuarios/{uid}` para `llamanteEsMecanico`.
 */
function fakeDbUsuarios(docs = {}) {
  return {
    collection(nombre) {
      assert.strictEqual(nombre, 'usuarios');
      return {
        doc(uid) {
          return {
            async get() {
              return {
                exists: Object.prototype.hasOwnProperty.call(docs, uid),
                data: () => docs[uid],
              };
            },
          };
        },
      };
    },
  };
}

describe('obtenerPerfilPublico / llamanteEsMecanico (hallazgo C2)', () => {
  // Antes de este chequeo, obtenerPerfilPublico nunca comprobaba `rol`: una
  // cuenta de CLIENTE que fabricara (o consiguiera de cualquier otra forma)
  // una conversacion con la victima podia leer su perfil publico igual.
  it('rechaza a una cuenta de rol Propietario (cliente)', async () => {
    const db = fakeDbUsuarios({ cli1: { rol: 'Propietario' } });
    assert.strictEqual(await llamanteEsMecanico(db, 'cli1'), false);
  });

  it('deja pasar a un Mecanico', async () => {
    const db = fakeDbUsuarios({ mec1: { rol: 'Mecanico' } });
    assert.strictEqual(await llamanteEsMecanico(db, 'mec1'), true);
  });

  it('deja pasar a un Taller', async () => {
    const db = fakeDbUsuarios({ t1: { rol: 'Taller' } });
    assert.strictEqual(await llamanteEsMecanico(db, 't1'), true);
  });

  it('rechaza si el documento de usuario no existe', async () => {
    const db = fakeDbUsuarios({});
    assert.strictEqual(await llamanteEsMecanico(db, 'fantasma'), false);
  });
});
