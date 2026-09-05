// test/features/chat/presentation/widgets/cotizacion_form_test.dart
//
// B1: la lista de renglones de material (nombre/material, cantidad, costo)
// es la única pieza genuinamente idéntica entre `CotizacionPicker` (chat) e
// `InitiateServiceScreen` (buscar vehículo) — ver task-7-report.md. Este test
// no reproduce el "test de paridad" del brief (asumía un `CotizacionForm`
// con `onSubmit(CotizacionModel)` y claves que no existen en ninguno de los
// dos lados): en su lugar comprueba la forma que sí se construyó — que
// ambos call sites montan `CotizacionItemsForm`, y que su campo de dinero
// rechaza letras.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/chat/presentation/widgets/cotizacion_form.dart';
import 'package:autodoc/features/chat/presentation/widgets/cotizacion_picker.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/chat_harness.dart';
import '../../../../support/mechanic_harness.dart';

VehicleModel _vehiculoFake() => VehicleModel(
  idVehiculo: 'v1',
  idPropietario: 'p1',
  placa: 'ABC123',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2020,
  kilometrajeActual: 50000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  testWidgets(
    'CotizacionPicker (chat) monta CotizacionItemsForm y su campo de costo '
    'rechaza letras',
    (tester) async {
      await pumpChatWidget(
        tester,
        CotizacionPicker(onConfirm: (_, _) async {}),
        width: 500,
      );

      expect(find.byType(CotizacionItemsForm), findsOneWidget);

      final campoCosto = find.byKey(const Key('cotizacion_item_costo_0'));
      expect(campoCosto, findsOneWidget);

      await tester.enterText(campoCosto, 'abc');
      await tester.pump();
      expect(
        tester.widget<TextFormField>(campoCosto).controller!.text,
        isEmpty,
        reason:
            'montoInputFormatters debe rechazar letras y conservar el valor '
            'anterior (vacío en este caso), igual que antes del refactor.',
      );
    },
  );

  testWidgets(
    'InitiateServiceScreen (buscar vehículo, sin cotización aprobada) monta '
    'CotizacionItemsForm y su campo de costo rechaza letras',
    (tester) async {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final db = FakeFirebaseFirestore();
      await pumpMechanicScreen(
        tester,
        InitiateServiceScreen(
          reparacionId: 'r1',
          vehiculoPrecargado: _vehiculoFake(),
        ),
        width: 1024,
        location: '/initiate_service/r1',
        disableAnimations: true,
        rutasExtra: const [
          '/mechanic_dashboard',
          '/mechanic_reparaciones',
          '/service_finalized',
        ],
        extraProviders: [
          ChangeNotifierProvider<AlertProvider>.value(
            value: AlertProvider(firestore: db, storage: MockFirebaseStorage()),
          ),
          ChangeNotifierProvider<ReparacionProvider>.value(
            value: FakeReparacionProvider(),
          ),
        ],
      );
      await tester.pump();

      expect(find.byType(CotizacionItemsForm), findsOneWidget);

      // Sin materiales agregados todavía, la lista de renglones empieza
      // vacía (a diferencia de CotizacionPicker, que exige al menos uno):
      // hay que agregar un renglón antes de poder tocar su campo de costo.
      await tester.tap(find.text('Agregar renglón'));
      await tester.pump();

      final campoCosto = find.byKey(const Key('cotizacion_item_costo_0'));
      expect(campoCosto, findsOneWidget);

      await tester.enterText(campoCosto, 'abc');
      await tester.pump();
      expect(
        tester.widget<TextFormField>(campoCosto).controller!.text,
        isEmpty,
      );
    },
  );
}
