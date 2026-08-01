import 'package:csv/csv.dart';

import 'csv_export_stub.dart'
    if (dart.library.html) 'csv_export_util_web.dart'
    if (dart.library.io) 'csv_export_util_io.dart'
    as platform;

/// Construye el contenido CSV (con encabezados + filas) a partir de datos
/// crudos. Es una función pura, sin I/O, por lo que es fácilmente testeable.
///
/// Usa `\r\n` como separador de línea (estándar CSV / RFC 4180) para máxima
/// compatibilidad con Excel y otras herramientas.
String buildCsv(List<String> headers, List<List<String>> rows) {
  final data = [headers, ...rows];
  return const ListToCsvConverter(eol: '\r\n').convert(data);
}

/// Dispara la descarga de [csvContent] como archivo [filename].
///
/// En web, dispara una descarga real del navegador. En plataformas con
/// `dart:io` (móvil/desktop), escribe el archivo en el directorio de
/// documentos de la aplicación.
Future<void> downloadCsv(String filename, String csvContent) {
  return platform.downloadCsv(filename, csvContent);
}
