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

        const vehiculoDoc = await db.collection('Vehiculos').doc(vehiculoId).get();
        if (!vehiculoDoc.exists) continue;

        const ownerId = vehiculoDoc.data().id_propietario;
        if (!ownerId) continue;

        const userDoc = await db.collection('Usuarios').doc(ownerId).get();
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
  .document('Vehiculos/{vehicleId}')
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

      const userDoc = await db.collection('Usuarios').doc(ownerId).get();
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
      const vehiculoDoc = await db.collection('Vehiculos').doc(vehiculoId).get();
      if (!vehiculoDoc.exists) return null;

      const ownerId = vehiculoDoc.data().id_propietario;
      if (!ownerId) return null;

      const userDoc = await db.collection('Usuarios').doc(ownerId).get();
      const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

      if (!fcmToken) return null;

      const tallerDoc = await db.collection('Usuarios').doc(tallerId).get();
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
