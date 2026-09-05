import 'package:cloud_firestore/cloud_firestore.dart';

class ConversacionModel {
  final String id;
  final String idPropietario;
  final String idMecanico;
  final String nombrePropietario;
  final String nombreMecanico;
  final String? idTaller;
  final String? idVehiculo;
  final String ultimoMensaje;
  final DateTime ultimoMensajeTs;
  final int noLeidosPropietario;
  final int noLeidosMecanico;
  final String estado;
  final String? typingId;

  /// Fotos de perfil denormalizadas al crear la conversación (ver C1,
  /// `.superpowers/sdd/2026-09-04-observaciones-colaboradores/task-9-brief.md`).
  /// Nulas en cualquier conversación creada antes de este cambio — la lista
  /// las lee con `data['foto_mecanico'] as String?` y `AppUserAvatar` cae a
  /// la inicial del nombre cuando no hay URL, así que un documento viejo
  /// sigue renderizando sin romperse.
  final String? fotoPropietario;
  final String? fotoMecanico;

  ConversacionModel({
    required this.id,
    required this.idPropietario,
    required this.idMecanico,
    required this.nombrePropietario,
    required this.nombreMecanico,
    this.idTaller,
    this.idVehiculo,
    required this.ultimoMensaje,
    required this.ultimoMensajeTs,
    this.noLeidosPropietario = 0,
    this.noLeidosMecanico = 0,
    this.estado = 'activo',
    this.typingId,
    this.fotoPropietario,
    this.fotoMecanico,
  });

  factory ConversacionModel.fromMap(Map<String, dynamic> map, String id) {
    return ConversacionModel(
      id: id,
      idPropietario: map['id_propietario'] ?? '',
      idMecanico: map['id_mecanico'] ?? '',
      nombrePropietario: map['nombre_propietario'] ?? 'Propietario',
      nombreMecanico: map['nombre_mecanico'] ?? 'Mecánico',
      idTaller: map['id_taller'],
      idVehiculo: map['id_vehiculo'],
      ultimoMensaje: map['ultimo_mensaje'] ?? '',
      ultimoMensajeTs:
          (map['ultimo_mensaje_ts'] as Timestamp?)?.toDate() ?? DateTime.now(),
      noLeidosPropietario: map['no_leidos_propietario'] ?? 0,
      noLeidosMecanico: map['no_leidos_mecanico'] ?? 0,
      estado: map['estado'] ?? 'activo',
      typingId: map['typing_id'],
      fotoPropietario: map['foto_propietario'] as String?,
      fotoMecanico: map['foto_mecanico'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_propietario': idPropietario,
      'id_mecanico': idMecanico,
      'nombre_propietario': nombrePropietario,
      'nombre_mecanico': nombreMecanico,
      if (idTaller != null) 'id_taller': idTaller,
      if (idVehiculo != null) 'id_vehiculo': idVehiculo,
      'ultimo_mensaje': ultimoMensaje,
      'ultimo_mensaje_ts': Timestamp.fromDate(ultimoMensajeTs),
      'no_leidos_propietario': noLeidosPropietario,
      'no_leidos_mecanico': noLeidosMecanico,
      'estado': estado,
      'typing_id': typingId,
      if (fotoPropietario != null) 'foto_propietario': fotoPropietario,
      if (fotoMecanico != null) 'foto_mecanico': fotoMecanico,
    };
  }
}
