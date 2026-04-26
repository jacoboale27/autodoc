import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String idAlerta;
  final String idVehiculo;
  final String? tipoAlerta;
  final DateTime fechaLimite;
  final String estado;

  AlertModel({
    required this.idAlerta,
    required this.idVehiculo,
    this.tipoAlerta,
    required this.fechaLimite,
    this.estado = 'Pendiente',
  });

  AlertModel copyWith({
    String? idAlerta,
    String? idVehiculo,
    String? tipoAlerta,
    DateTime? fechaLimite,
    String? estado,
  }) {
    return AlertModel(
      idAlerta: idAlerta ?? this.idAlerta,
      idVehiculo: idVehiculo ?? this.idVehiculo,
      tipoAlerta: tipoAlerta ?? this.tipoAlerta,
      fechaLimite: fechaLimite ?? this.fechaLimite,
      estado: estado ?? this.estado,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_alerta': idAlerta,
      'id_vehiculo': idVehiculo,
      'tipo_alerta': tipoAlerta,
      'fecha_limite': Timestamp.fromDate(fechaLimite),
      'estado': estado,
    };
  }

  factory AlertModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AlertModel(
      idAlerta: map['id_alerta'] ?? documentId,
      idVehiculo: map['id_vehiculo'] ?? '',
      tipoAlerta: map['tipo_alerta'],
      fechaLimite: (map['fecha_limite'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estado: map['estado'] ?? 'Pendiente',
    );
  }
}
