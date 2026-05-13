import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String idUsuario;
  final String nombreCompleto;
  final String correo;
  final String rol;
  final DateTime fechaRegistro;
  final String? fotoPerfilUrl;
  final String? especialidad;
  final String? ubicacionMunicipio;
  final String? telefono;
  final String estado;

  UserModel({
    required this.idUsuario,
    required this.nombreCompleto,
    required this.correo,
    required this.rol,
    required this.fechaRegistro,
    this.fotoPerfilUrl,
    this.especialidad,
    this.ubicacionMunicipio,
    this.telefono,
    this.estado = 'activo',
  });

  UserModel copyWith({
    String? idUsuario,
    String? nombreCompleto,
    String? correo,
    String? rol,
    DateTime? fechaRegistro,
    String? fotoPerfilUrl,
    String? especialidad,
    String? ubicacionMunicipio,
    String? telefono,
    String? estado,
  }) {
    return UserModel(
      idUsuario: idUsuario ?? this.idUsuario,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      correo: correo ?? this.correo,
      rol: rol ?? this.rol,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      fotoPerfilUrl: fotoPerfilUrl ?? this.fotoPerfilUrl,
      especialidad: especialidad ?? this.especialidad,
      ubicacionMunicipio: ubicacionMunicipio ?? this.ubicacionMunicipio,
      telefono: telefono ?? this.telefono,
      estado: estado ?? this.estado,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'nombre_completo': nombreCompleto,
      'correo': correo,
      'rol': rol,
      'fecha_registro': Timestamp.fromDate(fechaRegistro),
      'foto_perfil_url': fotoPerfilUrl,
      if (especialidad != null) 'especialidad': especialidad,
      if (ubicacionMunicipio != null) 'ubicacion_municipio': ubicacionMunicipio,
      if (telefono != null) 'telefono': telefono,
      'estado': estado,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      idUsuario: map['id_usuario'] ?? documentId,
      nombreCompleto: map['nombre_completo'] ?? '',
      correo: map['correo'] ?? '',
      rol: map['rol'] ?? 'Propietario',
      fechaRegistro: (map['fecha_registro'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fotoPerfilUrl: map['foto_perfil_url'] ?? map['foto_url'],
      especialidad: map['especialidad'],
      ubicacionMunicipio: map['ubicacion_municipio'],
      telefono: map['telefono'],
      estado: map['estado'] ?? 'activo',
    );
  }
}
