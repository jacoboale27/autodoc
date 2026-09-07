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
const { FieldValue } = require('firebase-admin/firestore');

const {
  debeAbrirTicket,
  idTicketDeCotizacion,
  construirTicketReparacion,
  existeTicketAbiertoParaVehiculo,
  resolverIdTallerPropietario,
  abrirTicketDeReparacion,
  ErrorAutorizacionPermanente,
  ErrorTicketNoAplicable,
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
            async update(data) {
              escrituras.push({ clave, data, update: true });
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
            limit() {
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
    // El ticket y el vinculo `talleres_vinculados` se escriben juntos en un
    // batch (Ronda 3), asi que el doble tiene que saber acumular y aplicar.
    batch() {
      const operaciones = [];
      return {
        set(ref, data) {
          operaciones.push(() => ref.set(data));
        },
        update(ref, data) {
          operaciones.push(() => ref.update(data));
        },
        async commit() {
          for (const operacion of operaciones) await operacion();
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
      idTaller: 't1',
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
      idTaller: 't1',
      ahora: AHORA,
    });

    assert.strictEqual(ticket.id_propietario, 'cli-real');
  });

  it('IGNORA el id_propietario de la cotizacion aunque nombre a otra persona (hallazgo C1)', () => {
    // La cotizacion es dato que el mecanico que la crea controla (firestore.rules
    // solo exige id_mecanico == auth.uid para crearla). Si esta funcion confiara
    // en cotizacion.id_propietario, un mecanico podria fabricar un ticket que
    // aparente pertenecer a la victima que el eligiera, aunque el vehiculo real
    // sea de otra persona.
    const conPropietarioFalso = cotizacion({ id_propietario: 'victima-elegida-por-el-atacante' });

    const ticket = construirTicketReparacion({
      cotizacionId: 'c1',
      cotizacion: conPropietarioFalso,
      vehiculo: { placa: 'ABC123', id_propietario: 'dueno-real' },
      idTaller: 't1',
      ahora: AHORA,
    });

    assert.strictEqual(ticket.id_propietario, 'dueno-real');
  });

  it('devuelve null si no hay vehiculo, taller o propietario que anclar', () => {
    const sinTaller = cotizacion();
    delete sinTaller.id_taller;

    assert.strictEqual(
      construirTicketReparacion({
        cotizacionId: 'c1',
        cotizacion: sinTaller,
        vehiculo: { placa: 'ABC123' },
        idTaller: '',
        ahora: AHORA,
      }),
      null
    );
  });

  it('el id_taller del ticket es el RESUELTO, no el crudo de la cotizacion', () => {
    // Ronda 4. La ronda anterior resolvia el uid del dueño solo para
    // comprobar el vinculo y escribia el crudo en el ticket. Una cotizacion
    // legacy creada por un EMPLEADO (uid de sesion en id_taller, antes del
    // FIX 2 de la Ronda 2) abria asi un ticket con el uid del empleado, y
    // TODO el cliente consulta `reparaciones` por el uid del DUEÑO
    // (idTallerEfectivo): el ticket no aparecia en ninguna pantalla.
    const deEmpleado = cotizacion({ id_taller: 'empleado1' });

    const ticket = construirTicketReparacion({
      cotizacionId: 'c1',
      cotizacion: deEmpleado,
      vehiculo: { placa: 'ABC123', id_propietario: 'cli1' },
      idTaller: 'dueno-del-taller',
      ahora: AHORA,
    });

    assert.strictEqual(ticket.id_taller, 'dueno-del-taller');
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
    // RONDA 5: UNA sola escritura. Aceptar la cotizacion abre el ticket y
    // nada mas. La Ronda 3 escribia aqui tambien
    // `vehiculos.talleres_vinculados`, es decir daba al taller acceso
    // permanente e irrevocable a la ficha del coche antes incluso de que el
    // coche llegara. El vinculo pasa a otorgarse al RECIBIR el vehiculo (ver
    // src/vinculoTaller.js) y a revocarse al cerrar el ticket.
    assert.strictEqual(db.escrituras.length, 1);
    const escrito = db.docs[`reparaciones/${id}`];
    assert.strictEqual(escrito.estado, 'pendiente_recepcion');
    assert.strictEqual(escrito.id_cotizacion, 'c1');
    assert.strictEqual(escrito.placa, 'ABC123');
    assert.strictEqual(
      db.escrituras.find((e) => e.clave === 'vehiculos/v1'),
      undefined,
      'aceptar la cotizacion NO puede dar acceso a la ficha del vehiculo'
    );
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

  it('si el vehiculo de la cotizacion no existe, lo AVISA al taller (no lo descarta en silencio)', async () => {
    // Ronda 3: antes devolvia null con un console.warn. El cliente veia su
    // cotizacion "aceptada", la tarjeta le pedia al taller que recibiera el
    // vehiculo, y no habia ticket ni forma de que lo hubiera. Ahora lanza
    // ErrorTicketNoAplicable, que el handler registra en
    // `error_apertura_ticket` y la tarjeta muestra.
    const db = fakeDb();
    const warn = sinon.stub(console, 'warn');
    try {
      await assert.rejects(
        abrirTicketDeReparacion(db, {
          cotizacionId: 'c3',
          antes: { estado: 'pendiente' },
          despues: cotizacion({ id_vehiculo: 'fantasma' }),
          ahora: AHORA,
        }),
        ErrorTicketNoAplicable
      );

      assert.deepStrictEqual(db.escrituras, []);
      assert.strictEqual(warn.calledOnce, true);
      assert.match(warn.firstCall.args[0], /c3/);
    } finally {
      warn.restore();
    }
  });

  it('una cotizacion SIN id_vehiculo (contacto desde el directorio) explica por que no habra ticket', async () => {
    // La via comun del cliente que escribe al taller desde el directorio sin
    // haber elegido coche: se podia aceptar, mostraba "EN PROCESO" y pedia
    // recibir el vehiculo. El mensaje tiene que decir que hacer.
    const db = fakeDb();
    const warn = sinon.stub(console, 'warn');
    try {
      const sinVehiculo = cotizacion();
      delete sinVehiculo.id_vehiculo;

      await assert.rejects(
        abrirTicketDeReparacion(db, {
          cotizacionId: 'c9',
          antes: { estado: 'pendiente' },
          despues: sinVehiculo,
          ahora: AHORA,
        }),
        (error) =>
          error instanceof ErrorTicketNoAplicable &&
          /no está asociada a ningún vehículo/.test(error.message)
      );
    } finally {
      warn.restore();
    }
  });

  it('no crea nada si la cotizacion no ancla a taller/propietario, y lo avisa por consola', async () => {
    const db = fakeDb({ 'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' } });
    const warn = sinon.stub(console, 'warn');
    try {
      const sinTaller = cotizacion();
      delete sinTaller.id_taller;

      await assert.rejects(
        abrirTicketDeReparacion(db, {
          cotizacionId: 'c4',
          antes: { estado: 'pendiente' },
          despues: sinTaller,
          ahora: AHORA,
        }),
        ErrorTicketNoAplicable
      );

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

describe('onCotizacionAceptada / abrirTicketDeReparacion, vinculo taller-vehiculo (hallazgo C1)', () => {
  it('NO crea ticket si el vehiculo no es del cliente al que va la cotizacion', async () => {
    // Este es el ataque central del hallazgo C1: un mecanico redacta una
    // cotizacion sobre el vehiculo de un desconocido y se la auto-acepta.
    // Sin esta comprobacion, el trigger le abria el ticket igual.
    //
    // Ronda 3: lo que lo bloquea ya no es `talleres_vinculados` (que era
    // circular, ver el comentario de `abrirTicketDeReparacion`) sino que el
    // vehiculo pertenezca al cliente nombrado en la cotizacion — y solo ese
    // cliente puede moverla a 'aceptada'.
    const db = fakeDb({
      'vehiculos/v1': {
        placa: 'ABC123',
        id_propietario: 'victima',
        talleres_vinculados: [],
      },
    });
    const error = sinon.stub(console, 'error');
    try {
      await assert.rejects(
        abrirTicketDeReparacion(db, {
          cotizacionId: 'c1',
          antes: { estado: 'pendiente' },
          despues: cotizacion({ id_taller: 'taller-atacante' }),
          ahora: AHORA,
        }),
        ErrorAutorizacionPermanente
      );
      assert.deepStrictEqual(db.escrituras, []);
      const tickets = Object.keys(db.docs).filter((k) => k.startsWith('reparaciones/'));
      assert.deepStrictEqual(tickets, []);
    } finally {
      error.restore();
    }
  });

  it('SI crea el ticket si el vehiculo es walk-in (sin ningun taller vinculado todavia)', async () => {
    const db = fakeDb({
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1', talleres_vinculados: [] },
    });

    const id = await abrirTicketDeReparacion(db, {
      cotizacionId: 'c1',
      antes: { estado: 'pendiente' },
      despues: cotizacion(),
      ahora: AHORA,
    });

    assert.strictEqual(id, idTicketDeCotizacion('c1'));
  });

  it('SI crea el ticket si el taller de la cotizacion SI esta entre los vinculados (caso legitimo)', async () => {
    const db = fakeDb({
      'vehiculos/v1': {
        placa: 'ABC123',
        id_propietario: 'cli1',
        talleres_vinculados: ['t1', 'otro-taller'],
      },
    });

    const id = await abrirTicketDeReparacion(db, {
      cotizacionId: 'c1',
      antes: { estado: 'pendiente' },
      despues: cotizacion(), // id_taller: 't1'
      ahora: AHORA,
    });

    assert.strictEqual(id, idTicketDeCotizacion('c1'));
    const escrito = db.docs[`reparaciones/${id}`];
    assert.strictEqual(escrito.id_propietario, 'cli1');
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
      'reparaciones/r2': { id_vehiculo: 'v1', id_taller: 't1', estado: 'entregado' },
    });

    assert.strictEqual(
      await existeTicketAbiertoParaVehiculo(db, { idVehiculo: 'v1', idTaller: 't1' }),
      false
    );
  });

  it('RONDA 6: `listo_para_entrega` SI cuenta como abierto', async () => {
    // El coche esta terminado pero sigue en el taller esperando a que lo
    // recojan: la visita no ha acabado. Antes contaba como cerrada, asi que
    // una cotizacion aceptada en ese momento abria un SEGUNDO ticket para la
    // misma visita y el mecanico se encontraba dos tarjetas del mismo coche.
    const db = fakeDb({
      'reparaciones/r1': {
        id_vehiculo: 'v1',
        id_taller: 't1',
        estado: 'listo_para_entrega',
      },
    });

    assert.strictEqual(
      await existeTicketAbiertoParaVehiculo(db, { idVehiculo: 'v1', idTaller: 't1' }),
      true
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

  it('si el ticket abierto ya se cerro (entregado), una cotizacion nueva SI abre uno propio', async () => {
    // Cierra el ciclo: un vehiculo que vuelve DESPUES de que su visita
    // anterior termino no debe quedar bloqueado para siempre.
    const db = fakeDb({
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
      'reparaciones/legado1': {
        id_vehiculo: 'v1',
        id_taller: 't1',
        estado: 'entregado',
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

describe('onCotizacionAceptada / resolverIdTallerPropietario (FIX 2, Ronda 2)', () => {
  it('resuelve el uid de un empleado al uid de su taller dueño', async () => {
    const db = fakeDb({ 'usuarios/emp1': { id_taller_propietario: 't1' } });
    assert.strictEqual(await resolverIdTallerPropietario(db, 'emp1'), 't1');
  });

  it('devuelve el mismo uid si el documento no tiene id_taller_propietario (es el dueño)', async () => {
    const db = fakeDb({ 'usuarios/t1': { rol: 'Taller' } });
    assert.strictEqual(await resolverIdTallerPropietario(db, 't1'), 't1');
  });

  it('devuelve el mismo uid si el documento de usuario no existe (dato legacy)', async () => {
    const db = fakeDb({});
    assert.strictEqual(await resolverIdTallerPropietario(db, 'fantasma'), 'fantasma');
  });

  it('devuelve el mismo valor si idTaller viene vacio', async () => {
    const db = fakeDb({});
    assert.strictEqual(await resolverIdTallerPropietario(db, ''), '');
  });
});

describe('onCotizacionAceptada / abrirTicketDeReparacion, empleado vs dueño (FIX 2, regresion de la revision de rama anterior)', () => {
  it('SI crea el ticket cuando la cotizacion la mando un EMPLEADO y el vehiculo esta vinculado al DUEÑO', async () => {
    // Regresion que este fix cierra: los tres creadores de cliente escriben
    // `idTaller: userId` (el uid de sesion). Para un empleado eso es SU
    // PROPIO uid, nunca el del dueño — pero `talleres_vinculados` solo
    // guarda uids de dueño. Antes de este fix, esta cotizacion fallaba
    // `vehiculoVinculadoOWalkIn` y no se abria ningun ticket pese a que el
    // taller SI estaba legitimamente vinculado al vehiculo.
    const db = fakeDb({
      'usuarios/emp1': { id_taller_propietario: 't1' },
      'vehiculos/v1': {
        placa: 'ABC123',
        id_propietario: 'cli1',
        talleres_vinculados: ['t1'],
      },
    });

    const id = await abrirTicketDeReparacion(db, {
      cotizacionId: 'c1',
      antes: { estado: 'pendiente' },
      despues: cotizacion({ id_mecanico: 'emp1', id_taller: 'emp1' }),
      ahora: AHORA,
    });

    assert.strictEqual(id, idTicketDeCotizacion('c1'));
    const escrito = db.docs[`reparaciones/${id}`];
    assert.strictEqual(escrito.id_propietario, 'cli1');
  });

  it('aceptar la cotizacion NO otorga ningun acceso al vehiculo (ronda 5)', async () => {
    const db = fakeDb({
      'usuarios/emp1': { id_taller_propietario: 't1' },
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
    });

    await abrirTicketDeReparacion(db, {
      cotizacionId: 'c1',
      antes: { estado: 'pendiente' },
      despues: cotizacion({ id_mecanico: 'emp1', id_taller: 'emp1' }),
      ahora: AHORA,
    });

    assert.strictEqual(
      db.escrituras.find((e) => e.clave === 'vehiculos/v1'),
      undefined,
      'el acceso a la ficha llega al recibir el coche, no al aceptar'
    );

    // Ronda 4: y el TICKET tambien. Antes se escribia el crudo ('emp1'), asi
    // que el ticket quedaba fuera de `watchReparacionesActivas`,
    // `buscarReparacionActiva` y del Kanban — todos consultan por el uid del
    // dueño — y `actuaPorTaller(resource.data.id_taller)` se lo negaba al
    // propio dueño del taller. Un ticket que no aparecia en ninguna parte.
    const escrituraTicket = db.escrituras.find((e) =>
      e.clave.startsWith('reparaciones/')
    );
    assert.strictEqual(escrituraTicket.data.id_taller, 't1');
  });

  it('el dedup por vehiculo+taller pregunta por el uid RESUELTO', async () => {
    // Corolario del anterior: si el dedup consulta con el uid del empleado no
    // ve el ticket que el taller ya tiene abierto para ese mismo coche y abre
    // un segundo ticket paralelo, que es justo lo que ese dedup existe para
    // impedir.
    const db = fakeDb({
      'usuarios/emp1': { id_taller_propietario: 't1' },
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
      'reparaciones/ticket-viejo': {
        id_vehiculo: 'v1',
        id_taller: 't1',
        estado: 'recibido',
      },
    });

    const id = await abrirTicketDeReparacion(db, {
      cotizacionId: 'c1',
      antes: { estado: 'pendiente' },
      despues: cotizacion({ id_mecanico: 'emp1', id_taller: 'emp1' }),
      ahora: AHORA,
    });

    assert.strictEqual(id, null);
    assert.deepStrictEqual(db.escrituras, []);
  });

  it('EL BLOQUEANTE DE LA RONDA 3: un SEGUNDO taller si puede abrir ticket', async () => {
    // Antes de este fix, `vehiculoVinculadoOWalkIn` solo dejaba pasar el caso
    // walk-in (lista vacia). Un vehiculo ya atendido por el taller A dejaba a
    // cualquier otro taller sin poder abrir ticket JAMAS, aunque el dueño
    // hubiera aceptado su cotizacion: el cliente veia "aceptada" y el taller
    // no recibia nada. Este test es esa situacion exacta.
    const db = fakeDb({
      'vehiculos/v1': {
        placa: 'ABC123',
        id_propietario: 'cli1',
        talleres_vinculados: ['taller-anterior'],
      },
    });

    const id = await abrirTicketDeReparacion(db, {
      cotizacionId: 'c1',
      antes: { estado: 'pendiente' },
      despues: cotizacion(), // id_taller: 't1', un taller nuevo para este coche
      ahora: AHORA,
    });

    assert.strictEqual(id, idTicketDeCotizacion('c1'));
    assert.strictEqual(db.docs[`reparaciones/${id}`].estado, 'pendiente_recepcion');
  });
});
