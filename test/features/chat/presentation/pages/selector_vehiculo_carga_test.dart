import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../../support/chat_harness.dart';
import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/vehicle_fixtures.dart';

/// Un `VehicleProvider` que **empieza vacio**, como el de verdad.
///
/// Los dobles que ya habia (`FakeVehicleProvider`) nacen con la lista puesta,
/// y por ahi se colo el defecto: en produccion el provider se construye vacio
/// y solo lo llena quien llame a `fetchVehicles`/`asegurarVehiculosCargados`.
/// Entrando al chat por un enlace directo, una notificacion o un F5, nadie
/// habia llamado — el selector de «Nueva Reserva» decia «No tienes vehiculos
/// registrados» con el garaje lleno, y eso bloquea cita, cotizacion y ticket.
class _ProviderVacioHastaQueSePida extends VehicleProvider {
  _ProviderVacioHastaQueSePida(this._alCargar)
    : super(vehicleService: MockVehicleService());

  final List<VehicleModel> _alCargar;
  final List<VehicleModel> _vehiculos = [];
  var cargasPedidas = 0;
  var _cargando = false;

  @override
  List<VehicleModel> get vehicles => _vehiculos;

  @override
  bool get isLoading => _cargando;

  @override
  Future<void> asegurarVehiculosCargados(String ownerId) async {
    cargasPedidas++;
    // Igual que el real: marca cargando de forma SINCRONA antes de esperar.
    _cargando = true;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    _vehiculos
      ..clear()
      ..addAll(_alCargar);
    _cargando = false;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'el selector de vehiculos del chat carga el garaje por su cuenta',
    (tester) async {
      final vehiculos = _ProviderVacioHastaQueSePida([fakeVehicle(0)]);

      await pumpChatWidget(
        tester,
        const ChatScreen(conversacionId: 'c1'),
        width: 500,
        height: 1000,
        user: fakeChatUser(),
        extraProviders: [
          ChangeNotifierProvider<VehicleProvider>.value(value: vehiculos),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Adjuntar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Nueva Reserva'));
      await tester.pumpAndSettle();

      expect(
        vehiculos.cargasPedidas,
        greaterThan(0),
        reason:
            'el chat abrio el selector sin pedir el garaje: si nadie lo cargo '
            'antes, el selector no puede tener vehiculos que enseñar',
      );
      expect(
        find.text(fakeVehicle(0).placa),
        findsOneWidget,
        reason:
            'el selector no enseña el vehiculo del propietario, asi que no se '
            'puede agendar la cita',
      );
    },
  );
}
