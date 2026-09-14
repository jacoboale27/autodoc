'use strict';

const assert = require('assert');

const {
  VIGENCIA_MINUTOS,
  MAX_CANJES,
  proyeccionServicioCompartido,
  crearTokenHistorial,
  leerHistorialPorToken,
  revocarTokenHistorial,
} = require('../src/historialCompartido');

// ---------------------------------------------------------------------------
// Doble de Firestore, minimo y honesto sobre lo que NO modela.
//
// Modela: get/set/update/delete de documento, y una consulta con `where` de
// igualdad mas `orderBy` y `limit`. El `limit` se APLICA de verdad: en este
// repo ya hubo dos dobles con `limit()` como no-op, y con eso un test de cota
// da verde sin ejercer la cota.
// ---------------------------------------------------------------------------
function hacerDb(semilla = {}) {
  const datos = JSON.parse(JSON.stringify(semilla));

  function coleccion(nombre) {
    datos[nombre] = datos[nombre] || {};
    const filtros = [];
    let orden = null;
    let tope = null;

    const api = {
      doc(id) {
        return {
          id,
          async get() {
            const d = datos[nombre][id];
            return {
              exists: d !== undefined,
              id,
              data: () =>
                d === undefined ? undefined : JSON.parse(JSON.stringify(d)),
            };
          },
          async set(v) {
            datos[nombre][id] = JSON.parse(JSON.stringify(v));
          },
          async update(v) {
            datos[nombre][id] = {
              ...datos[nombre][id],
              ...JSON.parse(JSON.stringify(v)),
            };
          },
          async delete() {
            delete datos[nombre][id];
          },
        };
      },
      where(campo, op, valor) {
        assert.strictEqual(op, '==', 'el doble solo modela igualdad');
        filtros.push([campo, valor]);
        return api;
      },
      orderBy(campo, dir) {
        orden = [campo, dir || 'asc'];
        return api;
      },
      limit(n) {
        tope = n;
        return api;
      },
      async get() {
        let docs = Object.entries(datos[nombre]).map(([id, d]) => ({
          id,
          data: () => JSON.parse(JSON.stringify(d)),
          _raw: d,
        }));
        for (const [campo, valor] of filtros) {
          docs = docs.filter((x) => x._raw[campo] === valor);
        }
        if (orden) {
          const [campo, dir] = orden;
          docs.sort((a, b) =>
            dir === 'desc'
              ? (b._raw[campo] || 0) - (a._raw[campo] || 0)
              : (a._raw[campo] || 0) - (b._raw[campo] || 0),
          );
        }
        if (tope !== null) docs = docs.slice(0, tope);
        return { empty: docs.length === 0, size: docs.length, docs };
      },
    };
    return api;
  }

  return { collection: coleccion, _datos: datos };
}

const AHORA = 1700000000000;
const idsFijos = () => 'token-fijo-para-pruebas';

// Forma real de un token: 64 hex. Los fixtures la respetan porque el modulo
// la valida antes de tocar Firestore.
const T = 'a'.repeat(64);

describe('historial compartido por QR temporal (INNO-01)', () => {
  describe('proyeccionServicioCompartido', () => {
    it('deja fuera el dinero y la factura, y es allowlist', () => {
      const proyectado = proyeccionServicioCompartido({
        tipo_servicio: 'Cambio de aceite',
        fecha: 123,
        kilometraje_servicio: 50000,
        descripcion: 'Sintetico 5W30',
        costo: 250000,
        mano_de_obra: 80000,
        materiales: 170000,
        foto_factura_url: 'https://ejemplo/factura.jpg',
        id_taller: 'taller1',
        campo_inventado_manana: 'no deberia salir',
      });

      assert.deepStrictEqual(Object.keys(proyectado).sort(), [
        'auto_declarado',
        'descripcion',
        'fecha',
        'id_taller',
        'kilometraje_servicio',
        'tipo_servicio',
      ]);
      assert.ok(!('costo' in proyectado));
      assert.ok(!('mano_de_obra' in proyectado));
      assert.ok(!('materiales' in proyectado));
      assert.ok(!('foto_factura_url' in proyectado));
    });

    it('marca como auto-declarado lo que escribio el propio propietario', () => {
      // ESTE es el caso que da sentido a la funcionalidad entera.
      //
      // `firestore.rules:728-729` autoriza al propietario a crear servicios
      // sobre su vehiculo con el centinela `id_taller == 'Manual
      // (Propietario)'`. Es una regla correcta —nadie puede prohibir el
      // mantenimiento propio— pero significa que un vendedor puede escribirse
      // diez servicios inventados, emitir el QR y ensenarselo al comprador.
      //
      // Sin este campo, esos diez llegan INDISTINGUIBLES de los que registro
      // un taller, con el sello de AutoDoc encima: exactamente lo contrario de
      // lo que la cabecera de este modulo dice que la funcionalidad evita.
      const propio = proyeccionServicioCompartido({
        tipo_servicio: 'Correa de distribucion',
        id_taller: 'Manual (Propietario)',
      });
      assert.strictEqual(propio.auto_declarado, true);

      const deTaller = proyeccionServicioCompartido({
        tipo_servicio: 'Correa de distribucion',
        id_taller: 'taller-real-1',
      });
      assert.strictEqual(deTaller.auto_declarado, false);
      assert.strictEqual(deTaller.id_taller, 'taller-real-1');
    });

    it('un servicio sin id_taller cuenta como auto-declarado, no como verificado', () => {
      // Fail-safe: ante la duda, la etiqueta que NO otorga confianza.
      assert.strictEqual(proyeccionServicioCompartido({}).auto_declarado, true);
    });

    it('normaliza un Timestamp de Firestore a epoch ms', () => {
      // `servicios.fecha` es un Timestamp; el Admin SDK lo serializa como
      // {_seconds,_nanoseconds} al cruzar el callable. Ningun test de
      // Functions lo veria: aparece al pintar la pantalla.
      const p = proyeccionServicioCompartido({
        fecha: { _seconds: 1700000000, _nanoseconds: 0 },
      });
      assert.strictEqual(p.fecha, 1700000000000);
    });
  });

  // GAPS-05 — gaps 1 y 2 de INNO-01, cerrados por el mismo cambio.
  //
  // La pantalla emite al abrirse, asi que cada visita a /compartir_historial
  // acunaba un pase nuevo: entrar y salir en bucle escribia documentos sin
  // tope (gap 2). Y como el boton de revocar solo existe en la pantalla que
  // emitio ESE pase, salir de ella dejaba el pase vivo y ya sin ninguna via
  // para anularlo (gap 1) — 15 minutos de acceso al historial que su dueno no
  // podia cortar.
  //
  // Reutilizar el pase vivo del mismo vehiculo cierra los dos: no nace un
  // documento por visita, y volver a la pantalla devuelve EL MISMO pase, con
  // su boton de revocar.
  //
  // La consulta es de igualdades puras a proposito (sin `orderBy`, sin rango):
  // Firestore sirve eso con los indices automaticos, asi que no anade un
  // compuesto. El vencimiento y el cupo se comprueban en codigo.
  describe('crearTokenHistorial: reutiliza el pase vivo', () => {
    const conVehiculo = () =>
      hacerDb({ vehiculos: { v1: { id_propietario: 'dueno' } } });

    const emitir = (db, extra = {}) =>
      crearTokenHistorial({
        db,
        uid: 'dueno',
        idVehiculo: 'v1',
        ahora: AHORA,
        ...extra,
      });

    it('emitir dos veces seguidas devuelve el MISMO pase', async () => {
      const db = conVehiculo();
      const primero = await emitir(db, { generarId: () => 'tok-1' });
      const segundo = await emitir(db, { generarId: () => 'tok-2' });

      assert.strictEqual(segundo.token, primero.token);
      assert.strictEqual(
        Object.keys(db._datos.tokens_historial).length,
        1,
        'una segunda visita a la pantalla no puede acunar un documento nuevo',
      );
    });

    it('si el pase vivo se reutiliza, conserva su vencimiento original', async () => {
      // Renovarlo al reutilizar convertiria la reutilizacion en una forma de
      // extender el pase indefinidamente con solo reabrir la pantalla, que es
      // justo lo que la vigencia corta viene a impedir.
      const db = conVehiculo();
      const primero = await emitir(db, { generarId: () => 'tok-1' });
      const segundo = await crearTokenHistorial({
        db,
        uid: 'dueno',
        idVehiculo: 'v1',
        ahora: AHORA + 60 * 1000,
        generarId: () => 'tok-2',
      });
      assert.strictEqual(segundo.expira_en, primero.expira_en);
    });

    it('un pase REVOCADO no se reutiliza', async () => {
      const db = conVehiculo();
      await emitir(db, { generarId: () => 'tok-1' });
      db._datos.tokens_historial['tok-1'].revocado = true;

      const segundo = await emitir(db, { generarId: () => 'tok-2' });
      assert.strictEqual(segundo.token, 'tok-2');
    });

    it('un pase CADUCADO no se reutiliza', async () => {
      const db = conVehiculo();
      await emitir(db, { generarId: () => 'tok-1' });

      const segundo = await crearTokenHistorial({
        db,
        uid: 'dueno',
        idVehiculo: 'v1',
        ahora: AHORA + (VIGENCIA_MINUTOS + 1) * 60 * 1000,
        generarId: () => 'tok-2',
      });
      assert.strictEqual(segundo.token, 'tok-2');
    });

    it('un pase con el cupo de canjes AGOTADO no se reutiliza', async () => {
      // Devolverlo seria peor que no reutilizar nada: la pantalla pintaria un
      // QR que solo puede responder `resource-exhausted`.
      const db = conVehiculo();
      await emitir(db, { generarId: () => 'tok-1' });
      db._datos.tokens_historial['tok-1'].canjes = MAX_CANJES;

      const segundo = await emitir(db, { generarId: () => 'tok-2' });
      assert.strictEqual(segundo.token, 'tok-2');
    });

    it('el pase vivo de OTRO vehiculo no se reutiliza', async () => {
      const db = hacerDb({
        vehiculos: {
          v1: { id_propietario: 'dueno' },
          v2: { id_propietario: 'dueno' },
        },
      });
      await emitir(db, { generarId: () => 'tok-v1' });

      const otro = await crearTokenHistorial({
        db,
        uid: 'dueno',
        idVehiculo: 'v2',
        ahora: AHORA,
        generarId: () => 'tok-v2',
      });
      assert.strictEqual(otro.token, 'tok-v2');
    });
  });

  describe('crearTokenHistorial', () => {
    it('el dueno del vehiculo obtiene un token con vencimiento', async () => {
      const db = hacerDb({ vehiculos: { v1: { id_propietario: 'dueno' } } });

      const r = await crearTokenHistorial({
        db,
        uid: 'dueno',
        idVehiculo: 'v1',
        ahora: AHORA,
        generarId: idsFijos,
      });

      assert.strictEqual(r.token, 'token-fijo-para-pruebas');
      assert.strictEqual(r.expira_en, AHORA + VIGENCIA_MINUTOS * 60 * 1000);

      const guardado = db._datos.tokens_historial['token-fijo-para-pruebas'];
      assert.strictEqual(guardado.id_vehiculo, 'v1');
      assert.strictEqual(guardado.id_propietario, 'dueno');
      assert.strictEqual(guardado.revocado, false);
    });

    it('escribe `purgar_en` como Date, que es lo unico que el TTL acepta', async () => {
      // La politica TTL de Firestore SOLO borra por un campo Timestamp: con un
      // numero la politica se crea y no borra nada nunca, y la coleccion crece
      // un documento por pase emitido para siempre.
      //
      // `solicitudesLanding.js:210-213` ya dejo escrito el precedente en este
      // mismo repo, con estas palabras: "Tiene que ser Timestamp, no
      // milisegundos". Este test existe para que no se vuelva a perder.
      //
      // Va en un campo APARTE de `expira_en`, que sigue siendo epoch ms porque
      // `leerHistorialPorToken` lo compara con `Date.now()`.
      const db = hacerDb({ vehiculos: { v1: { id_propietario: 'dueno' } } });
      await crearTokenHistorial({
        db,
        uid: 'dueno',
        idVehiculo: 'v1',
        ahora: AHORA,
        generarId: idsFijos,
      });

      const guardado = db._datos.tokens_historial['token-fijo-para-pruebas'];
      assert.ok(
        guardado.purgar_en instanceof Date ||
          typeof guardado.purgar_en === 'string',
        'purgar_en tiene que ser una fecha, no un numero',
      );
      assert.strictEqual(typeof guardado.expira_en, 'number');

      // El margen no es cosmetico: si el TTL borrara justo al vencer, un pase
      // caducado pasaria de decir "ya caduco" (deadline-exceeded) a "no
      // existe" (not-found). Ningun test puede verlo — el emulador no ejecuta
      // politicas TTL.
      const purga = new Date(guardado.purgar_en).getTime();
      assert.ok(purga > AHORA + VIGENCIA_MINUTOS * 60 * 1000);
    });

    it('quien NO es el dueno no puede emitir un token de ese vehiculo', async () => {
      const db = hacerDb({ vehiculos: { v1: { id_propietario: 'dueno' } } });

      await assert.rejects(
        crearTokenHistorial({
          db,
          uid: 'intruso',
          idVehiculo: 'v1',
          ahora: AHORA,
        }),
        /permission-denied/,
      );
      assert.deepStrictEqual(db._datos.tokens_historial || {}, {});
    });

    it('un vehiculo inexistente no emite token', async () => {
      const db = hacerDb({ vehiculos: {} });
      await assert.rejects(
        crearTokenHistorial({
          db,
          uid: 'dueno',
          idVehiculo: 'fantasma',
          ahora: AHORA,
        }),
        /not-found/,
      );
    });

    it('estar en shared_with NO alcanza para emitir', async () => {
      // Compartir la ficha es lectura; emitir un pase que abre el historial a
      // terceros es una decision del propietario y de nadie mas.
      const db = hacerDb({
        vehiculos: { v1: { id_propietario: 'dueno', shared_with: ['copiloto'] } },
      });
      await assert.rejects(
        crearTokenHistorial({
          db,
          uid: 'copiloto',
          idVehiculo: 'v1',
          ahora: AHORA,
        }),
        /permission-denied/,
      );
    });
  });

  describe('leerHistorialPorToken', () => {
    function dbConToken(extra = {}) {
      return hacerDb({
        vehiculos: {
          v1: { id_propietario: 'dueno', placa: 'ABC123', marca: 'Mazda' },
        },
        tokens_historial: {
          [T]: {
            id_vehiculo: 'v1',
            id_propietario: 'dueno',
            creado_en: AHORA,
            expira_en: AHORA + 60000,
            revocado: false,
            ...extra,
          },
        },
        servicios: {
          s1: { id_vehiculo: 'v1', fecha: 200, tipo_servicio: 'Frenos', costo: 9 },
          s2: { id_vehiculo: 'v1', fecha: 100, tipo_servicio: 'Aceite', costo: 9 },
          sOtro: { id_vehiculo: 'v2', fecha: 300, tipo_servicio: 'Ajeno', costo: 9 },
        },
      });
    }

    it('un token vigente devuelve el historial de SU vehiculo, sin dinero', async () => {
      const r = await leerHistorialPorToken({
        db: dbConToken(),
        uid: 'curioso',
        token: T,
        ahora: AHORA,
      });

      assert.strictEqual(r.placa, 'ABC123');
      assert.strictEqual(r.servicios.length, 2);
      assert.strictEqual(r.servicios[0].tipo_servicio, 'Frenos'); // fecha desc
      assert.ok(!('costo' in r.servicios[0]));
    });

    it('un token vencido no abre nada', async () => {
      await assert.rejects(
        leerHistorialPorToken({
          db: dbConToken(),
          uid: 'curioso',
          token: T,
          ahora: AHORA + 60001,
        }),
        /deadline-exceeded/,
      );
    });

    it('el vencimiento se mide contra el reloj del SERVIDOR', async () => {
      // El llamante no aporta la hora en ningun momento: si pudiera, el
      // vencimiento seria decorativo.
      const db = dbConToken({ expira_en: AHORA - 1 });
      await assert.rejects(
        leerHistorialPorToken({ db, uid: 'curioso', token: T, ahora: AHORA }),
        /deadline-exceeded/,
      );
    });

    it('un token revocado no abre nada, aunque siga vigente', async () => {
      await assert.rejects(
        leerHistorialPorToken({
          db: dbConToken({ revocado: true }),
          uid: 'curioso',
          token: T,
          ahora: AHORA,
        }),
        /permission-denied/,
      );
    });

    it('un token inventado no abre nada', async () => {
      await assert.rejects(
        leerHistorialPorToken({
          db: dbConToken(),
          uid: 'curioso',
          token: 'b'.repeat(64),
          ahora: AHORA,
        }),
        /not-found/,
      );
    });

    it('un pase se agota tras MAX_CANJES, aunque siga vigente', async () => {
      // Cada canje cuesta hasta 102 lecturas (token + vehiculo + 100
      // servicios). Sin tope, un QR fotografiado en un parqueadero es un
      // amplificador de ~102x sobre la cuota de Firestore durante toda la
      // ventana de 15 minutos, y App Check en `monitor` —que es la decision
      // de SEC-04— no lo frena. La caducidad acota la ventana, no el volumen
      // dentro de ella.
      const db = dbConToken({ canjes: MAX_CANJES });
      await assert.rejects(
        leerHistorialPorToken({ db, uid: 'curioso', token: T, ahora: AHORA }),
        /resource-exhausted/,
      );
    });

    it('cada canje incrementa el contador', async () => {
      const db = dbConToken();
      await leerHistorialPorToken({ db, uid: 'curioso', token: T, ahora: AHORA });
      assert.strictEqual(db._datos.tokens_historial[T].canjes, 1);
    });

    it('un token con barras se rechaza limpio, no revienta el SDK', async () => {
      // `.doc('a/b')` lanza un Error corriente del Admin SDK por numero de
      // segmentos, que sale al cliente como `internal`. No hay travesia
      // posible —la ruta esta enclavada bajo tokens_historial/— pero un
      // `invalid-argument` es lo correcto y corta el ruido de sondeo.
      await assert.rejects(
        leerHistorialPorToken({
          db: dbConToken(),
          uid: 'curioso',
          token: 'a/b',
          ahora: AHORA,
        }),
        /invalid-argument/,
      );
    });

    it('el token NO da acceso a otro vehiculo del mismo dueno', async () => {
      const db = dbConToken();
      const r = await leerHistorialPorToken({
        db,
        uid: 'curioso',
        token: T,
        ahora: AHORA,
      });
      assert.ok(r.servicios.every((s) => s.tipo_servicio !== 'Ajeno'));
    });
  });

  describe('revocarTokenHistorial', () => {
    function dbParaRevocar() {
      return hacerDb({
        tokens_historial: {
          [T]: {
            id_vehiculo: 'v1',
            id_propietario: 'dueno',
            expira_en: AHORA + 60000,
            revocado: false,
          },
        },
      });
    }

    it('el emisor puede revocar antes de que venza', async () => {
      const db = dbParaRevocar();
      await revocarTokenHistorial({ db, uid: 'dueno', token: T });
      assert.strictEqual(db._datos.tokens_historial[T].revocado, true);
    });

    it('un tercero no puede revocar el token de otro', async () => {
      const db = dbParaRevocar();
      await assert.rejects(
        revocarTokenHistorial({ db, uid: 'intruso', token: T }),
        /permission-denied/,
      );
      assert.strictEqual(db._datos.tokens_historial[T].revocado, false);
    });
  });
});
