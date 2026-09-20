import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/core/models/catalogo_item_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';

void main() {
  test('watchTaller puebla items desde el repositorio', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CatalogoRepository(firestore: firestore);
    await repo.agregarItem(
      idTaller: 't1',
      nombre: 'Cambio de aceite',
      precio: 25.0,
    );

    final provider = CatalogoProvider(repository: repo);
    provider.watchTaller('t1');
    await Future.delayed(Duration.zero);

    expect(provider.items.length, 1);
  });

  test(
    'agregar transiciona isLoading y limpia error en el camino exitoso',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = CatalogoRepository(firestore: firestore);
      final provider = CatalogoProvider(repository: repo);
      provider.watchTaller('t1');

      final loadingStates = <bool>[];
      provider.addListener(() => loadingStates.add(provider.isLoading));

      await provider.agregar('Cambio de aceite', 25.0);

      expect(provider.isLoading, false);
      expect(provider.error, isNull);
      expect(loadingStates.first, true);
      expect(loadingStates.last, false);

      final items = await repo.watchCatalogo('t1').first;
      expect(items.length, 1);
    },
  );

  test(
    'agregar transiciona isLoading y expone error cuando el repositorio falla',
    () async {
      // MockFirebaseFirestore (via test_helpers.mocks.dart) usa
      // throwOnMissingStub: sin stubs, cualquier llamada (aqui, .collection())
      // lanza una MissingStubError, lo que basta para ejercitar el try/catch
      // del provider sin necesitar simular una falla real de red/permisos.
      final mockFirestore = MockFirebaseFirestore();
      final repo = CatalogoRepository(firestore: mockFirestore);
      final provider = CatalogoProvider(repository: repo);
      // watchTaller asigna idTaller antes de invocar watchCatalogo, asi que
      // el idTaller queda seteado aunque la suscripcion (no stubbeada) lance
      // de forma sincronica; basta con descartar esa excepcion aqui, no es
      // lo que este test ejercita.
      try {
        provider.watchTaller('t1');
      } catch (_) {
        // ignorado: ver comentario arriba.
      }

      final loadingStates = <bool>[];
      provider.addListener(() => loadingStates.add(provider.isLoading));

      await expectLater(
        () => provider.agregar('Cambio de aceite', 25.0),
        throwsA(anything),
      );

      expect(provider.isLoading, false);
      expect(provider.error, isNotNull);
      expect(loadingStates.first, true);
      expect(loadingStates.last, false);
    },
  );

  test(
    'agregar lanza un error claro y no llama al repositorio cuando idTaller está vacío',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = CatalogoRepository(firestore: firestore);
      final provider = CatalogoProvider(repository: repo);
      provider.watchTaller(
        '',
      ); // simula idTallerEfectivo == null -> '' en el router

      await expectLater(
        () => provider.agregar('Cambio de aceite', 25.0),
        throwsA(isA<StateError>()),
      );

      expect(provider.error, isNotNull);
      // No debe haberse escrito nada en Firestore.
      final snapshot = await firestore
          .collectionGroup('catalogo_servicios')
          .get();
      expect(snapshot.docs, isEmpty);
    },
  );

  test(
    'watchTaller con idTaller vacío no crea una suscripción activa',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = CatalogoRepository(firestore: firestore);
      final provider = CatalogoProvider(repository: repo);

      provider.watchTaller('');
      await Future.delayed(Duration.zero);

      expect(provider.items, isEmpty);
    },
  );

  // Observaciones del 2026-09-19: el catálogo es de mano de obra con precio
  // estimado, y trae servicios comunes para no empezar vacío.
  group('catálogo de mano de obra', () {
    test('guarda el rango «desde – hasta»', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = CatalogoProvider(
        repository: CatalogoRepository(firestore: firestore),
      );
      provider.watchTaller('t1');
      await provider.agregar('Alineación', 15, precioMax: 25);
      await Future<void>.delayed(Duration.zero);

      final item = provider.items.single;
      expect(item.precio, 15);
      expect(item.precioMax, 25);
      expect(item.rangoTexto, '\$15.00 – \$25.00');
    });

    test('los servicios comunes se agregan una sola vez', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = CatalogoProvider(
        repository: CatalogoRepository(firestore: firestore),
      );
      provider.watchTaller('t1');
      await provider.agregar('alineación', 18);
      await Future<void>.delayed(Duration.zero);

      final agregados = await provider.cargarServiciosComunes();
      await Future<void>.delayed(Duration.zero);
      expect(
        agregados,
        serviciosComunesManoDeObra.length - 1,
        reason: 'la alineación ya estaba (sin distinguir mayúsculas)',
      );
      expect(await provider.cargarServiciosComunes(), 0);
      expect(provider.items, hasLength(serviciosComunesManoDeObra.length));
      expect(
        provider.items.every(
          (i) => i.precioMax == null || i.precioMax! >= i.precio,
        ),
        isTrue,
      );
    });
  });

  test(
    'las sugerencias dependen de los vehículos que atiende el taller',
    () async {
      // Observación del 2026-09-20: «según la especialidad deberían tener
      // sugerencias predeterminadas del catálogo». Un taller de motos no
      // quiere un catálogo lleno de kits de embrague de coche, pero sí lo
      // común a todos (aceite, frenos, diagnóstico).
      final firestore = FakeFirebaseFirestore();
      final repo = CatalogoRepository(firestore: firestore);
      final provider = CatalogoProvider(repository: repo);
      provider.watchTaller('t1');
      await Future.delayed(Duration.zero);

      final n = await provider.cargarServiciosComunes(tipos: ['motocicleta']);
      await Future.delayed(Duration.zero);

      final nombres = provider.items.map((i) => i.nombre).toSet();
      expect(n, serviciosComunesPara(['motocicleta']).length);
      expect(nombres, contains('Ajuste y lubricación de cadena'));
      expect(nombres, contains('Cambio de aceite y filtro'));
      expect(
        nombres,
        isNot(contains('Purga y revisión de frenos de aire')),
        reason: 'eso es de camiones y autobuses',
      );
    },
  );

  test('sin tipos declarados se sugiere solo lo común', () {
    final comunes = serviciosComunesPara(const []);
    expect(comunes.length, serviciosComunesManoDeObra.length);
    expect(
      serviciosComunesPara(['camion']).length,
      greaterThan(comunes.length),
    );
  });

  test('un taller que atiende varios tipos no repite servicios', () {
    // Camión y autobús comparten «Purga y revisión de frenos de aire» y
    // «Cambio de aceite de motor diésel»: el catálogo no debe nacer con la
    // misma línea dos veces.
    final nombres = serviciosComunesPara([
      'camion',
      'autobus',
    ]).map((s) => s.nombre.toLowerCase()).toList();
    expect(nombres.length, nombres.toSet().length);
  });
}
