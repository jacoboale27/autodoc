import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/shell_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

// DashboardScreen._buildNearbyServices instancia WorkshopService()
// directamente en build() (no inyectable) y su constructor toca
// FirebaseFirestore.instance. setupFirebaseCoreMocks() + Firebase.
// initializeApp() registran una app Firebase "[DEFAULT]" falsa (mismo patrón
// que dashboard_screen_vehicle_fetch_test.dart) para que ese getter no lance.
Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  Brightness brightness = Brightness.light,
}) async {
  await Firebase.initializeApp();
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(
          value: fakeVehicleProvider(),
        ),
        ChangeNotifierProvider<AlertProvider>(
          create: (_) => AlertProvider(
            firestore: FakeFirebaseFirestore(),
            storage: MockFirebaseStorage(),
          ),
        ),
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: FakeProfileProvider('Propietario'),
        ),
        ChangeNotifierProvider<NotificationCenterProvider>(
          create: (_) =>
              NotificationCenterProvider(firestore: FakeFirebaseFirestore()),
        ),
      ],
      child: const DashboardScreen(),
    ),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  test('no usa GoogleFonts ni colores literales', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/dashboard_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);

    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('//')) continue;
      if (lines[i].contains('Colors.transparent')) continue;
      if (RegExp(
        r'Color\(0x[0-9a-fA-F]{8}\)|Colors\.(white|black|grey|red)',
      ).hasMatch(lines[i])) {
        offenders.add('${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no queda ninguna URL externa hardcodeada', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/dashboard_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('w3schools.com'),
      isFalse,
      reason:
          'el avatar por defecto apunta a un dominio de terceros: '
          'falla sin red y filtra una petición a un host externo',
    );
  });

  testWidgets('compact y medium usan una sola columna', (tester) async {
    for (final width in [375.0, 768.0]) {
      await pumpScreen(tester, width);
      expect(
        find.byKey(const Key('dashboard-two-column')),
        findsNothing,
        reason: 'dos columnas a $width px',
      );
    }
  });

  testWidgets('expanded y large usan dos columnas', (tester) async {
    for (final width in [1024.0, 1440.0]) {
      await pumpScreen(tester, width);
      expect(
        find.byKey(const Key('dashboard-two-column')),
        findsOneWidget,
        reason: 'una sola columna a $width px',
      );
    }
  });

  testWidgets('el FAB lo gestiona el Scaffold, no un Positioned a mano', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(
      scaffold.floatingActionButton,
      isNotNull,
      reason:
          'un FAB en Positioned(bottom: 100) se solapa con la barra de '
          'navegación en cuanto cambia su altura',
    );
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
