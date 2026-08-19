import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String idUsuario;
  final String nombreCompleto;
  final String correo;
  final String rol;
  final DateTime fechaRegistro;
  final DateTime? fechaNacimiento;
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
  final double calificacionPromedio;
  final int totalResenias;

  /// Uid del taller dueño cuando esta cuenta es una sub-cuenta de empleado
  /// (`crearEmpleadoTaller` la fija en `usuarios/{uid}.id_taller_propietario`,
  /// solo via Admin SDK). `null`/vacío significa cuenta dueña real (o
  /// cualquier otro rol): distingue una sub-cuenta de empleado de su taller
  /// dueño aunque ambas compartan `rol == 'Taller'`.
  final String? idTallerPropietario;

  /// Uid del taller "efectivo" bajo el que debe operar esta cuenta en todo
  /// el panel mecánico (Kanban de reparaciones, catálogo, etc.): el del
  /// dueño real (`idTallerPropietario`) si esta cuenta es una sub-cuenta de
  /// empleado, o el propio `idUsuario` si es el dueño (o cualquier otro
  /// rol). Centraliza el `?? idUsuario` que, antes de este fix, cada
  /// pantalla/provider del panel mecánico repetía usando `idUsuario`
  /// directamente — lo que hacía que los datos de un empleado quedaran
  /// aislados bajo su propio uid en vez de bajo el taller real.
  String get idTallerEfectivo {
    final propietario = idTallerPropietario;
    return (propietario != null && propietario.isNotEmpty)
        ? propietario
        : idUsuario;
  }

  /// El nivel de rol más alto en AutoDoc, por encima de 'Administrador':
  /// puede crear cuentas de Administrador/Superusuario y eliminar cuentas
  /// de forma permanente (ver superUserCreateAccount/superUserDeleteAccount
  /// en functions/index.js y las reglas isSuperUser() en firestore.rules).
  bool get isSuperUser => rol == 'Superusuario';

  UserModel({
    required this.idUsuario,
    required this.nombreCompleto,
    required this.correo,
    required this.rol,
    required this.fechaRegistro,
    this.fechaNacimiento,
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
    this.calificacionPromedio = 0.0,
    this.totalResenias = 0,
    this.idTallerPropietario,
  });

  UserModel copyWith({
    String? idUsuario,
    String? nombreCompleto,
    String? correo,
    String? rol,
    DateTime? fechaRegistro,
    DateTime? fechaNacimiento,
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
    double? calificacionPromedio,
    int? totalResenias,
    String? idTallerPropietario,
  }) {
    return UserModel(
      idUsuario: idUsuario ?? this.idUsuario,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      correo: correo ?? this.correo,
      rol: rol ?? this.rol,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
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
      calificacionPromedio: calificacionPromedio ?? this.calificacionPromedio,
      totalResenias: totalResenias ?? this.totalResenias,
      idTallerPropietario: idTallerPropietario ?? this.idTallerPropietario,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'nombre_completo': nombreCompleto,
      'correo': correo,
      'rol': rol,
      'fecha_registro': Timestamp.fromDate(fechaRegistro),
      if (fechaNacimiento != null)
        'fecha_nacimiento': Timestamp.fromDate(fechaNacimiento!),
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
      'calificacion_promedio': calificacionPromedio,
      'total_resenias': totalResenias,
      if (idTallerPropietario != null)
        'id_taller_propietario': idTallerPropietario,
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

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      return parseDate(val);
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
      fechaNacimiento: parseNullableDate(
        map['fecha_nacimiento'] ?? map['fechaNacimiento'],
      ),
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
      estado: (map['estado'] ?? 'pendiente').toString(),
      fcmToken: map['fcmToken']?.toString(),
      departamento: map['departamento']?.toString(),
      municipio: map['municipio']?.toString(),
      latitud:
          parseDouble(map['latitud']) ??
          (map['ubicacion'] is GeoPoint
              ? (map['ubicacion'] as GeoPoint).latitude
              : null),
      longitud:
          parseDouble(map['longitud']) ??
          (map['ubicacion'] is GeoPoint
              ? (map['ubicacion'] as GeoPoint).longitude
              : null),
      calificacionPromedio: parseDouble(map['calificacion_promedio']) ?? 0.0,
      totalResenias: (map['total_resenias'] as num?)?.toInt() ?? 0,
      idTallerPropietario: (map['id_taller_propietario'])?.toString(),
    );
  }
}
