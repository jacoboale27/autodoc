import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';

void main() {
  test('agregarItem y watchCatalogo devuelven el ítem creado', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CatalogoRepository(firestore: firestore);

    await repo.agregarItem(
      idTaller: 't1',
      nombre: 'Cambio de aceite',
      precio: 25.0,
    );

    final items = await repo.watchCatalogo('t1').first;
    expect(items.length, 1);
    expect(items.first.nombre, 'Cambio de aceite');
    expect(items.first.precio, 25.0);
  });

  test('eliminarItem lo remueve del catálogo', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CatalogoRepository(firestore: firestore);
    final id = await repo.agregarItem(
      idTaller: 't1',
      nombre: 'Frenos',
      precio: 40.0,
    );

    await repo.eliminarItem('t1', id);

    final items = await repo.watchCatalogo('t1').first;
    expect(items, isEmpty);
  });
}
