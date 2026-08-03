import 'package:cloud_firestore/cloud_firestore.dart';

class ReservaModel {
  final String id;
  final String idConversacion;
  final String idPropietario;
  final String idMecanico;
  final String idVehiculo;
  final String idTaller;
  final DateTime fechaHoraPropuesta;
  final DateTime? fechaHoraConfirmada;
  final String tipoServicio;
  final String? descripcion;
  final String
  estado; // 'pendiente' | 'cotizada' | 'confirmada' | 'rechazada' | 'completada' | 'cancelada'
  final double? cotizacionEstimada;
  final bool recordatorioEnviado24h;
  final bool recordatorioEnviado1h;
  final DateTime fechaCreacion;

  ReservaModel({
    required this.id,
    required this.idConversacion,
    required this.idPropietario,
    required this.idMecanico,
    required this.idVehiculo,
    required this.idTaller,
    required this.fechaHoraPropuesta,
    this.fechaHoraConfirmada,
    required this.tipoServicio,
    this.descripcion,
    this.estado = 'pendiente',
    this.cotizacionEstimada,
    this.recordatorioEnviado24h = false,
    this.recordatorioEnviado1h = false,
    required this.fechaCreacion,
  });

  factory ReservaModel.fromMap(Map<String, dynamic> map, String id) {
    return ReservaModel(
      id: id,
      idConversacion: map['id_conversacion'] ?? '',
      idPropietario: map['id_propietario'] ?? '',
      idMecanico: map['id_mecanico'] ?? '',
      idVehiculo: map['id_vehiculo'] ?? '',
      idTaller: map['id_taller'] ?? '',
      fechaHoraPropuesta: (map['fecha_hora_propuesta'] as Timestamp).toDate(),
      fechaHoraConfirmada: (map['fecha_hora_confirmada'] as Timestamp?)
          ?.toDate(),
      tipoServicio: map['tipo_servicio'] ?? '',
      descripcion: map['descripcion'],
      estado: map['estado'] ?? 'pendiente',
      cotizacionEstimada: (map['cotizacion_estimada'] as num?)?.toDouble(),
      recordatorioEnviado24h: map['recordatorio_enviado_24h'] ?? false,
      recordatorioEnviado1h: map['recordatorio_enviado_1h'] ?? false,
      fechaCreacion:
          (map['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_conversacion': idConversacion,
      'id_propietario': idPropietario,
      'id_mecanico': idMecanico,
      'id_vehiculo': idVehiculo,
      'id_taller': idTaller,
      'fecha_hora_propuesta': Timestamp.fromDate(fechaHoraPropuesta),
      if (fechaHoraConfirmada != null)
        'fecha_hora_confirmada': Timestamp.fromDate(fechaHoraConfirmada!),
      'tipo_servicio': tipoServicio,
      if (descripcion != null) 'descripcion': descripcion,
      'estado': estado,
      if (cotizacionEstimada != null) 'cotizacion_estimada': cotizacionEstimada,
      'recordatorio_enviado_24h': recordatorioEnviado24h,
      'recordatorio_enviado_1h': recordatorioEnviado1h,
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    };
  }
}
