import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'mensaje_model.g.dart';

@HiveType(typeId: 0)
class MensajeModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String idRemitente;

  @HiveField(2)
  final String contenido;

  @HiveField(3)
  final String tipo; // 'texto' | 'imagen' | 'vehiculo_card' | 'reserva_card' | 'cotizacion_card'

  @HiveField(4)
  final Map<String, dynamic>? metadata;

  @HiveField(5)
  final DateTime timestamp;

  @HiveField(6)
  final String estado; // 'enviado' | 'entregado' | 'visto'

  @HiveField(7)
  final String? urlArchivo;

  @HiveField(8)
  final bool isDeleted;

  @HiveField(9)
  final int? duracionSegundos;

  MensajeModel({
    required this.id,
    required this.idRemitente,
    required this.contenido,
    this.tipo = 'texto',
    this.metadata,
    required this.timestamp,
    this.estado = 'enviado',
    this.urlArchivo,
    this.isDeleted = false,
    this.duracionSegundos,
  });

  factory MensajeModel.fromMap(Map<String, dynamic> map, String id) {
    return MensajeModel(
      id: id,
      idRemitente: map['id_remitente'] ?? '',
      contenido: map['contenido'] ?? '',
      tipo: map['tipo'] ?? 'texto',
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estado: map['estado'] ?? 'enviado',
      urlArchivo: map['url_archivo'],
      isDeleted: map['is_deleted'] ?? false,
      duracionSegundos: (map['duracion_segundos'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_remitente': idRemitente,
      'contenido': contenido,
      'tipo': tipo,
      if (metadata != null) 'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
      'estado': estado,
      if (urlArchivo != null) 'url_archivo': urlArchivo,
      'is_deleted': isDeleted,
      if (duracionSegundos != null) 'duracion_segundos': duracionSegundos,
    };
  }
}
