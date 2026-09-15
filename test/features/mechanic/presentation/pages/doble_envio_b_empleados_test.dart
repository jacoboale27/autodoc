import 'dart:async';

import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/empleados_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../../support/mechanic_harness.dart';

class _EmpleadoProviderPendiente extends EmpleadoProvider {
  _EmpleadoProviderPendiente({required super.repository});

  final operacion = Completer<void>();
  int desactivaciones = 0;

  @override
  Future<void> desactivar(String idTaller, String idEmpleado) {
    desactivaciones++;
    return operacion.future;
  }
}

void main() {
  testWidgets('dos taps al desactivar inician una sola desactivacion', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('talleres')
        .doc('t1')
        .collection('empleados')
        .doc('e1')
        .set({
          'id_taller_propietario': 't1',
          'nombre_completo': 'Ana Ruiz',
          'correo': 'ana@taller.com',
          'rol': 'Mecanico',
          'activo': true,
        });
    final provider = _EmpleadoProviderPendiente(
      repository: EmpleadoRepository(firestore: firestore),
    );

    await pumpMechanicScreen(
      tester,
      const EmpleadosScreen(idTaller: 't1'),
      width: 900,
      location: '/empleados',
      extraProviders: [
        ChangeNotifierProvider<EmpleadoProvider>.value(value: provider),
      ],
    );
    await tester.pumpAndSettle();

    final desactivar = find.byTooltip('Desactivar a Ana Ruiz');
    await tester.tap(desactivar);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivar'));
    await tester.pump();

    // Con la primera desactivacion en vuelo el boton de la tarjeta esta
    // deshabilitado, asi que el dialogo de confirmacion ya no se reabre: eso
    // es lo que se afirma, no solo el contador.
    await tester.tap(desactivar);
    await tester.pumpAndSettle();
    expect(find.text('Desactivar'), findsNothing);

    expect(provider.desactivaciones, 1);

    provider.operacion.complete();
    await tester.pumpAndSettle();
  });
}
