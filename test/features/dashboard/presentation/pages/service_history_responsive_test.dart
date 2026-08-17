import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:autodoc/features/dashboard/presentation/pages/service_history_screen.dart';

import '../../../../support/responsive_harness.dart';

// _buildReviewAction lee FirebaseAuth.instance.currentUser (registros no
// manuales), lo que exige una app Firebase "[DEFAULT]" registrada; mismo
// patrón que service_history_screen_test.dart.
Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  Brightness brightness = Brightness.light,
}) async {
  await Firebase.initializeApp();
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('servicios').add({
    'id_vehiculo': 'v0',
    'tipo_servicio': 'Cambio de aceite',
    'fecha': DateTime(2026, 6, 1),
    'costo': 45.0,
    'id_taller': 'Manual (Propietario)',
    'kilometraje_servicio': 51000,
  });

  await pumpAtWidth(
    tester,
    ServiceHistoryScreen(vehiculoId: 'v0', firestore: firestore),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  final source = File(
    'lib/features/dashboard/presentation/pages/service_history_screen.dart',
  ).readAsStringSync();

  test('no usa GoogleFonts ni colores fuera de la paleta', () {
    expect(source.contains('GoogleFonts.'), isFalse);
    for (final banned in ['Colors.blueGrey', 'Colors.green', 'Colors.grey']) {
      expect(source.contains(banned), isFalse, reason: banned);
    }
  });

  test('el date range picker no fuerza ColorScheme.light', () {
    expect(
      source.contains('ColorScheme.light('),
      isFalse,
      reason: 'sale en claro con la app en dark mode',
    );
  });

  test('el diálogo de detalle no tiene un ancho fijo mayor que 320', () {
    expect(
      RegExp(r'SizedBox\(\s*width:\s*380').hasMatch(source),
      isFalse,
      reason: 'un AlertDialog de 380px desborda a 320px de pantalla',
    );
  });

  testWidgets('las pestañas de filtro miden al menos 48dp', (tester) async {
    await pumpScreen(tester, 375);

    final tabs = find.byType(InkWell);
    for (var i = 0; i < 3; i++) {
      expect(tester.getSize(tabs.at(i)).height, greaterThanOrEqualTo(48.0));
    }
  });

  testWidgets('la lista se reparte en columnas en pantallas anchas', (
    tester,
  ) async {
    await pumpScreen(tester, 1440);
    expect(find.byType(GridView), findsWidgets);
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });
}
