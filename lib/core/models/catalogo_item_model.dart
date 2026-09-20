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

/// Un servicio de mano de obra sugerido, con su rango en dólares.
typedef ServicioComun = ({String nombre, double desde, double hasta});

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

/// Sugerencias propias de cada tipo de vehículo, ADEMÁS de las comunes.
///
/// Observación del 2026-09-20: «según la especialidad deberían tener
/// sugerencias predeterminadas del catálogo de servicios que puede hacer». Un
/// taller de motos no cambia kits de embrague de coche ni alinea con puente,
/// y uno de camiones sí purga frenos de aire.
///
/// `automovil` y `camioneta` no tienen lista propia: lo común YA es su
/// trabajo (la lista de arriba se escribió para ellos).
const Map<String, List<ServicioComun>> serviciosComunesPorTipo = {
  'camioneta': [
    (nombre: 'Cambio de aceite de diferencial', desde: 20, hasta: 40),
    (nombre: 'Revisión de tracción 4x4', desde: 25, hasta: 60),
    (nombre: 'Cambio de crucetas', desde: 30, hasta: 70),
  ],
  'motocicleta': [
    (nombre: 'Cambio de aceite de moto', desde: 5, hasta: 12),
    (nombre: 'Ajuste y lubricación de cadena', desde: 5, hasta: 12),
    (nombre: 'Cambio de kit de arrastre', desde: 15, hasta: 35),
    (nombre: 'Cambio de pastillas de freno de moto', desde: 8, hasta: 20),
    (nombre: 'Cambio de llanta de moto (por unidad)', desde: 5, hasta: 12),
    (nombre: 'Carburación / limpieza de carburador', desde: 15, hasta: 35),
    (nombre: 'Cambio de bujía de moto', desde: 3, hasta: 8),
    (nombre: 'Tensado de rayos y balanceo', desde: 8, hasta: 18),
  ],
  'camion': [
    (nombre: 'Purga y revisión de frenos de aire', desde: 30, hasta: 70),
    (nombre: 'Cambio de zapatas (por eje)', desde: 60, hasta: 140),
    (nombre: 'Cambio de aceite de motor diésel', desde: 30, hasta: 70),
    (nombre: 'Cambio de filtros de diésel', desde: 15, hasta: 40),
    (nombre: 'Revisión de sistema hidráulico', desde: 40, hasta: 100),
    (nombre: 'Cambio de hojas de muelle', desde: 80, hasta: 200),
  ],
  'microbus': [
    (nombre: 'Cambio de aceite de motor diésel', desde: 25, hasta: 55),
    (nombre: 'Revisión de frenos (4 ruedas)', desde: 30, hasta: 70),
    (
      nombre: 'Cambio de amortiguadores reforzados (par)',
      desde: 60,
      hasta: 120,
    ),
    (
      nombre: 'Revisión de aire acondicionado de pasajeros',
      desde: 35,
      hasta: 80,
    ),
  ],
  'autobus': [
    (nombre: 'Purga y revisión de frenos de aire', desde: 35, hasta: 80),
    (nombre: 'Cambio de aceite de motor diésel', desde: 40, hasta: 90),
    (nombre: 'Revisión de suspensión neumática', desde: 50, hasta: 120),
    (nombre: 'Revisión de puertas neumáticas', desde: 25, hasta: 60),
  ],
};

/// Las sugerencias para un taller que atiende [tipos]: lo común a todos más
/// lo propio de cada tipo, sin repetir nombres.
///
/// Con [tipos] vacío —un taller que todavía no ha dicho qué atiende— se
/// devuelve solo lo común, que es lo que había antes de esta observación.
List<ServicioComun> serviciosComunesPara(Iterable<String> tipos) {
  final vistos = <String>{};
  final lista = <ServicioComun>[];
  void agregar(Iterable<ServicioComun> servicios) {
    for (final s in servicios) {
      if (vistos.add(s.nombre.toLowerCase())) lista.add(s);
    }
  }

  agregar(serviciosComunesManoDeObra);
  for (final tipo in tipos) {
    agregar(serviciosComunesPorTipo[tipo] ?? const []);
  }
  return lista;
}
