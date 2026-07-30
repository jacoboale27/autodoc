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
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    final rawId = map['id_usuario'] ?? map['idUsuario'] ?? map['id'];
    final id = (rawId != null && rawId.toString().isNotEmpty)
        ? rawId.toString()
        : documentId;

    return UserModel(
      idUsuario: id,
      nombreCompleto:
          (map['nombre_completo'] ??
                  map['nombreCompleto'] ??
                  map['nombre'] ??
                  '')
              .toString(),
      correo: (map['correo'] ?? map['email'] ?? '').toString(),
      rol: (map['rol'] ?? map['role'] ?? 'Propietario').toString(),
      fechaRegistro: parseDate(map['fecha_registro'] ?? map['fechaRegistro']),
      talleresFavoritos: parseStringList(
        map['talleres_favoritos'] ?? map['talleresFavoritos'],
      ),
      fotoPerfilUrl:
          (map['foto_perfil_url'] ?? map['foto_url'] ?? map['fotoPerfilUrl'])
              ?.toString(),
      especialidad: map['especialidad']?.toString(),
      ubicacionMunicipio:
          (map['ubicacion_municipio'] ?? map['ubicacionMunicipio'])?.toString(),
      telefono: map['telefono']?.toString(),
      estado: (map['estado'] ?? 'activo').toString(),
      fcmToken: map['fcmToken']?.toString(),
      departamento: map['departamento']?.toString(),
      municipio: map['municipio']?.toString(),
      latitud: parseDouble(map['latitud']) ?? (map['ubicacion'] is GeoPoint ? (map['ubicacion'] as GeoPoint).latitude : null),
      longitud: parseDouble(map['longitud']) ?? (map['ubicacion'] is GeoPoint ? (map['ubicacion'] as GeoPoint).longitude : null),
    );
  }
}
