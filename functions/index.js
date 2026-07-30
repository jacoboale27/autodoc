const functions = require('firebase-functions');
const admin = require('firebase-admin');
const firestore = require('@google-cloud/firestore');
admin.initializeApp();

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
          body: `Has recibido una nueva solicitud de cita para el ${reserva.fecha_hora_propuesta ? new Date(reserva.fecha_hora_propuesta).toLocaleDateString() : 'día propuesto'}.`
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
        body: `Has recibido una nueva solicitud de cita para el ${reserva.fecha_hora_propuesta ? new Date(reserva.fecha_hora_propuesta).toLocaleDateString() : 'día propuesto'}.`,
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
      const isAccepted = newValue.estado === 'aprobada';
      const isRejected = newValue.estado === 'rechazada';
      
      if (!isAccepted && !isRejected) return null;

      const targetId = newValue.id_propietario;
      if (!targetId) return null;

      const userDoc = await db.collection('usuarios').doc(targetId).get();
      const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

      if (!fcmToken) return null;

      const title = isAccepted ? 'Reserva Confirmada' : 'Reserva Rechazada';
      const body = isAccepted 
        ? `Tu cita para el ${newValue.fecha} ha sido confirmada por el taller.`
        : `El taller no pudo confirmar tu cita para el ${newValue.fecha}.`;

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

      // Persist in notification center
      await writeNotification(targetId, {
        tipo: 'reserva',
        titulo: title,
        body: body,
        deepLink: '/reserva_detail',
        metadata: { reservaId: context.params.reservaId },
      });
    } catch (error) {
      console.error('Error sending reservation notification:', error);
    }
  });

/**
 * 6. Scheduled function to send reservation reminders daily.
 * Notifies the owner and mechanic if they have an approved reservation for the next day.
 */
exports.sendReservationReminders = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const dateString = tomorrow.toISOString().split('T')[0]; // Assuming format 'YYYY-MM-DD'

  const limit = 500;
  let lastDoc = null;

  try {
    while (true) {
      let q = db.collection('reservas')
        .where('estado', '==', 'aprobada')
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(limit);
      if (lastDoc) {
        q = q.startAfter(lastDoc);
      }
      const reservasSnapshot = await q.get();
      if (reservasSnapshot.empty) break;

      for (const doc of reservasSnapshot.docs) {
        const reserva = doc.data();
        
        // Simple check to see if the date starts with tomorrow's date
        if (reserva.fecha && reserva.fecha.startsWith(dateString)) {
          
          // Notify Owner
          if (reserva.id_propietario) {
            const ownerDoc = await db.collection('usuarios').doc(reserva.id_propietario).get();
            if (ownerDoc.exists && ownerDoc.data().fcmToken) {
              await messaging.send({
                token: ownerDoc.data().fcmToken,
                notification: {
                  title: 'Recordatorio de Cita',
                  body: `Tienes una cita programada para mañana a las ${reserva.hora || 'la hora acordada'}.`
                }
              });
            }
          }

          // Notify Mechanic
          if (reserva.id_mecanico) {
            const mechanicDoc = await db.collection('usuarios').doc(reserva.id_mecanico).get();
            if (mechanicDoc.exists && mechanicDoc.data().fcmToken) {
              await messaging.send({
                token: mechanicDoc.data().fcmToken,
                notification: {
                  title: 'Recordatorio de Cita',
                  body: `Tienes una cita programada para mañana con el vehículo del cliente.`
                }
              });
            }
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
    const resenia = change.after.exists ? change.after.data() : change.before.data();
    const tallerId = resenia.id_taller;
    if (!tallerId) return null;

    const reseniasSnap = await db.collection('resenias').where('id_taller', '==', tallerId).get();
    let total = 0;
    let sum = 0;
    reseniasSnap.forEach(doc => {
      total++;
      sum += doc.data().estrellas || 0;
    });

    const avg = total > 0 ? sum / total : 0;
    await db.collection('usuarios').doc(tallerId).update({
      calificacion_promedio: avg,
      total_resenias: total
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

exports.publishTallerProfile = require('./src/publishTallerProfile').publishTallerProfile;
