'use strict';

/**
 * Cobertura de `onCotizacionAceptada`: la aceptacion de la cotizacion es lo
 * que abre el ticket de `reparaciones` (A4b), en el estado inicial
 * `pendiente_recepcion`. Hasta ahora el ticket nacia cuando el mecanico
 * pulsaba "Recibir vehiculo", algo que A3/B2 prohibe: nadie puede recibir un
 * vehiculo sin una cotizacion aceptada, asi que si el ticket siguiera naciendo
 * ahi no naceria nunca.
 *
 * Se testea la logica extraida a `functions/src/aceptarCotizacion.js` en vez
 * del handler del trigger, siguiendo el precedente de
 * publishTallerProfile.test.js y empleados.test.js: stubbear `admin.firestore`
 * es hostil porque el getter llama a `ensureApp()` en cuanto se LEE la
 * propiedad. `abrirTicketDeReparacion` recibe el `db` por parametro justo por
 * eso, y aqui se le inyecta un doble en memoria.
 */

const assert = require('assert');
const sinon = require('sinon');

const {
  debeAbrirTicket,
  idTicketDeCotizacion,
  construirTicketReparacion,
  existeTicketAbiertoParaVehiculo,
  abrirTicketDeReparacion,
} = require('../src/aceptarCotizacion');

/**
 * Doble en memoria de Firestore, con lo justo que usa
 * `abrirTicketDeReparacion`: `collection(x).doc(y).get()/.set()` y
 * `collection(x).where(...).where(...).get()` con igualdad exacta (lo que
 * usa `existeTicketAbiertoParaVehiculo` para el dedup del hallazgo 2).
 * `docs` va indexado por `coleccion/id`.
 */
function fakeDb(docs = {}) {
  const escrituras = [];
  return {
    docs,
    escrituras,
    collection(coleccion) {
      return {
        doc(id) {
          const clave = `${coleccion}/${id}`;
          return {
            id,
            async get() {
              return {
                exists: Object.prototype.hasOwnProperty.call(docs, clave),
                data: () => docs[clave],
              };
            },
            async set(data, opciones) {
              escrituras.push({ clave, data, opciones });
              docs[clave] = Object.assign({}, docs[clave], data);
            },
          };
        },
        where(campo, op, valor) {
          const filtros = [[campo, valor]];
          const query = {
            where(campo2, op2, valor2) {
              filtros.push([campo2, valor2]);
              return query;
            },
            async get() {
              const prefijo = `${coleccion}/`;
              const coincidencias = Object.keys(docs)
                .filter((clave) => clave.startsWith(prefijo))
                .filter((clave) =>
                  filtros.every(([f, v]) => docs[clave][f] === v)
                )
                .map((clave) => ({
                  id: clave.slice(prefijo.length),
                  data: () => docs[clave],
                }));
              return { docs: coincidencias, empty: coincidencias.length === 0 };
            },
          };
          return query;
        },
      };
    },
  };
}

const AHORA = new Date('2026-09-04T12:00:00Z');

function cotizacion(extra) {
  return Object.assign(
    {
      id_mecanico: 'mec1',
      id_propietario: 'cli1',
      id_vehiculo: 'v1',
      id_taller: 't1',
      estado: 'aceptada',
    },
    extra
  );
}

describe('onCotizacionAceptada / debeAbrirTicket', () => {
  it('abre el ticket cuando la cotizacion pasa a aceptada', () => {
    assert.strictEqual(
      debeAbrirTicket({ estado: 'pendiente' }, { estado: 'aceptada' }),
      true
    );
  });

  it('no abre nada si la cotizacion pasa a rechazada', () => {
    assert.strictEqual(
      debeAbrirTicket({ estado: 'pendiente' }, { estado: 'rechazada' }),
      false
    );
  });

  it('no reacciona a un update que ya venia de aceptada (reintento del trigger)', () => {
    assert.strictEqual(
      debeAbrirTicket({ estado: 'aceptada' }, { estado: 'aceptada' }),
      false
    );
  });

  it('no reacciona a un cambio que no toca el estado', () => {
    assert.strictEqual(
      debeAbrirTicket({ estado: 'pendiente', total: 1 }, { estado: 'pendiente', total: 2 }),
      false
    );
  });
});

describe('onCotizacionAceptada / construirTicketReparacion', () => {
  it('el ticket nace en pendiente_recepcion y apunta a su cotizacion', () => {
    const ticket = construirTicketReparacion({
      cotizacionId: 'c1',
      cotizacion: cotizacion(),
      vehiculo: { placa: 'ABC123', id_propietario: 'cli1' },
      ahora: AHORA,
    });

    assert.strictEqual(ticket.estado, 'pendiente_recepcion');
    assert.strictEqual(ticket.id_cotizacion, 'c1');
    assert.strictEqual(ticket.id_vehiculo, 'v1');
    assert.strictEqual(ticket.id_taller, 't1');
    assert.strictEqual(ticket.id_propietario, 'cli1');
    assert.strictEqual(ticket.placa, 'ABC123');
    assert.deepStrictEqual(ticket.historial_estados, [
      { estado: 'pendiente_recepcion', timestamp: AHORA },
    ]);
  });

  it('cae al propietario del vehiculo si la cotizacion no lo trae', () => {
    const sinPropietario = cotizacion();
    delete sinPropietario.id_propietario;

    const ticket = construirTicketReparacion({
      cotizacionId: 'c1',
      cotizacion: sinPropietario,
      vehiculo: { placa: 'ABC123', id_propietario: 'cli-real' },
      ahora: AHORA,
    });

    assert.strictEqual(ticket.id_propietario, 'cli-real');
  });

  it('devuelve null si no hay vehiculo, taller o propietario que anclar', () => {
    const sinTaller = cotizacion();
    delete sinTaller.id_taller;

    assert.strictEqual(
      construirTicketReparacion({
        cotizacionId: 'c1',
        cotizacion: sinTaller,
        vehiculo: { placa: 'ABC123' },
        ahora: AHORA,
      }),
      null
    );
  });
});

describe('onCotizacionAceptada / abrirTicketDeReparacion', () => {
  it('crea el ticket de reparacion en pendiente_recepcion', async () => {
    const db = fakeDb({ 'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' } });

    const id = await abrirTicketDeReparacion(db, {
      cotizacionId: 'c1',
      antes: { estado: 'pendiente' },
      despues: cotizacion(),
      ahora: AHORA,
    });

    assert.strictEqual(id, idTicketDeCotizacion('c1'));
    assert.strictEqual(db.escrituras.length, 1);
    const escrito = db.docs[`reparaciones/${id}`];
    assert.strictEqual(escrito.estado, 'pendiente_recepcion');
    assert.strictEqual(escrito.id_cotizacion, 'c1');
    assert.strictEqual(escrito.placa, 'ABC123');
  });

  it('no duplica el ticket si la cotizacion se reescribe a aceptada', async () => {
    // El trigger se reintenta: onUpdate no garantiza exactly-once. El id del
    // ticket se deriva del id de la cotizacion, asi que un reintento apunta
    // al MISMO documento; ademas se comprueba que ya existe para no pisar el
    // estado al que lo haya movido el taller mientras tanto.
    const db = fakeDb({ 'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' } });
    const evento = {
      cotizacionId: 'c1',
      antes: { estado: 'pendiente' },
      despues: cotizacion(),
      ahora: AHORA,
    };

    await abrirTicketDeReparacion(db, evento);
    // El taller ya recibio el vehiculo entre el primer disparo y el reintento.
    db.docs['reparaciones/cot_c1'].estado = 'recibido';
    await abrirTicketDeReparacion(db, evento);

    const tickets = Object.keys(db.docs).filter((k) => k.startsWith('reparaciones/'));
    assert.deepStrictEqual(tickets, ['reparaciones/cot_c1']);
    assert.strictEqual(db.escrituras.length, 1, 'el reintento no debe volver a escribir');
    assert.strictEqual(
      db.docs['reparaciones/cot_c1'].estado,
      'recibido',
      'el reintento no puede arrastrar el ticket de vuelta a pendiente_recepcion'
    );
  });

  it('no crea nada si la cotizacion pasa a rechazada', async () => {
    const db = fakeDb({ 'vehiculos/v2': { placa: 'XYZ999', id_propietario: 'cli1' } });

    const id = await abrirTicketDeReparacion(db, {
      cotizacionId: 'c2',
      antes: { estado: 'pendiente' },
      despues: cotizacion({ estado: 'rechazada', id_vehiculo: 'v2' }),
      ahora: AHORA,
    });

    assert.strictEqual(id, null);
    assert.deepStrictEqual(db.escrituras, []);
  });

  it('no crea nada si el vehiculo de la cotizacion no existe, y lo avisa por consola', async () => {
    const db = fakeDb();
    const warn = sinon.stub(console, 'warn');
    try {
      const id = await abrirTicketDeReparacion(db, {
        cotizacionId: 'c3',
        antes: { estado: 'pendiente' },
        despues: cotizacion({ id_vehiculo: 'fantasma' }),
        ahora: AHORA,
      });

      assert.strictEqual(id, null);
      assert.deepStrictEqual(db.escrituras, []);
      // Sin esto, una cotizacion que el cliente cree aceptada no deja rastro
      // servidor de por que no abrio ticket.
      assert.strictEqual(warn.calledOnce, true);
      assert.match(warn.firstCall.args[0], /c3/);
    } finally {
      warn.restore();
    }
  });

  it('no crea nada si la cotizacion no ancla a taller/propietario, y lo avisa por consola', async () => {
    const db = fakeDb({ 'vehiculos/v1': { placa: 'ABC123' } }); // sin id_propietario
    const warn = sinon.stub(console, 'warn');
    try {
      const sinTaller = cotizacion();
      delete sinTaller.id_taller;

      const id = await abrirTicketDeReparacion(db, {
        cotizacionId: 'c4',
        antes: { estado: 'pendiente' },
        despues: sinTaller,
        ahora: AHORA,
      });

      assert.strictEqual(id, null);
      assert.deepStrictEqual(db.escrituras, []);
      assert.strictEqual(warn.calledOnce, true);
      assert.match(warn.firstCall.args[0], /c4/);
    } finally {
      warn.restore();
    }
  });

  it('el reintento normal (ticket ya abierto por su propia cotizacion) NO avisa por consola', async () => {
    // Contraste con los dos tests de arriba: este es el camino normal de
    // idempotencia (ver 'no duplica el ticket...' mas arriba), no un
    // problema que el equipo necesite ver en los logs.
    const db = fakeDb({
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
      'reparaciones/cot_c1': { estado: 'pendiente_recepcion' },
    });
    const warn = sinon.stub(console, 'warn');
    try {
      const id = await abrirTicketDeReparacion(db, {
        cotizacionId: 'c1',
        antes: { estado: 'aceptada' }, // reintento del trigger
        despues: cotizacion(),
        ahora: AHORA,
      });

      assert.strictEqual(id, null);
      assert.strictEqual(warn.called, false);
    } finally {
      warn.restore();
    }
  });
});

describe('onCotizacionAceptada / existeTicketAbiertoParaVehiculo (hallazgo 2)', () => {
  it('no ve nada abierto cuando no hay ningun ticket para ese vehiculo+taller', async () => {
    const db = fakeDb();

    assert.strictEqual(
      await existeTicketAbiertoParaVehiculo(db, { idVehiculo: 'v1', idTaller: 't1' }),
      false
    );
  });

  it('cuenta como abierto un ticket legado sin id_cotizacion, ya en recibido', async () => {
    // El escenario exacto que motiva el hallazgo: un ticket anterior a A4b,
    // creado directo en 'recibido', para el mismo vehiculo+taller.
    const db = fakeDb({
      'reparaciones/legado1': { id_vehiculo: 'v1', id_taller: 't1', estado: 'recibido' },
    });

    assert.strictEqual(
      await existeTicketAbiertoParaVehiculo(db, { idVehiculo: 'v1', idTaller: 't1' }),
      true
    );
  });

  it('no cuenta un ticket cancelado ni uno ya entregado', async () => {
    const db = fakeDb({
      'reparaciones/r1': { id_vehiculo: 'v1', id_taller: 't1', estado: 'cancelado' },
      'reparaciones/r2': { id_vehiculo: 'v1', id_taller: 't1', estado: 'listo_para_entrega' },
    });

    assert.strictEqual(
      await existeTicketAbiertoParaVehiculo(db, { idVehiculo: 'v1', idTaller: 't1' }),
      false
    );
  });

  it('no cuenta un ticket abierto de OTRO vehiculo o de OTRO taller', async () => {
    const db = fakeDb({
      'reparaciones/r1': { id_vehiculo: 'v2', id_taller: 't1', estado: 'recibido' },
      'reparaciones/r2': { id_vehiculo: 'v1', id_taller: 't2', estado: 'recibido' },
    });

    assert.strictEqual(
      await existeTicketAbiertoParaVehiculo(db, { idVehiculo: 'v1', idTaller: 't1' }),
      false
    );
  });
});

describe('onCotizacionAceptada / abrirTicketDeReparacion, dedup por vehiculo+taller (hallazgo 2)', () => {
  it('no abre un segundo ticket si ya hay uno legado (recibido, sin id_cotizacion) abierto', async () => {
    // Antes del hallazgo 2, el unico chequeo de reuso era el id derivado de
    // la cotizacion (cot_<id>), que no ve este ticket legado en absoluto:
    // se habria creado un SEGUNDO ticket para el mismo vehiculo+taller.
    const db = fakeDb({
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
      'reparaciones/legado1': { id_vehiculo: 'v1', id_taller: 't1', estado: 'recibido' },
    });

    const id = await abrirTicketDeReparacion(db, {
      cotizacionId: 'c1',
      antes: { estado: 'pendiente' },
      despues: cotizacion(),
      ahora: AHORA,
    });

    assert.strictEqual(id, null);
    assert.deepStrictEqual(db.escrituras, []);
    const tickets = Object.keys(db.docs).filter((k) => k.startsWith('reparaciones/'));
    assert.deepStrictEqual(tickets, ['reparaciones/legado1']);
  });

  it('si abrio otra cotizacion aceptada antes, no abre una segunda para el mismo vehiculo+taller', async () => {
    const db = fakeDb({
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
    });

    const primero = await abrirTicketDeReparacion(db, {
      cotizacionId: 'c1',
      antes: { estado: 'pendiente' },
      despues: cotizacion(),
      ahora: AHORA,
    });
    const segundo = await abrirTicketDeReparacion(db, {
      cotizacionId: 'c2', // una segunda cotizacion, id de ticket derivado distinto
      antes: { estado: 'pendiente' },
      despues: cotizacion(),
      ahora: AHORA,
    });

    assert.strictEqual(primero, idTicketDeCotizacion('c1'));
    assert.strictEqual(segundo, null);
    const tickets = Object.keys(db.docs).filter((k) => k.startsWith('reparaciones/'));
    assert.deepStrictEqual(tickets, ['reparaciones/cot_c1']);
  });

  it('si el ticket abierto ya se cerro (listo_para_entrega), una cotizacion nueva SI abre uno propio', async () => {
    // Cierra el ciclo: un vehiculo que vuelve DESPUES de que su visita
    // anterior termino no debe quedar bloqueado para siempre.
    const db = fakeDb({
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
      'reparaciones/legado1': {
        id_vehiculo: 'v1',
        id_taller: 't1',
        estado: 'listo_para_entrega',
      },
    });

    const id = await abrirTicketDeReparacion(db, {
      cotizacionId: 'c1',
      antes: { estado: 'pendiente' },
      despues: cotizacion(),
      ahora: AHORA,
    });

    assert.strictEqual(id, idTicketDeCotizacion('c1'));
    const tickets = Object.keys(db.docs).filter((k) => k.startsWith('reparaciones/'));
    assert.deepStrictEqual(tickets.sort(), ['reparaciones/cot_c1', 'reparaciones/legado1']);
  });
});
