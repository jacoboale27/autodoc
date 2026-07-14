import 'package:cloud_firestore/cloud_firestore.dart';

class MensajeModel {
  final String id;
  final String idRemitente;
  final String contenido;
  final String tipo; // 'texto' | 'imagen' | 'vehiculo_card' | 'reserva_card' | 'cotizacion_card'
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  final String estado; // 'enviado' | 'entregado' | 'visto'
  final String? urlArchivo;
  final bool isDeleted;

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
  });

  factory MensajeModel.fromMap(Map<String, dynamic> map, String id) {
    return MensajeModel(
      id: id,
      idRemitente: map['id_remitente'] ?? '',
      contenido: map['contenido'] ?? '',
      tipo: map['tipo'] ?? 'texto',
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estado: map['estado'] ?? 'enviado',
      urlArchivo: map['url_archivo'],
      isDeleted: map['is_deleted'] ?? false,
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
    };
  }
}
