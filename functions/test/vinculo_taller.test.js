'use strict';

/**
 * Ronda 5 — el vinculo taller-vehiculo sigue a la POSESION del coche.
 *
 * Estas pruebas cubren la logica que ANTES vivia en
 * `ReparacionRepository.recibirVehiculo` (cliente, sobre FakeFirebaseFirestore)
 * y que se mudo al servidor al tener que escribir el vinculo en la misma
 * operacion atomica que la recepcion.
 */

const assert = require('assert');
const { FieldValue } = require('firebase-admin/firestore');

const {
  ErrorRecepcion,
  debeRevocarVinculo,
  revocarVinculo,
  recibirTicketYVincular,
  revocarVinculoAlCerrar,
} = require('../src/vinculoTaller');

const AHORA = new Date('2026-09-06T12:00:00Z');

/**
 * Doble en memoria con lo justo que usan estas funciones: `doc().get()`,
 * `doc().update()`, un `batch()` que acumula y aplica, y un `runTransaction()`
 * que modela el CONFLICTO. `docs` va indexado por `coleccion/id`; una clave
 * ausente es un documento que no existe.
 *
 * El `runTransaction` no es decorativo. Firestore reintenta la transaccion
 * entera si algo de lo que leyo cambio antes del commit, y esa propiedad es
 * justo lo que se estaba probando al mudar la recepcion de `batch` a
 * transaccion: sin modelar el conflicto, un doble que se limitara a ejecutar
 * el cuerpo y aplicar las escrituras daria verde igual con las dos versiones,
 * y el test no probaria nada. Aqui se lleva una version por documento, se
 * anota la de cada `tx.get`, y si al commit alguna cambio se reejecuta el
 * cuerpo con los datos nuevos.
 */
/**
 * `JSON.stringify` convierte un `Date` en cadena y el `parse` no lo deshace.
 * El historial de estados lleva fechas, y los tests las comparan como `Date`,
 * asi que se marcan y se reconstruyen.
 */
function serializarFechas(clave, valor) {
  return valor instanceof Date ? { __fecha: valor.toISOString() } : valor;
}

function revivirFechas(clave, valor) {
  return valor && valor.__fecha ? new Date(valor.__fecha) : valor;
}

function fakeDb(docs = {}, ganchoLectura = null, fallarAlEscribir = new Set()) {
  const escrituras = [];
  const versiones = new Map();
  const bump = (clave) => versiones.set(clave, (versiones.get(clave) || 0) + 1);
  const existe = (clave) => Object.prototype.hasOwnProperty.call(docs, clave);
  const errorNoExiste = (clave) => {
    const error = new Error(`No document to update: ${clave}`);
    error.code = 5;
    return error;
  };
  const refDe = (coleccion, id) => {
    const clave = `${coleccion}/${id}`;
    return {
      id,
      clave,
      async get() {
        // Un snapshot de Firestore es INMUTABLE: es una copia del documento en
        // el instante de la lectura. El doble devolvia `docs[clave]` vivo, asi
        // que una escritura posterior se veia retroactivamente en un snapshot
        // ya leido — y con eso ningun test podia distinguir "lei antes" de
        // "lei despues". Copiar aqui es lo que hace observable la carrera.
        const copia = existe(clave)
          ? JSON.parse(JSON.stringify(docs[clave], serializarFechas), revivirFechas)
          : undefined;
        const instantanea = { exists: copia !== undefined, data: () => copia };
        // Punto de interferencia: deja que un test escriba ENTRE la lectura y
        // el commit, que es donde vive la carrera. Va en el doble, y no en un
        // callback de produccion, para que la ventana sea la misma con `batch`
        // y con transaccion — si no, el test no llegaria a ejercer la version
        // rota y daria verde con ella.
        if (ganchoLectura) await ganchoLectura(clave);
        return instantanea;
      },
      async update(data) {
        // Un fallo que NO es "el documento no existe": indisponibilidad,
        // cuota, permisos. `revocarVinculo` trata el not-found como caso
        // normal (el dueño borro el coche, no hay vinculo que revocar), asi
        // que para probar el camino de error hace falta otro.
        if (fallarAlEscribir.has(clave)) {
          const error = new Error(`UNAVAILABLE: ${clave}`);
          error.code = 14;
          throw error;
        }
        if (!existe(clave)) throw errorNoExiste(clave);
        escrituras.push({ clave, data });
        docs[clave] = Object.assign({}, docs[clave], data);
        bump(clave);
      },
    };
  };
  return {
    docs,
    escrituras,
    collection: (coleccion) => ({ doc: (id) => refDe(coleccion, id) }),
    // El batch del doble tiene que ser ATOMICO como el de verdad: comprueba
    // TODAS las precondiciones antes de escribir ninguna. Con un bucle que
    // escribia una a una, el test de "el vehiculo ya no existe" veia el ticket
    // recibido a medias — un artefacto del doble, no del codigo.
    batch() {
      const operaciones = [];
      return {
        update(ref, data) {
          operaciones.push({ ref, data });
        },
        async commit() {
          for (const { ref } of operaciones) {
            if (!existe(ref.clave)) throw errorNoExiste(ref.clave);
          }
          for (const { ref, data } of operaciones) await ref.update(data);
        },
      };
    },
    async runTransaction(cuerpo) {
      for (let intento = 0; intento < 5; intento += 1) {
        const leidos = new Map();
        const pendientes = [];
        const tx = {
          async get(ref) {
            leidos.set(ref.clave, versiones.get(ref.clave) || 0);
            return ref.get();
          },
          update(ref, data) {
            pendientes.push({ ref, data });
          },
        };
        const resultado = await cuerpo(tx);

        const conflicto = [...leidos].some(
          ([clave, version]) => (versiones.get(clave) || 0) !== version
        );
        if (conflicto) continue;

        for (const { ref } of pendientes) {
          if (!existe(ref.clave)) throw errorNoExiste(ref.clave);
        }
        for (const { ref, data } of pendientes) await ref.update(data);
        return resultado;
      }
      throw new Error('transaccion: demasiados reintentos');
    },
  };
}

const ticketPendiente = (extra = {}) =>
  Object.assign(
    {
      id_vehiculo: 'v1',
      id_taller: 't1',
      id_propietario: 'cli1',
      placa: 'ABC123',
      estado: 'pendiente_recepcion',
      historial_estados: [{ estado: 'pendiente_recepcion', timestamp: AHORA }],
    },
    extra
  );

describe('vinculoTaller / debeRevocarVinculo', () => {
  it('revoca al pasar de abierto a cerrado', () => {
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'listo_para_entrega' }, { estado: 'entregado' }),
      true
    );
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'en_revision' }, { estado: 'cancelado' }),
      true
    );
  });

  it('NO revoca si el ticket sigue abierto', () => {
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'pendiente_recepcion' }, { estado: 'recibido' }),
      false
    );
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'recibido' }, { estado: 'en_revision' }),
      false
    );
  });

  it('RONDA 6: `listo_para_entrega` NO revoca — el coche sigue en el taller', () => {
    // Este era el bug: el ultimo estado del pipeline se tomaba por el final
    // de la visita, asi que al terminar el trabajo el taller perdia el acceso
    // a la ficha del coche que todavia tenia aparcado dentro, y una
    // cotizacion aceptada nueva del mismo cliente abria un SEGUNDO ticket
    // para la misma visita.
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'en_revision' }, { estado: 'listo_para_entrega' }),
      false
    );
    // Y desde ahi si se revoca, pero solo al entregar.
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'listo_para_entrega' }, { estado: 'cancelado' }),
      true
    );
  });

  it('NO revoca dos veces: una escritura sobre un ticket YA cerrado no cuenta', () => {
    // Sin esta guarda, cualquier correccion tardia sobre un ticket viejo
    // volveria a revocar — y si el mismo coche ya habia vuelto al mismo
    // taller, le arrancaria el vinculo VIVO de la visita nueva.
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'entregado' }, { estado: 'entregado' }),
      false
    );
    assert.strictEqual(
      debeRevocarVinculo({ estado: 'cancelado' }, { estado: 'entregado' }),
      false
    );
  });

  it('un ticket legado sin `estado` cuenta como abierto (nacia en recibido)', () => {
    assert.strictEqual(debeRevocarVinculo({}, { estado: 'cancelado' }), true);
  });
});

describe('vinculoTaller / revocarVinculo', () => {
  it('saca al taller de talleres_vinculados', async () => {
    const db = fakeDb({ 'vehiculos/v1': { talleres_vinculados: ['t1'] } });

    assert.strictEqual(
      await revocarVinculo(db, { idVehiculo: 'v1', idTaller: 't1' }),
      true
    );
    assert.deepStrictEqual(db.escrituras[0].data.talleres_vinculados, FieldValue.arrayRemove('t1'));
  });

  it('un vehiculo ya borrado no es un error que reintentar', async () => {
    const db = fakeDb({});
    assert.strictEqual(
      await revocarVinculo(db, { idVehiculo: 'fantasma', idTaller: 't1' }),
      false
    );
  });
});

describe('vinculoTaller / recibirTicketYVincular', () => {
  it('mueve el ticket a recibido Y otorga el vinculo, en el mismo lote', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente(),
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
    });

    const resultado = await recibirTicketYVincular(db, {
      idReparacion: 'r1',
      ahora: AHORA,
    });

    assert.strictEqual(resultado.recibidoAhora, true);
    assert.strictEqual(db.docs['reparaciones/r1'].estado, 'recibido');
    assert.strictEqual(db.docs['reparaciones/r1'].historial_estados.length, 2);
    // Las dos mitades: sin la segunda, el ticket queda recibido y el taller
    // sigue sin poder abrir la ficha del coche que tiene en el patio.
    assert.deepStrictEqual(
      db.escrituras.map((e) => e.clave),
      ['reparaciones/r1', 'vehiculos/v1']
    );
    assert.deepStrictEqual(
      db.escrituras[1].data.talleres_vinculados,
      FieldValue.arrayUnion('t1')
    );
    // Ronda 6: ademas del vinculo "ahora", se deja constancia permanente de
    // que este taller ha tenido este coche. Es lo unico que le permitira
    // completar o corregir su propio registro de servicio despues de
    // entregarlo, sin reabrirle la ficha ajena a todo el mundo — ver el
    // carve-out de walk-in en firestore.rules.
    assert.deepStrictEqual(
      db.escrituras[1].data.talleres_conocidos,
      FieldValue.arrayUnion('t1')
    );
  });

  it('deja el ticket marcado como ABIERTO (gap 9.1)', async () => {
    // El ticket ya estaba abierto antes de recibirlo, asi que el valor no
    // cambia; lo que importa es que quede ESCRITO. Los tickets anteriores al
    // gap 9.1 no traen el campo, y desde que el tablero consulta
    // `abierto == true` un documento sin el no aparece: esta escritura es lo
    // que repara a los legados que pasen por una recepcion, sin esperar al
    // backfill.
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente(),
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
    });

    await recibirTicketYVincular(db, { idReparacion: 'r1', ahora: AHORA });

    assert.strictEqual(db.docs['reparaciones/r1'].abierto, true);
  });

  it('repara `abierto` en un ticket LEGADO, que es el que lo necesita', async () => {
    // Gate de revision: la escritura vivia dentro de `if (recibidoAhora)`, y
    // `recibidoAhora` solo es cierto para un ticket en `pendiente_recepcion`
    // — o sea uno que creo `construirTicketReparacion`, que YA escribe el
    // campo. Reparaba justo el caso que no lo necesitaba.
    //
    // Los legados (anteriores a A4b, sin `estado`) se resuelven a 'recibido',
    // asi que caen por la rama idempotente y nunca recibian `abierto`. Son
    // exactamente los que no salen en el tablero.
    const db = fakeDb({
      'reparaciones/r1': { id_vehiculo: 'v1', id_taller: 't1', id_propietario: 'cli1' },
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
    });

    const resultado = await recibirTicketYVincular(db, {
      idReparacion: 'r1',
      ahora: AHORA,
    });

    assert.strictEqual(resultado.recibidoAhora, false);
    assert.strictEqual(db.docs['reparaciones/r1'].abierto, true);
  });

  it('un legado ya reparado no paga otra escritura', async () => {
    // La rama idempotente solo escribe si hace falta: recibir dos veces no
    // puede costar una escritura cada vez.
    const db = fakeDb({
      'reparaciones/r1': {
        id_vehiculo: 'v1', id_taller: 't1', id_propietario: 'cli1',
        estado: 'en_revision', abierto: true, vinculo_activo: true,
      },
      'vehiculos/v1': { placa: 'ABC123', id_propietario: 'cli1' },
    });

    await recibirTicketYVincular(db, { idReparacion: 'r1', ahora: AHORA });

    assert.deepStrictEqual(
      db.escrituras.map((e) => e.clave),
      ['vehiculos/v1']
    );
  });

  it('revocar el vinculo NO borra `talleres_conocidos`', async () => {
    // La visita termina y el taller pierde el acceso a la ficha, pero no la
    // historia de que atendio el coche: si `talleres_conocidos` se borrara,
    // el taller no podria ni corregir la factura que acaba de emitir.
    const db = fakeDb({ 'vehiculos/v1': { talleres_vinculados: ['t1'] } });

    await revocarVinculo(db, { idVehiculo: 'v1', idTaller: 't1' });

    assert.strictEqual(db.escrituras.length, 1);
    assert.ok(
      !Object.prototype.hasOwnProperty.call(
        db.escrituras[0].data,
        'talleres_conocidos'
      )
    );
  });

  it('recibir dos veces no es un error, y reasegura el vinculo', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente({ estado: 'en_revision' }),
      'vehiculos/v1': { placa: 'ABC123' },
    });

    const resultado = await recibirTicketYVincular(db, {
      idReparacion: 'r1',
      ahora: AHORA,
    });

    // No-op en el estado: no se arrastra hacia atras un ticket ya avanzado.
    assert.strictEqual(resultado.recibidoAhora, false);
    assert.strictEqual(db.docs['reparaciones/r1'].estado, 'en_revision');
    // Pero el vinculo SI se reescribe: un ticket abierto antes de que
    // existiera este flujo (o uno cuyo vinculo se revoco por error) recupera
    // el acceso al reabrirlo, en vez de quedarse sin ficha para siempre. Y el
    // ticket queda marcado como vinculado, que es lo que lo pone bajo la
    // caducidad por inactividad: recuperar el acceso sin quedar sujeto a ella
    // seria una puerta trasera al residual 7.2.
    assert.deepStrictEqual(
      db.escrituras.map((e) => e.clave),
      ['reparaciones/r1', 'vehiculos/v1']
    );
  });

  it('un ticket CANCELADO se rechaza y no toca nada', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente({ estado: 'cancelado' }),
      'vehiculos/v1': { placa: 'ABC123' },
    });

    await assert.rejects(
      recibirTicketYVincular(db, { idReparacion: 'r1', ahora: AHORA }),
      (error) =>
        error instanceof ErrorRecepcion &&
        error.code === 'failed-precondition' &&
        /cancelado/.test(error.message)
    );
    assert.deepStrictEqual(db.escrituras, []);
  });

  it('un ticket YA ENTREGADO se rechaza y no toca nada', async () => {
    // Recibir un ticket cerrado volveria a otorgar el vinculo al vehiculo
    // sobre una visita que ya termino — el acceso permanente que la ronda 5
    // elimino, reintroducido por la puerta de atras.
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente({ estado: 'entregado' }),
      'vehiculos/v1': { placa: 'ABC123' },
    });

    await assert.rejects(
      recibirTicketYVincular(db, { idReparacion: 'r1', ahora: AHORA }),
      (error) =>
        error instanceof ErrorRecepcion &&
        error.code === 'failed-precondition' &&
        /ya se entreg/.test(error.message)
    );
    assert.deepStrictEqual(db.escrituras, []);
  });

  it('un ticket en `listo_para_entrega` SI se puede recibir (reasegura el vinculo)', async () => {
    // El coche sigue dentro: ese ticket esta abierto, y reabrir su pantalla
    // tiene que devolverle al taller el acceso a la ficha, no rechazarlo.
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente({ estado: 'listo_para_entrega' }),
      'vehiculos/v1': { placa: 'ABC123' },
    });

    const resultado = await recibirTicketYVincular(db, {
      idReparacion: 'r1',
      ahora: AHORA,
    });

    assert.strictEqual(resultado.recibidoAhora, false);
    // Igual que arriba: el vinculo se reasegura y el ticket queda marcado.
    assert.deepStrictEqual(db.escrituras.map((x) => x.clave), [
      'reparaciones/r1',
      'vehiculos/v1',
    ]);
  });

  it('un ticket que no existe se rechaza con not-found', async () => {
    const db = fakeDb({});
    await assert.rejects(
      recibirTicketYVincular(db, { idReparacion: 'fantasma', ahora: AHORA }),
      (error) => error instanceof ErrorRecepcion && error.code === 'not-found'
    );
  });

  it('si el vehiculo ya no existe, NO deja el ticket recibido a medias', async () => {
    // El lote es atomico: o entran las dos escrituras o ninguna. Sin eso, el
    // ticket quedaria en `recibido` y el taller sin acceso, que es justo el
    // estado inconsistente que este diseño existe para evitar.
    const db = fakeDb({ 'reparaciones/r1': ticketPendiente() });

    await assert.rejects(
      recibirTicketYVincular(db, { idReparacion: 'r1', ahora: AHORA }),
      (error) =>
        error instanceof ErrorRecepcion &&
        error.code === 'not-found' &&
        /ya no existe/.test(error.message)
    );
    assert.strictEqual(db.docs['reparaciones/r1'].estado, 'pendiente_recepcion');
  });
});

describe('vinculoTaller / recibirTicketYVincular, concurrencia y autorizacion', () => {
  it('no pierde una entrada de historial escrita mientras se recibia', async () => {
    // Residual 7.7 de FUNC-02. `historial_estados` se reconstruye EN MEMORIA
    // (se lee el array, se le hace push y se escribe entero, porque una
    // entrada nueva no se puede añadir con `arrayUnion` sin arriesgar
    // deduplicacion de objetos iguales). Con un `batch`, esa lectura no esta
    // atada a la escritura: cualquier otra transicion que ocurra entre medias
    // —el cliente avanzando el ticket desde el tablero, una cancelacion— se
    // escribe y acto seguido la recepcion la pisa con su copia vieja del
    // array. El estado se pierde sin error y sin rastro.
    //
    // Con `runTransaction`, Firestore detecta que el documento leido cambio y
    // reejecuta el cuerpo sobre los datos nuevos.
    let interferido = false;
    const db = fakeDb({}, async (clave) => {
      if (clave !== 'reparaciones/r1' || interferido) return;
      interferido = true;
      // Otro escritor mete su transicion justo despues de que la recepcion
      // haya leido el ticket.
      await db.collection('reparaciones').doc('r1').update({
        historial_estados: [
          { estado: 'pendiente_recepcion', timestamp: AHORA },
          { estado: 'en_revision', timestamp: AHORA },
        ],
      });
    });
    db.docs['reparaciones/r1'] = ticketPendiente();
    db.docs['vehiculos/v1'] = { talleres_vinculados: [] };

    await recibirTicketYVincular(db, { idReparacion: 'r1', ahora: AHORA });

    const estados = db.docs['reparaciones/r1'].historial_estados.map(
      (e) => e.estado
    );
    assert.deepStrictEqual(estados, [
      'pendiente_recepcion',
      'en_revision',
      'recibido',
    ]);
  });

  it('sin autorizacion no escribe nada y lanza permission-denied', async () => {
    // La autorizacion pasa a ocurrir DENTRO de la transaccion, sobre el mismo
    // snapshot del ticket que decide la escritura. Antes el callable leia el
    // ticket para autorizar y `recibirTicketYVincular` lo volvia a leer para
    // escribir: una lectura de mas y, peor, una ventana en la que el
    // `id_taller` podia cambiar entre las dos y la autorizacion quedaba
    // decidida sobre el documento viejo.
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente(),
      'vehiculos/v1': { talleres_vinculados: [] },
    });

    await assert.rejects(
      recibirTicketYVincular(db, {
        idReparacion: 'r1',
        ahora: AHORA,
        autorizar: async () => false,
      }),
      (error) =>
        error instanceof ErrorRecepcion && error.code === 'permission-denied'
    );
    assert.deepStrictEqual(db.escrituras, []);
    assert.strictEqual(db.docs['reparaciones/r1'].estado, 'pendiente_recepcion');
  });

  it('la autorizacion recibe el id_taller del ticket recien leido', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente({ id_taller: 't-real' }),
      'vehiculos/v1': { talleres_vinculados: [] },
    });
    const vistos = [];

    await recibirTicketYVincular(db, {
      idReparacion: 'r1',
      ahora: AHORA,
      autorizar: async (idTaller) => {
        vistos.push(idTaller);
        return true;
      },
    });

    assert.deepStrictEqual(vistos, ['t-real']);
  });
});

describe('vinculoTaller / revocarVinculoAlCerrar, un fallo no se pierde', () => {
  const cerrado = { id_vehiculo: 'v1', id_taller: 't1', estado: 'entregado' };
  const abierto = { id_vehiculo: 'v1', id_taller: 't1', estado: 'recibido' };

  it('si la revocacion falla, deja marca en el ticket', async () => {
    // Residual 7.9 de FUNC-02. El trigger capturaba el error, lo registraba y
    // seguia. La razon era buena —el ticket ya esta cerrado y relanzar sin
    // `failurePolicy` no reintenta nada— pero el resultado era que el vinculo
    // sobrevivia al `entregado` sin que nadie pudiera saberlo: el taller
    // conserva el acceso a la ficha de un coche que ya devolvio, y la unica
    // huella es una linea de log. Dejar marca no arregla la revocacion, pero
    // convierte un estado invisible en uno CONSULTABLE y reparable.
    const db = fakeDb(
      { 'reparaciones/r1': cerrado, 'vehiculos/v1': { talleres_vinculados: ['t1'] } },
      null,
      new Set(['vehiculos/v1'])
    );

    const { resultado, error } = await revocarVinculoAlCerrar(db, {
      antes: abierto,
      despues: cerrado,
      ref: db.collection('reparaciones').doc('r1'),
    });

    assert.strictEqual(resultado, 'pendiente');
    assert.ok(error, 'el error se devuelve para que el llamador lo registre');
    assert.strictEqual(db.docs['reparaciones/r1'].vinculo_revocacion_pendiente, true);
  });

  it('una escritura posterior con la marca reintenta y la limpia', async () => {
    // Autorreparacion sin maquinaria nueva: el propio trigger `onUpdate` se
    // despierta con cualquier escritura sobre el ticket, y si ve la marca
    // vuelve a intentarlo. No hace falta un barrido programado.
    const db = fakeDb({
      'reparaciones/r1': Object.assign({}, cerrado, {
        vinculo_revocacion_pendiente: true,
      }),
      'vehiculos/v1': { talleres_vinculados: ['t1'] },
    });

    const { resultado } = await revocarVinculoAlCerrar(db, {
      // Ya estaba cerrado antes y despues: no es la transicion, es la marca
      // la que dispara el reintento.
      antes: db.docs['reparaciones/r1'],
      despues: db.docs['reparaciones/r1'],
      ref: db.collection('reparaciones').doc('r1'),
    });

    assert.strictEqual(resultado, 'revocado');
    const limpieza = db.escrituras.find(
      (x) => x.clave === 'reparaciones/r1'
    );
    assert.ok(
      limpieza && 'vinculo_revocacion_pendiente' in limpieza.data,
      'la marca tiene que limpiarse, o el ticket se reintenta para siempre'
    );
  });

  it('sin transicion de cierre y sin marca, no hace nada', async () => {
    const db = fakeDb({ 'reparaciones/r1': abierto, 'vehiculos/v1': {} });

    const { resultado } = await revocarVinculoAlCerrar(db, {
      antes: abierto,
      despues: abierto,
      ref: db.collection('reparaciones').doc('r1'),
    });

    assert.strictEqual(resultado, 'nada');
    assert.deepStrictEqual(db.escrituras, []);
  });

  it('un reintento que vuelve a fallar no reescribe la marca', async () => {
    // Si reescribiera, cada reescritura despertaria al trigger otra vez: un
    // bucle facturado sobre un fallo que no se arregla solo.
    const db = fakeDb(
      {
        'reparaciones/r1': Object.assign({}, cerrado, {
          vinculo_revocacion_pendiente: true,
        }),
        'vehiculos/v1': { talleres_vinculados: ['t1'] },
      },
      null,
      new Set(['vehiculos/v1'])
    );

    const { resultado } = await revocarVinculoAlCerrar(db, {
      antes: db.docs['reparaciones/r1'],
      despues: db.docs['reparaciones/r1'],
      ref: db.collection('reparaciones').doc('r1'),
    });

    assert.strictEqual(resultado, 'pendiente');
    assert.deepStrictEqual(db.escrituras, []);
  });
});

describe('vinculoTaller / el ticket dice si su vinculo esta vivo', () => {
  // `vinculo_activo` es lo que hace barrible la caducidad del residual 7.2:
  // el barrido pregunta por ese campo, no por el estado del ticket, porque un
  // ticket abandonado sigue abandonado despues de caducarle el vinculo y
  // volveria a salir en cada corrida. Lo mantienen los dos extremos, y si uno
  // de los dos se olvida el barrido deja de funcionar en silencio.
  it('recibir el vehiculo lo marca como vivo', async () => {
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente(),
      'vehiculos/v1': { talleres_vinculados: [] },
    });

    await recibirTicketYVincular(db, { idReparacion: 'r1', ahora: AHORA });

    assert.strictEqual(db.docs['reparaciones/r1'].vinculo_activo, true);
  });

  it('recibir un ticket YA recibido tambien lo marca (reasegura el vinculo)', async () => {
    // La recepcion es idempotente y reasegura el vinculo aunque no transicione
    // el estado; si no marcara, un ticket legado recuperaria el acceso sin
    // quedar sujeto a la caducidad.
    const db = fakeDb({
      'reparaciones/r1': ticketPendiente({ estado: 'en_revision' }),
      'vehiculos/v1': { talleres_vinculados: [] },
    });

    const { recibidoAhora } = await recibirTicketYVincular(db, {
      idReparacion: 'r1',
      ahora: AHORA,
    });

    assert.strictEqual(recibidoAhora, false);
    assert.strictEqual(db.docs['reparaciones/r1'].vinculo_activo, true);
  });

  it('cerrar el ticket lo marca como muerto', async () => {
    const cerrado = {
      id_vehiculo: 'v1',
      id_taller: 't1',
      estado: 'entregado',
      vinculo_activo: true,
    };
    const db = fakeDb({
      'reparaciones/r1': cerrado,
      'vehiculos/v1': { talleres_vinculados: ['t1'] },
    });

    await revocarVinculoAlCerrar(db, {
      antes: { id_vehiculo: 'v1', id_taller: 't1', estado: 'recibido' },
      despues: cerrado,
      ref: db.collection('reparaciones').doc('r1'),
    });

    assert.strictEqual(db.docs['reparaciones/r1'].vinculo_activo, false);
  });
});

describe('vinculoTaller / la marca no cuesta escrituras de mas', () => {
  it('cerrar un ticket legado (sin el campo) no le escribe nada', async () => {
    // Cada escritura sobre el ticket vuelve a despertar al trigger, que es un
    // `onUpdate` sobre la misma coleccion. Termina, pero se factura, y un
    // ticket que nunca tuvo `vinculo_activo` no tiene nada que limpiar.
    const cerrado = { id_vehiculo: 'v1', id_taller: 't1', estado: 'entregado' };
    const db = fakeDb({
      'reparaciones/r1': cerrado,
      'vehiculos/v1': { talleres_vinculados: ['t1'] },
    });

    const { resultado } = await revocarVinculoAlCerrar(db, {
      antes: { id_vehiculo: 'v1', id_taller: 't1', estado: 'recibido' },
      despues: cerrado,
      ref: db.collection('reparaciones').doc('r1'),
    });

    assert.strictEqual(resultado, 'revocado');
    assert.deepStrictEqual(
      db.escrituras.map((e) => e.clave),
      ['vehiculos/v1']
    );
  });
});
