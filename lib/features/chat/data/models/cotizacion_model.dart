import 'package:cloud_firestore/cloud_firestore.dart';

class CotizacionModel {
  final String id;
  final String idPropietario;
  final String idMecanico;
  final String? idVehiculo;
  final String? idTaller;
  final String descripcion;
  final double total;
  final String estado; // 'pendiente', 'aceptada', 'rechazada'
  final DateTime fecha;
  final double? manoDeObra;
  final List<Map<String, dynamic>>? materiales;

  CotizacionModel({
    required this.id,
    required this.idPropietario,
    required this.idMecanico,
    this.idVehiculo,
    this.idTaller,
    required this.descripcion,
    required this.total,
    this.estado = 'pendiente',
    required this.fecha,
    this.manoDeObra,
    this.materiales,
  });

  factory CotizacionModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CotizacionModel(
      id: documentId,
      idPropietario: map['id_propietario'] ?? '',
      idMecanico: map['id_mecanico'] ?? '',
      idVehiculo: map['id_vehiculo'],
      idTaller: map['id_taller'],
      descripcion: map['descripcion'] ?? '',
      total: (map['total'] ?? 0.0).toDouble(),
      estado: map['estado'] ?? 'pendiente',
      fecha: (map['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      manoDeObra: map['mano_de_obra']?.toDouble(),
      materiales: map['materiales'] != null
          ? List<Map<String, dynamic>>.from(map['materiales'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_propietario': idPropietario,
      'id_mecanico': idMecanico,
      if (idVehiculo != null) 'id_vehiculo': idVehiculo,
      if (idTaller != null) 'id_taller': idTaller,
      'descripcion': descripcion,
      'total': total,
      'estado': estado,
      'fecha': Timestamp.fromDate(fecha),
      if (manoDeObra != null) 'mano_de_obra': manoDeObra,
      if (materiales != null) 'materiales': materiales,
    };
  }
}
