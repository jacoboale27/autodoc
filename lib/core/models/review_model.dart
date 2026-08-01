import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String idResenia;
  final String idUsuario;
  final String idTaller;
  final String idServicio;
  final int estrellas;
  final String? comentario;
  final DateTime fechaResenia;
  final bool isReported;
  final List<String> fotos;
  final Map<String, dynamic>? respuestaTaller;

  ReviewModel({
    required this.idResenia,
    required this.idUsuario,
    required this.idTaller,
    required this.idServicio,
    required this.estrellas,
    this.comentario,
    required this.fechaResenia,
    this.isReported = false,
    this.fotos = const [],
    this.respuestaTaller,
  });

  ReviewModel copyWith({
    String? idResenia,
    String? idUsuario,
    String? idTaller,
    String? idServicio,
    int? estrellas,
    String? comentario,
    DateTime? fechaResenia,
    bool? isReported,
    List<String>? fotos,
    Map<String, dynamic>? respuestaTaller,
  }) {
    return ReviewModel(
      idResenia: idResenia ?? this.idResenia,
      idUsuario: idUsuario ?? this.idUsuario,
      idTaller: idTaller ?? this.idTaller,
      idServicio: idServicio ?? this.idServicio,
      estrellas: estrellas ?? this.estrellas,
      comentario: comentario ?? this.comentario,
      fechaResenia: fechaResenia ?? this.fechaResenia,
      isReported: isReported ?? this.isReported,
      fotos: fotos ?? this.fotos,
      respuestaTaller: respuestaTaller ?? this.respuestaTaller,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_resenia': idResenia,
      'id_usuario': idUsuario,
      'id_taller': idTaller,
      'id_servicio': idServicio,
      'estrellas': estrellas,
      'comentario': comentario,
      'fecha_resenia': Timestamp.fromDate(fechaResenia),
      'is_reported': isReported,
      'fotos': fotos,
      if (respuestaTaller != null)
        'respuesta_taller': {
          'texto': respuestaTaller!['texto'],
          'fecha': respuestaTaller!['fecha'] is DateTime
              ? Timestamp.fromDate(respuestaTaller!['fecha'] as DateTime)
              : respuestaTaller!['fecha'],
        },
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, String documentId) {
    Map<String, dynamic>? parseRespuesta(dynamic v) {
      if (v is! Map) return null;
      final fecha = v['fecha'];
      return {
        'texto': (v['texto'] ?? '').toString(),
        'fecha': fecha is Timestamp ? fecha.toDate() : fecha,
      };
    }

    return ReviewModel(
      idResenia: map['id_resenia'] ?? documentId,
      idUsuario: map['id_usuario'] ?? '',
      idTaller: map['id_taller'] ?? '',
      idServicio: map['id_servicio'] ?? '',
      estrellas: map['estrellas'] ?? 5,
      comentario: map['comentario'],
      fechaResenia:
          (map['fecha_resenia'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isReported: map['is_reported'] ?? false,
      fotos: (map['fotos'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      respuestaTaller: parseRespuesta(map['respuesta_taller']),
    );
  }
}
