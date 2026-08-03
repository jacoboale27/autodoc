class CatalogoItemModel {
  final String idItem;
  final String idTaller;
  final String nombre;
  final double precio;

  CatalogoItemModel({
    required this.idItem,
    required this.idTaller,
    required this.nombre,
    required this.precio,
  });

  Map<String, dynamic> toMap() => {
    'id_taller': idTaller,
    'nombre': nombre,
    'precio': precio,
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
    );
  }
}
