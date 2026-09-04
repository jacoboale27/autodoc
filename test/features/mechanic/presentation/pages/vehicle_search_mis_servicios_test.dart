// test/features/mechanic/presentation/pages/vehicle_search_mis_servicios_test.dart
//
// A4a: un mecanico se quejo de que los vehiculos que esta atendiendo no
// aparecen en "Buscar Vehiculo" a menos que el servicio se haya iniciado
// desde "mis vehiculos". El PDF conjeturaba un campo "origen" que filtraria
// la consulta — ese campo no existe. Ahora que `reparaciones` es la unica
// fuente de verdad (Tarea 4), la unica condicion real es `id_taller`: este
// archivo lo fija.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/features/mechanic/presentation/pages/vehicle_search_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../../../support/mechanic_harness.dart';

ReparacionModel _reparacionFake({
  required String idReparacion,
  required String placa,
  required String estado,
}) {
  final ahora = DateTime.now();
  return ReparacionModel(
    idReparacion: idReparacion,
    idVehiculo: 'v-$idReparacion',
    idTaller: 't1',
    idPropietario: 'p1',
    placa: placa,
    estado: estado,
    historialEstados: [
      {'estado': estado, 'timestamp': ahora},
    ],
    fechaCreacion: ahora,
    fechaActualizacion: ahora,
  );
}

/// Doble de `ReparacionProvider` con una lista fija de tickets — no importa
/// desde donde se haya "creado" cada uno (no hay tal campo), solo que
/// pertenezcan al taller.
class _FakeReparacionProviderConLista extends FakeReparacionProvider {
  _FakeReparacionProviderConLista(this._lista);

  final List<ReparacionModel> _lista;

  @override
  List<ReparacionModel> get reparaciones => _lista;
}

Future<void> _pumpBuscarVehiculo(
  WidgetTester tester, {
  required List<ReparacionModel> reparaciones,
}) async {
  await pumpMechanicScreen(
    tester,
    const VehicleSearchScreen(),
    width: 400,
    location: '/mechanic_search',
    disableAnimations: true,
    extraProviders: [
      ChangeNotifierProvider<ReparacionProvider>.value(
        value: _FakeReparacionProviderConLista(reparaciones),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'mis servicios lista las reparaciones del taller sin importar el origen',
    (tester) async {
      await _pumpBuscarVehiculo(
        tester,
        reparaciones: [
          _reparacionFake(
            idReparacion: 'r1',
            placa: 'P111111',
            estado: 'pendiente_recepcion',
          ),
          _reparacionFake(
            idReparacion: 'r2',
            placa: 'P222222',
            estado: 'recibido',
          ),
        ],
      );

      expect(find.text('Mis Servicios'), findsOneWidget);
      expect(find.text('P111111'), findsOneWidget);
      expect(find.text('P222222'), findsOneWidget);
    },
  );

  testWidgets(
    'un ticket cancelado no aparece en mis servicios (cuenta como sin ticket)',
    (tester) async {
      // Consistente con `ReparacionProvider.buscarReparacionActiva`: un
      // ticket `cancelado` es "no hay ticket" en toda la app. Listarlo aqui
      // y mandar a la vista publica al tocarlo seria inconsistente.
      await _pumpBuscarVehiculo(
        tester,
        reparaciones: [
          _reparacionFake(
            idReparacion: 'r3',
            placa: 'P333333',
            estado: 'cancelado',
          ),
          _reparacionFake(
            idReparacion: 'r4',
            placa: 'P444444',
            estado: 'en_revision',
          ),
        ],
      );

      expect(find.text('P333333'), findsNothing);
      expect(find.text('P444444'), findsOneWidget);
    },
  );

  testWidgets('sin servicios activos, muestra un estado vacio', (tester) async {
    await _pumpBuscarVehiculo(tester, reparaciones: const []);

    expect(find.text('No hay servicios activos'), findsOneWidget);
  });
}
