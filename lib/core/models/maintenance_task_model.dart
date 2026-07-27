import 'package:cloud_firestore/cloud_firestore.dart';

enum MaintenanceStatus { optimal, preventive, critical }

class MaintenanceTask {
  final String id;
  final String vehicleId;
  final String nombre;
  final int ultimoKm;
  final DateTime fechaUltimoServicio;
  final int frecuenciaKm;
  final int frecuenciaMeses;

  MaintenanceTask({
    required this.id,
    required this.vehicleId,
    required this.nombre,
    required this.ultimoKm,
    required this.fechaUltimoServicio,
    required this.frecuenciaKm,
    required this.frecuenciaMeses,
  });

  MaintenanceStatus getStatus(int kilometrajeActual) {
    final now = DateTime.now();

    // Cálculo por Kilometraje
    final kmDesdeUltimo = kilometrajeActual - ultimoKm;
    final kmRestantes = frecuenciaKm - kmDesdeUltimo;

    // Cálculo por Tiempo
    final proximoServicioFecha = DateTime(
      fechaUltimoServicio.year,
      fechaUltimoServicio.month + frecuenciaMeses,
      fechaUltimoServicio.day,
    );
    final diasRestantes = proximoServicioFecha.difference(now).inDays;

    // Lógica de Estados
    if (kmRestantes <= 0 || diasRestantes <= 0) {
      return MaintenanceStatus.critical;
    } else if (kmRestantes < 500 || diasRestantes < 15) {
      return MaintenanceStatus.preventive;
    } else {
      return MaintenanceStatus.optimal;
    }
  }

  String getStatusLabel(int kilometrajeActual) {
    final status = getStatus(kilometrajeActual);
    switch (status) {
      case MaintenanceStatus.critical:
        return 'CRÍTICO';
      case MaintenanceStatus.preventive:
        return 'PREVENTIVO';
      case MaintenanceStatus.optimal:
        return 'ÓPTIMO';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id_vehiculo': vehicleId,
      'nombre': nombre,
      'ultimo_km': ultimoKm,
      'fecha_ultimo_servicio': Timestamp.fromDate(fechaUltimoServicio),
      'frecuencia_km': frecuenciaKm,
      'frecuencia_meses': frecuenciaMeses,
    };
  }

  factory MaintenanceTask.fromMap(Map<String, dynamic> map, String id) {
    return MaintenanceTask(
      id: id,
      vehicleId: map['id_vehiculo'] ?? '',
      nombre: map['nombre'] ?? '',
      ultimoKm: map['ultimo_km'] ?? 0,
      fechaUltimoServicio: (map['fecha_ultimo_servicio'] as Timestamp).toDate(),
      frecuenciaKm: map['frecuencia_km'] ?? 5000,
      frecuenciaMeses: map['frecuencia_meses'] ?? 6,
    );
  }
}
