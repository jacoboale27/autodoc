import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String idUsuario;
  final String nombreCompleto;
  final String correo;
  final String rol;
  final DateTime fechaRegistro;

  UserModel({
    required this.idUsuario,
    required this.nombreCompleto,
    required this.correo,
    required this.rol,
    required this.fechaRegistro,
  });

  UserModel copyWith({
    String? idUsuario,
    String? nombreCompleto,
    String? correo,
    String? rol,
    DateTime? fechaRegistro,
  }) {
    return UserModel(
      idUsuario: idUsuario ?? this.idUsuario,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      correo: correo ?? this.correo,
      rol: rol ?? this.rol,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'nombre_completo': nombreCompleto,
      'correo': correo,
      'rol': rol,
      'fecha_registro': Timestamp.fromDate(fechaRegistro),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      idUsuario: map['id_usuario'] ?? documentId,
      nombreCompleto: map['nombre_completo'] ?? '',
      correo: map['correo'] ?? '',
      rol: map['rol'] ?? 'Propietario',
      fechaRegistro: (map['fecha_registro'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
