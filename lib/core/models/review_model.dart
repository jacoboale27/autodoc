import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String idResenia;
  final String idUsuario;
  final String idTaller;
  final int estrellas;
  final String? comentario;
  final DateTime fechaResenia;
  final bool isReported;

  ReviewModel({
    required this.idResenia,
    required this.idUsuario,
    required this.idTaller,
    required this.estrellas,
    this.comentario,
    required this.fechaResenia,
    this.isReported = false,
  });

  ReviewModel copyWith({
    String? idResenia,
    String? idUsuario,
    String? idTaller,
    int? estrellas,
    String? comentario,
    DateTime? fechaResenia,
    bool? isReported,
  }) {
    return ReviewModel(
      idResenia: idResenia ?? this.idResenia,
      idUsuario: idUsuario ?? this.idUsuario,
      idTaller: idTaller ?? this.idTaller,
      estrellas: estrellas ?? this.estrellas,
      comentario: comentario ?? this.comentario,
      fechaResenia: fechaResenia ?? this.fechaResenia,
      isReported: isReported ?? this.isReported,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_resenia': idResenia,
      'id_usuario': idUsuario,
      'id_taller': idTaller,
      'estrellas': estrellas,
      'comentario': comentario,
      'fecha_resenia': Timestamp.fromDate(fechaResenia),
      'is_reported': isReported,
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ReviewModel(
      idResenia: map['id_resenia'] ?? documentId,
      idUsuario: map['id_usuario'] ?? '',
      idTaller: map['id_taller'] ?? '',
      estrellas: map['estrellas'] ?? 5,
      comentario: map['comentario'],
      fechaResenia:
          (map['fecha_resenia'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isReported: map['is_reported'] ?? false,
    );
  }
}
