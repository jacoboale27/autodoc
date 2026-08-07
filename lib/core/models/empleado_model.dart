import 'package:cloud_firestore/cloud_firestore.dart';

class EmpleadoModel {
  final String idEmpleado;
  final String idTallerPropietario;
  final String nombreCompleto;
  final String correo;
  final String? telefono;
  final String rol;
  final bool activo;
  final DateTime fechaCreacion;

  EmpleadoModel({
    required this.idEmpleado,
    required this.idTallerPropietario,
    required this.nombreCompleto,
    required this.correo,
    this.telefono,
    required this.rol,
    this.activo = true,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() => {
    'id_taller_propietario': idTallerPropietario,
    'nombre_completo': nombreCompleto,
    'correo': correo,
    if (telefono != null) 'telefono': telefono,
    'rol': rol,
    'activo': activo,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
  };

  factory EmpleadoModel.fromMap(Map<String, dynamic> map, String documentId) {
    return EmpleadoModel(
      idEmpleado: documentId,
      idTallerPropietario: (map['id_taller_propietario'] ?? '').toString(),
      nombreCompleto: (map['nombre_completo'] ?? '').toString(),
      correo: (map['correo'] ?? '').toString(),
      telefono: map['telefono']?.toString(),
      rol: (map['rol'] as String?) ?? 'Mecanico',
      activo: map['activo'] as bool? ?? true,
      fechaCreacion:
          (map['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
