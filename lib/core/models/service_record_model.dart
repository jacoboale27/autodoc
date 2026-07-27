import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRecordModel {
  final String idServicio;
  final String idVehiculo;
  final String? idTaller;
  final String? tipoServicio;
  final DateTime fecha;
  final int? kilometrajeServicio;
  final double? costo;
  final String? fotoFacturaUrl;
  final String? descripcion;

  ServiceRecordModel({
    required this.idServicio,
    required this.idVehiculo,
    this.idTaller,
    this.tipoServicio,
    required this.fecha,
    this.kilometrajeServicio,
    this.costo,
    this.fotoFacturaUrl,
    this.descripcion,
  });

  ServiceRecordModel copyWith({
    String? idServicio,
    String? idVehiculo,
    String? idTaller,
    String? tipoServicio,
    DateTime? fecha,
    int? kilometrajeServicio,
    double? costo,
    String? fotoFacturaUrl,
    String? descripcion,
  }) {
    return ServiceRecordModel(
      idServicio: idServicio ?? this.idServicio,
      idVehiculo: idVehiculo ?? this.idVehiculo,
      idTaller: idTaller ?? this.idTaller,
      tipoServicio: tipoServicio ?? this.tipoServicio,
      fecha: fecha ?? this.fecha,
      kilometrajeServicio: kilometrajeServicio ?? this.kilometrajeServicio,
      costo: costo ?? this.costo,
      fotoFacturaUrl: fotoFacturaUrl ?? this.fotoFacturaUrl,
      descripcion: descripcion ?? this.descripcion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_servicio': idServicio,
      'id_vehiculo': idVehiculo,
      'id_taller': idTaller,
      'tipo_servicio': tipoServicio,
      'fecha': Timestamp.fromDate(fecha),
      'kilometraje_servicio': kilometrajeServicio,
      'costo': costo,
      'foto_factura_url': fotoFacturaUrl,
      'descripcion': descripcion,
    };
  }

  factory ServiceRecordModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ServiceRecordModel(
      idServicio: map['id_servicio'] ?? documentId,
      idVehiculo: map['id_vehiculo'] ?? '',
      idTaller: map['id_taller'],
      tipoServicio: map['tipo_servicio'],
      fecha: (map['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      kilometrajeServicio: map['kilometraje_servicio'],
      costo: map['costo']?.toDouble(),
      fotoFacturaUrl: map['foto_factura_url'],
      descripcion: map['descripcion'],
    );
  }
}
