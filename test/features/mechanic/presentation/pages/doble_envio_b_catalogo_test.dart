import 'dart:async';

import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/catalogo_servicios_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../../support/mechanic_harness.dart';

class _CatalogoRepositoryPendiente extends CatalogoRepository {
  _CatalogoRepositoryPendiente({required super.firestore});

  final operacion = Completer<void>();
  int eliminaciones = 0;

  @override
  Future<void> eliminarItem(String idTaller, String idItem) {
    eliminaciones++;
    return operacion.future;
  }
}

void main() {
  testWidgets('dos taps al eliminar un item inician una sola eliminacion', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('talleres')
        .doc('t1')
        .collection('catalogo_servicios')
        .doc('item1')
        .set({'id_taller': 't1', 'nombre': 'Aceite', 'precio': 25});
    final repository = _CatalogoRepositoryPendiente(firestore: firestore);
    final provider = CatalogoProvider(repository: repository);

    await pumpMechanicScreen(
      tester,
      const CatalogoServiciosScreen(idTaller: 't1'),
      width: 900,
      location: '/catalogo',
      extraProviders: [
        ChangeNotifierProvider<CatalogoProvider>.value(value: provider),
      ],
    );
    await tester.pumpAndSettle();

    final eliminar = find.byTooltip('Eliminar Aceite del catálogo');
    await tester.tap(eliminar);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pump();

    // Con la primera eliminacion en vuelo el boton de la tarjeta esta
    // deshabilitado, asi que el dialogo de confirmacion ya no se reabre: eso
    // es lo que se afirma, no solo el contador.
    await tester.tap(eliminar);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Eliminar'), findsNothing);

    expect(repository.eliminaciones, 1);

    repository.operacion.complete();
    await tester.pumpAndSettle();
  });
}
