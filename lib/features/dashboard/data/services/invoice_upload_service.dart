import 'dart:math';

class InvoiceUploadService {
  static Map<String, String> getFileMetadata(String fileName) {
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    return {
      'extension': isPdf ? '.pdf' : '.jpg',
      'contentType': isPdf ? 'application/pdf' : 'image/jpeg',
    };
  }

  static final Random _azar = Random.secure();

  /// Nombre del objeto de una factura en Storage.
  ///
  /// **El sufijo aleatorio no es decoracion.** El nombre era solo
  /// `<epoch-ms><extension>`, o sea completamente predecible, y desde GAPS-05
  /// `storage.rules` deniega escribir sobre una factura que ya exista (antes
  /// se podia sobrescribir la de otro, que es borrarla con pasos extra). Las
  /// dos cosas juntas abren un modo de fallo que por separado no existia: un
  /// taller vinculado puede sembrar archivos de 1 byte en las rutas de
  /// milisegundos FUTUROS y dejarlas inutilizables para siempre, porque ya
  /// solo un admin puede tocarlas. Lo levanto el gate de revision sobre el
  /// propio cambio de reglas.
  ///
  /// Con 64 bits de azar, adivinar la ruta antes de que se use deja de ser
  /// posible, y de paso desaparece la colision entre dos facturas del mismo
  /// vehiculo subidas en el mismo milisegundo — que con la regla nueva habria
  /// pasado de sobrescritura silenciosa a fallo duro.
  ///
  /// `Random.secure()` y no `Random()`: el `Random` normal se siembra de forma
  /// predecible y aqui lo que se pide al numero es justo que no se pueda
  /// anticipar.
  static String nombreDeArchivo(String extension) {
    final sufijo = List.generate(
      4,
      (_) => _azar.nextInt(65536).toRadixString(16).padLeft(4, '0'),
    ).join();
    return '${DateTime.now().millisecondsSinceEpoch}-$sufijo$extension';
  }
}
