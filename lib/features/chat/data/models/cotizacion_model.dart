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

  /// Payload publico (escrito en el documento cotizaciones/{id}, legible por
  /// el propietario): nunca incluye [beneficio]. Ver
  /// CotizacionModel.toPrivateMap para donde vive el beneficio.
  Map<String, dynamic> toMap() {
    return {'material': material, 'cantidad': cantidad, 'costo': costo};
  }

  factory CotizacionItem.fromMap(Map<String, dynamic> map) {
    return CotizacionItem(
      material: map['material'] ?? '',
      cantidad: (map['cantidad'] ?? 0).toDouble(),
      costo: (map['costo'] ?? 0).toDouble(),
      beneficio: (map['beneficio'] ?? 0).toDouble(),
    );
  }

  CotizacionItem copyWithBeneficio(double beneficio) {
    return CotizacionItem(
      material: material,
      cantidad: cantidad,
      costo: costo,
      beneficio: beneficio,
    );
  }
}

class CotizacionModel {
  final String id;
  final String idPropietario;
  final String idMecanico;
  final String? idVehiculo;
  final String? idTaller;
  final String? idReserva;
  final List<CotizacionItem> items;
  final DateTime? fechaPropuesta;
  final String estado; // 'pendiente', 'aceptada', 'rechazada', 'finalizada'
  final DateTime fecha;
  final double? manoDeObra;
  final List<Map<String, dynamic>>? materiales;

  CotizacionModel({
    required this.id,
    required this.idPropietario,
    required this.idMecanico,
    this.idVehiculo,
    this.idTaller,
    this.idReserva,
    required this.items,
    this.fechaPropuesta,
    this.estado = 'pendiente',
    required this.fecha,
    this.manoDeObra,
    this.materiales,
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
      idReserva: map['id_reserva'],
      items: rawItems
          .map((e) => CotizacionItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      fechaPropuesta: (map['fecha_propuesta'] as Timestamp?)?.toDate(),
      estado: map['estado'] ?? 'pendiente',
      fecha: (map['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      manoDeObra: map['mano_de_obra']?.toDouble(),
      materiales: map['materiales'] is List
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
      if (idReserva != null) 'id_reserva': idReserva,
      'items': items.map((i) => i.toMap()).toList(),
      if (fechaPropuesta != null)
        'fecha_propuesta': Timestamp.fromDate(fechaPropuesta!),
      'descripcion': resumen,
      'total': total,
      'estado': estado,
      'fecha': Timestamp.fromDate(fecha),
      if (manoDeObra != null) 'mano_de_obra': manoDeObra,
      if (materiales != null) 'materiales': materiales,
    };
  }

  /// Documento privado (cotizaciones/{id}/privado/margen): el beneficio por
  /// renglon, visible solo para el mecanico dueño de la cotizacion (ver
  /// firestore.rules). Nunca debe fusionarse con [toMap].
  Map<String, dynamic> toPrivateMap() {
    return {'beneficios': items.map((i) => i.beneficio).toList()};
  }

  /// Copia este modelo sustituyendo el beneficio de cada item por el valor
  /// en la misma posicion de [beneficios] (leido de toPrivateMap). Si
  /// [beneficios] es mas corto que [items], los renglones sobrantes quedan
  /// en 0.
  CotizacionModel copyWithBeneficios(List<double> beneficios) {
    final nuevosItems = <CotizacionItem>[];
    for (var i = 0; i < items.length; i++) {
      final beneficio = i < beneficios.length ? beneficios[i] : 0.0;
      nuevosItems.add(items[i].copyWithBeneficio(beneficio));
    }
    return CotizacionModel(
      id: id,
      idPropietario: idPropietario,
      idMecanico: idMecanico,
      idVehiculo: idVehiculo,
      idTaller: idTaller,
      idReserva: idReserva,
      items: nuevosItems,
      fechaPropuesta: fechaPropuesta,
      estado: estado,
      fecha: fecha,
      manoDeObra: manoDeObra,
      materiales: materiales,
    );
  }
}
