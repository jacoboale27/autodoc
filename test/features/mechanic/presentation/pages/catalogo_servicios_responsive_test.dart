import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/catalogo_servicios_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> seedCatalogo({int count = 6}) async {
  final firestore = FakeFirebaseFirestore();
  for (var i = 0; i < count; i++) {
    await firestore
        .collection('talleres')
        .doc('t1')
        .collection('catalogo_servicios')
        .doc('i$i')
        .set({'nombre': 'Cambio de aceite $i', 'precio': 25.0 + i});
  }
  return firestore;
}

Future<void> pumpCatalogo(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
}) async {
  await pumpMechanicScreen(
    tester,
    const CatalogoServiciosScreen(idTaller: 't1'),
    width: width,
    location: '/mechanic/catalogo',
    disableAnimations: true,
    extraProviders: [
      ChangeNotifierProvider(
        create: (_) => CatalogoProvider(
          repository: CatalogoRepository(firestore: firestore),
        ),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('los ítems se distribuyen en rejilla, no en una sola columna', (
    tester,
  ) async {
    final firestore = await seedCatalogo();
    await pumpCatalogo(tester, width: 1440, firestore: firestore);

    expect(find.byType(AppGrid), findsOneWidget);

    final lefts = tester
        .widgetList<Text>(find.textContaining('Cambio de aceite'))
        .map((t) => tester.getTopLeft(find.text(t.data!)).dx)
        .toSet();
    expect(
      lefts.length,
      greaterThan(1),
      reason: 'a 1440 px debe haber más de una columna',
    );
  });

  testWidgets('el estado vacío usa AppEmptyState', (tester) async {
    final firestore = await seedCatalogo(count: 0);
    await pumpCatalogo(tester, width: 375, firestore: firestore);

    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('el botón de borrar se anuncia', (tester) async {
    final firestore = await seedCatalogo(count: 1);
    await pumpCatalogo(tester, width: 375, firestore: firestore);

    final boton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.delete_outline),
    );
    expect(boton.tooltip, isNotNull);
    expect(boton.tooltip, contains('Eliminar'));
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedCatalogo();
      await pumpCatalogo(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  test('el fichero no usa GoogleFonts ni el breakpoint de 700', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
    expect(source.contains('MechanicSidebar'), isFalse);
  });
}
