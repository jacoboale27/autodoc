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
/// `initiate_service_responsive_test.dart`. Desde A4b la pantalla ya no se
/// bifurca por ese campo (no crea nada, solo transiciona un ticket que ya
/// existe), pero se mantiene el vehículo completo para no cambiar más de una
/// cosa a la vez respecto del resto de tests de esta pantalla.
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
    WidgetTester tester, {
    String? errorAlRecibir,
  }) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final repo = FakeReparacionProvider(errorAlRecibir: errorAlRecibir);
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

  testWidgets('"Recibir vehículo" transiciona el ticket, no lo crea', (
    tester,
  ) async {
    final repo = await pumpInitiateService(tester);

    expect(
      repo.llamadasRecibir,
      0,
      reason:
          'buscar una placa es una consulta: no puede mover el ticket ni '
          'notificar al propietario sin que el taller confirme',
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

    expect(repo.llamadasRecibir, 1);
    expect(
      repo.llamadasIniciar,
      0,
      reason:
          'desde A4b el ticket lo abre onCotizacionAceptada: la pantalla no '
          'puede crear ninguno (firestore.rules ya lo prohíbe, así que '
          'hacerlo sería un permission-denied en producción)',
    );
    expect(
      find.text('Vehículo recibido: ya aparece en Reparaciones.'),
      findsOneWidget,
    );
  });

  testWidgets('sin cotización aceptada no se recibe nada: se explica por qué', (
    tester,
  ) async {
    // El caso que A3/B2 quiere impedir. El ticket solo existe si el cliente
    // aceptó una cotización, así que aquí el provider no encuentra ninguno.
    const mensaje =
        'Este vehículo no tiene una cotización aceptada en tu taller, '
        'así que todavía no hay nada que recibir.';
    final repo = await pumpInitiateService(tester, errorAlRecibir: mensaje);

    await tester.tap(find.text('Recibir vehículo'));
    await tester.pump();
    await tester.pump();

    expect(repo.llamadasIniciar, 0);
    expect(find.text(mensaje), findsOneWidget);
    expect(
      find.text('Vehículo recibido: ya aparece en Reparaciones.'),
      findsNothing,
    );
  });
}
