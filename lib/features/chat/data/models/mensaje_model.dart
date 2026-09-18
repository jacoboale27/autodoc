import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'mensaje_model.g.dart';

/// Cuántos mensajes trae un hilo como mucho.
///
/// Gap 9.3 de `GAPS-FUNC-02-cierre-de-residuales.md`: `streamMensajes` traía
/// el hilo ENTERO en cada apertura del chat, sin techo, y un hilo solo crece.
///
/// El recorte va por el FINAL —los [maxMensajesHilo] más recientes— y no por
/// el principio: un hilo al que le falta lo último dicho es peor que uno
/// lento. La consulta ya venía ordenada `timestamp DESC`, así que el `limit`
/// cae del lado correcto por construcción.
///
/// Llegar al tope se anuncia ([ChatProvider.hiloTruncado]).
const int maxMensajesHilo = 200;

/// Cuántos mensajes se marcan como vistos por lote (gap 7.1).
///
/// `marcarComoLeidos` leía el hilo ENTERO y metía todas las escrituras en un
/// solo `WriteBatch`. Un batch de Firestore admite **500 operaciones**: con más
/// de 499 mensajes del otro participante el `commit()` falla entero, y con él
/// se queda sin resetear el contador de no leídos — la conversación arrastra su
/// globo rojo para siempre y cada apertura reintenta el mismo batch imposible.
///
/// 400 y no 499 para dejar sitio holgado al reseteo del contador, que viaja en
/// el primer lote, y por el mismo margen que usa `TAM_LOTE` en
/// `functions/backfill_entregado.js`.
const int maxMensajesPorLoteDeLectura = 400;

/// Estado de un mensaje que el receptor ya vio (el doble check).
///
/// Vive aquí y no como literal suelto porque `ChatRepository.marcarComoLeidos`
/// lo usa en los DOS lados de la misma operación —el filtro de la consulta y
/// el valor que escribe—, y si esos dos se separaran el bucle dejaría de
/// converger: marcaría una y otra vez los mismos documentos.
const String kEstadoMensajeVisto = 'visto';

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

  /// Marca "editado" (Tarea 11b, C4): true si el autor cambió `contenido`
  /// tras enviarlo. Los mensajes ya existentes en producción no traen este
  /// campo — `fromMap` lo lee tolerante (`?? false`), igual que `isDeleted`.
  @HiveField(10)
  final bool editado;

  /// Mensaje al que este responde (observaciones del 2026-09-18: "responder"
  /// en el menú del mensaje). Copia lo justo para pintar la cita sin otra
  /// lectura: `id`, `id_remitente`, `tipo` y un extracto de `contenido`. Es
  /// una copia a propósito: si el original se borra o se edita después, la
  /// respuesta sigue diciendo a qué contestaba.
  @HiveField(11)
  final Map<String, dynamic>? respuestaA;

  /// El mensaje se reenvió desde otra conversación ("reenviar" en el menú).
  @HiveField(12)
  final bool reenviado;

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
    this.editado = false,
    this.respuestaA,
    this.reenviado = false,
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
      editado: map['editado'] ?? false,
      respuestaA: map['respuesta_a'] is Map
          ? Map<String, dynamic>.from(map['respuesta_a'] as Map)
          : null,
      reenviado: map['reenviado'] == true,
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
      'editado': editado,
      if (respuestaA != null) 'respuesta_a': respuestaA,
      if (reenviado) 'reenviado': true,
    };
  }
}
