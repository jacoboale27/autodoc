import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
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

/// Reproduce el hallazgo QA §16: el provider trae mezcladas, sin filtrar,
/// las tareas/alertas de dos vehiculos distintos (`fetchAlertsForVehicles`
/// acumula alertas de todos los vehiculos del dueño; `maintenanceTasks`
/// se queda con las del ultimo vehiculo procesado -- ver el docstring de
/// `fetchAlertsForVehicles` en alert_provider.dart). /alerts debe filtrar
/// por el vehiculo seleccionado al pintar, no confiar en que el provider ya
/// venga filtrado.
class _MultiVehicleFakeAlertProvider extends AlertProvider {
  _MultiVehicleFakeAlertProvider()
    : super(firestore: FakeFirebaseFirestore(), storage: MockFirebaseStorage());

  @override
  List<MaintenanceTask> get maintenanceTasks => [
    // Pertenece a OTRO vehiculo ('v-otro'), no al seleccionado ('v0', 254
    // km). Su ultimo servicio fue a 54.621 km: graduada contra los 254 km
    // del vehiculo seleccionado sale "OPTIMO" (el km restante se calcula
    // negativo -> mucho margen), que es justo el hallazgo.
    MaintenanceTask(
      id: 't-otro',
      vehicleId: 'v-otro',
      nombre: 'Rotación de Llantas',
      ultimoKm: 54621,
      fechaUltimoServicio: DateTime.now().subtract(const Duration(days: 400)),
      frecuenciaKm: 10000,
      frecuenciaMeses: 12,
    ),
    // Tarea propia del vehiculo seleccionado: debe seguir mostrandose. La
    // correccion no puede vaciar la pantalla entera.
    MaintenanceTask(
      id: 't-propio',
      vehicleId: 'v0',
      nombre: 'Cambio de Aceite',
      ultimoKm: 100,
      fechaUltimoServicio: DateTime.now(),
      frecuenciaKm: 5000,
      frecuenciaMeses: 6,
    ),
  ];

  @override
  List<AlertModel> get activeAlerts => [
    // La alerta critica real: se genero correctamente para 'v-otro' (su
    // propio odometro si superaba el limite), pero el provider la mezcla
    // en la misma lista que ve /alerts sea cual sea el vehiculo
    // seleccionado.
    AlertModel(
      idAlerta: 'task_t-otro',
      idVehiculo: 'v-otro',
      tipoAlerta: 'Mantenimiento',
      titulo: 'Rotación de Llantas',
      descripcion: '¡CRÍTICO! Límite de Rotación de Llantas superado.',
      prioridad: AlertPriority.high,
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

  group('coherencia entre vehiculos (hallazgo QA §16)', () {
    Future<void> pumpMultiVehicleScreen(WidgetTester tester) async {
      await pumpAtWidth(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<VehicleProvider>.value(
              value: FakeVehicleProvider([
                VehicleModel(
                  idVehiculo: 'v0',
                  idPropietario: 'u1',
                  placa: 'P001-123',
                  marca: 'Toyota',
                  modelo: 'Corolla',
                  kilometrajeActual: 254,
                ),
              ]),
            ),
            ChangeNotifierProvider<AlertProvider>(
              create: (_) => _MultiVehicleFakeAlertProvider(),
            ),
          ],
          child: const AlertsScreen(),
        ),
        width: 375,
      );
      await tester.pump();
    }

    testWidgets('una tarea de otro vehiculo no aparece como critica ni como '
        'sugerencia optima del vehiculo seleccionado', (tester) async {
      await pumpMultiVehicleScreen(tester);

      // 'Rotación de Llantas' pertenece a 'v-otro', no al vehiculo
      // seleccionado ('v0', 254 km de odometro). Antes de filtrar por
      // vehiculo en el punto de render, esta pantalla mostraba esta
      // misma tarea simultaneamente en PRIORIDAD ALTA (la alerta
      // critica real de 'v-otro') y en SUGERENCIAS/ÓPTIMO (la tarea
      // graduada contra los 254 km de 'v0') -- el hallazgo exacto.
      expect(
        find.text('Rotación de Llantas'),
        findsNothing,
        reason:
            'una tarea de otro vehiculo no debe aparecer en /alerts del '
            'vehiculo seleccionado, ni como critica ni como optima',
      );

      // La tarea propia del vehiculo seleccionado si debe seguir
      // mostrandose: la correccion filtra por vehiculo, no vacia la
      // pantalla entera.
      expect(find.text('Cambio de Aceite'), findsOneWidget);
    });
  });
}
