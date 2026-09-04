// test/features/mechanic/presentation/pages/vehicle_search_mis_servicios_test.dart
//
// A4a: un mecanico se quejo de que los vehiculos que esta atendiendo no
// aparecen en "Buscar Vehiculo" a menos que el servicio se haya iniciado
// desde "mis vehiculos". El PDF conjeturaba un campo "origen" que filtraria
// la consulta — ese campo no existe. Ahora que `reparaciones` es la unica
// fuente de verdad (Tarea 4), la unica condicion real es `id_taller`: este
// archivo lo fija.
//
// Tambien cubre el camino de navegacion (revision de la Tarea 6): resolver
// el vehiculo del ticket por `idVehiculo`, no por placa — una placa
// duplicada o desactualizada en datos legados podria resolver a un vehiculo
// DISTINTO del que abrio el ticket, y `abrirVehiculoComoMecanico` navegaria
// en silencio a otra parte, sin ningun error visible. Y los estados de
// carga/error de `ReparacionProvider`, para que un stream que falla
// (permission-denied, ver el commit inmediato anterior a esta rama) no se
// confunda con "no hay servicios".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/vehicle_search_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

ReparacionModel _reparacionFake({
  required String idReparacion,
  required String placa,
  required String estado,
  String? idVehiculo,
}) {
  final ahora = DateTime.now();
  return ReparacionModel(
    idReparacion: idReparacion,
    idVehiculo: idVehiculo ?? 'v-$idReparacion',
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
/// pertenezcan al taller. [error]/[isLoading] simulan lo que expone el
/// stream real de `watchTaller` para probar que `_MisServicios` los
/// distingue de una lista vacía.
class _FakeReparacionProviderConLista extends FakeReparacionProvider {
  _FakeReparacionProviderConLista(
    this._lista, {
    String? error,
    bool isLoading = false,
  }) : _error = error,
       _isLoading = isLoading;

  final List<ReparacionModel> _lista;
  final String? _error;
  final bool _isLoading;

  @override
  List<ReparacionModel> get reparaciones => _lista;
  @override
  String? get error => _error;
  @override
  bool get isLoading => _isLoading;
}

/// Doble de `VehicleProvider` que resuelve por `idVehiculo` desde un mapa
/// fijo, y cuenta las llamadas a `findVehicleByPlate` — la resolución de
/// `_MisServicios` no debe pasar por ahí (ver el comentario de cabecera).
class _FakeVehicleProviderParaMisServicios extends FakeVehicleProvider {
  _FakeVehicleProviderParaMisServicios(this._porId) : super(const []);

  final Map<String, VehicleModel> _porId;
  int llamadasPorPlaca = 0;

  @override
  Future<VehicleModel?> findVehicleById(String idVehiculo) async =>
      _porId[idVehiculo];

  @override
  Future<VehicleModel?> findVehicleByPlate(String plate) async {
    llamadasPorPlaca++;
    return null;
  }
}

Future<void> _pumpBuscarVehiculo(
  WidgetTester tester, {
  required List<ReparacionModel> reparaciones,
  String? error,
  bool isLoading = false,
}) async {
  await pumpMechanicScreen(
    tester,
    const VehicleSearchScreen(),
    width: 400,
    location: '/mechanic_search',
    disableAnimations: true,
    extraProviders: [
      ChangeNotifierProvider<ReparacionProvider>.value(
        value: _FakeReparacionProviderConLista(
          reparaciones,
          error: error,
          isLoading: isLoading,
        ),
      ),
    ],
  );
  // `pumpAndSettle` no sirve para el caso "cargando": el spinner es una
  // animación indeterminada que nunca deja de reconstruirse, así que
  // `pumpAndSettle` agota su plazo esperando un frame estable que no llega.
  if (isLoading) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
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

  testWidgets(
    'mientras el stream carga sin datos previos, muestra un indicador de carga en vez de "sin servicios"',
    (tester) async {
      await _pumpBuscarVehiculo(
        tester,
        reparaciones: const [],
        isLoading: true,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No hay servicios activos'), findsNothing);
    },
  );

  testWidgets(
    'si el stream de reparaciones falla, muestra un error distinto de "sin servicios activos"',
    (tester) async {
      // El escenario real: un permission-denied en la consulta (ver el
      // commit inmediato anterior a esta rama, "fix(taller):
      // permission-denied al finalizar servicio"). Sin distinguirlo, el
      // mecanico ve "No hay servicios activos" cuando en realidad la
      // consulta fallo — el peor resultado posible para una lista que existe
      // para que confie en que ve TODO su trabajo.
      await _pumpBuscarVehiculo(
        tester,
        reparaciones: const [],
        error: 'permission-denied',
      );

      expect(find.text('No se pudieron cargar tus servicios'), findsOneWidget);
      expect(find.text('No hay servicios activos'), findsNothing);
    },
  );

  testWidgets(
    'al tocar un servicio, resuelve el vehiculo por idVehiculo (no por placa) y navega con abrirVehiculoComoMecanico',
    (tester) async {
      final vehicleProvider = _FakeVehicleProviderParaMisServicios({
        'v1': VehicleModel(
          idVehiculo: 'v1',
          idPropietario: 'p1',
          placa: 'P123456',
          marca: 'Toyota',
          modelo: 'Corolla',
          anio: 2020,
        ),
      });
      // `FakeReparacionProvider.buscarReparacionActiva` por defecto devuelve
      // 'r1' (su propio `reparacionActivaId`), asi que este ticket resuelve
      // a esa misma ruta — coherente con que 'r1' es tambien el ticket que
      // esta pantalla ya conoce por la lista.
      final reparacionProvider = _FakeReparacionProviderConLista([
        _reparacionFake(
          idReparacion: 'r1',
          idVehiculo: 'v1',
          placa: 'P123456',
          estado: 'recibido',
        ),
      ]);

      final router = await pumpMechanicScreen(
        tester,
        const VehicleSearchScreen(),
        width: 400,
        location: '/mechanic_search',
        disableAnimations: true,
        rutasExtra: const [
          '/initiate_service/:reparacionId',
          '/vehiculo_publico/:vehiculoId',
        ],
        extraProviders: [
          ChangeNotifierProvider<ReparacionProvider>.value(
            value: reparacionProvider,
          ),
          ChangeNotifierProvider<VehicleProvider>.value(value: vehicleProvider),
        ],
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('P123456'));
      await tester.tap(find.text('P123456'));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), '/initiate_service/r1');
      expect(
        vehicleProvider.llamadasPorPlaca,
        0,
        reason:
            'debe resolver por idVehiculo: una placa duplicada o legada '
            'podria resolver a un vehiculo distinto del que abrio el ticket',
      );
    },
  );

  testWidgets(
    'si el vehiculo del ticket no se encuentra por id, avisa y no navega a ningun lado',
    (tester) async {
      // El vehiculo referenciado por el ticket no existe (o fue borrado):
      // la resolucion por id debe fallar limpio con un aviso, nunca navegar
      // en silencio a otro vehiculo.
      final vehicleProvider = _FakeVehicleProviderParaMisServicios(const {});
      final reparacionProvider = _FakeReparacionProviderConLista([
        _reparacionFake(
          idReparacion: 'r5',
          idVehiculo: 'v-fantasma',
          placa: 'P555555',
          estado: 'recibido',
        ),
      ]);

      final router = await pumpMechanicScreen(
        tester,
        const VehicleSearchScreen(),
        width: 400,
        location: '/mechanic_search',
        disableAnimations: true,
        rutasExtra: const [
          '/initiate_service/:reparacionId',
          '/vehiculo_publico/:vehiculoId',
        ],
        extraProviders: [
          ChangeNotifierProvider<ReparacionProvider>.value(
            value: reparacionProvider,
          ),
          ChangeNotifierProvider<VehicleProvider>.value(value: vehicleProvider),
        ],
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('P555555'));
      await tester.tap(find.text('P555555'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se encontró el vehículo con placa P555555'),
        findsOneWidget,
      );
      expect(router.state.uri.toString(), '/mechanic_search');
    },
  );
}
