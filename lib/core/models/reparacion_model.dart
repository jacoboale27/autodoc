import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> estadosReparacion = [
  'recibido',
  'en_revision',
  'esperando_repuestos',
  'listo_para_entrega',
];

class ReparacionModel {
  final String idReparacion;
  final String idVehiculo;
  final String idTaller;
  final String idPropietario;
  final String placa;
  final String estado;
  final List<Map<String, dynamic>> historialEstados;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  ReparacionModel({
    required this.idReparacion,
    required this.idVehiculo,
    required this.idTaller,
    required this.idPropietario,
    required this.placa,
    this.estado = 'recibido',
    this.historialEstados = const [],
    required this.fechaCreacion,
    required this.fechaActualizacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_vehiculo': idVehiculo,
      'id_taller': idTaller,
      'id_propietario': idPropietario,
      'placa': placa,
      'estado': estado,
      'historial_estados': historialEstados
          .map(
            (h) => {
              'estado': h['estado'],
              'timestamp': h['timestamp'] is DateTime
                  ? Timestamp.fromDate(h['timestamp'] as DateTime)
                  : h['timestamp'],
            },
          )
          .toList(),
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      'fecha_actualizacion': Timestamp.fromDate(fechaActualizacion),
    };
  }

  factory ReparacionModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();

    return ReparacionModel(
      idReparacion: documentId,
      idVehiculo: (map['id_vehiculo'] ?? '').toString(),
      idTaller: (map['id_taller'] ?? '').toString(),
      idPropietario: (map['id_propietario'] ?? '').toString(),
      placa: (map['placa'] ?? '').toString(),
      estado: (map['estado'] ?? 'recibido').toString(),
      historialEstados: (map['historial_estados'] as List<dynamic>? ?? [])
          .map(
            (h) => {
              'estado': h['estado'],
              'timestamp': h['timestamp'] is Timestamp
                  ? (h['timestamp'] as Timestamp).toDate()
                  : h['timestamp'],
            },
          )
          .toList(),
      fechaCreacion: parseDate(map['fecha_creacion']),
      fechaActualizacion: parseDate(map['fecha_actualizacion']),
    );
  }
}
