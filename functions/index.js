const functions = require('firebase-functions');
const admin = require('firebase-admin');
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
 * 1. Scheduled function to check alerts (alertas) daily.
 * Notifies the user if an alert is expiring in 7 days or less, or already expired.
 */
exports.checkAlertsDaily = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const now = new Date();
  const futureDate = new Date();
  futureDate.setDate(now.getDate() + 7);

  try {
    const alertasSnapshot = await db.collection('alertas').where('estado', '==', 'Pendiente').get();
    
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

        const vehiculoDoc = await db.collection('vehiculos').doc(vehiculoId).get();
        if (!vehiculoDoc.exists) continue;

        const ownerId = vehiculoDoc.data().id_propietario;
        if (!ownerId) continue;

        const userDoc = await db.collection('usuarios').doc(ownerId).get();
        if (!userDoc.exists) continue;

        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) continue;

        const isExpired = fechaLimite < now;
        const title = isExpired ? '¡Alerta Vencida!' : 'Alerta por Vencer';
        const body = isExpired 
            ? `La alerta de ${alerta.tipo_alerta} para tu vehículo ${vehiculoDoc.data().placa} ya venció.`
            : `La alerta de ${alerta.tipo_alerta} para tu vehículo ${vehiculoDoc.data().placa} está por vencer.`;

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

      const ownerId = vehiculoDoc.data().id_propietario;
      if (!ownerId) return null;

      const userDoc = await db.collection('usuarios').doc(ownerId).get();
      const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

      if (!fcmToken) return null;

      const tallerDoc = await db.collection('usuarios').doc(tallerId).get();
      const tallerName = tallerDoc.exists ? (tallerDoc.data().nombre_completo || 'el taller') : 'el taller';

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

      // Persist in notification center
      await writeNotification(ownerId, {
        tipo: 'review',
        titulo: '¿Qué tal te fue en tu servicio?',
        body: `Tu vehículo ${vehiculoDoc.data().placa} fue atendido en ${tallerName}. Por favor, déjales una reseña.`,
        deepLink: '/workshop_directory',
        metadata: { tallerId, serviceId: context.params.serviceId },
      });
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

  try {
    const reservasSnapshot = await db.collection('reservas').where('estado', '==', 'aprobada').get();
    
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

    // 2. Delete all vehicles owned by the user
    const vehiculosSnapshot = await db.collection('vehiculos').where('id_propietario', '==', userId).get();
    
    for (const vehiculoDoc of vehiculosSnapshot.docs) {
      const vehiculoId = vehiculoDoc.id;
      
      // Delete alerts for this vehicle
      const alertasSnapshot = await db.collection('alertas').where('id_vehiculo', '==', vehiculoId).get();
      for (const alertaDoc of alertasSnapshot.docs) {
        await db.collection('alertas').doc(alertaDoc.id).delete();
      }

      // Delete services for this vehicle
      const serviciosSnapshot = await db.collection('servicios').where('id_vehiculo', '==', vehiculoId).get();
      for (const servicioDoc of serviciosSnapshot.docs) {
        await db.collection('servicios').doc(servicioDoc.id).delete();
      }

      // Finally, delete the vehicle
      await db.collection('vehiculos').doc(vehiculoId).delete();
      console.log(`Vehicle ${vehiculoId} and its related data deleted.`);
    }
    
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
    const batch = db.batch();

    // 1. Delete alerts
    const alertas = await db.collection('alertas').where('id_vehiculo', '==', vehicleId).get();
    alertas.docs.forEach(doc => batch.delete(doc.ref));

    // 2. Delete mantenimientos
    const mantenimientos = await db.collection('mantenimientos').where('id_vehiculo', '==', vehicleId).get();
    mantenimientos.docs.forEach(doc => batch.delete(doc.ref));

    // 3. Delete servicios
    const servicios = await db.collection('servicios').where('id_vehiculo', '==', vehicleId).get();
    servicios.docs.forEach(doc => batch.delete(doc.ref));

    // 4. Delete historial_mantenimientos
    const historial = await db.collection('historial_mantenimientos').where('id_vehiculo', '==', vehicleId).get();
    historial.docs.forEach(doc => batch.delete(doc.ref));

    await batch.commit();
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
