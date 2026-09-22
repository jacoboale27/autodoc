'use strict';

/**
 * OPS-01 — barrido diario de alertas por vencer.
 *
 * Extraido de `checkAlertsDaily` para poder ejercerlo con fixtures. Ver
 * `functions/test/alertas_vencidas.test.js`: el defecto que destapa la
 * extraccion es que la misma alerta se notificaba cada 24 h indefinidamente.
 */

/** Cuantos dias antes del vencimiento se avisa. */
const DIAS_DE_AVISO = 7;

const LIMITE_POR_PAGINA = 500;
const MS_POR_DIA = 24 * 60 * 60 * 1000;

/** Los dos escalones del aviso, en orden. Ver `estadoDeAviso`. */
const ESCALONES = ['por_vencer', 'vencida'];

/**
 * Normaliza `fecha_limite`, que en produccion aparece como `Timestamp` y
 * tambien como cadena ISO heredada. Devuelve `null` si no hay forma de leerla.
 */
function leerFechaLimite(valor) {
  if (!valor) return null;
  const fecha = typeof valor.toDate === 'function' ? valor.toDate() : new Date(valor);
  return Number.isNaN(fecha.getTime()) ? null : fecha;
}

/**
 * En que escalon de aviso esta una alerta, o `null` si aun no toca avisar.
 *
 * @param {Date} fechaLimite
 * @param {Date} ahora
 * @param {number} [diasDeAviso]
 * @returns {'por_vencer'|'vencida'|null}
 */
function estadoDeAviso(fechaLimite, ahora, diasDeAviso = DIAS_DE_AVISO) {
  if (fechaLimite < ahora) return 'vencida';
  if (fechaLimite.getTime() <= ahora.getTime() + diasDeAviso * MS_POR_DIA) return 'por_vencer';
  return null;
}

function textoDeAviso(escalon, alerta, vehiculo) {
  const tipo = alerta.tipo_alerta || 'mantenimiento';
  const placa = vehiculo.placa || 'tu vehículo';
  return escalon === 'vencida'
    ? {
        title: '¡Alerta Vencida!',
        body: `La alerta de ${tipo} para tu vehículo ${placa} ya venció.`,
      }
    : {
        title: 'Alerta por Vencer',
        body: `La alerta de ${tipo} para tu vehículo ${placa} está por vencer.`,
      };
}

/**
 * Recorre las alertas pendientes y avisa a los propietarios.
 *
 * **Por que la consulta no esta acotada por fecha**, al contrario que la de
 * `recordatoriosReserva`: `fecha_limite` convive en Timestamp y en cadena, y
 * Firestore ordena por tipo antes que por valor. Una cota sobre Timestamp
 * dejaria fuera, en silencio, todas las alertas heredadas con fecha de texto —
 * exactamente el fallo del `orderBy` que excluye documentos sin el campo. Para
 * acotarla hace falta antes un backfill que normalice el tipo; queda anotado
 * como gap de OPS-01.
 *
 * @param {object} db Firestore o un doble con la misma forma
 * @param {object} messaging FCM o un doble con `send`
 * @param {{ahora?: Date, limite?: number, escribirNotificacion: Function}} opciones
 */
async function notificarAlertasVencidas(db, messaging, opciones = {}) {
  const ahora = opciones.ahora || new Date();
  const limite = opciones.limite || LIMITE_POR_PAGINA;
  const escribirNotificacion = opciones.escribirNotificacion;
  if (typeof escribirNotificacion !== 'function') {
    throw new TypeError('notificarAlertasVencidas necesita `escribirNotificacion`');
  }

  const vehiculos = new Map();
  const usuarios = new Map();
  const resumen = {
    revisadas: 0,
    notificadas: 0,
    yaAvisadas: 0,
    ilegibles: 0,
    sinDestinatario: 0,
    fallidas: 0,
    noMarcadas: 0,
    // Notas del centro de notificaciones que `writeNotification` no pudo
    // escribir. El escalon se marca igual, asi que este contador es la UNICA
    // senal de que alguien se quedo sin su aviso en la app.
    notasFallidas: 0,
  };
  let cursor = null;

  for (;;) {
    // Las DOS igualdades van en el servidor. `avisos_pendientes` es la
    // negacion denormalizada del estado terminal: false en cuanto la alerta
    // consumio su ultimo escalon, y entonces ya no va a avisar nunca mas.
    // Antes esas alertas llegaban igual y se descartaban en memoria, asi que
    // una alerta vencida que nadie cierre —y solo el usuario la cierra, a
    // mano— costaba una lectura cada dia para siempre.
    //
    // Dos igualdades no necesitan indice compuesto (Firestore las resuelve con
    // merge join de los indices de campo unico), asi que esto NO es un paso de
    // despliegue de indices. El backfill si es un paso de runbook, y
    // bloqueante: una igualdad sobre un campo ausente no devuelve nada.
    let consulta = db
      .collection('alertas')
      .where('estado', '==', 'Pendiente')
      .where('avisos_pendientes', '==', true)
      .orderBy('__name__')
      .limit(limite);
    if (cursor) consulta = consulta.startAfter(cursor);

    const pagina = await consulta.get();
    if (pagina.empty) break;

    for (const doc of pagina.docs) {
      resumen.revisadas += 1;
      await revisar(doc);
    }

    if (pagina.size < limite) break;
    cursor = pagina.docs[pagina.docs.length - 1];
  }

  return resumen;

  async function revisar(doc) {
    const alerta = doc.data();
    const fechaLimite = leerFechaLimite(alerta.fecha_limite);
    if (!fechaLimite) {
      resumen.ilegibles += 1;
      return;
    }

    const escalon = estadoDeAviso(fechaLimite, ahora);
    if (!escalon) return;

    // El corazon del arreglo: cada escalon se avisa UNA vez. Sin esto, el
    // barrido reenvia el mismo push cada 24 h mientras la alerta siga
    // 'Pendiente' — y solo el usuario la saca de ese estado, a mano.
    if (yaSeAviso(alerta.ultimo_aviso, escalon)) {
      resumen.yaAvisadas += 1;
      return;
    }

    const vehiculo = await cachear(vehiculos, 'vehiculos', alerta.id_vehiculo);
    const propietarioId = vehiculo && vehiculo.id_propietario;
    if (!propietarioId) {
      resumen.sinDestinatario += 1;
      return;
    }
    const usuario = await cachear(usuarios, 'usuarios', propietarioId);
    if (!usuario) {
      resumen.sinDestinatario += 1;
      return;
    }

    const texto = textoDeAviso(escalon, alerta, vehiculo);
    try {
      // El push es el transporte; el centro de notificaciones es el registro
      // duradero. Antes, sin `fcmToken` no se escribia NI el registro: el
      // aviso se perdia entero por no tener por donde empujarlo.
      if (usuario.fcmToken) {
        await messaging.send({
          token: usuario.fcmToken,
          notification: texto,
          data: { type: 'alerta', alertaId: doc.id, vehiculoId: alerta.id_vehiculo },
        });
      }
      // El valor devuelto SI se mira. `writeNotification` se traga su error y
      // no relanza, asi que un fallo escribiendo la nota no llegaba al `catch`
      // de abajo: se seguia adelante, **se marcaba el escalon** y la nota se
      // perdia para siempre — justo lo contrario de lo que afirma el
      // comentario de ese catch. Lo destapo el gate de rendimiento al revisar
      // el barrido hermano.
      //
      // Aqui solo se hace VISIBLE (se cuenta y se registra). No se deja de
      // marcar el escalon, porque reintentar manana reenviaria tambien el
      // push que ya se entrego: elegir entre una nota perdida y un push
      // duplicado es decision de producto y queda anotada como gap.
      const notaEscrita = await escribirNotificacion(propietarioId, {
        tipo: 'alerta',
        titulo: texto.title,
        body: texto.body,
        deepLink: '/alerts',
        metadata: { alertaId: doc.id, vehiculoId: alerta.id_vehiculo },
      });
      if (notaEscrita === false) {
        resumen.notasFallidas += 1;
        console.error(
          `Nota de alerta no escrita para ${propietarioId} (alerta ${doc.id}); ` +
            'el escalon se marca igual: la nota NO se reintenta.'
        );
      }
    } catch (e) {
      // No se marca el escalon: si se marcara, un fallo de entrega consumiria
      // el aviso y la alerta no volveria a avisarse nunca.
      resumen.fallidas += 1;
      console.error(`Aviso de alerta ${doc.id} no entregado:`, e && e.code ? e.code : e);
      return;
    }

    try {
      // La bandera se apaga en el MISMO update que el escalon. Partirlo en dos
      // escrituras dejaria una ventana en la que la alerta ya esta avisada del
      // todo y sigue en la cola — y si la segunda falla, para siempre.
      await doc.ref.update({
        ultimo_aviso: escalon,
        fecha_ultimo_aviso: ahora,
        avisos_pendientes: !esUltimoEscalon(escalon),
      });
    } catch (e) {
      // Esta escritura estaba FUERA del try, y eso la volvia una denegacion de
      // servicio disparable por cualquier usuario con una operacion que las
      // reglas le permiten: `allow delete` deja al propietario borrar su
      // alerta, y si la borra entre el `get()` de la pagina y su turno en el
      // bucle, el update falla con NOT_FOUND, la promesa sube sin capturar y
      // el barrido ENTERO aborta — todas las alertas de todos los usuarios se
      // quedan sin aviso ese dia, y sin checkpoint que recupere el cursor.
      // La ventana es real: una pagina son hasta 500 documentos y cada uno
      // hace lecturas y un envio de push.
      //
      // El precio de no propagar: si el marcado falla despues de haber
      // enviado el push, manana se reenvia. Reenviar una vez es mucho mejor
      // que tumbar la corrida.
      resumen.noMarcadas += 1;
      console.error(`Alerta ${doc.id} avisada pero no marcada:`, e && e.code ? e.code : e);
      return;
    }
    resumen.notificadas += 1;
  }

  async function cachear(mapa, coleccion, id) {
    if (!id) return null;
    if (!mapa.has(id)) {
      const snap = await db.collection(coleccion).doc(id).get();
      mapa.set(id, snap.exists ? snap.data() : null);
    }
    return mapa.get(id);
  }
}

/**
 * Un escalon ya consumido no se repite, y `vencida` no retrocede a
 * `por_vencer` (una alerta vencida que el usuario edite hacia el futuro vuelve
 * a empezar solo si su nuevo escalon esta por delante del anotado).
 */
/**
 * Si este escalon es el ultimo, la alerta no volvera a avisar nunca: no queda
 * ninguno por delante y `yaSeAviso` devolvera true para todos. Se deriva de
 * ESCALONES en vez de escribir 'vencida' a pelo, para que anadir un escalon
 * nuevo no deje la bandera apagandose antes de tiempo.
 */
function esUltimoEscalon(escalon) {
  return ESCALONES.indexOf(escalon) === ESCALONES.length - 1;
}

function yaSeAviso(anotado, escalon) {
  if (!anotado) return false;
  const iAnotado = ESCALONES.indexOf(anotado);
  const iActual = ESCALONES.indexOf(escalon);
  if (iAnotado === -1) return false;
  return iActual <= iAnotado;
}

module.exports = {
  DIAS_DE_AVISO,
  ESCALONES,
  LIMITE_POR_PAGINA,
  estadoDeAviso,
  esUltimoEscalon,
  notificarAlertasVencidas,
};
