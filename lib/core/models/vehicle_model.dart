import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleModel {
  final String idVehiculo;
  final String idPropietario;
  final String placa;
  final String? marca;
  final String? modelo;
  final int? anio;
  final String? color;
  final int kilometrajeActual;
  final DateTime? vencimientoTarjeta;
  final DateTime? vencimientoSoat;
  final String? fotoUrl;
  final bool isPrimary;
  final List<String> sharedWith; // UIDs de usuarios con acceso
  final List<String> notas;
  final List<String> talleresVinculados;
  final String? tallerPendienteConfirmacion;
  // Datos denormalizados de la solicitud pendiente (cierre C-1 de la
  // revision adversarial): permiten que el banner de confirmacion muestre
  // QUIEN pide acceso, en vez de un texto generico indistinguible de un
  // intento de secuestro. Los escribe unicamente el trigger de Cloud
  // Functions (ver functions/index.js), nunca el cliente.
  final String? tallerPendienteNombre;
  final String? tallerPendienteServicioId;
  // Talleres que el propietario ya rechazo explicitamente para este
  // vehiculo (cierre I-1): el trigger no debe volver a marcarlos como
  // pendientes, para cerrar el reintento gratis.
  final List<String> talleresRechazados;

  VehicleModel({
    required this.idVehiculo,
    required this.idPropietario,
    required this.placa,
    this.marca,
    this.modelo,
    this.anio,
    this.color,
    this.kilometrajeActual = 0,
    this.vencimientoTarjeta,
    this.vencimientoSoat,
    this.fotoUrl,
    this.isPrimary = false,
    this.sharedWith = const [],
    this.notas = const [],
    this.talleresVinculados = const [],
    this.tallerPendienteConfirmacion,
    this.tallerPendienteNombre,
    this.tallerPendienteServicioId,
    this.talleresRechazados = const [],
  });

  VehicleModel copyWith({
    String? idVehiculo,
    String? idPropietario,
    String? placa,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
    int? kilometrajeActual,
    DateTime? vencimientoTarjeta,
    DateTime? vencimientoSoat,
    String? fotoUrl,
    bool? isPrimary,
    List<String>? sharedWith,
    List<String>? notas,
    List<String>? talleresVinculados,
    String? tallerPendienteConfirmacion,
    String? tallerPendienteNombre,
    String? tallerPendienteServicioId,
    List<String>? talleresRechazados,
  }) {
    return VehicleModel(
      idVehiculo: idVehiculo ?? this.idVehiculo,
      idPropietario: idPropietario ?? this.idPropietario,
      placa: placa ?? this.placa,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      anio: anio ?? this.anio,
      color: color ?? this.color,
      kilometrajeActual: kilometrajeActual ?? this.kilometrajeActual,
      vencimientoTarjeta: vencimientoTarjeta ?? this.vencimientoTarjeta,
      vencimientoSoat: vencimientoSoat ?? this.vencimientoSoat,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      isPrimary: isPrimary ?? this.isPrimary,
      sharedWith: sharedWith ?? this.sharedWith,
      notas: notas ?? this.notas,
      talleresVinculados: talleresVinculados ?? this.talleresVinculados,
      tallerPendienteConfirmacion:
          tallerPendienteConfirmacion ?? this.tallerPendienteConfirmacion,
      tallerPendienteNombre:
          tallerPendienteNombre ?? this.tallerPendienteNombre,
      tallerPendienteServicioId:
          tallerPendienteServicioId ?? this.tallerPendienteServicioId,
      talleresRechazados: talleresRechazados ?? this.talleresRechazados,
    );
  }

  // NOTA (cierre I-2 de la revision adversarial de la tarea C1): a proposito
  // NO incluye talleres_vinculados / taller_pendiente_confirmacion /
  // taller_pendiente_nombre / taller_pendiente_servicio_id /
  // talleres_rechazados. Estos son campos server/consentimiento-owned:
  // updateVehicle() usa este toMap() para escribir el documento completo
  // (.update(vehicle.toMap())) desde ediciones normales del dueño
  // (kilometraje, foto, etc.) con un modelo local que puede estar
  // desactualizado respecto al ultimo write del trigger de Cloud Functions.
  // Si viajaran aqui, un update de formulario cualquiera podria pisar o
  // borrar silenciosamente el estado de vinculo/consentimiento. Solo
  // VehicleService.confirmarVinculoTaller/rechazarVinculoTaller (updates
  // parciales) deben tocarlos.
  Map<String, dynamic> toMap() {
    return {
      'id_vehiculo': idVehiculo,
      'id_propietario': idPropietario,
      'placa': placa,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'color': color,
      'kilometraje_actual': kilometrajeActual,
      'vencimiento_tarjeta': vencimientoTarjeta != null
          ? Timestamp.fromDate(vencimientoTarjeta!)
          : null,
      'vencimiento_soat': vencimientoSoat != null
          ? Timestamp.fromDate(vencimientoSoat!)
          : null,
      'foto_url': fotoUrl,
      'es_principal': isPrimary,
      'shared_with': sharedWith,
      'notas': notas,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id_vehiculo': idVehiculo,
      'id_propietario': idPropietario,
      'placa': placa,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'color': color,
      'kilometraje_actual': kilometrajeActual,
      'vencimiento_tarjeta': vencimientoTarjeta?.toIso8601String(),
      'vencimiento_soat': vencimientoSoat?.toIso8601String(),
      'foto_url': fotoUrl,
      'es_principal': isPrimary,
      'shared_with': sharedWith,
      'notas': notas,
      'talleres_vinculados': talleresVinculados,
      'taller_pendiente_confirmacion': tallerPendienteConfirmacion,
      'taller_pendiente_nombre': tallerPendienteNombre,
      'taller_pendiente_servicio_id': tallerPendienteServicioId,
      'talleres_rechazados': talleresRechazados,
    };
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return VehicleModel(
      idVehiculo: map['id_vehiculo'] ?? documentId,
      idPropietario: map['id_propietario'] ?? '',
      placa: map['placa'] ?? '',
      marca: map['marca'],
      modelo: map['modelo'],
      anio: map['anio'],
      color: map['color'],
      kilometrajeActual: map['kilometraje_actual'] ?? 0,
      vencimientoTarjeta: parseDate(map['vencimiento_tarjeta']),
      vencimientoSoat: parseDate(map['vencimiento_soat']),
      fotoUrl: map['foto_url'],
      isPrimary: map['es_principal'] ?? false,
      sharedWith: List<String>.from(map['shared_with'] ?? []),
      notas: List<String>.from(map['notas'] ?? []),
      talleresVinculados: List<String>.from(map['talleres_vinculados'] ?? []),
      tallerPendienteConfirmacion: map['taller_pendiente_confirmacion'],
      tallerPendienteNombre: map['taller_pendiente_nombre'],
      tallerPendienteServicioId: map['taller_pendiente_servicio_id'],
      talleresRechazados: List<String>.from(map['talleres_rechazados'] ?? []),
    );
  }

  factory VehicleModel.fromJson(Map<String, dynamic> map) {
    return VehicleModel.fromMap(map, map['id_vehiculo'] ?? '');
  }
}
