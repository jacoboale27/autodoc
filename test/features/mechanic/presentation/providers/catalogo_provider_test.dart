import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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
}
