import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Escribe [csvContent] como archivo [filename] en el directorio de
/// documentos de la aplicación.
///
/// El panel de administración es predominantemente web (GridView/sidebar
/// responsive), así que esta rama IO existe principalmente para no romper
/// builds de otras plataformas; no comparte el archivo automáticamente en
/// esta iteración.
Future<void> downloadCsv(String filename, String csvContent) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(csvContent);
}
