const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

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
          } else if (diff <= 0 && currentKm > ultimoKm) {
            // Exceeded
            await messaging.send({
              token: fcmToken,
              notification: {
                title: 'Mantenimiento Requerido',
                body: `Tu vehículo ${newValue.placa} ya superó el kilometraje para ${task.nombre || 'el servicio'}.`
              }
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
      
    } catch (error) {
      console.error('Error sending chat notification:', error);
    }
  });

/**
 * 5. Firestore trigger when a reservation status changes.
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
