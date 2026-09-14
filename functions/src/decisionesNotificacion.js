'use strict';

const { esMigracion } = require('./migracion');

// Los handlers consultan primero el destinatario y despues aportan el token.
// Separar esa informacion permite conservar las salidas tempranas y el orden
// de las lecturas. push/centro expresan elegibilidad, no exito de la entrega.
function decidirAvisoKilometraje(antes, despues, { tarea = null, fcmToken = null } = {}) {
  if (despues.kilometraje_actual === antes.kilometraje_actual) return null;
  const targetId = despues.id_propietario;
  if (!targetId) return null;

  const decision = { targetId, push: false, centro: false, tipo: null, diff: null };
  if (!fcmToken || !tarea) return decision;
  const currentKm = despues.kilometraje_actual || 0;
  const ultimoKm = tarea.ultimo_km || 0;
  const frecuenciaKm = tarea.frecuencia_km || 0;
  if (frecuenciaKm > 0) {
    const diff = ultimoKm + frecuenciaKm - currentKm;
    decision.diff = diff;
    if (diff <= 500 && diff > 0) {
      decision.tipo = 'cercano';
    } else if (diff <= 0 && currentKm > ultimoKm) {
      decision.tipo = 'requerido';
    }
  }
  decision.push = decision.tipo !== null;
  decision.centro = decision.push;
  return decision;
}

function decidirSolicitudResenia(servicio, vehiculo = null, fcmToken = null) {
  const tallerId = servicio.id_taller;
  const consultarVehiculo = !!(tallerId && servicio.id_vehiculo && !tallerId.includes('Manual'));
  const decision = {
    consultarVehiculo, vehiculoExiste: false, targetId: null,
    yaVinculado: false, debeMarcarPendiente: false,
    push: false, centro: false, confirmacion: false,
  };
  if (!consultarVehiculo || !vehiculo) return decision;

  decision.vehiculoExiste = true;
  decision.yaVinculado = (vehiculo.talleres_vinculados || []).includes(tallerId);
  const pendienteActual = vehiculo.taller_pendiente_confirmacion || null;
  const haySolicitudDeOtroTaller = pendienteActual !== null && pendienteActual !== tallerId;
  const yaRechazado = (vehiculo.talleres_rechazados || []).includes(tallerId);
  decision.debeMarcarPendiente = !decision.yaVinculado && !haySolicitudDeOtroTaller && !yaRechazado;
  decision.targetId = vehiculo.id_propietario || null;
  decision.push = !!(decision.targetId && fcmToken);
  decision.centro = decision.push;
  decision.confirmacion = decision.push && decision.debeMarcarPendiente;
  return decision;
}

function decidirMensajeChat(mensaje, conversacion, fcmToken = null) {
  if (!conversacion) return null;
  let targetId;
  if (mensaje.id_remitente === conversacion.id_mecanico) {
    targetId = conversacion.id_propietario;
  } else if (mensaje.id_remitente === conversacion.id_propietario) {
    targetId = conversacion.id_mecanico;
  }
  if (!targetId) return null;
  return { targetId, push: !!fcmToken, centro: !!fcmToken };
}

function decidirNuevaReserva(reserva, fcmToken = null) {
  const targetId = reserva.id_mecanico;
  if (!targetId) return null;
  return { targetId, push: !!fcmToken, centro: !!fcmToken };
}

function decidirCambioReserva(antes, despues, fcmToken = null) {
  if (despues.estado === antes.estado) return null;
  const isAccepted = despues.estado === 'confirmada';
  const isRejected = despues.estado === 'rechazada';
  if (!isAccepted && !isRejected) return null;
  const recipientIds = [despues.id_propietario, despues.id_mecanico].filter(Boolean);
  return {
    isAccepted, recipientIds,
    push: recipientIds.length > 0 && !!fcmToken,
    centro: recipientIds.length > 0,
  };
}

function decidirCotizacionAceptada(abierto, fcmToken = null) {
  if (!abierto.id) return null;
  const targetId = (abierto.ticket && abierto.ticket.id_propietario) || null;
  return {
    id: abierto.id, targetId, leerTicket: !abierto.ticket,
    push: !!(targetId && fcmToken), centro: !!targetId,
  };
}

function decidirCambioReparacion(antes, despues, fcmToken = null) {
  if (antes.estado === despues.estado) return null;
  if (esMigracion(despues)) return null;
  const targetId = despues.id_propietario;
  if (!targetId) return null;
  return { targetId, push: !!fcmToken, centro: true };
}

module.exports = {
  decidirAvisoKilometraje,
  decidirSolicitudResenia,
  decidirMensajeChat,
  decidirNuevaReserva,
  decidirCambioReserva,
  decidirCotizacionAceptada,
  decidirCambioReparacion,
};
