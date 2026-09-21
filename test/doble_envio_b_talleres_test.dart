import 'dart:async';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/talleres_con_acceso_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/test_helpers.mocks.dart';
import 'support/responsive_harness.dart';

class _Revocaciones extends VehicleProvider {
  _Revocaciones() : super(vehicleService: MockVehicleService());

  Completer<bool> pendiente = Completer<bool>();
  final llamadas = <(String, String)>[];

  @override
  Future<bool> revocarAccesoTaller(String vehiculoId, String tallerId) {
    llamadas.add((vehiculoId, tallerId));
    return pendiente.future;
  }
}

void main() {
  testWidgets('retirar acceso no repite la llamada mientras sigue pendiente', (
    tester,
  ) async {
    final provider = _Revocaciones();
    await pumpAtWidth(
      tester,
      ChangeNotifierProvider<VehicleProvider>.value(
        value: provider,
        child: TalleresConAccesoCard(
          vehicle: VehicleModel(
            idVehiculo: 'v1',
            idPropietario: 'u1',
            placa: 'ABC123',
            kilometrajeActual: 1000,
            talleresVinculados: const ['t1'],
          ),
          resolverTaller: (_) async => {'nombre_taller': 'Taller uno'},
        ),
      ),
      width: 800,
      disableAnimations: true,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, retirar'));
    await tester.pumpAndSettle();

    // La tarjeta sigue montada: se intenta repetir el mismo flujo mientras
    // la primera escritura está pendiente, confirmando si abre otro diálogo.
    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();
    if (find.text('Sí, retirar').evaluate().isNotEmpty) {
      await tester.tap(find.text('Sí, retirar'));
      await tester.pumpAndSettle();
    }
    expect(provider.llamadas, [('v1', 't1')]);
    provider.pendiente.complete(true);
    await tester.pumpAndSettle();
  });
}
