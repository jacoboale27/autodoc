// test/features/mechanic/presentation/pages/initiate_service_ticket_test.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../../../support/mechanic_harness.dart';

/// Vehículo con `id_propietario` no vacío, igual que
/// `initiate_service_responsive_test.dart`: así
/// `_iniciarTicketReparacion` toma la rama `iniciarOReutilizar` (escribe
/// directo) en vez de `iniciarOReutilizarPorVehiculo` (pasa por un
/// `httpsCallable` que este harness no mockea). Cuál de las dos ramas se usa
/// no es lo que este test verifica; lo que importa es cuándo se llama, no
/// asociada a un `id_propietario` en particular.
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
  // `_onVehiculoListo` consulta 'cotizaciones' con `FirebaseFirestore.
  // instance` directamente (no inyectable). Mismo setup que
  // `initiate_service_responsive_test.dart` para que ese getter no lance
  // antes de que el widget termine de montar.
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  Future<FakeReparacionProvider> pumpInitiateService(
    WidgetTester tester,
  ) async {
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
        // Va después del `ReparacionProvider` real que ya registra
        // `pumpMechanicScreen`: en `MultiProvider`, el último de la lista es
        // el más cercano en el árbol y gana sobre el anterior del mismo tipo.
        ChangeNotifierProvider<ReparacionProvider>.value(value: repo),
      ],
    );
    // El postFrameCallback de `initState` (que llama a `_onVehiculoListo`)
    // ya corrió como parte de `pumpMechanicScreen`; este pump aplica el
    // `setState` que suelta `_cargando` y muestra la pantalla completa. Mismo
    // patrón que `initiate_service_responsive_test.dart`.
    await tester.pump();
    return repo;
  }

  testWidgets('abrir la pantalla de servicio NO crea el ticket de reparación; '
      'el botón "Recibir vehículo" sí', (tester) async {
    final repo = await pumpInitiateService(tester);

    expect(
      repo.llamadasIniciar,
      0,
      reason:
          'buscar una placa es una consulta: no puede escribir un '
          'ticket ni notificar al propietario sin que el taller confirme',
    );
    expect(
      find.text('Recibir vehículo'),
      findsOneWidget,
      reason:
          'sin ticket ni error, la pantalla debe ofrecer el botón de '
          'confirmación explícita',
    );

    await tester.tap(find.text('Recibir vehículo'));
    await tester.pump();
    await tester.pump();

    expect(repo.llamadasIniciar, 1);
    expect(
      find.text('Vehículo recibido: ya aparece en Reparaciones.'),
      findsOneWidget,
    );
  });
}
