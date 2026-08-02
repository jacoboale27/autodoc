import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';

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
}
