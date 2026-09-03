/// Plan de mantenimiento por defecto que recibe todo vehiculo de AutoDoc.
///
/// Vive aparte de `AlertProvider` porque no es solo suyo: el script de
/// backfill `functions/seed_tareas_mantenimiento.js` replica esta misma tabla
/// en JS para poder sembrarla con el Admin SDK sobre vehiculos que ya
/// existen. Si cambias un valor aqui, cambialo tambien alli — el script
/// arranca con un comentario que apunta a este archivo.
///
/// Las claves son las del documento de `mantenimientos` tal cual las lee
/// `MaintenanceTask.fromMap`, no nombres nuevos.
const List<Map<String, dynamic>> kTareasMantenimientoPorDefecto = [
  {'nombre': 'Cambio de Aceite', 'frecuencia_km': 5000, 'frecuencia_meses': 6},
  {'nombre': 'Filtro de Aire', 'frecuencia_km': 10000, 'frecuencia_meses': 12},
  {'nombre': 'Filtro de Aceite', 'frecuencia_km': 5000, 'frecuencia_meses': 6},
  {
    'nombre': 'Pastillas de Freno',
    'frecuencia_km': 20000,
    'frecuencia_meses': 24,
  },
  {
    'nombre': 'Rotación de Llantas',
    'frecuencia_km': 10000,
    'frecuencia_meses': 12,
  },
  {
    'nombre': 'Revisión de Frenos',
    'frecuencia_km': 15000,
    'frecuencia_meses': 18,
  },
  {
    'nombre': 'Cambio de Refrigerante',
    'frecuencia_km': 40000,
    'frecuencia_meses': 24,
  },
  {'nombre': 'Bujías', 'frecuencia_km': 30000, 'frecuencia_meses': 24},
];

/// Id determinista del documento de `mantenimientos` para una tarea por
/// defecto de un vehiculo.
///
/// Existe para que sembrar el plan sea IDEMPOTENTE. Con ids aleatorios
/// (`collection().doc()`), cada llamada a `createDefaultTasks` anadia otras
/// ocho tareas: bastaba con que el vehiculo se abriera varias veces sin que
/// la escritura anterior fuera visible todavia para acabar con el plan
/// duplicado x2, x3, x6... Con un id derivado del vehiculo y del nombre, dos
/// llamadas simultaneas escriben el MISMO documento en vez de dos distintos.
///
/// El mismo id lo calcula `functions/seed_tareas_mantenimiento.js`; si tocas
/// esta funcion, toca tambien su gemela en JS.
String idTareaMantenimiento(String vehicleId, String nombre) {
  const conAcento = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sinAcento = 'aaaaaeeeeiiiiooooouuuunc';

  final buffer = StringBuffer();
  for (final rune in nombre.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final idx = conAcento.indexOf(char);
    final normal = idx == -1 ? char : sinAcento[idx];
    buffer.write(RegExp(r'[a-z0-9]').hasMatch(normal) ? normal : '_');
  }
  return '${vehicleId}__${buffer.toString()}';
}
