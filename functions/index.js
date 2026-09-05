const functions = require('firebase-functions');
const admin = require('firebase-admin');
const firestore = require('@google-cloud/firestore');
admin.initializeApp();

const { abrirTicketDeReparacion } = require('./src/aceptarCotizacion');
const { verificarAperturaManual } = require('./src/iniciarReparacionPorVehiculo');
const {
  subconjuntoPublicoCliente,
  compartenConversacion,
  llamanteEsMecanico,
} = require('./src/obtenerPerfilPublico');
const { listarEmpleadosPublicos } = require('./src/obtenerEmpleadosPublicos');

const db = admin.firestore();
const messaging = admin.messaging();
const storage = admin.storage();

/**
 * Helper: Write a notification to Firestore for the in-app notification center.
 * Stored under `notificaciones/{userId}/items/{auto-id}`
 * 
 * @param {string} userId - The recipient user ID
 * @param {object} notification - { tipo, titulo, body, deepLink, metadata }
 */
async function writeNotification(userId, notification) {
  try {
    await db.collection('notificaciones').doc(userId).collection('items').add({
      tipo: notification.tipo || 'sistema',
      titulo: notification.titulo || '',
      body: notification.body || '',
      leida: false,
      deepLink: notification.deepLink || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metadata: notification.metadata || null,
    });
  } catch (e) {
    console.error(`Error writing notification for user ${userId}:`, e);
  }
}

/**
 * Helper: Batch delete documents matching a query in chunks of max 500 operations to prevent OOM/Timeouts.
 * 
 * @param {object} db - Firestore database instance
 * @param {object} query - Firestore query object with .limit(500)
 * @param {function} resolve - Promise resolve callback
 * @param {function} [reject] - Promise reject callback
 */
async function deleteQueryBatch(db, query, resolve, reject) {
  try {
    const snapshot = await query.get();
    if (snapshot.size === 0) {
      resolve();
      return;
    }
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    process.nextTick(() => deleteQueryBatch(db, query, resolve, reject));
  } catch (error) {
    if (reject) {
      reject(error);
    } else {
      throw error;
    }
  }
}


/**
 * 1. Scheduled function to check alerts (alertas) daily.
 * Notifies the user if an alert is expiring in 7 days or less, or already expired.
 */
exports.checkAlertsDaily = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const now = new Date();
  const futureDate = new Date();
  futureDate.setDate(now.getDate() + 7);

  const limit = 500;
  let lastDoc = null;
  
  const vehiculosCache = {};
  const usuariosCache = {};

  try {
    while (true) {
      let q = db.collection('alertas')
        .where('estado', '==', 'Pendiente')
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(limit);
      if (lastDoc) {
        q = q.startAfter(lastDoc);
      }
      const alertasSnapshot = await q.get();
      if (alertasSnapshot.empty) break;

      for (const doc of alertasSnapshot.docs) {
        const alerta = doc.data();
        let fechaLimite;
        
        if (alerta.fecha_limite && alerta.fecha_limite.toDate) {
          fechaLimite = alerta.fecha_limite.toDate();
        } else if (typeof alerta.fecha_limite === 'string') {
          fechaLimite = new Date(alerta.fecha_limite);
        } else {
          continue; // No valid date
        }

        if (fechaLimite <= futureDate) {
          // Find the vehicle owner
          const vehiculoId = alerta.id_vehiculo;
          if (!vehiculoId) continue;

          if (!vehiculosCache[vehiculoId]) {
            const vehiculoDoc = await db.collection('vehiculos').doc(vehiculoId).get();
            vehiculosCache[vehiculoId] = vehiculoDoc.exists ? vehiculoDoc.data() : null;
          }
          const vehiculoData = vehiculosCache[vehiculoId];
          if (!vehiculoData) continue;

          const ownerId = vehiculoData.id_propietario;
          if (!ownerId) continue;

          if (!usuariosCache[ownerId]) {
            const userDoc = await db.collection('usuarios').doc(ownerId).get();
            usuariosCache[ownerId] = userDoc.exists ? userDoc.data() : null;
          }
          const userData = usuariosCache[ownerId];
          if (!userData) continue;

          const fcmToken = userData.fcmToken;
          if (!fcmToken) continue;

          const isExpired = fechaLimite < now;
          const title = isExpired ? '¡Alerta Vencida!' : 'Alerta por Vencer';
          const body = isExpired 
              ? `La alerta de ${alerta.tipo_alerta} para tu vehículo ${vehiculoData.placa} ya venció.`
              : `La alerta de ${alerta.tipo_alerta} para tu vehículo ${vehiculoData.placa} está por vencer.`;

          await messaging.send({
            token: fcmToken,
            notification: {
              title: title,
              body: body,
            },
            data: {
              type: 'alerta',
              alertaId: doc.id,
              vehiculoId: vehiculoId
            }
          });

          // Persist in notification center
          await writeNotification(ownerId, {
            tipo: 'alerta',
            titulo: title,
            body: body,
            deepLink: '/alerts',
            metadata: { alertaId: doc.id, vehiculoId: vehiculoId },
          });
        }
      }

      lastDoc = alertasSnapshot.docs[alertasSnapshot.docs.length - 1];
    }
  } catch (error) {
    console.error('Error checking alerts:', error);
  }
});

/**
 * 2. Firestore trigger when a vehicle's mileage is updated.
 * Checks maintenance tasks (mantenimientos) to see if they are due based on mileage.
 */
exports.checkMileageOnVehicleUpdate = functions.firestore
  .document('vehiculos/{vehicleId}')
  .onUpdate(async (change, context) => {
    const newValue = change.after.data();
    const previousValue = change.before.data();
    const vehicleId = context.params.vehicleId;

    if (newValue.kilometraje_actual === previousValue.kilometraje_actual) {
      return null; // Mileage hasn't changed
    }

    const currentKm = newValue.kilometraje_actual || 0;
    const ownerId = newValue.id_propietario;

    if (!ownerId) return null;

    try {
      const mantenimientosSnapshot = await db.collection('mantenimientos')
        .where('id_vehiculo', '==', vehicleId)
        .get();

      const userDoc = await db.collection('usuarios').doc(ownerId).get();
      const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

      if (!fcmToken) return null;

      for (const doc of mantenimientosSnapshot.docs) {
        const task = doc.data();
        const ultimoKm = task.ultimo_km || 0;
        const frecuenciaKm = task.frecuencia_km || 0;

        if (frecuenciaKm > 0) {
          const expectedKm = ultimoKm + frecuenciaKm;
          const diff = expectedKm - currentKm;

          if (diff <= 500 && diff > 0) {
            // Nearing
            await messaging.send({
              token: fcmToken,
              notification: {
                title: 'Mantenimiento Cercano',
                body: `Tu vehículo ${newValue.placa} está a ${diff}km de requerir ${task.nombre || 'un servicio'}.`
              }
            });

            await writeNotification(ownerId, {
              tipo: 'mantenimiento',
              titulo: 'Mantenimiento Cercano',
              body: `Tu vehículo ${newValue.placa} está a ${diff}km de requerir ${task.nombre || 'un servicio'}.`,
              deepLink: '/garage',
              metadata: { vehicleId, taskId: doc.id },
            });
          } else if (diff <= 0 && currentKm > ultimoKm) {
            // Exceeded
            await messaging.send({
              token: fcmToken,
              notification: {
                title: 'Mantenimiento Requerido',
                body: `Tu vehículo ${newValue.placa} ha superado el kilometraje para ${task.nombre || 'el servicio'}.`
              }
            });

            await writeNotification(ownerId, {
              tipo: 'mantenimiento',
              titulo: 'Mantenimiento Requerido',
              body: `Tu vehículo ${newValue.placa} ha superado el kilometraje para ${task.nombre || 'el servicio'}.`,
              deepLink: '/garage',
              metadata: { vehicleId, taskId: doc.id },
            });
          }
        }
      }
    } catch (error) {
      console.error('Error checking maintenance tasks:', error);
    }
  });

/**
 * 3. Firestore trigger when a new service is created.
 * Asks the user to review the workshop.
 */
exports.requestReviewOnServiceComplete = functions.firestore
  .document('servicios/{serviceId}')
  .onCreate(async (snap, context) => {
    const serviceData = snap.data();
    const vehiculoId = serviceData.id_vehiculo;
    const tallerId = serviceData.id_taller;

    // We do not ask to review if there's no taller ID or if it is the owner manually
    if (!tallerId || !vehiculoId || tallerId.includes('Manual')) {
      return null;
    }

    try {
      const vehiculoDoc = await db.collection('vehiculos').doc(vehiculoId).get();
      if (!vehiculoDoc.exists) return null;

      // Nombre del taller, usado tanto en la notificación de reseña como
      // (si aplica) en el dato denormalizado taller_pendiente_nombre. Se
      // obtiene antes de decidir el update del vehículo porque el banner de
      // confirmación (cierre C-1, ver mas abajo) necesita mostrar QUIEN
      // pide acceso, no solo un texto generico.
      const tallerDoc = await db.collection('usuarios').doc(tallerId).get();
      const tallerName = tallerDoc.exists ? (tallerDoc.data().nombre_completo || 'el taller') : 'el taller';

      // Cierre del hallazgo C1 (ver firestore.rules:126-148): solo se vincula
      // automáticamente el taller si YA existía una relación previa (visita
      // recurrente, sin riesgo nuevo). Si el vehículo nunca tuvo taller
      // vinculado, no se otorga acceso permanente aquí: se marca
      // `taller_pendiente_confirmacion` y se le pide confirmación explícita
      // al propietario (ver confirmarVinculoTaller/rechazarVinculoTaller en
      // VehicleService, y el banner en dashboard_screen.dart). El caso
      // "vehículo ya vinculado a OTRO taller distinto" no puede ocurrir aquí
      // porque firestore.rules:149-159 ya impide crear el `servicios`
      // correspondiente.
      const talleresVinculados = vehiculoDoc.data().talleres_vinculados || [];
      const yaVinculado = talleresVinculados.includes(tallerId);

      // Cierre C-1 (revisión adversarial): si ya hay una solicitud pendiente
      // de OTRO taller distinto, NO la pisamos. Sin esto, un atacante podía
      // crear un `servicios` falso justo después de una visita legítima y
      // reemplazar silenciosamente el taller_pendiente_confirmacion real
      // por el suyo, indistinguibles para el propietario en el banner.
      const pendienteActual = vehiculoDoc.data().taller_pendiente_confirmacion || null;
      const haySolicitudDeOtroTaller =
        pendienteActual !== null && pendienteActual !== tallerId;

      // Cierre I-1 (revisión adversarial): si el propietario ya rechazó
      // explícitamente a este taller para este vehículo, no se le vuelve a
      // marcar como pendiente. Sin esto, el mismo taller podía reintentar
      // gratis creando otro `servicios` falso inmediatamente después de un
      // rechazo, re-armando el banner indefinidamente y contaminando el
      // historial con un registro de servicio falso por intento.
      const talleresRechazados = vehiculoDoc.data().talleres_rechazados || [];
      const yaRechazado = talleresRechazados.includes(tallerId);

      const debeMarcarPendiente =
        !yaVinculado && !haySolicitudDeOtroTaller && !yaRechazado;

      const vehicleUpdate = {};
      if (yaVinculado) {
        // Vincula el taller al vehículo para que las reglas de seguridad le
        // permitan leer/actualizar ese vehículo (tenant isolation, ver
        // firestore.rules match /vehiculos). Se hace vía Admin SDK porque el
        // cliente no tiene permiso de escribir este campo directamente.
        vehicleUpdate.talleres_vinculados = admin.firestore.FieldValue.arrayUnion(tallerId);
      } else if (debeMarcarPendiente) {
        vehicleUpdate.taller_pendiente_confirmacion = tallerId;
        // Denormalizado para que el banner de confirmación pueda mostrar
        // quién pide acceso (nombre del taller) y a qué servicio
        // corresponde, en vez de un texto genérico indistinguible de un
        // intento de secuestro (cierre C-1).
        vehicleUpdate.taller_pendiente_nombre = tallerName;
        vehicleUpdate.taller_pendiente_servicio_id = context.params.serviceId;
      }
      // Si !yaVinculado && !debeMarcarPendiente (hay otra solicitud pendiente
      // o el taller ya fue rechazado), no se toca ningún campo de vínculo:
      // el `servicios` walk-in igual se crea (regla ya lo permite), pero no
      // se otorga ni se solicita ningún acceso permanente nuevo.

      // Actualiza el kilometraje aquí mismo (server-side) en vez de que el
      // cliente lea/escriba el vehículo justo después de crear el servicio:
      // en la primera visita de un cliente nuevo, ese vinculo recién se está
      // creando en este mismo trigger, y una escritura del cliente en
      // paralelo podría llegar antes de que se propague.
      const nuevoKm = serviceData.kilometraje_servicio;
      const kmActual = vehiculoDoc.data().kilometraje_actual || 0;
      if (typeof nuevoKm === 'number' && nuevoKm > kmActual) {
        vehicleUpdate.kilometraje_actual = nuevoKm;
      }

      if (Object.keys(vehicleUpdate).length > 0) {
        await vehiculoDoc.ref.update(vehicleUpdate);
      }

      const ownerId = vehiculoDoc.data().id_propietario;
      if (!ownerId) return null;

      const userDoc = await db.collection('usuarios').doc(ownerId).get();
      const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

      if (!fcmToken) return null;

      // Cierre I-3 (revisión adversarial): el push FCM se envía en su
      // propio try/catch para que, si falla (token inválido/expirado, algo
      // rutinario), el registro persistente del centro de notificaciones
      // (writeNotification) se escriba igual. Antes, un fallo de
      // messaging.send() para el prompt de consentimiento de seguridad
      // dejaba al propietario sin ningún rastro de la solicitud.
      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: '¿Qué tal te fue en tu servicio?',
            body: `Tu vehículo ${vehiculoDoc.data().placa} fue atendido en ${tallerName}. Por favor, déjales una reseña.`
          },
          data: {
            type: 'review',
            tallerId: tallerId,
            serviceId: context.params.serviceId
          }
        });
      } catch (fcmError) {
        console.error('Error sending FCM review push:', fcmError);
      }

      // Persist in notification center
      await writeNotification(ownerId, {
        tipo: 'review',
        titulo: '¿Qué tal te fue en tu servicio?',
        body: `Tu vehículo ${vehiculoDoc.data().placa} fue atendido en ${tallerName}. Por favor, déjales una reseña.`,
        deepLink: '/workshop_directory',
        metadata: { tallerId, serviceId: context.params.serviceId },
      });

      // Si corresponde marcar una solicitud pendiente nueva, pide
      // confirmación explícita del propietario antes de otorgar acceso
      // permanente al historial.
      if (debeMarcarPendiente) {
        try {
          await messaging.send({
            token: fcmToken,
            notification: {
              title: 'Nuevo taller quiere acceder al historial de tu vehículo',
              body: `${tallerName} atendió tu vehículo ${vehiculoDoc.data().placa} y solicita acceso a su historial. Confírmalo desde tu panel.`
            },
            data: {
              type: 'confirmacion_taller',
              tallerId: tallerId,
              vehiculoId: vehiculoId,
              serviceId: context.params.serviceId
            }
          });
        } catch (fcmError) {
          console.error('Error sending FCM confirmacion_taller push:', fcmError);
        }

        await writeNotification(ownerId, {
          tipo: 'confirmacion_taller',
          titulo: 'Nuevo taller quiere acceder al historial de tu vehículo',
          body: `${tallerName} atendió tu vehículo ${vehiculoDoc.data().placa} y solicita acceso a su historial. Confírmalo desde tu panel.`,
          deepLink: '/dashboard',
          metadata: { tallerId, vehiculoId, serviceId: context.params.serviceId },
        });
      }
    } catch (error) {
      console.error('Error sending review request:', error);
    }
  });

/**
 * 4. Firestore trigger when a new message is sent in chat.
 * Sends a push notification to the receiver.
 */
exports.notifyOnNewChatMessage = functions.firestore
  .document('conversaciones/{conversacionId}/mensajes/{mensajeId}')
  .onCreate(async (snap, context) => {
    const msgData = snap.data();
    const conversacionId = context.params.conversacionId;
    
    try {
      const convDoc = await db.collection('conversaciones').doc(conversacionId).get();
      if (!convDoc.exists) return null;
      
      const convData = convDoc.data();
      const idRemitente = msgData.id_remitente;
      
      // Determinar el id del receptor
      let receptorId;
      if (idRemitente === convData.id_mecanico) {
        receptorId = convData.id_propietario;
      } else if (idRemitente === convData.id_propietario) {
        receptorId = convData.id_mecanico;
      }
      
      if (!receptorId) return null;
      
      const userDoc = await db.collection('usuarios').doc(receptorId).get();
      const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
      
      if (!fcmToken) return null;
      
      // Definir título y cuerpo basado en el tipo de mensaje
      const remitenteName = idRemitente === convData.id_mecanico ? (convData.nombre_mecanico || 'Mecánico') : (convData.nombre_propietario || 'Propietario');
      
      let title = `Nuevo mensaje de ${remitenteName}`;
      let body = msgData.contenido;
      
      if (msgData.tipo === 'cotizacion_card') {
        title = 'Nueva Cotización Recibida';
        body = `${remitenteName} te ha enviado una cotización.`;
      } else if (msgData.tipo === 'reserva_card') {
        title = 'Solicitud de Cita';
        body = `${remitenteName} te ha propuesto una fecha para cita.`;
      } else if (msgData.tipo === 'vehiculo_card') {
        title = 'Vehículo Compartido';
        body = `${remitenteName} te ha compartido un vehículo.`;
      } else if (msgData.tipo === 'imagen') {
        body = '📷 Foto adjunta';
      } else if (msgData.tipo === 'audio') {
        body = '🎤 Nota de voz';
      }
      
      await messaging.send({
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: 'chat',
          conversacionId: conversacionId
        }
      });

      // Persist in notification center
      await writeNotification(receptorId, {
        tipo: 'chat',
        titulo: title,
        body: body,
        deepLink: `/chat/${conversacionId}`,
        metadata: { conversacionId },
      });
      
    } catch (error) {
      console.error('Error sending chat notification:', error);
    }
  });

/**
 * 5. Firestore trigger when a new reservation is created.
 * Sends a push notification to the mechanic.
 */
exports.notifyOnNewReservation = functions.firestore
  .document('reservas/{reservaId}')
  .onCreate(async (snap, context) => {
    const reserva = snap.data();
    
    try {
      const targetId = reserva.id_mecanico;
      if (!targetId) return null;

      const userDoc = await db.collection('usuarios').doc(targetId).get();
      const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

      if (!fcmToken) return null;

      await messaging.send({
        token: fcmToken,
        notification: {
          title: 'Nueva Solicitud de Cita',
          body: `Has recibido una nueva solicitud de cita para el ${reserva.fecha_hora_propuesta ? reserva.fecha_hora_propuesta.toDate().toLocaleDateString('es') : 'día propuesto'}.`
        },
        data: {
          type: 'reserva',
          reservaId: context.params.reservaId
        }
      });

      // Persist in notification center
      await writeNotification(targetId, {
        tipo: 'reserva',
        titulo: 'Nueva Solicitud de Cita',
        body: `Has recibido una nueva solicitud de cita para el ${reserva.fecha_hora_propuesta ? reserva.fecha_hora_propuesta.toDate().toLocaleDateString('es') : 'día propuesto'}.`,
        deepLink: '/mechanic_dashboard',
        metadata: { reservaId: context.params.reservaId },
      });
    } catch (error) {
      console.error('Error sending new reservation notification:', error);
    }
  });

/**
 * 5.1. Firestore trigger when a reservation status changes.
 * Sends a push notification to the owner or mechanic.
 */
exports.notifyOnReservationStatusChange = functions.firestore
  .document('reservas/{reservaId}')
  .onUpdate(async (change, context) => {
    const newValue = change.after.data();
    const previousValue = change.before.data();

    if (newValue.estado === previousValue.estado) {
      return null;
    }

    try {
      const isAccepted = newValue.estado === 'confirmada';
      const isRejected = newValue.estado === 'rechazada';

      if (!isAccepted && !isRejected) return null;

      const fechaPropuesta = newValue.fecha_hora_propuesta && newValue.fecha_hora_propuesta.toDate
        ? newValue.fecha_hora_propuesta.toDate().toLocaleDateString('es')
        : 'la fecha propuesta';

      const title = isAccepted ? 'Reserva Confirmada' : 'Reserva Rechazada';
      const body = isAccepted
        ? `La cita para el ${fechaPropuesta} fue confirmada.`
        : `La cita para el ${fechaPropuesta} fue rechazada.`;

      // Tanto reserva_detail_screen.dart como reserva_chat_card.dart permiten
      // que el propietario O el mecanico sean quien confirma/rechaza segun
      // el contexto, y este trigger no puede saber cual de los dos hizo el
      // cambio -- se notifica a ambos con texto neutral en vez de asumir
      // siempre el mismo actor (bug encontrado en la revision final: el
      // codigo anterior asumia que 'el taller' confirmaba y notificaba solo
      // al propietario, quedando mal incluso cuando era el mecanico quien
      // debia enterarse).
      const recipientIds = [newValue.id_propietario, newValue.id_mecanico].filter(Boolean);

      for (const targetId of recipientIds) {
        const userDoc = await db.collection('usuarios').doc(targetId).get();
        const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
        if (fcmToken) {
          await messaging.send({
            token: fcmToken,
            notification: {
              title: title,
              body: body,
            },
            data: {
              type: 'reserva',
              reservaId: context.params.reservaId
            }
          });
        }

        // Persist in notification center
        await writeNotification(targetId, {
          tipo: 'reserva',
          titulo: title,
          body: body,
          deepLink: `/reserva_detail/${context.params.reservaId}`,
          metadata: { reservaId: context.params.reservaId },
        });
      }
    } catch (error) {
      console.error('Error sending reservation notification:', error);
    }
  });

/**
 * Helper: crea (o reutiliza, si ya existe uno para el mismo vehiculo+taller)
 * el ticket Kanban de reparación y notifica al propietario. Corre siempre
 * con Admin SDK porque necesita leer `vehiculos/{id}` (placa, id_propietario)
 * sin las restricciones de `talleres_vinculados` que aplican al cliente (ver
 * firestore.rules match /vehiculos) — ni el trigger de cotización ni el
 * callable de "Buscar Vehículo" pueden resolver esos datos del lado cliente
 * sin reabrir el bug de permission-denied que originó este helper.
 *
 * Devuelve `{ idReparacion, creado }` o `null` si el vehículo no existe.
 */
async function crearOReutilizarTicketReparacion({ idVehiculo, idTaller }) {
  const existente = await db.collection('reparaciones')
    .where('id_vehiculo', '==', idVehiculo)
    .where('id_taller', '==', idTaller)
    .limit(1)
    .get();
  if (!existente.empty) {
    return { idReparacion: existente.docs[0].id, creado: false };
  }

  const vehiculoDoc = await db.collection('vehiculos').doc(idVehiculo).get();
  if (!vehiculoDoc.exists) return null;
  const placa = vehiculoDoc.data().placa || '';
  const propietarioId = vehiculoDoc.data().id_propietario;
  if (!propietarioId) return null;

  const ahora = admin.firestore.FieldValue.serverTimestamp();
  const reparacionRef = db.collection('reparaciones').doc();
  await reparacionRef.set({
    id_vehiculo: idVehiculo,
    id_taller: idTaller,
    id_propietario: propietarioId,
    placa: placa,
    estado: 'recibido',
    historial_estados: [{ estado: 'recibido', timestamp: new Date() }],
    fecha_creacion: ahora,
    fecha_actualizacion: ahora,
  });

  const userDoc = await db.collection('usuarios').doc(propietarioId).get();
  const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
  const title = 'Tu vehículo ya está en seguimiento';
  const body = `${placa}: se abrió el ticket de servicio en el taller.`;
  if (fcmToken) {
    try {
      await messaging.send({
        token: fcmToken,
        notification: { title, body },
        data: { type: 'reparacion', reparacionId: reparacionRef.id },
      });
    } catch (fcmError) {
      console.error('Error sending FCM reparacion-created push:', fcmError);
    }
  }
  await writeNotification(propietarioId, {
    tipo: 'reparacion',
    titulo: title,
    body,
    deepLink: `/vehicle_profile/${idVehiculo}`,
    metadata: { reparacionId: reparacionRef.id, estado: 'recibido' },
  });

  return { idReparacion: reparacionRef.id, creado: true, placa, propietarioId };
}

/**
 * Verifica que quien llama pueda actuar en nombre de `tallerId`: o es el
 * propio taller, o es un empleado suyo (usuarios/{uid}.id_taller_propietario
 * == tallerId). Espejo en Admin SDK de `actuaPorTaller()` en firestore.rules.
 */
async function actuaPorTaller(callerUid, tallerId) {
  if (callerUid === tallerId) return true;
  const callerDoc = await db.collection('usuarios').doc(callerUid).get();
  return callerDoc.exists && callerDoc.data().id_taller_propietario === tallerId;
}

/**
 * 5a2. Trigger fired when a 'cotizaciones' document's estado changes and it
 * is linked to a reserva (id_reserva): traduce la cotización aceptada o
 * rechazada al estado de la cita.
 *
 * Ya NO abre el ticket de Reparaciones: eso lo hace `onCotizacionAceptada`
 * (A4b) para TODA cotización aceptada, tenga o no reserva detrás, y en el
 * estado `pendiente_recepcion`. Si esta función siguiera llamando a
 * `crearOReutilizarTicketReparacion`, cada aceptación con cita abriría dos
 * tickets para el mismo vehículo (uno aquí en 'recibido' y otro allí), que es
 * exactamente el "vehículo recibido sin que nadie lo reciba" que A3 prohíbe.
 */
exports.sincronizarReservaYReparacionAlCotizar = functions.firestore
  .document('cotizaciones/{cotizacionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.estado === after.estado) return null;
    if (after.estado !== 'aceptada' && after.estado !== 'rechazada') return null;

    const reservaId = after.id_reserva;
    if (!reservaId) return null;

    try {
      const reservaRef = db.collection('reservas').doc(reservaId);
      const reservaUpdate = { estado: after.estado === 'aceptada' ? 'confirmada' : 'rechazada' };
      if (after.estado === 'aceptada' && after.fecha_propuesta) {
        reservaUpdate.fecha_hora_confirmada = after.fecha_propuesta;
      }
      await reservaRef.update(reservaUpdate);
    } catch (error) {
      console.error('Error syncing reserva on cotizacion accept:', error);
    }

    return null;
  });

/**
 * 5a2b. A4b — la aceptación de la cotización abre el ticket de `reparaciones`
 * en `pendiente_recepcion`. Es el ÚNICO creador de esa colección: el cliente
 * ya no puede crearla (`allow create: if false` en firestore.rules), y
 * "Recibir vehículo" pasó a ser la transición `pendiente_recepcion` ->
 * `recibido`.
 *
 * Toda la lógica vive en ./src/aceptarCotizacion para poder testearla sin
 * montar el SDK de Admin; aquí solo queda el enganche del trigger.
 */
exports.onCotizacionAceptada = functions.firestore
  .document('cotizaciones/{cotizacionId}')
  .onUpdate(async (change, context) => {
    try {
      await abrirTicketDeReparacion(db, {
        cotizacionId: context.params.cotizacionId,
        antes: change.before.data() || {},
        despues: change.after.data() || {},
        ahora: new Date(),
      });
    } catch (error) {
      // Revision de rama completa (hallazgo C1/Blocker 3): este es el UNICO
      // creador de `reparaciones`. Devolver `null` tras un fallo le decia a
      // Firestore que la invocacion habia tenido exito, asi que no habia
      // reintento: el cliente veia "cotizacion aceptada" y ningun ticket
      // existia, sin que nadie se enterara. Se relanza para que la
      // invocacion quede marcada como fallida (visible en los logs/metricas
      // de Cloud Functions). La guarda de idempotencia de
      // `abrirTicketDeReparacion` (el id derivado `cot_<cotizacionId>` y el
      // `existente.exists` de arriba) sigue intacta, asi que un reintento no
      // puede duplicar el ticket.
      console.error('Error abriendo el ticket de reparacion al aceptar la cotizacion:', error);
      throw error;
    }
    return null;
  });

/**
 * 5a3. Callable: abre (o reutiliza) el ticket Kanban de reparación para un
 * vehículo encontrado por placa desde "Buscar Vehículo"
 * (VehicleSearchScreen -> InitiateServiceScreen). Existe porque
 * `buscarVehiculoPorPlaca` deliberadamente NO devuelve `id_propietario` al
 * cliente (ver ese callable) para no exponer al dueño a cualquier mecánico
 * que busque una placa — pero `reparaciones` sí necesita ese campo para
 * crearse. En vez de relajar esa protección, la creación del ticket se hace
 * aquí, del lado servidor, donde sí se puede leer el vehículo completo.
 *
 * Corre con Admin SDK, así que `firestore.rules` (que en /reparaciones tiene
 * `allow create: if false` desde A4b) no lo alcanza. Hallazgo 1 de la
 * revisión de la Tarea 4: antes de `verificarAperturaManual` este callable
 * era la única puerta server-side que quedaba abierta para abrir un ticket
 * sin vínculo con el vehículo y sin cotización aceptada — justo lo que A3
 * prohíbe. Ver `./src/iniciarReparacionPorVehiculo.js`.
 */
exports.iniciarReparacionPorVehiculo = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }

  const callerDoc = await db.collection('usuarios').doc(context.auth.uid).get();
  const rol = callerDoc.exists ? callerDoc.data().rol : null;
  if (!['Mecanico', 'Taller'].includes(rol)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo mecánicos pueden abrir tickets de reparación.'
    );
  }

  const idVehiculo = data && data.id_vehiculo ? String(data.id_vehiculo) : '';
  const idTaller = data && data.id_taller ? String(data.id_taller) : '';
  if (!idVehiculo || !idTaller) {
    throw new functions.https.HttpsError('invalid-argument', 'Faltan id_vehiculo o id_taller.');
  }

  const puedeActuar = await actuaPorTaller(context.auth.uid, idTaller);
  if (!puedeActuar) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'No puedes abrir tickets en nombre de ese taller.'
    );
  }

  const verificacion = await verificarAperturaManual(db, { idVehiculo, idTaller });
  if (!verificacion.ok) {
    throw new functions.https.HttpsError(verificacion.code, verificacion.message);
  }

  const resultado = await crearOReutilizarTicketReparacion({ idVehiculo, idTaller });
  if (!resultado) {
    throw new functions.https.HttpsError('not-found', 'Vehículo no encontrado.');
  }
  return { id_reparacion: resultado.idReparacion };
});

/**
 * 5b. Trigger fired when a 'reparaciones' document's estado field changes.
 * Notifies the vehicle owner (push + in-app notification center).
 */
exports.notifyOnReparacionStatusChange = functions.firestore
  .document('reparaciones/{reparacionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.estado === after.estado) {
      return null;
    }

    try {
      const etiquetas = {
        recibido: 'Recibido',
        en_revision: 'En Revisión',
        esperando_repuestos: 'Esperando Repuestos',
        listo_para_entrega: 'Listo para Entregar',
      };

      const targetId = after.id_propietario;
      if (!targetId) return null;

      const title = 'Actualización de tu vehículo';
      const body = `${after.placa}: ${etiquetas[after.estado] || after.estado}`;

      const userDoc = await db.collection('usuarios').doc(targetId).get();
      const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

      if (fcmToken) {
        // El push FCM va en su propio try/catch (mismo patron que el fix
        // I-3 de arriba, notifyOnServiceComplete): un fallo de
        // messaging.send() (token invalido/expirado, algo rutinario) no
        // debe impedir que se escriba el registro persistente del centro
        // de notificaciones (writeNotification) de abajo. Antes ambas
        // llamadas compartian el try/catch externo de esta funcion, asi
        // que un token muerto dejaba al propietario sin ningun rastro de
        // la actualizacion de su reparacion.
        try {
          await messaging.send({
            token: fcmToken,
            notification: {
              title: title,
              body: body,
            },
            data: {
              type: 'reparacion',
              reparacionId: context.params.reparacionId,
            },
          });
        } catch (fcmError) {
          console.error('Error sending FCM reparacion push:', fcmError);
        }
      }

      // Persist in notification center
      await writeNotification(targetId, {
        tipo: 'reparacion',
        titulo: title,
        body: body,
        deepLink: `/vehicle_profile/${after.id_vehiculo}`,
        metadata: { reparacionId: context.params.reparacionId, estado: after.estado },
      });
    } catch (error) {
      console.error('Error sending reparacion notification:', error);
    }

    return null;
  });

/**
 * 6. Scheduled function to send reservation reminders daily.
 * Notifies the owner and mechanic if they have an approved reservation for the next day.
 */
exports.sendReservationReminders = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const dateString = tomorrow.toISOString().split('T')[0]; // 'YYYY-MM-DD'

  const limit = 500;
  let lastDoc = null;

  const usuariosCache = {};

  try {
    while (true) {
      let q = db.collection('reservas')
        .where('estado', '==', 'confirmada')
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(limit);
      if (lastDoc) {
        q = q.startAfter(lastDoc);
      }
      const reservasSnapshot = await q.get();
      if (reservasSnapshot.empty) break;

      for (const doc of reservasSnapshot.docs) {
        const reserva = doc.data();

        const fechaPropuesta = reserva.fecha_hora_propuesta && reserva.fecha_hora_propuesta.toDate
          ? reserva.fecha_hora_propuesta.toDate()
          : null;
        if (!fechaPropuesta) continue;
        const fechaPropuestaString = fechaPropuesta.toISOString().split('T')[0];
        if (fechaPropuestaString !== dateString) continue;

        // Notify Owner
        if (reserva.id_propietario) {
          if (!(reserva.id_propietario in usuariosCache)) {
            const ownerDoc = await db.collection('usuarios').doc(reserva.id_propietario).get();
            usuariosCache[reserva.id_propietario] = ownerDoc.exists ? ownerDoc.data() : null;
          }
          const ownerData = usuariosCache[reserva.id_propietario];
          if (ownerData && ownerData.fcmToken) {
            await messaging.send({
              token: ownerData.fcmToken,
              notification: {
                title: 'Recordatorio de Cita',
                body: 'Tienes una cita programada para mañana a la hora acordada.'
              }
            });
          }
        }

        // Notify Mechanic
        if (reserva.id_mecanico) {
          if (!(reserva.id_mecanico in usuariosCache)) {
            const mechanicDoc = await db.collection('usuarios').doc(reserva.id_mecanico).get();
            usuariosCache[reserva.id_mecanico] = mechanicDoc.exists ? mechanicDoc.data() : null;
          }
          const mechanicData = usuariosCache[reserva.id_mecanico];
          if (mechanicData && mechanicData.fcmToken) {
            await messaging.send({
              token: mechanicData.fcmToken,
              notification: {
                title: 'Recordatorio de Cita',
                body: 'Tienes una cita programada para mañana con el vehículo del cliente.'
              }
            });
          }
        }
      }

      lastDoc = reservasSnapshot.docs[reservasSnapshot.docs.length - 1];
    }
  } catch (error) {
    console.error('Error in sendReservationReminders:', error);
  }
});



/**
 * 6. Auth trigger when a user is deleted.
 * Cleans up user data (Firestore) when an account is deleted from Firebase Auth.
 */
exports.onUserDelete = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  console.log(`User ${userId} deleted. Cleaning up data...`);

  try {
    // 1. Delete user document
    await db.collection('usuarios').doc(userId).delete();
    console.log(`User document ${userId} deleted.`);

    // 2. Delete all vehicles owned by the user (onVehicleDelete will handle their related data)
    await new Promise((resolve, reject) => {
      deleteQueryBatch(db, db.collection('vehiculos').where('id_propietario', '==', userId).limit(500), resolve, reject);
    });

    // 3. Delete reviews (resenias) left by the user
    await new Promise((resolve, reject) => {
      deleteQueryBatch(db, db.collection('resenias').where('id_usuario', '==', userId).limit(500), resolve, reject);
    });

    // 4. Delete reservations (reservas) made by the user
    await new Promise((resolve, reject) => {
      deleteQueryBatch(db, db.collection('reservas').where('id_propietario', '==', userId).limit(500), resolve, reject);
    });
    
    // 3. Delete user's profile picture
    try {
      await storage.bucket().deleteFiles({ prefix: `perfiles/${userId}/` });
      console.log(`Profile pictures for user ${userId} deleted.`);
    } catch (e) {
      console.error(`Error deleting profile pictures for user ${userId}:`, e);
    }

  } catch (error) {
    console.error(`Error cleaning up data for user ${userId}:`, error);
  }
});

/**
 * 7. Firestore trigger when a vehicle is deleted.
 * Cleans up related data (alerts, maintenance, services) and Storage files.
 */
exports.onVehicleDelete = functions.firestore.document('vehiculos/{vehicleId}').onDelete(async (snap, context) => {
  const vehicleId = context.params.vehicleId;
  console.log(`Vehicle ${vehicleId} deleted. Cleaning up related data...`);

  try {
    // 1. Delete alerts in batches of 500
    await new Promise((resolve, reject) => {
      deleteQueryBatch(db, db.collection('alertas').where('id_vehiculo', '==', vehicleId).limit(500), resolve, reject);
    });

    // 2. Delete mantenimientos in batches of 500
    await new Promise((resolve, reject) => {
      deleteQueryBatch(db, db.collection('mantenimientos').where('id_vehiculo', '==', vehicleId).limit(500), resolve, reject);
    });

    // 3. Delete servicios in batches of 500
    await new Promise((resolve, reject) => {
      deleteQueryBatch(db, db.collection('servicios').where('id_vehiculo', '==', vehicleId).limit(500), resolve, reject);
    });

    // 4. Delete historial_mantenimientos in batches of 500
    await new Promise((resolve, reject) => {
      deleteQueryBatch(db, db.collection('historial_mantenimientos').where('id_vehiculo', '==', vehicleId).limit(500), resolve, reject);
    });

    console.log(`Firestore data for vehicle ${vehicleId} deleted.`);

    // 5. Delete storage files
    try {
      await storage.bucket().deleteFiles({ prefix: `facturas/${vehicleId}/` });
      console.log(`Storage files for vehicle ${vehicleId} deleted.`);
    } catch (e) {
      console.error(`Error deleting storage files for vehicle ${vehicleId}:`, e);
    }

  } catch (error) {
    console.error(`Error cleaning up data for vehicle ${vehicleId}:`, error);
  }
});

/**
 * 8. Scheduled function for automated Firestore backup (C-03).
 * Runs every 24 hours to export the database to Google Cloud Storage.
 */
exports.scheduledFirestoreExport = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const projectId = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
  const client = new firestore.v1.FirestoreAdminClient();
  const databaseName = client.databasePath(projectId, '(default)');
  const bucket = 'gs://' + projectId + '-backups';

  try {
    const [response] = await client.exportDocuments({
      name: databaseName,
      outputUriPrefix: bucket,
    });
    console.log(`Export operation initiated: ${response.name}`);
    return response;
  } catch (error) {
    console.error('Error exporting Firestore database:', error);
    throw error;
  }
});

/**
 * 9. Aggregate ratings on review write.
 */
exports.aggregateRatings = functions.firestore
  .document('resenias/{reseniaId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const tallerId = (after || before || {}).id_taller;
    if (!tallerId) return null;

    const beforeEstrellas = before ? (before.estrellas || 0) : 0;
    const afterEstrellas = after ? (after.estrellas || 0) : 0;
    const deltaCount = (after ? 1 : 0) - (before ? 1 : 0);
    const deltaSum = afterEstrellas - beforeEstrellas;
    // Un update que no toca 'estrellas' (respuesta_taller, is_reported, etc.)
    // no cambia el agregado: nos ahorramos la escritura.
    if (deltaCount === 0 && deltaSum === 0) return null;

    const userRef = db.collection('usuarios').doc(tallerId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) return null;

    if (userSnap.data().suma_estrellas === undefined) {
      // Migracion perezosa: este taller aun no paso por la version
      // incremental. Se siembra suma_estrellas con un recuento completo,
      // una sola vez; las escrituras futuras ya son incrementales (O(1) en
      // vez de O(n) reseñas del taller).
      const reseniasSnap = await db.collection('resenias').where('id_taller', '==', tallerId).get();
      let total = 0;
      let sum = 0;
      reseniasSnap.forEach((doc) => {
        total++;
        sum += doc.data().estrellas || 0;
      });
      await userRef.update({
        calificacion_promedio: total > 0 ? sum / total : 0,
        total_resenias: total,
        suma_estrellas: sum,
      });
      return null;
    }

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) return;
      const data = snap.data();
      const count = Math.max(0, (data.total_resenias || 0) + deltaCount);
      const sum = Math.max(0, (data.suma_estrellas || 0) + deltaSum);
      tx.update(userRef, {
        calificacion_promedio: count > 0 ? sum / count : 0,
        total_resenias: count,
        suma_estrellas: sum,
      });
    });
  });

/**
 * 10. Callable: search a vehicle by plate for mechanics onboarding a
 * walk-in customer they have no prior service relationship with.
 *
 * Returns only non-sensitive identifying fields. It intentionally does NOT
 * expose id_propietario or any other owner data — full vehicle documents
 * stay protected by firestore.rules (owner, admin, or talleres_vinculados).
 */
exports.buscarVehiculoPorPlaca = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }

  const callerDoc = await db.collection('usuarios').doc(context.auth.uid).get();
  const rol = callerDoc.exists ? callerDoc.data().rol : null;
  if (!['Mecanico', 'Taller'].includes(rol)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo mecánicos pueden buscar vehículos por placa.'
    );
  }

  const placa = (data && data.placa ? String(data.placa) : '').trim().toUpperCase();
  if (!placa) {
    throw new functions.https.HttpsError('invalid-argument', 'Debes indicar una placa.');
  }

  const snapshot = await db
    .collection('vehiculos')
    .where('placa', '==', placa)
    .limit(1)
    .get();

  if (snapshot.empty) return null;

  const doc = snapshot.docs[0];
  const v = doc.data();
  return {
    id_vehiculo: doc.id,
    placa: v.placa || placa,
    marca: v.marca || null,
    modelo: v.modelo || null,
    anio: v.anio || null,
    color: v.color || null,
    kilometraje_actual: v.kilometraje_actual || 0,
  };
});

/**
 * 11. Callable: resuelve los datos publicos (uid, correo, nombre) de los
 * usuarios con quienes el propietario ya comparte un vehiculo.
 *
 * Necesaria desde la Tarea 8 (Fase C): 'usuarios' quedo cerrada a solo
 * lectura del propio documento, lo que rompio share_vehicle_sheet.dart, que
 * antes leia usuarios/{uid} de cada uid en vehiculo.shared_with. Esta
 * funcion corre con Admin SDK y solo devuelve datos de los uids que YA
 * figuran en shared_with del vehiculo del propio llamante, verificado aqui
 * server-side (no confia en una lista que mande el cliente).
 */
exports.obtenerUsuariosCompartidos = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }

  const vehicleId = data && data.vehicleId ? String(data.vehicleId) : '';
  if (!vehicleId) {
    throw new functions.https.HttpsError('invalid-argument', 'Debes indicar el vehiculo.');
  }

  const vehiculoDoc = await db.collection('vehiculos').doc(vehicleId).get();
  if (!vehiculoDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Vehículo no encontrado.');
  }
  if (vehiculoDoc.data().id_propietario !== context.auth.uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo el propietario del vehículo puede ver con quién lo comparte.'
    );
  }

  const sharedWith = Array.isArray(vehiculoDoc.data().shared_with)
    ? vehiculoDoc.data().shared_with
    : [];

  const usuarios = await Promise.all(
    sharedWith.map(async (uid) => {
      const doc = await db.collection('usuarios').doc(String(uid)).get();
      if (!doc.exists) return null;
      const d = doc.data();
      return {
        uid: doc.id,
        correo: d.correo || '',
        nombre: d.nombre_completo || 'Sin nombre',
      };
    })
  );

  return usuarios.filter(Boolean);
});

/**
 * 11b. Callable: perfil publico del CLIENTE que el mecanico ve desde el
 * chat (Tarea 10, C3 — "ver el perfil del otro desde el chat").
 *
 * `usuarios/{userId}` esta cerrado a `isOwner(userId) || isAdmin()`
 * (firestore.rules), asi que un mecanico no puede leerlo directamente —
 * correcto, porque ese documento trae telefono/dui/correo/vehiculos. Este
 * callable corre con Admin SDK (fuera del alcance de firestore.rules) y
 * hace EXPLICITAMENTE, del lado servidor, lo que una regla no puede
 * expresar: proyectar solo {nombre, foto_perfil_url, municipio}
 * (subconjuntoPublicoCliente) Y solo si el llamante comparte una
 * conversacion real con el objetivo (compartenConversacion) — sin eso,
 * cualquier mecanico podria consultar a cualquier cliente por uid.
 *
 * El caso simetrico (mecanico visto por un cliente) NO pasa por aqui: ese
 * ya tiene una proyeccion publica de lectura anonima en `talleres/{uid}`
 * (publishTallerProfile.js), que el cliente de Flutter lee directamente sin
 * ningun round-trip a Cloud Functions.
 */
exports.obtenerPerfilPublico = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }

  const clienteId = data && data.userId ? String(data.userId) : '';
  if (!clienteId) {
    throw new functions.https.HttpsError('invalid-argument', 'Debes indicar el usuario.');
  }

  const mecanicoId = context.auth.uid;
  if (mecanicoId === clienteId) {
    throw new functions.https.HttpsError('invalid-argument', 'No aplica a tu propio perfil.');
  }

  // Hallazgo C2 (revision de rama completa): segunda barrera independiente
  // del arreglo en firestore.rules — una cuenta de CLIENTE no puede usar
  // este callable en absoluto, ni siquiera si consiguiera una conversacion
  // real. Antes de esto la unica puerta era `compartenConversacion`, y
  // `conversaciones.create` no comprobaba rol.
  const puedeUsarlo = await llamanteEsMecanico(db, mecanicoId);
  if (!puedeUsarlo) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo mecánicos pueden consultar este perfil.'
    );
  }

  const compartida = await compartenConversacion(db, { mecanicoId, clienteId });
  if (!compartida) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'No tienes ninguna conversación con este usuario.'
    );
  }

  const clienteDoc = await db.collection('usuarios').doc(clienteId).get();
  if (!clienteDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Usuario no encontrado.');
  }

  return subconjuntoPublicoCliente(clienteDoc.data());
});

/**
 * 11c. Callable: empleados publicos de un taller (Tarea 13, D1 — "perfil
 * publico del taller").
 *
 * `talleres/{tallerId}/empleados` esta cerrado en `firestore.rules` a
 * `request.auth.uid == tallerId || isAdmin()` (ni el propio empleado puede
 * leer la subcoleccion completa) porque cada documento trae correo y
 * telefono del empleado. Abrir esa lectura a "cualquiera que mire el perfil
 * publico del taller" expondria esos dos campos de forma anonima — una
 * regla de Firestore no puede proyectar SOLO nombre/rol/activo, un
 * `get()`/`list()` permitido siempre trae el documento completo (mismo
 * principio que `obtenerPerfilPublico` arriba).
 *
 * Este callable corre con Admin SDK, fuera del alcance de esas reglas, y
 * proyecta explicitamente el ALLOWLIST {nombre_completo, rol, activo} via
 * `listarEmpleadosPublicos` (que ademas ya filtra a solo los activos).
 *
 * SI requiere `context.auth` (correccion de controller sobre la primera
 * version de esta tarea, que lo dejaba anonimo igual que `talleres/{uid}`).
 * Esa comparacion aplicaba el consentimiento del DUEÑO al EMPLEADO: el
 * dueño eligio operar un negocio publico y aparecer en el directorio; su
 * mecanico contratado no eligio nada de eso — solo le dio su nombre a un
 * patron para conseguir trabajo. Esa distincion es la razon completa por la
 * que esto es un callable en vez de un cambio de reglas; dejarlo sin
 * autenticacion devuelve gran parte de lo que el diseño protegia: un
 * endpoint abierto que cualquiera, sin cuenta, puede invocar con cualquier
 * idTaller para enumerar personal a escala. Ni el directorio de talleres ni
 * el perfil publico son rutas anonimas en la app (`app_router.dart`,
 * `_publicRoutes`), asi que exigir sesion no le cuesta nada a quien ya
 * llega hasta aqui.
 */
exports.obtenerEmpleadosPublicos = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }

  const idTaller = data && data.idTaller ? String(data.idTaller) : '';
  if (!idTaller) {
    throw new functions.https.HttpsError('invalid-argument', 'Debes indicar el taller.');
  }

  const empleados = await listarEmpleadosPublicos(db, idTaller);
  return { empleados };
});

/**
 * 12. Callable: busca un propietario por correo para compartir un vehiculo.
 *
 * Igual que buscarVehiculoPorPlaca, resuelve del lado del servidor lo que
 * 'usuarios' ya no expone al cliente.
 *
 * Lo que el gate de "vehicleId + soy su propietario" SI protege: exige que
 * quien llama tenga una cuenta real con rol Propietario y sea dueno de ALGUN
 * vehiculo, y solo devuelve cuentas con rol 'Propietario' (nunca expone
 * mecanicos/admins por correo).
 *
 * Lo que el gate NO protege (hallazgo Important, revision de la 2a ronda de
 * Fase C): 'vehiculos' create solo exige id_propietario == auth.uid
 * (firestore.rules), asi que cualquier cuenta Propietario puede crearse un
 * vehiculo desechable en un solo write y usarlo para pasar este chequeo. En
 * la practica esta funcion es, para cualquier cuenta Propietario, un oraculo
 * correo -> (uid, nombre_completo) sobre toda la poblacion de propietarios,
 * sin limite de tasa. No es una regresion respecto al estado anterior a la
 * Fase C (antes el cliente podia consultar 'usuarios' por correo
 * directamente), pero SI reabre parcialmente lo que la Tarea 8 buscaba
 * cerrar. Deliberadamente NO se agrega aqui un rate-limiter ad-hoc: el
 * cierre real de este vector depende de App Check (Fase E, Tarea 14 del
 * plan), que verifica que la llamada viene de la app real y no de un script,
 * y es donde corresponde resolverlo sin duplicar infraestructura fragil.
 */
exports.buscarPropietarioPorCorreo = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }

  const vehicleId = data && data.vehicleId ? String(data.vehicleId) : '';
  const correo = (data && data.correo ? String(data.correo) : '').trim().toLowerCase();
  if (!vehicleId || !correo) {
    throw new functions.https.HttpsError('invalid-argument', 'Debes indicar el vehiculo y el correo.');
  }

  const vehiculoDoc = await db.collection('vehiculos').doc(vehicleId).get();
  if (!vehiculoDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Vehículo no encontrado.');
  }
  if (vehiculoDoc.data().id_propietario !== context.auth.uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo el propietario del vehículo puede compartirlo.'
    );
  }

  const snapshot = await db
    .collection('usuarios')
    .where('correo', '==', correo)
    .limit(1)
    .get();

  if (snapshot.empty) return null;

  const doc = snapshot.docs[0];
  const d = doc.data();
  if (d.rol !== 'Propietario') return null;

  return {
    uid: doc.id,
    correo: d.correo || correo,
    nombre: d.nombre_completo || 'Sin nombre',
  };
});

/**
 * 13. Callable: crea una cuenta de empleado para un taller.
 *
 * Solo el Admin SDK (esta Cloud Function) puede crear un usuario de Auth en
 * nombre de otra persona sin cerrar la sesion del que llama, y solo el
 * Admin SDK puede fijar 'rol' e 'id_taller_propietario' en 'usuarios': el
 * cliente tiene ambos campos bloqueados en firestore.rules (ver seccion
 * `match /usuarios/{userId}`), asi que un empleado no puede auto-asignarse
 * el rol Taller ni reasignar su vinculo a otro taller.
 */
exports.crearEmpleadoTaller = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }
  const idTallerPropietario = context.auth.uid;

  const tallerDoc = await db.collection('usuarios').doc(idTallerPropietario).get();
  const tallerData = tallerDoc.exists ? tallerDoc.data() : null;
  const rol = tallerData ? tallerData.rol : null;
  if (!['Mecanico', 'Taller'].includes(rol)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo un taller puede crear cuentas de empleados.'
    );
  }
  // Un empleado tambien tiene rol 'Taller' (hereda los mismos permisos
  // operativos que el dueño, ver el write mas abajo), asi que el check de
  // arriba por si solo NO distingue a un empleado del dueño real: sin este
  // guard, un empleado podia llamar este callable directamente (saltandose
  // la UI, donde el item de sidebar esta oculto) y provisionar sus propias
  // sub-cuentas, escalando privilegios y rompiendo el modelo de un solo
  // dueño por taller. Solo una cuenta SIN id_taller_propietario (el dueño
  // real) puede crear empleados.
  if (tallerData && tallerData.id_taller_propietario) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo el dueño del taller puede crear cuentas de empleados.'
    );
  }

  // Espejo exacto del check de estado de isMecanico() en firestore.rules
  // (getUserData().get('estado', 'pendiente') in ['aprobado', 'activo']):
  // sin esto, un taller aun 'pendiente' de aprobacion admin podia llamar
  // este callable (Admin SDK, no pasa por firestore.rules) y crearse a si
  // mismo una sub-cuenta de empleado con 'estado: activo' fijo (ver el
  // segundo write mas abajo), que SI pasa isMecanico() — saltandose la
  // aprobacion del admin por completo via esa cuenta de empleado.
  const estado = tallerData ? tallerData.estado : undefined;
  if (!['aprobado', 'activo'].includes(estado)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Tu cuenta de taller aún no ha sido aprobada.'
    );
  }

  const correo = (data && data.correo ? String(data.correo) : '').trim().toLowerCase();
  const password = data && data.password ? String(data.password) : '';
  const nombreCompleto = (data && data.nombreCompleto ? String(data.nombreCompleto) : '').trim();
  const telefono = data && data.telefono ? String(data.telefono).trim() : null;
  // `rol` ausente (no enviado por el cliente) se trata distinto de un `rol`
  // presente pero invalido: esta funcion y la app Flutter se despliegan por
  // separado (`firebase deploy --only functions:crearEmpleadoTaller` es un
  // paso independiente de publicar la app). Si esta validacion se
  // desplegara ANTES que la actualizacion de la app, todo cliente viejo
  // aun en produccion llamaria este callable sin campo `rol` y quedaria
  // hard-rechazado con invalid-argument, rompiendo la creacion de
  // empleados hasta que ese cliente actualice. Por eso `rol` ausente cae al
  // default implícito pre-Task 3 ('Mecanico') en silencio, mientras que un
  // valor explícito fuera del vocabulario sigue siendo rechazado.
  const rolEmpleado =
    data && data.rol !== undefined && data.rol !== null
      ? String(data.rol)
      : 'Mecanico';

  if (!correo || !password || !nombreCompleto) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Correo, contraseña y nombre son requeridos.'
    );
  }
  if (password.length < 6) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'La contraseña debe tener al menos 6 caracteres.'
    );
  }
  if (!['Mecanico', 'Recepcionista'].includes(rolEmpleado)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      "El rol debe ser 'Mecanico' o 'Recepcionista'."
    );
  }

  let userRecord;
  try {
    userRecord = await admin.auth().createUser({
      email: correo,
      password,
      displayName: nombreCompleto,
    });
  } catch (err) {
    if (err && err.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'Ya existe una cuenta con ese correo.');
    }
    throw new functions.https.HttpsError('invalid-argument', err.message);
  }

  const empleadoRef = db
    .collection('talleres')
    .doc(idTallerPropietario)
    .collection('empleados')
    .doc(userRecord.uid);

  try {
    await empleadoRef.set({
      id_taller_propietario: idTallerPropietario,
      nombre_completo: nombreCompleto,
      correo,
      telefono: telefono || null,
      rol: rolEmpleado,
      activo: true,
      fecha_creacion: admin.firestore.Timestamp.now(),
    });

    // El empleado hereda rol Taller (mismos permisos operativos que el
    // dueño en firestore.rules/isMecanico()) pero queda vinculado al taller
    // dueño via id_taller_propietario, campo que el cliente no puede tocar
    // (firestore.rules) y que distingue esta cuenta de la del dueño real
    // para fines de UI/administración.
    await db.collection('usuarios').doc(userRecord.uid).set({
      id_usuario: userRecord.uid,
      nombre_completo: nombreCompleto,
      correo,
      rol: 'Taller',
      id_taller_propietario: idTallerPropietario,
      estado: 'activo',
      fecha_registro: admin.firestore.Timestamp.now(),
    });
  } catch (err) {
    // Si cualquiera de los dos writes de Firestore falla, la cuenta de Auth
    // ya fue creada: sin este rollback quedaria huerfana (sin registro en
    // Firestore, invisible para el dueño del taller) y el correo quedaria
    // consumido para siempre (un reintento fallaria con 'already-exists').
    try {
      await admin.auth().deleteUser(userRecord.uid);
    } catch (cleanupErr) {
      console.error(
        `crearEmpleadoTaller: fallo al hacer rollback del usuario Auth huerfano ${userRecord.uid}:`,
        cleanupErr
      );
    }
    throw new functions.https.HttpsError(
      'internal',
      'No se pudo completar el registro del empleado. Intenta de nuevo.'
    );
  }

  return { idEmpleado: userRecord.uid };
});

/**
 * Desactiva la sub-cuenta de un empleado, revocando su acceso de verdad.
 *
 * Antes de este fix, EmpleadoRepository.desactivarEmpleado() solo escribia
 * `talleres/{tallerId}/empleados/{empleadoId}.activo = false` desde el
 * cliente — un campo que ningun lugar del sistema (ni firestore.rules, ni
 * ninguna Cloud Function, ni el router) llegaba a leer. La cuenta Auth y el
 * doc `usuarios/{uid}` del empleado quedaban intactos, asi que un empleado
 * "desactivado" seguia pudiendo iniciar sesion y usar el panel completo
 * (isMecanico() solo mira rol + estado en 'usuarios', nunca esta
 * subcoleccion). Este callable, con Admin SDK, hace la revocacion real:
 * 1) deshabilita la cuenta de Firebase Auth (admin.auth().updateUser
 *    disabled:true) — el intento de login/uso de token existente falla.
 * 2) fija usuarios/{empleadoId}.estado = 'suspendido', que isMecanico() ya
 *    rechaza (getUserData().get('estado', 'pendiente') in ['aprobado',
 *    'activo']) — defensa en profundidad si el disable de Auth no se
 *    propaga de inmediato (tokens ya emitidos siguen siendo validos hasta
 *    que expiran o se revocan explicitamente).
 * 3) mantiene el write de talleres/.../empleados.activo = false solo para
 *    que la UI (EmpleadosScreen) siga reflejando el estado sin re-leer
 *    'usuarios'.
 */
exports.desactivarEmpleadoTaller = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }
  const callerUid = context.auth.uid;
  const idEmpleado = data && data.idEmpleado ? String(data.idEmpleado) : '';
  if (!idEmpleado) {
    throw new functions.https.HttpsError('invalid-argument', 'idEmpleado es requerido.');
  }

  // Verifica que quien llama sea el dueño REAL del empleado objetivo:
  // el doc talleres/{callerUid}/empleados/{idEmpleado} solo existe si
  // crearEmpleadoTaller lo creo bajo ese dueño exacto (mismo patron de
  // ownership que el resto del callable hermano). Se comprueba tambien
  // usuarios/{idEmpleado}.id_taller_propietario == callerUid como segunda
  // fuente de verdad, por si algun dia ambos documentos llegaran a
  // desincronizarse.
  const empleadoRef = db.collection('talleres').doc(callerUid).collection('empleados').doc(idEmpleado);
  const [empleadoDoc, empleadoUserDoc] = await Promise.all([
    empleadoRef.get(),
    db.collection('usuarios').doc(idEmpleado).get(),
  ]);

  const perteneceAlCaller =
    empleadoDoc.exists ||
    (empleadoUserDoc.exists && empleadoUserDoc.data().id_taller_propietario === callerUid);

  if (!perteneceAlCaller) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo el dueño del taller puede desactivar a este empleado.'
    );
  }

  try {
    await admin.auth().updateUser(idEmpleado, { disabled: true });
  } catch (err) {
    console.error(`desactivarEmpleadoTaller: fallo al deshabilitar la cuenta Auth ${idEmpleado}:`, err);
    throw new functions.https.HttpsError(
      'internal',
      'No se pudo desactivar la cuenta del empleado. Intenta de nuevo.'
    );
  }

  const writes = [];
  if (empleadoDoc.exists) {
    writes.push(empleadoRef.update({ activo: false }));
  }
  if (empleadoUserDoc.exists) {
    writes.push(db.collection('usuarios').doc(idEmpleado).update({ estado: 'suspendido' }));
  }
  await Promise.all(writes);

  return { ok: true };
});

/**
 * Verifica que `uid` tenga rol Superusuario en Firestore. Compartido por
 * superUserCreateAccount y superUserDeleteAccount: ambos requieren el mismo
 * nivel de privilegio (por encima de Administrador) y, como corren con
 * Admin SDK (bypassa firestore.rules), no pueden fiarse de ningún claim que
 * venga del cliente — solo del doc real en Firestore.
 */
async function assertSuperUser(uid) {
  const doc = await db.collection('usuarios').doc(uid).get();
  const rol = doc.exists ? doc.data().rol : null;
  if (rol !== 'Superusuario') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo un Superusuario puede realizar esta acción.'
    );
  }
}

// Contraseña temporal fija para cuentas creadas manualmente por un
// Superusuario (decisión de producto: nunca pedirle al Superusuario que
// escriba/transmita una contraseña específica por usuario). El nuevo
// usuario debe cambiarla desde "Olvidé mi contraseña" en su primer login.
const SUPERUSER_TEMP_PASSWORD = 'AutoDoc2026*';

/**
 * Crea una cuenta (Auth + Firestore) en nombre de un Superusuario sin que
 * este pierda su propia sesión: FirebaseAuth.createUserWithEmailAndPassword
 * desde el cliente cerraría la sesión del Superusuario e iniciaría sesión
 * como el usuario recién creado (limitación conocida del SDK cliente). Al
 * crear la cuenta aquí con el Admin SDK, el cliente nunca cambia de sesión.
 * Mismo patrón de rollback que crearEmpleadoTaller: si el write de
 * Firestore falla, se borra el usuario de Auth para no dejarlo huérfano.
 */
exports.superUserCreateAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }
  await assertSuperUser(context.auth.uid);

  const correo = (data && data.correo ? String(data.correo) : '').trim().toLowerCase();
  const nombreCompleto = (data && data.nombreCompleto ? String(data.nombreCompleto) : '').trim();
  const rol = data && data.rol ? String(data.rol) : '';

  if (!correo || !nombreCompleto) {
    throw new functions.https.HttpsError('invalid-argument', 'Correo y nombre son requeridos.');
  }
  // 'Superusuario' se excluye a propósito: crear otro Superusuario es
  // demasiado privilegiado para exponerlo en un formulario del panel.
  if (!['Propietario', 'Mecanico', 'Administrador'].includes(rol)) {
    throw new functions.https.HttpsError('invalid-argument', 'Rol inválido.');
  }

  let userRecord;
  try {
    userRecord = await admin.auth().createUser({
      email: correo,
      password: SUPERUSER_TEMP_PASSWORD,
      displayName: nombreCompleto,
    });
  } catch (err) {
    if (err && err.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'Ya existe una cuenta con ese correo.');
    }
    throw new functions.https.HttpsError('invalid-argument', err.message);
  }

  try {
    await db.collection('usuarios').doc(userRecord.uid).set({
      id_usuario: userRecord.uid,
      nombre_completo: nombreCompleto,
      correo,
      rol,
      estado: 'activo',
      fecha_registro: admin.firestore.Timestamp.now(),
    });
  } catch (err) {
    try {
      await admin.auth().deleteUser(userRecord.uid);
    } catch (cleanupErr) {
      console.error(
        `superUserCreateAccount: fallo al hacer rollback del usuario Auth huerfano ${userRecord.uid}:`,
        cleanupErr
      );
    }
    throw new functions.https.HttpsError(
      'internal',
      'No se pudo completar el registro. Intenta de nuevo.'
    );
  }

  return { idUsuario: userRecord.uid, passwordTemporal: SUPERUSER_TEMP_PASSWORD };
});

/**
 * Elimina una cuenta de forma permanente (Auth + cascada de Firestore/
 * Storage vía el trigger onUserDelete existente). Exclusivo de Superusuario:
 * ni firestore.rules (isSuperUser() en el delete de 'usuarios') ni este
 * callable lo permiten a un Administrador. No se puede auto-eliminar ni
 * eliminar a otro Superusuario (evita que una cuenta comprometida borre a
 * las demás cuentas de máximo privilegio).
 */
exports.superUserDeleteAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }
  await assertSuperUser(context.auth.uid);

  const targetUid = data && data.uid ? String(data.uid) : '';
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'uid es requerido.');
  }
  if (targetUid === context.auth.uid) {
    throw new functions.https.HttpsError('failed-precondition', 'No puedes eliminar tu propia cuenta.');
  }

  const targetDoc = await db.collection('usuarios').doc(targetUid).get();
  if (targetDoc.exists && targetDoc.data().rol === 'Superusuario') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'No puedes eliminar la cuenta de otro Superusuario.'
    );
  }

  try {
    await admin.auth().deleteUser(targetUid);
  } catch (err) {
    if (err && err.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('not-found', 'La cuenta ya no existe.');
    }
    throw new functions.https.HttpsError('internal', err.message);
  }

  return { ok: true };
});

exports.publishTallerProfile = require('./src/publishTallerProfile').publishTallerProfile;
