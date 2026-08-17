import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

VehicleModel vehiculoFake() => VehicleModel(
  idVehiculo: 'v1',
  idPropietario: 'p1',
  placa: 'ABC123',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2020,
  kilometrajeActual: 50000,
);

void main() {
  // `_onVehiculoListo` consulta 'cotizaciones' con `FirebaseFirestore.
  // instance` directamente (no inyectable: es lógica de negocio fuera del
  // alcance de este pase, no se toca). Sin una app Firebase '[DEFAULT]'
  // registrada, ese getter lanza de forma síncrona antes de que el widget
  // termine de montar. `setupFirebaseCoreMocks()` + `Firebase.initializeApp()`
  // registran una app falsa por canal de método (mismo patrón que
  // `dashboard_screen_vehicle_fetch_test.dart`); la consulta real que se
  // dispara después es un `.then()` sin `await` que nunca resuelve
  // (`MissingPluginException` capturada en su propio Future, no observada por
  // el test), así que no afecta las aserciones de layout.
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  Future<void> pumpServicio(WidgetTester tester, double width) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await pumpMechanicScreen(
      tester,
      InitiateServiceScreen(
        vehiculoId: 'v1',
        vehiculoPrecargado: vehiculoFake(),
      ),
      width: width,
      location: '/initiate_service/v1',
      disableAnimations: true,
    );
    await tester.pump();
  }

  testWidgets('a 1440 px el formulario usa dos columnas', (tester) async {
    await pumpServicio(tester, 1440);

    final km = tester.getTopLeft(find.text('KILOMETRAJE DE INGRESO')).dx;
    final costo = tester.getTopLeft(find.text('COSTO DEL SERVICIO (TOTAL)')).dx;
    expect(
      costo,
      greaterThan(km + 100),
      reason: 'el bloque de facturación va en la segunda columna',
    );
  });

  testWidgets('a 375 px es una sola columna', (tester) async {
    await pumpServicio(tester, 375);

    final km = tester.getTopLeft(find.text('KILOMETRAJE DE INGRESO'));
    final costo = tester.getTopLeft(find.text('COSTO DEL SERVICIO (TOTAL)'));
    expect(costo.dx, closeTo(km.dx, 1));
    expect(costo.dy, greaterThan(km.dy));
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pumpServicio(tester, width);
      expectNoOverflow(tester);
    }
  });

  test('el fichero usa el design system, no su propia versión', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/initiate_service_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('Colors.white'), isFalse);
    expect(
      source.contains('_getStatusIcon'),
      isFalse,
      reason: 'la severidad la resuelve AppSeverity, quinta copia eliminada',
    );
    expect(
      source.contains('class _BoxedField'),
      isTrue,
      reason: 'los tres campos con caja idéntica se escriben una vez',
    );
  });
}
