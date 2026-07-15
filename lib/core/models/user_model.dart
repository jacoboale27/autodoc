import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String idUsuario;
  final String nombreCompleto;
  final String correo;
  final String rol;
  final DateTime fechaRegistro;
  final List<String> talleresFavoritos;
  final String? fotoPerfilUrl;
  final String? especialidad;
  final String? ubicacionMunicipio;
  final String? telefono;
  final String estado;
  final String? fcmToken;
  final String? departamento;
  final String? municipio;
  final double? latitud;
  final double? longitud;

  UserModel({
    required this.idUsuario,
    required this.nombreCompleto,
    required this.correo,
    required this.rol,
    required this.fechaRegistro,
    this.talleresFavoritos = const [],
    this.fotoPerfilUrl,
    this.especialidad,
    this.ubicacionMunicipio,
    this.telefono,
    this.estado = 'activo',
    this.fcmToken,
    this.departamento,
    this.municipio,
    this.latitud,
    this.longitud,
  });

  UserModel copyWith({
    String? idUsuario,
    String? nombreCompleto,
    String? correo,
    String? rol,
    DateTime? fechaRegistro,
    List<String>? talleresFavoritos,
    String? fotoPerfilUrl,
    String? especialidad,
    String? ubicacionMunicipio,
    String? telefono,
    String? estado,
    String? fcmToken,
    String? departamento,
    String? municipio,
    double? latitud,
    double? longitud,
  }) {
    return UserModel(
      idUsuario: idUsuario ?? this.idUsuario,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      correo: correo ?? this.correo,
      rol: rol ?? this.rol,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      talleresFavoritos: talleresFavoritos ?? this.talleresFavoritos,
      fotoPerfilUrl: fotoPerfilUrl ?? this.fotoPerfilUrl,
      especialidad: especialidad ?? this.especialidad,
      ubicacionMunicipio: ubicacionMunicipio ?? this.ubicacionMunicipio,
      telefono: telefono ?? this.telefono,
      estado: estado ?? this.estado,
      fcmToken: fcmToken ?? this.fcmToken,
      departamento: departamento ?? this.departamento,
      municipio: municipio ?? this.municipio,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'nombre_completo': nombreCompleto,
      'correo': correo,
      'rol': rol,
      'fecha_registro': Timestamp.fromDate(fechaRegistro),
      'talleres_favoritos': talleresFavoritos,
      'foto_perfil_url': fotoPerfilUrl,
      if (especialidad != null) 'especialidad': especialidad,
      if (ubicacionMunicipio != null) 'ubicacion_municipio': ubicacionMunicipio,
      if (telefono != null) 'telefono': telefono,
      'estado': estado,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (departamento != null) 'departamento': departamento,
      if (municipio != null) 'municipio': municipio,
      if (latitud != null) 'latitud': latitud,
      if (longitud != null) 'longitud': longitud,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      idUsuario: map['id_usuario'] ?? documentId,
      nombreCompleto: map['nombre_completo'] ?? '',
      correo: map['correo'] ?? '',
      rol: map['rol'] ?? 'Propietario',
      fechaRegistro: (map['fecha_registro'] as Timestamp?)?.toDate() ?? DateTime.now(),
      talleresFavoritos: List<String>.from(map['talleres_favoritos'] ?? []),
      fotoPerfilUrl: map['foto_perfil_url'] ?? map['foto_url'],
      especialidad: map['especialidad'],
      ubicacionMunicipio: map['ubicacion_municipio'],
      telefono: map['telefono'],
      estado: map['estado'] ?? 'activo',
      fcmToken: map['fcmToken'],
      departamento: map['departamento'],
      municipio: map['municipio'],
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
    );
  }
}
