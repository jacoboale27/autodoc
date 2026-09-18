import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Hace que `Image.network` devuelva un PNG válido en vez de salir a la red.
///
/// Sin esto, cualquier test que monte un widget con `Image.network` falla con
/// `NetworkImageLoadException: HTTP request failed, statusCode: 400`: el
/// binding de test no bloquea las peticiones HTTP, las deja salir, y en un
/// entorno sin red (o con una URL de fixture) revientan. La excepción la lanza
/// el servicio de imágenes, no el widget, así que el test falla por algo que no
/// estaba probando.
///
/// Uso:
/// ```dart
/// await conImagenesDeRed(() async {
///   await tester.pumpWidget(...);
///   ...
/// });
/// ```
Future<T> conImagenesDeRed<T>(Future<T> Function() cuerpo) {
  return HttpOverrides.runZoned(cuerpo, createHttpClient: (_) => _Cliente());
}

/// PNG de 1×1 transparente. Tiene que ser una imagen DECODIFICABLE de verdad:
/// con bytes cualesquiera el códec falla y el síntoma es el mismo que se venía
/// a evitar.
final _png = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _Cliente implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Peticion();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Peticion implements HttpClientRequest {
  @override
  final HttpHeaders headers = _Cabeceras();

  @override
  Future<HttpClientResponse> close() async => _Respuesta();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Respuesta implements HttpClientResponse {
  @override
  int statusCode = HttpStatus.ok;
  @override
  int contentLength = _png.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  final HttpHeaders headers = _Cabeceras();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_png).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cabeceras implements HttpHeaders {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
