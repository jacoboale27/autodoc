/// Un servicio del catálogo del taller, con el precio ESTIMADO de su mano de
/// obra.
///
/// Observaciones del 2026-09-19: «al haber tantas posibilidades de carros,
/// modelos y diferentes piezas ... las posibilidades de presupuestos son
/// infinitas, por lo que debería hacerse el catálogo pero que este tenga los
/// precios haciendo una estimación de lo que podría costar la mano de obra en
/// cualquier vehículo». Los repuestos se cotizan aparte, en cada cotización.
///
/// [precio] es el «desde» (y el que se usa al cotizar) y [precioMax] el
/// «hasta», opcional: un rango cubre de una moto a un camión.
class CatalogoItemModel {
  final String idItem;
  final String idTaller;
  final String nombre;
  final double precio;
  final double? precioMax;

  CatalogoItemModel({
    required this.idItem,
    required this.idTaller,
    required this.nombre,
    required this.precio,
    this.precioMax,
  });

  /// «$20.00 – $40.00», o «$25.00» si no hay rango.
  String get rangoTexto {
    final desde = '\$${precio.toStringAsFixed(2)}';
    final hasta = precioMax;
    if (hasta == null || hasta <= precio) return desde;
    return '$desde – \$${hasta.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toMap() => {
    'id_taller': idTaller,
    'nombre': nombre,
    'precio': precio,
    if (precioMax != null) 'precio_max': precioMax,
  };

  factory CatalogoItemModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return CatalogoItemModel(
      idItem: documentId,
      idTaller: (map['id_taller'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      precioMax: (map['precio_max'] as num?)?.toDouble(),
    );
  }
}

/// Servicios de mano de obra frecuentes, con un rango de precio estimado en
/// dólares para El Salvador. Son un punto de partida para que el catálogo no
/// empiece vacío: cada taller los ajusta o los borra.
const List<({String nombre, double desde, double hasta})>
serviciosComunesManoDeObra = [
  (nombre: 'Cambio de aceite y filtro', desde: 10, hasta: 20),
  (nombre: 'Diagnóstico con escáner', desde: 15, hasta: 30),
  (nombre: 'Cambio de pastillas de freno (por eje)', desde: 20, hasta: 40),
  (nombre: 'Rectificado de discos de freno (par)', desde: 20, hasta: 35),
  (nombre: 'Alineación', desde: 15, hasta: 25),
  (nombre: 'Balanceo de llantas (4)', desde: 10, hasta: 20),
  (nombre: 'Cambio de bujías', desde: 15, hasta: 35),
  (nombre: 'Afinado mayor', desde: 40, hasta: 90),
  (nombre: 'Cambio de batería', desde: 5, hasta: 10),
  (nombre: 'Cambio de amortiguadores (par)', desde: 40, hasta: 80),
  (nombre: 'Cambio de kit de embrague', desde: 120, hasta: 300),
  (nombre: 'Cambio de banda de distribución', desde: 80, hasta: 250),
  (nombre: 'Cambio de refrigerante', desde: 15, hasta: 30),
  (nombre: 'Limpieza de inyectores', desde: 30, hasta: 60),
  (nombre: 'Revisión y recarga de aire acondicionado', desde: 25, hasta: 50),
  (nombre: 'Reparación de pinchazo', desde: 3, hasta: 8),
  (nombre: 'Cambio de faja de accesorios', desde: 15, hasta: 35),
  (nombre: 'Revisión del sistema eléctrico', desde: 20, hasta: 50),
];
