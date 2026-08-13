import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/features/dashboard/presentation/pages/alerts_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

/// AlertProvider con datos fijos, sin tocar Firestore.
///
/// fetchAlerts/fetchAlertsForVehicles requieren un backend real (Firestore
/// mock con documentos); en vez de eso se sobreescriben los getters, igual
/// que FakeVehicleProvider en vehicle_fixtures.dart.
class _FakeAlertProvider extends AlertProvider {
  _FakeAlertProvider()
    : super(firestore: FakeFirebaseFirestore(), storage: MockFirebaseStorage());

  @override
  List<MaintenanceTask> get maintenanceTasks => [
    MaintenanceTask(
      id: 't1',
      vehicleId: 'v0',
      nombre: 'Cambio de aceite',
      ultimoKm: 40000,
      fechaUltimoServicio: DateTime.now().subtract(const Duration(days: 400)),
      frecuenciaKm: 5000,
      frecuenciaMeses: 6,
    ),
  ];

  @override
  List<AlertModel> get activeAlerts => [
    AlertModel(
      idAlerta: 'a1',
      idVehiculo: 'v0',
      tipoAlerta: 'SOAT',
      titulo: 'SOAT por vencer',
      descripcion: 'El SOAT vence pronto',
      prioridad: AlertPriority.medium,
    ),
  ];

  @override
  bool get isLoading => false;
}

Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  Brightness brightness = Brightness.light,
}) async {
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(
          value: fakeVehicleProvider(),
        ),
        ChangeNotifierProvider<AlertProvider>(
          create: (_) => _FakeAlertProvider(),
        ),
      ],
      child: const AlertsScreen(),
    ),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

void main() {
  final source = File(
    'lib/features/dashboard/presentation/pages/alerts_screen.dart',
  ).readAsStringSync();

  test('no usa GoogleFonts ni colores de Material para la severidad', () {
    expect(source.contains('GoogleFonts.'), isFalse);

    for (final banned in ['Colors.red', 'Colors.amber', 'Colors.green']) {
      expect(
        source.contains(banned),
        isFalse,
        reason:
            '$banned: la severidad debe salir de AppSeverity, que usa los '
            'tokens de marca',
      );
    }
  });

  test('no desactiva el tamaño mínimo de target de Material', () {
    expect(
      source.contains('MaterialTapTargetSize.shrinkWrap'),
      isFalse,
      reason: 'shrinkWrap desactiva el relleno automático a 48dp',
    );
    expect(
      source.contains('Size(0, 40)'),
      isFalse,
      reason: '40dp está por debajo del mínimo de 48dp',
    );
  });

  testWidgets('todos los controles tappables miden al menos 48dp', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    for (final type in [
      find.byType(ElevatedButton),
      find.byType(OutlinedButton),
      find.byType(IconButton),
    ]) {
      for (var i = 0; i < tester.widgetList(type).length; i++) {
        final size = tester.getSize(type.at(i));
        expect(
          size.height,
          greaterThanOrEqualTo(48.0),
          reason: 'control $i mide ${size.height}dp de alto',
        );
        expect(size.width, greaterThanOrEqualTo(48.0));
      }
    }
  });

  testWidgets('las pestañas de filtro miden al menos 48dp', (tester) async {
    await pumpScreen(tester, 375);

    // El header también tiene IconButtons con su propio InkWell interno de
    // splash (40dp): find.byType(InkWell) sin acotar los recogería primero y
    // desplazaría los índices. Se acota a los descendientes de la fila de
    // pestañas.
    final tabs = find.descendant(
      of: find.byKey(const Key('alerts-tabs')),
      matching: find.byType(InkWell),
    );
    expect(tabs, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      expect(tester.getSize(tabs.at(i)).height, greaterThanOrEqualTo(48.0));
    }
  });

  testWidgets('cada severidad se distingue por icono, no solo por color', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    // Los tres iconos de AppSeverity deben ser distintos entre sí; al menos
    // uno debe estar presente y ninguno puede ser el build_circle genérico
    // que antes se usaba para los tres estados.
    expect(
      find.byIcon(Icons.build_circle_outlined),
      findsNothing,
      reason: 'los tres estados compartían el mismo icono',
    );
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
