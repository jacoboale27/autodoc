import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/galeria_taller.dart';

void main() {
  group('huecos permitidos', () {
    test('son exactamente los seis que aceptan las reglas de Storage', () {
      expect(GaleriaTaller.slotsPermitidos, [
        'logo',
        'local-1',
        'local-2',
        'local-3',
        'local-4',
        'local-5',
      ]);
    });

    test('esArchivoValido acepta el whitelist y nada más', () {
      for (final valido in [
        'logo.jpg',
        'logo.webp',
        'local-1.png',
        'local-5.jpeg',
      ]) {
        expect(GaleriaTaller.esArchivoValido(valido), isTrue, reason: valido);
      }

      for (final invalido in [
        'local-0.jpg',
        'local-6.jpg',
        'local-10.jpg',
        'logo.pdf',
        'logo.svg',
        'logo.jpg.exe',
        'otra.jpg',
        'logo',
        '',
      ]) {
        expect(
          GaleriaTaller.esArchivoValido(invalido),
          isFalse,
          reason: invalido,
        );
      }
    });
  });

  group('fromLista: la lista llega de un documento público', () {
    test('lee una galería normal conservando el orden de los huecos', () {
      final galeria = GaleriaTaller.fromLista([
        'local-2.png',
        'logo.jpg',
        'local-1.webp',
      ]);

      expect(galeria.archivos, ['local-2.png', 'logo.jpg', 'local-1.webp']);
      expect(galeria.archivoLogo, 'logo.jpg');
      expect(galeria.archivosDelLocal, ['local-2.png', 'local-1.webp']);
    });

    test('descarta un salto de ruta sin tumbar la pantalla', () {
      // `galeria` la escribe el propio taller y viaja al documento publico,
      // que cualquiera lee. Una entrada asi solo puede venir de un write
      // manipulado: se descarta en silencio, ni se pinta ni revienta.
      final galeria = GaleriaTaller.fromLista([
        '../../perfiles/otra-victima.jpg',
        'logo.jpg',
        'https://rastreador.example.com/pixel.gif',
        'local-9.jpg',
      ]);

      expect(galeria.archivos, ['logo.jpg']);
    });

    test('un mismo hueco repetido se queda con el primero', () {
      final galeria = GaleriaTaller.fromLista(['logo.jpg', 'logo.png']);
      expect(galeria.archivos, ['logo.jpg']);
    });

    test('cualquier cosa que no sea una lista da una galería vacía', () {
      for (final basura in [null, 'logo.jpg', 42, <String, dynamic>{}]) {
        expect(GaleriaTaller.fromLista(basura).estaVacia, isTrue);
      }
    });
  });

  group('urlDe: la única forma de llegar a una URL', () {
    test('construye la ruta desde el uid y el nombre, nada más', () {
      final url = GaleriaTaller.urlDe(
        bucket: 'autodoc.appspot.com',
        idTaller: 'taller-1',
        nombreArchivo: 'logo.jpg',
      );

      expect(
        url,
        'https://firebasestorage.googleapis.com/v0/b/autodoc.appspot.com/o/'
        'talleres_fotos%2Ftaller-1%2Flogo.jpg?alt=media',
      );
    });

    test('un nombre no válido no produce URL', () {
      // La defensa estructural: aunque una entrada manipulada se colara hasta
      // aqui, no hay forma de que salga una URL apuntando a otro sitio.
      expect(
        GaleriaTaller.urlDe(
          bucket: 'autodoc.appspot.com',
          idTaller: 'taller-1',
          nombreArchivo: '../../secreto.jpg',
        ),
        isNull,
      );
    });

    test('sin bucket devuelve null en vez de una URL rota', () {
      // La app compilada sin --dart-define-from-file=.env no tiene bucket.
      expect(
        GaleriaTaller.urlDe(
          bucket: '',
          idTaller: 'taller-1',
          nombreArchivo: 'logo.jpg',
        ),
        isNull,
      );
    });
  });

  group('conArchivo / sinSlot', () {
    test('ordena por hueco, no por orden de subida', () {
      // Asi el logo sale siempre primero aunque se subiera el ultimo.
      final galeria = const GaleriaTaller()
          .conArchivo('local-3.jpg')
          .conArchivo('logo.png')
          .conArchivo('local-1.webp');

      expect(galeria.archivos, ['logo.png', 'local-1.webp', 'local-3.jpg']);
    });

    test('subir al mismo hueco sustituye en vez de acumular', () {
      final galeria = const GaleriaTaller()
          .conArchivo('logo.jpg')
          .conArchivo('logo.webp');

      expect(galeria.archivos, ['logo.webp']);
    });

    test('un nombre inválido no entra', () {
      expect(const GaleriaTaller().conArchivo('local-9.jpg').estaVacia, isTrue);
    });

    test('sinSlot vacía solo ese hueco', () {
      final galeria = const GaleriaTaller()
          .conArchivo('logo.jpg')
          .conArchivo('local-1.jpg')
          .sinSlot('logo');

      expect(galeria.archivos, ['local-1.jpg']);
      expect(galeria.archivoLogo, isNull);
    });
  });

  group('slotsLibres', () {
    test('lista los huecos vacíos en orden', () {
      expect(const GaleriaTaller().slotsLibres, GaleriaTaller.slotsPermitidos);

      final galeria = const GaleriaTaller()
          .conArchivo('logo.jpg')
          .conArchivo('local-2.jpg');

      expect(galeria.slotsLibres, ['local-1', 'local-3', 'local-4', 'local-5']);
    });
  });
}
