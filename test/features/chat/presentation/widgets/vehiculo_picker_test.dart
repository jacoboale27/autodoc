import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/features/chat/presentation/widgets/vehiculo_picker.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import '../../../../support/chat_harness.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

void _noop(Map<String, dynamic> _) {}

/// `VehiculoPicker` no recibe `VehicleProvider` de `pumpChatWidget` (el
/// harness común del módulo `chat` no lo registra: solo lo consume esta
/// pantalla). Se inyecta aquí mismo, envolviendo el widget bajo prueba, con
/// el mismo `FakeVehicleProvider` que ya usa `garage_screen_test.dart`.
Widget _withVehicleProvider(VehicleProvider provider, Widget child) {
  return ChangeNotifierProvider<VehicleProvider>.value(
    value: provider,
    child: child,
  );
}

void main() {
  testWidgets('el sheet no es más alto que la ventana en horizontal', (
    tester,
  ) async {
    // Container(height: 400) en un teléfono horizontal (alto 375) produce un
    // sheet más alto que la pantalla.
    await pumpChatWidget(
      tester,
      _withVehicleProvider(
        fakeVehicleProvider(count: 3),
        const VehiculoPicker(userId: 'u1', onSelected: _noop),
      ),
      width: 812,
      height: 375,
    );
    final alto = tester.getSize(find.byType(VehiculoPicker)).height;
    expect(alto, lessThanOrEqualTo(375));
    expectNoOverflow(tester);
  });

  testWidgets('usa AppEmptyState cuando no hay vehículos', (tester) async {
    await pumpChatWidget(
      tester,
      _withVehicleProvider(
        FakeVehicleProvider(const []),
        const VehiculoPicker(userId: 'u1', onSelected: _noop),
      ),
      width: 375,
    );
    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('no desborda en ningún ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      await pumpChatWidget(
        tester,
        _withVehicleProvider(
          fakeVehicleProvider(count: 5),
          const VehiculoPicker(userId: 'u1', onSelected: _noop),
        ),
        width: width,
      );
      expectNoOverflow(tester);
    }
  });

  testWidgets('anuncia marca, modelo y placa como un solo renglón', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      _withVehicleProvider(
        fakeVehicleProvider(count: 1),
        const VehiculoPicker(userId: 'u1', onSelected: _noop),
      ),
      width: 375,
    );
    expect(
      find.bySemanticsLabel('Toyota Corolla, placa P000-123'),
      findsOneWidget,
    );
  });
}
