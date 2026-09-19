import 'package:cloud_firestore/cloud_firestore.dart';

/// Invitación de un taller a una persona que YA tiene cuenta en AutoDoc para
/// que se una como empleada (`talleres/{idTaller}/invitaciones/{idInvitado}`,
/// observaciones del 2026-09-19).
///
/// Solo la escriben las Cloud Functions: `crearEmpleadoTaller` la crea y
/// `responderInvitacionEmpleo` la resuelve. El taller la lee para enseñar las
/// pendientes y la puede retirar.
class InvitacionEmpleoModel {
  final String idInvitado;
  final String idTaller;
  final String nombreCompleto;
  final String correo;
  final String rol;
  final DateTime? fechaCreacion;
  final DateTime? expira;

  const InvitacionEmpleoModel({
    required this.idInvitado,
    required this.idTaller,
    required this.nombreCompleto,
    required this.correo,
    required this.rol,
    this.fechaCreacion,
    this.expira,
  });

  bool caducada(DateTime ahora) => expira != null && !expira!.isAfter(ahora);

  factory InvitacionEmpleoModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? fecha(Object? v) => v is Timestamp
        ? v.toDate()
        : v is DateTime
        ? v
        : null;
    return InvitacionEmpleoModel(
      idInvitado: id,
      idTaller: (map['id_taller'] ?? '').toString(),
      nombreCompleto: (map['nombre_completo'] ?? '').toString(),
      correo: (map['correo'] ?? '').toString(),
      rol: (map['rol'] as String?) ?? 'Mecanico',
      fechaCreacion: fecha(map['fecha_creacion']),
      expira: fecha(map['expira']),
    );
  }
}
