import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/galeria_taller.dart';
import 'package:autodoc/features/mechanic/data/services/galeria_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late List<String> subidas;
  late List<String> borrados;
  late GaleriaService service;
  Object? errorAlBorrar;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    subidas = [];
    borrados = [];
    errorAlBorrar = null;
    service = GaleriaService(
      firestore: firestore,
      subidor:
          ({
            required String ruta,
            required Uint8List bytes,
            required String contentType,
          }) async => subidas.add('$ruta|$contentType'),
      borrador: (ruta) async {
        if (errorAlBorrar != null) throw errorAlBorrar!;
        borrados.add(ruta);
      },
    );
  });

  Future<GaleriaTaller> subir(String slot, String nombre) => service.subirFoto(
    tallerId: 'taller-1',
    slot: slot,
    nombreOriginal: nombre,
    bytes: Uint8List.fromList([1, 2, 3]),
  );

  Future<List<dynamic>?> galeriaEnFirestore() async {
    final doc = await firestore.collection('usuarios').doc('taller-1').get();
    return doc.data()?['galeria'] as List<dynamic>?;
  }

  group('subirFoto', () {
    test('sube a la ruta canónica y publica el hueco', () async {
      final galeria = await subir('logo', 'MI LOGO.JPEG');

      // El nombre original no manda: el objeto se guarda como {slot}.{ext},
      // que es lo unico que aceptan las reglas de Storage.
      expect(subidas.single, 'talleres_fotos/taller-1/logo.jpg|image/jpeg');
      expect(galeria.archivoLogo, 'logo.jpg');
      expect(await galeriaEnFirestore(), ['logo.jpg']);
    });

    test('conserva el content-type de PNG y WebP', () async {
      await subir('local-1', 'foto.png');
      await subir('local-2', 'foto.webp');

      expect(subidas[0], endsWith('local-1.png|image/png'));
      expect(subidas[1], endsWith('local-2.webp|image/webp'));
    });

    test('rechaza un hueco que no existe', () async {
      await expectLater(
        subir('local-9', 'foto.jpg'),
        throwsA(isA<GaleriaException>()),
      );
      expect(subidas, isEmpty);
    });

    test('rechaza un archivo que no es imagen', () async {
      for (final nombre in ['folleto.pdf', 'logo.svg', 'sinextension']) {
        await expectLater(
          subir('logo', nombre),
          throwsA(isA<GaleriaException>()),
        );
      }
      expect(subidas, isEmpty);
    });

    test('cambiar de extensión en el mismo hueco borra el huérfano', () async {
      // Sobrescribir solo funciona si el nombre coincide: logo.jpg -> logo.png
      // dejaria el .jpg ocupando cuota facturable para siempre, y no hay
      // ninguna Cloud Function que limpie detrás.
      await subir('logo', 'a.jpg');
      await subir('logo', 'b.png');

      expect(borrados, ['talleres_fotos/taller-1/logo.jpg']);
      expect(await galeriaEnFirestore(), ['logo.png']);
    });

    test('resubir con la misma extensión no borra nada', () async {
      await subir('logo', 'a.jpg');
      await subir('logo', 'b.jpg');

      expect(borrados, isEmpty);
      expect(await galeriaEnFirestore(), ['logo.jpg']);
    });

    test('la lista sale ordenada por hueco, no por orden de subida', () async {
      await subir('local-2', 'a.jpg');
      await subir('logo', 'b.jpg');
      await subir('local-1', 'c.jpg');

      expect(await galeriaEnFirestore(), [
        'logo.jpg',
        'local-1.jpg',
        'local-2.jpg',
      ]);
    });

    test('no arrasa el resto del documento de usuario', () async {
      await firestore.collection('usuarios').doc('taller-1').set({
        'nombre_completo': 'Taller El Buen Motor',
        'estado': 'activo',
      });

      await subir('logo', 'a.jpg');

      final doc = await firestore.collection('usuarios').doc('taller-1').get();
      expect(doc.data()!['nombre_completo'], 'Taller El Buen Motor');
      expect(doc.data()!['estado'], 'activo');
    });

    test(
      'si falla Storage la galería no anuncia una foto inexistente',
      () async {
        final roto = GaleriaService(
          firestore: firestore,
          subidor:
              ({
                required String ruta,
                required Uint8List bytes,
                required String contentType,
              }) async => throw Exception('sin red'),
        );

        await expectLater(
          roto.subirFoto(
            tallerId: 'taller-1',
            slot: 'logo',
            nombreOriginal: 'a.jpg',
            bytes: Uint8List.fromList([1]),
          ),
          throwsA(isA<Exception>()),
        );

        expect(await galeriaEnFirestore(), isNull);
      },
    );
  });

  group('quitarFoto', () {
    test('quita el hueco de la lista y borra el objeto', () async {
      await subir('logo', 'a.jpg');
      await subir('local-1', 'b.jpg');

      final galeria = await service.quitarFoto(
        tallerId: 'taller-1',
        slot: 'logo',
      );

      expect(galeria.archivoLogo, isNull);
      expect(await galeriaEnFirestore(), ['local-1.jpg']);
      expect(borrados, ['talleres_fotos/taller-1/logo.jpg']);
    });

    test('quitar un hueco vacío no hace nada', () async {
      final galeria = await service.quitarFoto(
        tallerId: 'taller-1',
        slot: 'logo',
      );

      expect(galeria.estaVacia, isTrue);
      expect(borrados, isEmpty);
    });

    test('si el borrado en Storage falla, la foto igualmente desaparece '
        'de la ficha', () async {
      // Lo que decide si una foto se ve es la lista. Un objeto invisible en
      // Storage es cuota desperdiciada; una ficha apuntando a un objeto que ya
      // no existe es un hueco roto delante del cliente.
      await subir('logo', 'a.jpg');
      errorAlBorrar = Exception('object-not-found');

      final galeria = await service.quitarFoto(
        tallerId: 'taller-1',
        slot: 'logo',
      );

      expect(galeria.estaVacia, isTrue);
      expect(await galeriaEnFirestore(), isEmpty);
    });
  });

  group('obtener', () {
    test('un taller sin galería devuelve una vacía, no null', () async {
      expect((await service.obtener('taller-1')).estaVacia, isTrue);
    });

    test('descarta entradas manipuladas al leer', () async {
      await firestore.collection('usuarios').doc('taller-1').set({
        'galeria': ['../../otra.jpg', 'logo.jpg'],
      });

      expect((await service.obtener('taller-1')).archivos, ['logo.jpg']);
    });
  });
}
