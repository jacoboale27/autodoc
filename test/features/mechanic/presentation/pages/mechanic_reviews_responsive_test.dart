import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_reviews_screen.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> seedResenias({int count = 4}) async {
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('usuarios').doc('t1').set({
    'calificacion_promedio': 4.5,
    'total_resenias': count,
  });
  for (var i = 0; i < count; i++) {
    await firestore.collection('resenias').doc('r$i').set({
      'id_taller': 't1',
      'id_usuario': 'u$i',
      'estrellas': 5 - (i % 5),
      'comentario': 'Muy buen servicio $i',
      'fecha_resenia': DateTime(2026, 7, 1 + i),
      'fotos': <String>[],
    });
  }
  return firestore;
}

Future<void> pumpResenias(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
}) async {
  await pumpMechanicScreen(
    tester,
    MechanicReviewsScreen(firestore: firestore),
    width: width,
    location: '/mechanic_reviews',
    disableAnimations: true,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cada reseña anuncia su calificación', (tester) async {
    final firestore = await seedResenias(count: 1);
    await pumpResenias(tester, width: 375, firestore: firestore);

    expect(
      find.bySemanticsLabel(RegExp(r'5 de 5 estrellas')),
      findsOneWidget,
      reason: 'la calificación es el dato principal y solo se dibujaba',
    );
  });

  testWidgets('las reseñas se distribuyen en rejilla en escritorio', (
    tester,
  ) async {
    final firestore = await seedResenias();
    await pumpResenias(tester, width: 1440, firestore: firestore);

    expect(find.byType(AppGrid), findsOneWidget);
  });

  testWidgets('sin reseñas muestra AppEmptyState', (tester) async {
    final firestore = await seedResenias(count: 0);
    await pumpResenias(tester, width: 375, firestore: firestore);

    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedResenias();
      await pumpResenias(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  test('el fichero está tokenizado y la tarjeta está extraída', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart',
    ).readAsStringSync();

    expect(source.contains('Colors.red'), isFalse);
    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
    expect(source.contains('SizedBox(width: 30)'), isFalse);
    expect(
      source.contains('class _ReviewCard'),
      isTrue,
      reason: 'el itemBuilder de 290 líneas se extrae a su propio widget',
    );
  });
}
