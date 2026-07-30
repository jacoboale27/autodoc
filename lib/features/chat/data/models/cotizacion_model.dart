import 'package:cloud_firestore/cloud_firestore.dart';

/// Un renglón de material/repuesto dentro de una cotización.
/// [beneficio] es la ganancia del mecánico sobre ese renglón y solo debe
/// mostrarse al mecánico, nunca al cliente.
class CotizacionItem {
  final String material;
  final double cantidad;
  final double costo;
  final double beneficio;

  CotizacionItem({
    required this.material,
    required this.cantidad,
    required this.costo,
    this.beneficio = 0,
  });

  double get subtotal => cantidad * costo;

  Map<String, dynamic> toMap() {
    return {
      'material': material,
      'cantidad': cantidad,
      'costo': costo,
      'beneficio': beneficio,
    };
  }

  factory CotizacionItem.fromMap(Map<String, dynamic> map) {
    return CotizacionItem(
      material: map['material'] ?? '',
      cantidad: (map['cantidad'] ?? 0).toDouble(),
      costo: (map['costo'] ?? 0).toDouble(),
      beneficio: (map['beneficio'] ?? 0).toDouble(),
    );
  }
}

class CotizacionModel {
  final String id;
  final String idPropietario;
  final String idMecanico;
  final String? idVehiculo;
  final String? idTaller;
  final List<CotizacionItem> items;
  final DateTime? fechaPropuesta;
  final String estado; // 'pendiente', 'aceptada', 'rechazada', 'finalizada'
  final DateTime fecha;

  CotizacionModel({
    required this.id,
    required this.idPropietario,
    required this.idMecanico,
    this.idVehiculo,
    this.idTaller,
    required this.items,
    this.fechaPropuesta,
    this.estado = 'pendiente',
    required this.fecha,
  });

  /// Resumen legible de los materiales/repuestos cotizados.
  String get resumen => items.isEmpty
      ? 'Cotización sin detalles'
      : items.map((i) => i.material).where((m) => m.isNotEmpty).join(', ');

  /// Total que paga el cliente (sin incluir el beneficio del mecánico aparte;
  /// el beneficio ya está reflejado en el costo de cada renglón).
  double get total => items.fold(0.0, (acc, i) => acc + i.subtotal);

  factory CotizacionModel.fromMap(Map<String, dynamic> map, String documentId) {
    final rawItems = map['items'] as List? ?? const [];
    return CotizacionModel(
      id: documentId,
      idPropietario: map['id_propietario'] ?? '',
      idMecanico: map['id_mecanico'] ?? '',
      idVehiculo: map['id_vehiculo'],
      idTaller: map['id_taller'],
      items: rawItems
          .map((e) => CotizacionItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      fechaPropuesta: (map['fecha_propuesta'] as Timestamp?)?.toDate(),
      estado: map['estado'] ?? 'pendiente',
      fecha: (map['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_propietario': idPropietario,
      'id_mecanico': idMecanico,
      if (idVehiculo != null) 'id_vehiculo': idVehiculo,
      if (idTaller != null) 'id_taller': idTaller,
      'items': items.map((i) => i.toMap()).toList(),
      if (fechaPropuesta != null)
        'fecha_propuesta': Timestamp.fromDate(fechaPropuesta!),
      'descripcion': resumen,
      'total': total,
      'estado': estado,
      'fecha': Timestamp.fromDate(fecha),
    };
  }
}
