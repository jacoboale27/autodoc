class WorkshopModel {
  final String idTaller;
  final String nombre;
  final String? ubicacionMunicipio;
  final String? especialidad;
  final String? telefono;
  final double calificacionPromedio;
  final String estado;

  WorkshopModel({
    required this.idTaller,
    required this.nombre,
    this.ubicacionMunicipio,
    this.especialidad,
    this.telefono,
    this.calificacionPromedio = 0.0,
    this.estado = 'pendiente',
  });

  WorkshopModel copyWith({
    String? idTaller,
    String? nombre,
    String? ubicacionMunicipio,
    String? especialidad,
    String? telefono,
    double? calificacionPromedio,
    String? estado,
  }) {
    return WorkshopModel(
      idTaller: idTaller ?? this.idTaller,
      nombre: nombre ?? this.nombre,
      ubicacionMunicipio: ubicacionMunicipio ?? this.ubicacionMunicipio,
      especialidad: especialidad ?? this.especialidad,
      telefono: telefono ?? this.telefono,
      calificacionPromedio: calificacionPromedio ?? this.calificacionPromedio,
      estado: estado ?? this.estado,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_taller': idTaller,
      'nombre': nombre,
      'ubicacion_municipio': ubicacionMunicipio,
      'especialidad': especialidad,
      'telefono': telefono,
      'calificacion_promedio': calificacionPromedio,
      'estado': estado,
    };
  }

  factory WorkshopModel.fromMap(Map<String, dynamic> map, String documentId) {
    return WorkshopModel(
      idTaller: map['id_taller'] ?? documentId,
      nombre: map['nombre'] ?? '',
      ubicacionMunicipio: map['ubicacion_municipio'],
      especialidad: map['especialidad'],
      telefono: map['telefono'],
      calificacionPromedio: (map['calificacion_promedio'] ?? 0.0).toDouble(),
      estado: map['estado'] ?? 'pendiente',
    );
  }
}
