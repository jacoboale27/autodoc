// test/features/mechanic/presentation/pages/mechanic_service_history_responsive_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_service_history_screen.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> seedServicios({int count = 4}) async {
  final firestore = FakeFirebaseFirestore();
  for (var i = 0; i < count; i++) {
    await firestore.collection('servicios').doc('s$i').set({
      'id_taller': 't1',
      'tipo_servicio': 'Cambio de aceite $i',
      'fecha': DateTime(2026, 7, 10 + i),
      'kilometraje_servicio': 50000 + i,
      'costo': 45.0 + i,
    });
  }
  return firestore;
}

Future<void> pumpHistorial(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
  Brightness brightness = Brightness.light,
}) async {
  await pumpMechanicScreen(
    tester,
    MechanicServiceHistoryScreen(firestore: firestore),
    width: width,
    location: '/mechanic_service_history',
    brightness: brightness,
    disableAnimations: true,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('los servicios se distribuyen en rejilla en escritorio', (
    tester,
  ) async {
    final firestore = await seedServicios();
    await pumpHistorial(tester, width: 1440, firestore: firestore);

    expect(find.byType(AppGrid), findsOneWidget);
    final lefts = tester
        .widgetList<Text>(find.textContaining('Cambio de aceite'))
        .map((t) => tester.getTopLeft(find.text(t.data!)).dx)
        .toSet();
    expect(lefts.length, greaterThan(1));
  });

  testWidgets('sin servicios muestra AppEmptyState', (tester) async {
    final firestore = await seedServicios(count: 0);
    await pumpHistorial(tester, width: 375, firestore: firestore);

    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('no desborda en ninguno de los anchos de auditoria', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedServicios();
      await pumpHistorial(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  test('el selector de fechas no fuerza un ColorScheme claro', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/'
      'mechanic_service_history_screen.dart',
    ).readAsStringSync();

    expect(
      source.contains('ColorScheme.light('),
      isFalse,
      reason: 'con la app en oscuro el selector salia en claro',
    );
    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('Colors.grey'), isFalse);
    expect(source.contains('SizedBox(width: 380)'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
  });
}
