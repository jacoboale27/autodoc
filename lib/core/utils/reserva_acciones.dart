/// Modelo y lógica pura de decisiones sobre acciones disponibles en una reserva.
///
/// Implementa el invariante del hallazgo #4:
/// "Quien propone la fecha vigente no la resuelve (no acepta, no rechaza, ni reprograma sobre sí mismo)".
/// Las cancelaciones dejan rastro con sufijo por rol (`cancelada_por_propietario` / `cancelada_por_taller`).
class ReservaAccionesDisponibles {
  final bool puedeAceptar;
  final bool puedeCotizarYAceptar;
  final bool puedeReprogramar;
  final bool puedeRechazar;
  final bool puedeCancelar;

  const ReservaAccionesDisponibles({
    this.puedeAceptar = false,
    this.puedeCotizarYAceptar = false,
    this.puedeReprogramar = false,
    this.puedeRechazar = false,
    this.puedeCancelar = false,
  });

  bool get tieneAcciones =>
      puedeAceptar ||
      puedeCotizarYAceptar ||
      puedeReprogramar ||
      puedeRechazar ||
      puedeCancelar;
}

/// Determina qué acciones puede realizar [currentUserId] sobre una reserva
/// según su [estado], el [idProponente] de la fecha vigente y si es mecánico.
ReservaAccionesDisponibles calcularAccionesReserva({
  required String estado,
  required String idProponente,
  required String currentUserId,
  required bool isMecanico,
}) {
  if (estado == 'pendiente') {
    final esProponente = currentUserId == idProponente;
    if (!esProponente) {
      return ReservaAccionesDisponibles(
        puedeAceptar: !isMecanico,
        puedeCotizarYAceptar: isMecanico,
        puedeReprogramar: true,
        puedeRechazar: true,
        puedeCancelar: true,
      );
    } else {
      // El proponente no puede resolver su propia propuesta, pero sí puede
      // cancelar con aviso si ya no puede asistir o cometió un error.
      return const ReservaAccionesDisponibles(puedeCancelar: true);
    }
  }

  if (estado == 'confirmada') {
    return const ReservaAccionesDisponibles(puedeCancelar: true);
  }

  // Estados terminales ('rechazada', 'completada', 'cancelada', 'cancelada_por_*')
  return const ReservaAccionesDisponibles();
}

/// Retorna el estado de cancelación correspondiente según el rol del usuario que cancela.
String estadoCancelacionSegunRol({required bool isMecanico}) {
  return isMecanico ? 'cancelada_por_taller' : 'cancelada_por_propietario';
}
