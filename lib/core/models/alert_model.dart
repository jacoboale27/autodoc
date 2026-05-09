import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertPriority { high, medium, low }

class AlertModel {
  final String idAlerta;
  final String idVehiculo;
  final String tipoAlerta; // 'Aceite', 'SOAT', 'Llantas', 'Fluidos', 'Luces', 'Bateria'
  final String titulo;
  final String descripcion;
  final DateTime? fechaLimite;
  final int? kilometrajeObjetivo;
  final String estado; // 'Pendiente', 'Completada', 'Vencida'
  final AlertPriority prioridad;
  final Map<String, dynamic>? metadata; // Para guardar PSI, etc.

  AlertModel({
    required this.idAlerta,
    required this.idVehiculo,
    required this.tipoAlerta,
    required this.titulo,
    required this.descripcion,
    this.fechaLimite,
    this.kilometrajeObjetivo,
    this.estado = 'Pendiente',
    this.prioridad = AlertPriority.medium,
    this.metadata,
  });

  AlertModel copyWith({
    String? idAlerta,
    String? idVehiculo,
    String? tipoAlerta,
    String? titulo,
    String? descripcion,
    DateTime? fechaLimite,
    int? kilometrajeObjetivo,
    String? estado,
    AlertPriority? prioridad,
    Map<String, dynamic>? metadata,
  }) {
    return AlertModel(
      idAlerta: idAlerta ?? this.idAlerta,
      idVehiculo: idVehiculo ?? this.idVehiculo,
      tipoAlerta: tipoAlerta ?? this.tipoAlerta,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      fechaLimite: fechaLimite ?? this.fechaLimite,
      kilometrajeObjetivo: kilometrajeObjetivo ?? this.kilometrajeObjetivo,
      estado: estado ?? this.estado,
      prioridad: prioridad ?? this.prioridad,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_alerta': idAlerta,
      'id_vehiculo': idVehiculo,
      'tipo_alerta': tipoAlerta,
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha_limite': fechaLimite != null ? Timestamp.fromDate(fechaLimite!) : null,
      'kilometraje_objetivo': kilometrajeObjetivo,
      'estado': estado,
      'prioridad': prioridad.name,
      'metadata': metadata,
    };
  }

  factory AlertModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AlertModel(
      idAlerta: map['id_alerta'] ?? documentId,
      idVehiculo: map['id_vehiculo'] ?? '',
      tipoAlerta: map['tipo_alerta'] ?? 'Mantenimiento',
      titulo: map['titulo'] ?? 'Alerta',
      descripcion: map['descripcion'] ?? '',
      fechaLimite: (map['fecha_limite'] as Timestamp?)?.toDate(),
      kilometrajeObjetivo: map['kilometraje_objetivo'],
      estado: map['estado'] ?? 'Pendiente',
      prioridad: AlertPriority.values.firstWhere(
        (e) => e.name == (map['prioridad'] ?? 'medium'),
        orElse: () => AlertPriority.medium,
      ),
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
    );
  }
}
