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
    );
  }

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
      'vencimiento_tarjeta': vencimientoTarjeta != null ? Timestamp.fromDate(vencimientoTarjeta!) : null,
      'vencimiento_soat': vencimientoSoat != null ? Timestamp.fromDate(vencimientoSoat!) : null,
      'foto_url': fotoUrl,
      'es_principal': isPrimary,
      'shared_with': sharedWith,
    };
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map, String documentId) {
    return VehicleModel(
      idVehiculo: map['id_vehiculo'] ?? documentId,
      idPropietario: map['id_propietario'] ?? '',
      placa: map['placa'] ?? '',
      marca: map['marca'],
      modelo: map['modelo'],
      anio: map['anio'],
      color: map['color'],
      kilometrajeActual: map['kilometraje_actual'] ?? 0,
      vencimientoTarjeta: (map['vencimiento_tarjeta'] as Timestamp?)?.toDate(),
      vencimientoSoat: (map['vencimiento_soat'] as Timestamp?)?.toDate(),
      fotoUrl: map['foto_url'],
      isPrimary: map['es_principal'] ?? false,
      sharedWith: List<String>.from(map['shared_with'] ?? []),
    );
  }
}
