// Gap 9.1 — los tres escritores server-side de `/reparaciones` mantienen el
// booleano `abierto` que el tablero consulta.
//
// El tablero pasa de `whereIn` sobre cinco estados a `abierto == true` porque
// un `in` aplica el `limit` a CADA subconsulta: leia hasta 1000 documentos
// para devolver 200. El precio es un campo denormalizado, y un campo
// denormalizado solo vale lo que valga el peor de sus escritores.
//
// Los escritores son exactamente tres y no hay mas (lo vigila
// `apertura_unica_ticket.test.js`):
//
//   1. `onCotizacionAceptada`      crea el ticket en 'pendiente_recepcion'
//   2. `recibirVehiculoDelTicket`  lo transiciona a 'recibido'
//   3. el barrido de `onVehicleDelete` lo cierra como 'cancelado'
//
// El tercero es el que importa de verdad: si NO bajara `abierto`, el ticket de
// un vehiculo borrado se quedaria en el tablero del taller para siempre, y la
// consulta ya no mira `estado` para descartarlo.
const assert = require('assert');

const {
  construirTicketReparacion,
  ticketAbierto,
} = require('../src/aceptarCotizacion');
const { cerrarTicketsDeVehiculo } = require('../src/cerrarTicketsDeVehiculo');

describe('ticketAbierto', () => {
  it('los estados de columna dejan el ticket abierto', () => {
    for (const estado of [
      'pendiente_recepcion',
      'recibido',
      'en_revision',
      'esperando_repuestos',
      'listo_para_entrega',
    ]) {
      assert.strictEqual(ticketAbierto(estado), true, estado);
    }
  });

  it('entregado y cancelado lo cierran', () => {
    assert.strictEqual(ticketAbierto('entregado'), false);
    assert.strictEqual(ticketAbierto('cancelado'), false);
  });

  it('un ticket legado sin estado cuenta como abierto', () => {
    // Los tickets anteriores a A4b no traen `estado` y nacian en 'recibido';
    // el cliente, las reglas y las functions aplican todos ese mismo defecto.
    assert.strictEqual(ticketAbierto(undefined), true);
  });
});

/**
 * Doble minimo para el barrido: `collection().where().get()` y un `batch()`
 * que **guarda lo que se le pide escribir, literalmente**.
 *
 * Guardar el update tal cual es el punto: en la tanda anterior dos dobles no
 * podian ver el defecto que cubrian —uno tenia `limit()` como no-op y otro
 * devolvia el documento vivo desde `get()`—, asi que aqui lo escrito se
 * inspecciona campo a campo en vez de comprobar solo que "se escribio algo".
 */
function fakeDb(docs = {}) {
  const escrituras = [];
  const refDe = (clave) => ({ clave });
  return {
    docs,
    escrituras,
    collection: (coleccion) => ({
      where: (campo, op, valor) => ({
        async get() {
          const encontrados = Object.entries(docs)
            .filter(([clave]) => clave.startsWith(`${coleccion}/`))
            .filter(([, data]) => op === '==' && data[campo] === valor)
            .map(([clave, data]) => ({ ref: refDe(clave), data: () => data }));
          return { docs: encontrados, empty: encontrados.length === 0 };
        },
      }),
    }),
    batch() {
      const operaciones = [];
      return {
        update(ref, data) {
          operaciones.push({ ref, data });
        },
        async commit() {
          for (const { ref, data } of operaciones) {
            escrituras.push({ clave: ref.clave, data });
            docs[ref.clave] = Object.assign({}, docs[ref.clave], data);
          }
        },
      };
    },
  };
}

describe('onVehicleDelete: el barrido cierra Y baja `abierto`', () => {
  const fieldValue = { arrayUnion: (...v) => ({ __arrayUnion: v }) };

  it('un ticket abierto queda cancelado y fuera del tablero', async () => {
    const db = fakeDb({
      'reparaciones/r1': { id_vehiculo: 'v1', estado: 'en_revision', abierto: true },
    });

    const cerrados = await cerrarTicketsDeVehiculo(db, {
      vehicleId: 'v1',
      ahora: new Date('2026-09-11T10:00:00Z'),
      fieldValue,
    });

    assert.strictEqual(cerrados, 1);
    assert.strictEqual(db.docs['reparaciones/r1'].estado, 'cancelado');
    assert.strictEqual(
      db.docs['reparaciones/r1'].abierto,
      false,
      'sin esto la tarjeta se queda clavada en el tablero para siempre, ' +
        'apuntando a una ficha que ya no existe: la consulta ya no mira `estado`'
    );
  });

  it('no toca los tickets ya cerrados', async () => {
    const db = fakeDb({
      'reparaciones/r1': { id_vehiculo: 'v1', estado: 'entregado', abierto: false },
    });

    const cerrados = await cerrarTicketsDeVehiculo(db, {
      vehicleId: 'v1',
      ahora: new Date('2026-09-11T10:00:00Z'),
      fieldValue,
    });

    assert.strictEqual(cerrados, 0);
    assert.deepStrictEqual(db.escrituras, []);
  });

  it('no toca los tickets de otro vehiculo', async () => {
    const db = fakeDb({
      'reparaciones/r1': { id_vehiculo: 'v2', estado: 'recibido', abierto: true },
    });

    const cerrados = await cerrarTicketsDeVehiculo(db, {
      vehicleId: 'v1',
      ahora: new Date('2026-09-11T10:00:00Z'),
      fieldValue,
    });

    assert.strictEqual(cerrados, 0);
    assert.strictEqual(db.docs['reparaciones/r1'].abierto, true);
  });
});

describe('onCotizacionAceptada: el ticket nace abierto', () => {
  it('construirTicketReparacion escribe abierto: true', () => {
    const ticket = construirTicketReparacion({
      cotizacionId: 'cot1',
      cotizacion: { id_vehiculo: 'v1', placa: 'ABC123' },
      vehiculo: { id_propietario: 'p1', placa: 'ABC123' },
      idTaller: 't1',
      ahora: new Date('2026-09-11T10:00:00Z'),
    });

    assert.strictEqual(ticket.estado, 'pendiente_recepcion');
    assert.strictEqual(
      ticket.abierto,
      true,
      'un ticket que nace sin el campo no aparece en el tablero: una igualdad ' +
        'sobre un campo ausente no devuelve nada'
    );
  });
});
