import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLogModel {
  final String idLog;
  final String adminUid;
  final String accion;
  final String modulo;
  final String referenciaId;
  final String detalle;
  final DateTime fecha;

  AdminLogModel({
    required this.idLog,
    required this.adminUid,
    required this.accion,
    required this.modulo,
    required this.referenciaId,
    required this.detalle,
    required this.fecha,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_log': idLog,
      'admin_uid': adminUid,
      'accion': accion,
      'modulo': modulo,
      'referencia_id': referenciaId,
      'detalle': detalle,
      'fecha': Timestamp.fromDate(fecha),
    };
  }

  factory AdminLogModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AdminLogModel(
      idLog: map['id_log'] ?? documentId,
      adminUid: map['admin_uid'] ?? '',
      accion: map['accion'] ?? '',
      modulo: map['modulo'] ?? '',
      referenciaId: map['referencia_id'] ?? '',
      detalle: map['detalle'] ?? '',
      fecha: (map['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
