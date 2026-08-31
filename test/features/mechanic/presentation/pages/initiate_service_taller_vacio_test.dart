// test/features/mechanic/presentation/pages/initiate_service_taller_vacio_test.dart
//
// `_iniciarTicketReparacion` empezaba con un `return` pelado cuando el
// taller efectivo estaba vacio (perfil aun no cargado). El usuario pulsaba
// "Recibir vehiculo" y no pasaba NADA: ni ticket, ni mensaje, ni spinner.
// La pantalla ya tiene un banner de error con boton "Reintentar"; esa es la
// salida correcta.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

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
    'si el taller efectivo esta vacio, "Recibir vehiculo" avisa en vez de '
    'no hacer nada',
    (tester) async {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final repo = FakeReparacionProvider();
      await pumpMechanicScreen(
        tester,
        InitiateServiceScreen(
          vehiculoId: 'v1',
          vehiculoPrecargado: _vehiculoFake(),
        ),
        width: 1024,
        location: '/initiate_service/v1',
        disableAnimations: true,
        extraProviders: [
          ChangeNotifierProvider<ReparacionProvider>.value(value: repo),
          // Perfil sin cargar: `userData?.idTallerEfectivo ?? ''` da ''.
          // Va el ultimo, asi que gana sobre el del harness.
          ChangeNotifierProvider<UserProfileProvider>(
            create: (_) => FakeUserProfileProvider(),
          ),
        ],
      );
      await tester.pump();

      expect(find.text('Recibir vehículo'), findsOneWidget);

      await tester.tap(find.text('Recibir vehículo'));
      await tester.pump();
      await tester.pump();

      expect(
        repo.llamadasIniciar,
        0,
        reason: 'sanity: sin taller no se puede escribir el ticket',
      );
      expect(
        find.text('Reintentar'),
        findsOneWidget,
        reason:
            'el boton no puede quedarse mudo: hay que mostrar el banner de '
            'error con reintento en vez de un return pelado',
      );
    },
  );
}
