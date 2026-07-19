import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for in-app notifications stored in
/// `notificaciones/{userId}/items/{notifId}`
class AppNotification {
  final String id;
  final String tipo; // 'alerta', 'chat', 'reserva', 'review', 'sistema'
  final String titulo;
  final String body;
  final bool leida;
  final String? deepLink; // e.g. '/chat/abc123', '/alerts', '/reserva_detail'
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const AppNotification({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.body,
    this.leida = false,
    this.deepLink,
    required this.timestamp,
    this.metadata,
  });

  factory AppNotification.fromMap(Map<String, dynamic> data, String id) {
    return AppNotification(
      id: id,
      tipo: data['tipo'] ?? 'sistema',
      titulo: data['titulo'] ?? '',
      body: data['body'] ?? '',
      leida: data['leida'] ?? false,
      deepLink: data['deepLink'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification.fromMap(data, doc.id);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tipo': tipo,
      'titulo': titulo,
      'body': body,
      'leida': leida,
      'deepLink': deepLink,
      'timestamp': Timestamp.fromDate(timestamp),
      if (metadata != null) 'metadata': metadata,
    };
  }

  AppNotification copyWith({
    String? id,
    String? tipo,
    String? titulo,
    String? body,
    bool? leida,
    String? deepLink,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      titulo: titulo ?? this.titulo,
      body: body ?? this.body,
      leida: leida ?? this.leida,
      deepLink: deepLink ?? this.deepLink,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}
