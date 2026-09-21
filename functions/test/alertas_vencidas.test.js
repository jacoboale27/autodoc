'use strict';

/**
 * OPS-01 — barrido diario de alertas por vencer.
 *
 * `checkAlertsDaily` tampoco tenia test, y el defecto que sale al escribirlo
 * es el mas visible para un usuario real:
 *
 * **La misma alerta se notificaba TODOS LOS DIAS, para siempre.** El barrido
 * consulta `estado == 'Pendiente'` y notifica todo lo que venza dentro de
 * siete dias o ya haya vencido. Nada marcaba la alerta como avisada, y
 * `estado` solo pasa a `Completada` cuando el propietario la marca a mano
 * desde la app (`alert_provider.dart:304`). Un SOAT vencido que su dueño no
 * cierre —el caso normal, porque la gente renueva y se olvida de la app— le
 * manda un push diario indefinidamente. Es la clase de notificacion que hace
 * que el usuario desactive TODAS las notificaciones de la app.
 *
 * El arreglo es un campo de control del servidor, `ultimo_aviso`, con los dos
 * escalones que tiene el aviso: `por_vencer` y `vencida`. Se notifica al
 * entrar en cada escalon y no mas: dos pushes en la vida de una alerta.
 *
 * Segundo defecto, mas pequeno: sin `fcmToken` no se escribia **tampoco** la
 * entrada del centro de notificaciones. El push es el transporte y el centro
 * de notificaciones es el registro duradero; perder el registro porque el
 * transporte no esta disponible es al reves de como deberia ser.
 */

const assert = require('assert');
const { Timestamp } = require('firebase-admin/firestore');

const {
  DIAS_DE_AVISO,
  estadoDeAviso,
  notificarAlertasVencidas,
} = require('../src/alertasVencidas');

const AHORA = new Date('2026-09-12T12:00:00Z');
const enDias = (d) => Timestamp.fromDate(new Date(AHORA.getTime() + d * 86400000));

function fakeDb(docs = {}) {
  const escrituras = [];
  let lecturas = 0;
  const cumple = (data, campo, op, valor) => {
    if (!Object.prototype.hasOwnProperty.call(data, campo)) return false;
    if (op === '==') return data[campo] === valor;
    throw new Error('operador no modelado: ' + op);
  };
  const refDe = (coleccion, id) => ({
    id,
    async update(data) {
      const clave = coleccion + '/' + id;
      if (!Object.prototype.hasOwnProperty.call(docs, clave)) {
        // Firestore rechaza el update de un documento que ya no existe. El
        // doble tiene que modelarlo: sin esto no se puede ver que borrar una
        // alerta a media pasada tumbaba el barrido entero.
        const e = new Error('No document to update: ' + clave);
        e.code = 5;
        throw e;
      }
      escrituras.push({ clave, data });
      docs[clave] = Object.assign({}, docs[clave], data);
    },
    async get() {
      lecturas += 1;
      const clave = coleccion + '/' + id;
      const existe = Object.prototype.hasOwnProperty.call(docs, clave);
      return { exists: existe, id, data: () => (existe ? Object.assign({}, docs[clave]) : undefined) };
    },
  });
  const anadidos = [];
  return {
    docs,
    escrituras,
    anadidos,
    get lecturas() {
      return lecturas;
    },
    collection(coleccion) {
      const consulta = (filtros) => {
        // `startAfter` avanza de verdad. Cuando era un no-op, un caso de dos
        // paginas devolvia la primera para siempre — asi que no habia forma de
        // escribir el test, y la paginacion se quedaba sin ejercer. Es la
        // trampa que este proyecto ya tiene documentada: un doble que no puede
        // ver la propiedad que dice cubrir.
        const conLimite = (n, desde) => ({
          startAfter: (doc) => conLimite(n, doc.id),
          async get() {
            const prefijo = coleccion + '/';
            const claves = Object.keys(docs)
              .filter((k) => k.startsWith(prefijo))
              .sort()
              .filter((k) => desde === undefined || k.slice(prefijo.length) > desde)
              .filter((k) => filtros.every((f) => cumple(docs[k], f[0], f[1], f[2])))
              .slice(0, n);
            return {
              empty: claves.length === 0,
              size: claves.length,
              docs: claves.map((k) => {
                const id = k.slice(prefijo.length);
                return { id, ref: refDe(coleccion, id), data: () => docs[k] };
              }),
            };
          },
        });
        return {
          where: (c, o, v) => consulta(filtros.concat([[c, o, v]])),
          orderBy: () => consulta(filtros),
          limit: conLimite,
        };
      };
      return {
        doc: (id) => refDe(coleccion, id),
        where: (c, o, v) => consulta([[c, o, v]]),
      };
    },
  };
}

function fakeMessaging(opciones) {
  const fallaPara = (opciones && opciones.fallaPara) || [];
  const enviados = [];
  return {
    enviados,
    async send(mensaje) {
      if (fallaPara.indexOf(mensaje.token) !== -1) throw new Error('token muerto');
      enviados.push(mensaje);
      return 'ok';
    },
  };
}

function recolector() {
  const escritas = [];
  return {
    escritas,
    async escribirNotificacion(uid, notificacion) {
      escritas.push({ uid, notificacion });
    },
  };
}

const escenario = (alerta, extra) =>
  Object.assign(
    {
      'alertas/a1': Object.assign(
        // `avisos_pendientes: true` es como nace una alerta: la regla del
        // create lo pinea a true, igual que `estado`. Sembrarlo aqui no es
        // decoracion — sin el, estos once tests se ponen rojos, que es
        // exactamente lo que le pasaria a produccion sin correr el backfill.
        { estado: 'Pendiente', id_vehiculo: 'v1', tipo_alerta: 'SOAT', avisos_pendientes: true },
        alerta
      ),
      'vehiculos/v1': { id_propietario: 'p1', placa: 'ABC123' },
      'usuarios/p1': { fcmToken: 'tok-p1' },
    },
    extra || {}
  );

describe('alertasVencidas / estadoDeAviso', () => {
  it('no avisa de algo que vence mas alla de la ventana', () => {
    assert.strictEqual(estadoDeAviso(new Date(AHORA.getTime() + 30 * 86400000), AHORA), null);
  });

  it('avisa por_vencer dentro de la ventana', () => {
    assert.strictEqual(estadoDeAviso(new Date(AHORA.getTime() + 3 * 86400000), AHORA), 'por_vencer');
  });

  it('avisa vencida cuando la fecha ya paso', () => {
    assert.strictEqual(estadoDeAviso(new Date(AHORA.getTime() - 1 * 86400000), AHORA), 'vencida');
  });

  it('el borde de la ventana entra, y es por_vencer y no vencida', () => {
    const borde = new Date(AHORA.getTime() + DIAS_DE_AVISO * 86400000);
    assert.strictEqual(estadoDeAviso(borde, AHORA), 'por_vencer');
  });
});

describe('alertasVencidas / notificarAlertasVencidas', () => {
  it('notifica una alerta por vencer y anota el escalon', async () => {
    const db = fakeDb(escenario({ fecha_limite: enDias(3) }));
    const messaging = fakeMessaging();
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, messaging, {
      ahora: AHORA,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.notificadas, 1);
    assert.strictEqual(messaging.enviados.length, 1);
    assert.strictEqual(centro.escritas.length, 1);
    assert.strictEqual(db.docs['alertas/a1'].ultimo_aviso, 'por_vencer');
  });

  it('NO vuelve a notificar la misma alerta al dia siguiente', async () => {
    // El defecto. Sin `ultimo_aviso`, este barrido reenvia el mismo push cada
    // 24 h mientras la alerta siga en 'Pendiente' — es decir, para siempre,
    // porque solo el usuario la cierra a mano.
    const db = fakeDb(escenario({ fecha_limite: enDias(3) }));
    const centro = recolector();
    const opciones = { ahora: AHORA, escribirNotificacion: centro.escribirNotificacion };

    await notificarAlertasVencidas(db, fakeMessaging(), opciones);

    const messaging2 = fakeMessaging();
    const manana = new Date(AHORA.getTime() + 86400000);
    const r = await notificarAlertasVencidas(db, messaging2, {
      ahora: manana,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.notificadas, 0);
    assert.strictEqual(r.yaAvisadas, 1);
    assert.deepStrictEqual(messaging2.enviados, []);
  });

  it('vuelve a notificar UNA vez cuando pasa de por vencer a vencida', async () => {
    const db = fakeDb(escenario({ fecha_limite: enDias(3), ultimo_aviso: 'por_vencer' }));
    const messaging = fakeMessaging();
    const centro = recolector();
    const despues = new Date(AHORA.getTime() + 5 * 86400000);

    const r = await notificarAlertasVencidas(db, messaging, {
      ahora: despues,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.notificadas, 1);
    assert.strictEqual(db.docs['alertas/a1'].ultimo_aviso, 'vencida');
    assert.ok(/venci/i.test(messaging.enviados[0].notification.title));
  });

  it('acepta la fecha como Timestamp y como cadena ISO heredada', async () => {
    const db = fakeDb(
      escenario({ fecha_limite: new Date(AHORA.getTime() + 2 * 86400000).toISOString() })
    );
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.notificadas, 1);
  });

  it('una fecha ilegible se salta sin abortar el barrido', async () => {
    const db = fakeDb(
      Object.assign(escenario({ fecha_limite: 'no-es-una-fecha' }), {
        'alertas/a2': {
          estado: 'Pendiente',
          avisos_pendientes: true,
          id_vehiculo: 'v1',
          tipo_alerta: 'Tecnomecanica',
          fecha_limite: enDias(1),
        },
      })
    );
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.ilegibles, 1);
    assert.strictEqual(r.notificadas, 1);
  });

  it('sin fcmToken no hay push pero SI queda registro en el centro', async () => {
    const db = fakeDb(escenario({ fecha_limite: enDias(3) }, { 'usuarios/p1': {} }));
    const messaging = fakeMessaging();
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, messaging, {
      ahora: AHORA,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.deepStrictEqual(messaging.enviados, []);
    assert.strictEqual(centro.escritas.length, 1, 'el centro de notificaciones se quedo vacio');
    assert.strictEqual(r.notificadas, 1);
    assert.strictEqual(db.docs['alertas/a1'].ultimo_aviso, 'por_vencer');
  });

  it('un push fallido no marca la alerta como avisada', async () => {
    // Si se marcara, el aviso se perderia para siempre: el escalon ya estaria
    // consumido y el barrido del dia siguiente lo saltaria.
    const db = fakeDb(escenario({ fecha_limite: enDias(3) }));
    const messaging = fakeMessaging({ fallaPara: ['tok-p1'] });
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, messaging, {
      ahora: AHORA,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.fallidas, 1);
    assert.strictEqual(db.docs['alertas/a1'].ultimo_aviso, undefined);
  });

  it('un vehiculo huerfano no rompe el barrido', async () => {
    const db = fakeDb(escenario({ fecha_limite: enDias(3) }, { 'vehiculos/v1': undefined }));
    delete db.docs['vehiculos/v1'];
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.notificadas, 0);
    assert.strictEqual(r.sinDestinatario, 1);
  });

  it('recorre TODAS las paginas y no procesa ninguna alerta dos veces', async () => {
    // La paginacion no la ejercia ningun test, porque `startAfter` era un
    // no-op en el doble: con el, un caso de dos paginas devolvia la primera
    // eternamente. Este test comprueba las dos mitades del contrato —que no se
    // salta documentos y que no los repite— y de paso que las escrituras de
    // `ultimo_aviso` sobre documentos ya recorridos no desestabilizan el
    // cursor, porque no tocan ni `estado` ni `__name__`, que son los dos
    // campos del indice que sirve la consulta.
    const docs = { 'vehiculos/v1': { id_propietario: 'p1', placa: 'ABC123' },
                   'usuarios/p1': { fcmToken: 'tok-p1' } };
    for (let i = 1; i <= 5; i += 1) {
      docs[`alertas/a${i}`] = {
        estado: 'Pendiente', avisos_pendientes: true, id_vehiculo: 'v1',
        tipo_alerta: 'SOAT', fecha_limite: enDias(3),
      };
    }
    const db = fakeDb(docs);
    const messaging = fakeMessaging();
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, messaging, {
      ahora: AHORA,
      limite: 2,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.revisadas, 5, 'se salto alguna pagina');
    assert.strictEqual(r.notificadas, 5);
    const avisadas = messaging.enviados.map((m) => m.data.alertaId).sort();
    assert.deepStrictEqual(avisadas, ['a1', 'a2', 'a3', 'a4', 'a5'], 'repitio o se salto alguna');
  });

  it('borrar una alerta a media pasada NO tumba el barrido entero', async () => {
    // Lo destapo el revisor de reglas, y es el hallazgo mas grave de esta
    // tanda: el `update` de contabilidad estaba FUERA del try, asi que un
    // NOT_FOUND subia sin capturar y abortaba la corrida completa. Las reglas
    // permiten al propietario borrar su alerta (`allow delete`), y una pagina
    // son hasta 500 documentos con lecturas y un push cada uno: la ventana
    // para que alguien borre entre el `get()` y su turno en el bucle es real.
    // Una denegacion de servicio a todos los usuarios, disparable por
    // cualquiera con una operacion que las reglas le autorizan.
    const db = fakeDb(
      Object.assign(escenario({ fecha_limite: enDias(3) }), {
        'alertas/a2': {
          estado: 'Pendiente',
          avisos_pendientes: true,
          id_vehiculo: 'v1',
          tipo_alerta: 'Tecnomecanica',
          fecha_limite: enDias(2),
        },
      })
    );
    const messaging = fakeMessaging();
    // El borrado se cuela justo donde cabe en la realidad: entre el envio y
    // el marcado.
    const escribirNotificacion = async (uid, n) => {
      if (n.metadata.alertaId === 'a1') delete db.docs['alertas/a1'];
    };

    const r = await notificarAlertasVencidas(db, messaging, {
      ahora: AHORA,
      escribirNotificacion,
    });

    assert.strictEqual(r.noMarcadas, 1, 'no se contabilizo la alerta sin marcar');
    assert.strictEqual(r.notificadas, 1, 'la segunda alerta se quedo sin avisar');
    assert.strictEqual(db.docs['alertas/a2'].ultimo_aviso, 'por_vencer');
  });

  it('no relee el mismo vehiculo ni el mismo usuario dos veces', async () => {
    const db = fakeDb(
      Object.assign(escenario({ fecha_limite: enDias(3) }), {
        'alertas/a2': {
          estado: 'Pendiente',
          avisos_pendientes: true,
          id_vehiculo: 'v1',
          tipo_alerta: 'Tecnomecanica',
          fecha_limite: enDias(2),
        },
      })
    );
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.notificadas, 2);
    // Un vehiculo + un usuario. Sin cache serian cuatro lecturas.
    assert.strictEqual(db.lecturas, 2, 'el cache no esta funcionando');
  });
});

describe('alertasVencidas / el barrido no relee lo ya avisado (gap 1)', () => {
  // El barrido consultaba `estado == 'Pendiente'` a secas y descartaba en
  // MEMORIA las que ya tenian su escalon anotado. O sea que una alerta vencida
  // que nadie cierre —y solo el usuario la cierra, a mano— costaba una lectura
  // cada dia, para siempre. El coste crece con la historia de la cuenta, no
  // con el trabajo del dia.
  //
  // Lo que se denormaliza es el estado TERMINAL, que es uno solo: con
  // `ultimo_aviso === 'vencida'` ya no queda escalon por delante (`yaSeAviso`
  // devuelve true para los dos), asi que esa alerta no va a volver a avisar
  // nunca. `avisos_pendientes` es exactamente esa negacion.
  //
  // Las que estan en `por_vencer` SI se siguen releyendo, y es correcto: les
  // queda el escalon `vencida` por delante, y esa ventana dura como mucho
  // DIAS_DE_AVISO. Lo que se elimina es la cola infinita, no la de trabajo.

  it('una alerta ya avisada del todo NI SIQUIERA se lee', async () => {
    const db = fakeDb(
      escenario({
        fecha_limite: enDias(-3),
        ultimo_aviso: 'vencida',
        avisos_pendientes: false,
      })
    );
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: centro.escribirNotificacion,
    });

    // `revisadas` cuenta los documentos que la CONSULTA devolvio. Antes esta
    // alerta llegaba y se descartaba (`yaAvisadas: 1`); ahora no llega.
    assert.strictEqual(r.revisadas, 0, 'la consulta no deberia traerla');
    assert.strictEqual(r.yaAvisadas, 0, 'ya no hace falta descartarla en memoria');
    assert.strictEqual(r.notificadas, 0);
  });

  it('avisar el ultimo escalon apaga la bandera en la misma escritura', async () => {
    const db = fakeDb(
      escenario({ fecha_limite: enDias(3), ultimo_aviso: 'por_vencer', avisos_pendientes: true })
    );
    const centro = recolector();
    const despues = new Date(AHORA.getTime() + 5 * 86400000);

    const r = await notificarAlertasVencidas(db, fakeMessaging(), {
      ahora: despues,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.notificadas, 1);
    assert.strictEqual(db.docs['alertas/a1'].ultimo_aviso, 'vencida');
    assert.strictEqual(
      db.docs['alertas/a1'].avisos_pendientes,
      false,
      'va en el MISMO update que el escalon: dos escrituras dejarian una ventana ' +
        'en la que la alerta esta avisada del todo y sigue en la cola'
    );
  });

  it('avisar un escalon INTERMEDIO deja la bandera encendida', async () => {
    // Si se apagara aqui, la alerta saldria de la cola teniendo todavia el
    // escalon `vencida` por delante y no avisaria nunca de que vencio, que es
    // el aviso que mas importa.
    const db = fakeDb(escenario({ fecha_limite: enDias(3), avisos_pendientes: true }));
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.notificadas, 1);
    assert.strictEqual(db.docs['alertas/a1'].ultimo_aviso, 'por_vencer');
    assert.strictEqual(db.docs['alertas/a1'].avisos_pendientes, true);
  });

  it('una alerta HEREDADA, sin el campo, se queda fuera del barrido', async () => {
    // Esto NO es el comportamiento deseado: es la razon por la que el backfill
    // es un paso de runbook BLOQUEANTE y va ANTES de desplegar las funciones.
    // Una igualdad sobre un campo ausente no devuelve nada, asi que sin el
    // backfill las alertas de produccion dejan de avisar **en silencio**.
    // Es la misma trampa que `abierto` en GAPS-02 y que `estado` en H-01, y se
    // ensaya aqui gratis en vez de en produccion.
    const heredada = escenario({ fecha_limite: enDias(3) });
    delete heredada['alertas/a1'].avisos_pendientes;
    const db = fakeDb(heredada);
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.revisadas, 0);
    assert.strictEqual(r.notificadas, 0);
  });
});


/**
 * Una nota perdida se ve, y el escalon se marca igual — a proposito.
 *
 * Lo destapo el gate de `functions-perf-reviewer` revisando el barrido
 * hermano: `writeNotification` **se traga su error y no relanza**, asi que un
 * fallo escribiendo la nota no llegaba nunca al `catch` de este barrido. Se
 * seguia adelante, **se marcaba el escalon**, y la nota se perdia para siempre
 * — justo lo contrario de lo que afirma el comentario de ese `catch`, que dice
 * que un fallo de entrega no debe consumir el aviso.
 *
 * Lo que se arregla es la VISIBILIDAD, no la politica: el escalon se sigue
 * marcando, porque reintentar manana reenviaria tambien el push que ya se
 * entrego. Elegir entre una nota perdida y un push duplicado es decision de
 * producto y queda anotada como gap; lo que no es admisible es que la nota se
 * pierda sin que nada lo diga.
 */
describe('alertasVencidas / una nota perdida no pasa desapercibida', () => {
  it('cuenta la nota que DEVUELVE false, y el push sigue saliendo', async () => {
    // Esta es la forma real del helper: registra el error y devuelve false.
    const db = fakeDb(escenario({ fecha_limite: enDias(3) }));
    const messaging = fakeMessaging();

    const r = await notificarAlertasVencidas(db, messaging, {
      ahora: AHORA,
      escribirNotificacion: async () => false,
    });

    assert.strictEqual(
      r.notasFallidas,
      1,
      'la nota se perdio en silencio: es la forma REAL de writeNotification'
    );
    assert.strictEqual(messaging.enviados.length, 1, 'el push no deberia perderse por la nota');
    assert.strictEqual(
      db.docs['alertas/a1'].ultimo_aviso,
      'por_vencer',
      'el escalon se marca igual, a proposito: reintentar duplicaria el push'
    );
  });

  it('una nota escrita no cuenta como perdida', async () => {
    // Sin este, un contador que incrementara siempre pasaria el de arriba.
    const db = fakeDb(escenario({ fecha_limite: enDias(3) }));
    const centro = recolector();

    const r = await notificarAlertasVencidas(db, fakeMessaging(), {
      ahora: AHORA,
      escribirNotificacion: centro.escribirNotificacion,
    });

    assert.strictEqual(r.notasFallidas, 0);
    assert.strictEqual(centro.escritas.length, 1);
  });
});
