/// Galeria comercial de un taller: su logo y hasta cinco fotos del local.
///
/// ## Por que aqui NO se guardan URLs
///
/// El documento publico `talleres/{uid}` es de lectura **anonima**
/// (`allow read: if true`) y lo alimenta `publishTallerProfile` copiando
/// campos de `usuarios/{uid}`, que el propio taller escribe. Un campo de URL
/// libre en esa cadena no produce "una imagen rota" si alguien lo manipula:
/// produce una peticion HTTP que hace la app de **cada visitante del
/// directorio** contra un servidor que elige el taller. Eso es cosecha de IP y
/// User-Agent de todo el que abra el listado.
///
/// Asi que la galeria guarda **nombres de archivo de un whitelist**, nunca
/// URLs. La ruta de Storage se reconstruye con [rutaDe] a partir de dos cosas
/// de confianza —el uid del taller y un nombre validado— de modo que no existe
/// ninguna URL que un taller pueda elegir. Es una garantia estructural, no un
/// filtro que haya que mantener al dia.
///
/// `firestore.rules` complementa esto acotando el tamaño de la lista, para que
/// nadie plante una lista enorme que el proyector copiaria al documento
/// publico. Que los nombres sean legitimos lo resuelve [fromLista], que
/// descarta en silencio todo lo que no case.
class GaleriaTaller {
  /// Hueco del logo. Es el que usa la tarjeta del directorio como imagen
  /// principal.
  static const String slotLogo = 'logo';

  /// Cuantas fotos del local caben, ademas del logo.
  static const int maxFotosLocal = 5;

  static const Set<String> extensionesPermitidas = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  /// Huecos aceptados, en el orden en que se ofrecen.
  ///
  /// El tope es duro y sale de aqui: las reglas de Storage no pueden CONTAR
  /// archivos, pero si restringir el nombre, asi que fijar seis nombres es lo
  /// unico que impide subir objetos ilimitados sin contador ni Cloud Function.
  /// Debe coincidir con el `matches()` del bloque
  /// `talleres_fotos/{tallerId}/{fileName}` de `storage.rules`.
  static List<String> get slotsPermitidos => [
    slotLogo,
    for (var i = 1; i <= maxFotosLocal; i++) 'local-$i',
  ];

  /// Nombres de archivo, en el orden en que el taller los coloco.
  ///
  /// Cada entrada es `{slot}.{extension}`, por ejemplo `logo.webp`. Se guarda
  /// la extension y no solo el hueco porque hace falta para reconstruir la
  /// ruta del objeto en Storage.
  final List<String> archivos;

  const GaleriaTaller({this.archivos = const []});

  bool get estaVacia => archivos.isEmpty;

  /// Nombre de archivo del logo, si el taller subio uno.
  String? get archivoLogo => _buscar(slotLogo);

  /// Fotos del local, sin el logo, en orden.
  List<String> get archivosDelLocal =>
      archivos.where((a) => _slotDe(a) != slotLogo).toList(growable: false);

  /// Huecos que el taller todavia no ha llenado, en orden estable.
  List<String> get slotsLibres {
    final ocupados = archivos.map(_slotDe).toSet();
    return slotsPermitidos
        .where((slot) => !ocupados.contains(slot))
        .toList(growable: false);
  }

  String? archivoDe(String slot) => _buscar(slot);

  String? _buscar(String slot) {
    for (final archivo in archivos) {
      if (_slotDe(archivo) == slot) return archivo;
    }
    return null;
  }

  /// ¿Es `nombreArchivo` uno de los nombres que aceptan las reglas?
  ///
  /// Igualdad exacta contra `{slot}.{extension}`, nunca un `matches` laxo: asi
  /// no hay nada que escapar y un `../` no puede colarse.
  static bool esArchivoValido(String nombreArchivo) {
    for (final slot in slotsPermitidos) {
      for (final extension in extensionesPermitidas) {
        if (nombreArchivo == '$slot.$extension') return true;
      }
    }
    return false;
  }

  /// Ruta del objeto en Storage. Solo acepta nombres ya validados.
  static String rutaDe(String idTaller, String nombreArchivo) {
    assert(
      esArchivoValido(nombreArchivo),
      'La ruta de Storage nunca se construye con un nombre sin validar: '
      'es lo unico que impide que un valor escrito por el taller apunte a '
      'donde quiera.',
    );
    return 'talleres_fotos/$idTaller/$nombreArchivo';
  }

  /// URL publica de descarga de una foto de la galeria.
  ///
  /// Se construye en vez de pedirla con `getDownloadURL()` porque el
  /// directorio pinta decenas de talleres a la vez y una llamada de red por
  /// imagen es un coste que no hace falta pagar: la ruta ya es conocida y el
  /// bloque de Storage es de lectura publica, asi que la forma `?alt=media`
  /// sin token resuelve sin autenticar.
  ///
  /// Devuelve `null` si falta el bucket —la app compilada sin
  /// `--dart-define-from-file=.env` no lo tiene— para que quien pinte pueda
  /// caer en el marcador de posicion en lugar de fabricar una URL rota.
  static String? urlDe({
    required String bucket,
    required String idTaller,
    required String nombreArchivo,
  }) {
    if (bucket.isEmpty || !esArchivoValido(nombreArchivo)) return null;
    final ruta = Uri.encodeComponent(rutaDe(idTaller, nombreArchivo));
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$ruta?alt=media';
  }

  /// Lee la lista tal cual viene de Firestore, descartando lo que no case.
  ///
  /// Descartar en silencio y no lanzar es deliberado: esta lista llega tambien
  /// desde el documento PUBLICO, que cualquiera puede leer y que se alimenta de
  /// un campo que el taller escribe. Una entrada rara solo puede venir de un
  /// write manipulado, y no debe ni pintarse ni tumbar la pantalla de quien la
  /// esta mirando.
  factory GaleriaTaller.fromLista(dynamic crudo) {
    if (crudo is! List) return const GaleriaTaller();

    final vistos = <String>{};
    final archivos = <String>[];
    for (final entrada in crudo) {
      final nombre = entrada?.toString() ?? '';
      if (!esArchivoValido(nombre)) continue;
      // Un mismo hueco dos veces (`logo.jpg` y `logo.png`) solo puede salir de
      // un write a mano: se queda el primero y se ignora el resto.
      final slot = _slotDe(nombre);
      if (!vistos.add(slot)) continue;
      archivos.add(nombre);
    }
    return GaleriaTaller(archivos: archivos);
  }

  List<String> toLista() => List.unmodifiable(archivos);

  /// Coloca `nombreArchivo` en su hueco, sustituyendo lo que hubiera.
  GaleriaTaller conArchivo(String nombreArchivo) {
    if (!esArchivoValido(nombreArchivo)) return this;
    final slot = _slotDe(nombreArchivo);
    final restantes = archivos.where((a) => _slotDe(a) != slot);
    // El orden lo fija `slotsPermitidos` y no el orden de subida: asi el logo
    // sale siempre primero y las fotos del local en su numeracion, sin que la
    // galeria dependa de en que orden se subieron las cosas.
    return GaleriaTaller(archivos: _ordenar([...restantes, nombreArchivo]));
  }

  /// Vacia un hueco.
  GaleriaTaller sinSlot(String slot) => GaleriaTaller(
    archivos: archivos.where((a) => _slotDe(a) != slot).toList(growable: false),
  );

  static List<String> _ordenar(List<String> archivos) {
    final orden = slotsPermitidos;
    final copia = [...archivos]
      ..sort(
        (a, b) =>
            orden.indexOf(_slotDe(a)).compareTo(orden.indexOf(_slotDe(b))),
      );
    return List.unmodifiable(copia);
  }

  static String _slotDe(String nombreArchivo) {
    final punto = nombreArchivo.lastIndexOf('.');
    return punto == -1 ? nombreArchivo : nombreArchivo.substring(0, punto);
  }
}
