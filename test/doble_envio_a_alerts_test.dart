import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/pages/alerts_screen.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'helpers/test_helpers.mocks.dart';
import 'support/vehicle_fixtures.dart';
import 'support/responsive_harness.dart';
import 'support/shell_harness.dart';

class _Vehicles extends FakeVehicleProvider {
  _Vehicles() : super([fakeVehicle(0)]);
  final pending = Completer<void>();
  int calls = 0;
  @override
  Future<void> updateVehicleMileage(String id, int km) {
    calls++;
    return pending.future;
  }
}

class _Alerts extends AlertProvider {
  _Alerts()
    : super(firestore: FakeFirebaseFirestore(), storage: MockFirebaseStorage());
  @override
  Future<void> fetchAlertsForVehicles(List<VehicleModel> vehicles) async {}
}

void main() {
  testWidgets('grupo 7: guardar kilometraje llama una vez con dos taps', (
    tester,
  ) async {
    final vehicles = _Vehicles();
    await pumpAtWidth(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<VehicleProvider>.value(value: vehicles),
          ChangeNotifierProvider<AlertProvider>.value(value: _Alerts()),
          ChangeNotifierProvider<UserProfileProvider>.value(
            value: FakeProfileProvider('Propietario'),
          ),
        ],
        child: const AlertsScreen(),
      ),
      width: 800,
    );
    await tester.pumpAndSettle();
    // Los dos disparadores del dialogo son IconButton con tooltip, no texto.
    await tester.tap(find.byTooltip('Actualizar Kilometraje').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '51000');
    final button = find.text('Guardar');
    await tester.tap(button);
    await tester.tap(button);
    expect(vehicles.calls, 1);
    vehicles.pending.complete();
    await tester.pumpAndSettle();
  });
}
