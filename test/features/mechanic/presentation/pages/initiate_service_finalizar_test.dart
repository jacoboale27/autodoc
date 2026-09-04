// test/features/mechanic/presentation/pages/initiate_service_finalizar_test.dart
//
// Cerrar un servicio cuando el vehiculo NO tiene tareas de mantenimiento
// configuradas. La propia pantalla promete, en ese caso, que "Puedes cerrar
// el servicio igualmente: quedara registrado en el historial"
// (_buildMaintenanceTasks), y `requiereTareaSeleccionada` deja pasar el
// submit sin ninguna casilla marcada.
//
// Los dos tests de aqui cubren lo que esa promesa implica: que el servicio
// se escriba, y que la pantalla tenga a donde ir despues.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/mechanic_harness.dart';

/// `AlertProvider` real —los metodos de escritura son los de produccion, que
/// es lo que estos tests comprueban— pero con la lista de tareas de
/// mantenimiento SIEMPRE vacia.
///
/// No es una comodidad de test: es el estado real del cliente del mecanico
/// ante un vehiculo de paso. `firestore.rules:738-748` solo deja LEER
/// `mantenimientos` al propietario, a un taller ya vinculado o a un admin, y
/// solo deja CREARLOS al propietario o a un admin. Ante un walk-in sin
/// vinculo previo, el `fetchAlerts` del mecanico se topa con
/// permission-denied —tanto en la consulta como en el `createDefaultTasks`
/// que intenta a continuacion—, se lo traga en su `catch`, y la pantalla
/// acaba con cero tareas y el cartel de "este vehiculo no tiene tareas de
/// mantenimiento configuradas".
///
/// `FakeFirebaseFirestore` no aplica reglas, asi que sin este doble
/// `createDefaultTasks` triunfa, aparecen tareas por defecto y el escenario
/// que rompe en produccion no llega a darse.
class AlertProviderSinTareas extends AlertProvider {
  AlertProviderSinTareas({required super.firestore, required super.storage});

  @override
  List<MaintenanceTask> get maintenanceTasks => const [];
}

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

  late FakeFirebaseFirestore db;

  Future<GoRouter> pumpPantalla(WidgetTester tester) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    // `AlertProvider` propio para poder inspeccionar lo que se escribio.
    // Sin tareas cargadas, `maintenanceTasks` queda vacio: el escenario
    // exacto que describe el texto de la pantalla.
    db = FakeFirebaseFirestore();
    final router = await pumpMechanicScreen(
      tester,
      InitiateServiceScreen(
        vehiculoId: 'v1',
        vehiculoPrecargado: _vehiculoFake(),
      ),
      width: 1024,
      location: '/initiate_service/v1',
      disableAnimations: true,
      rutasExtra: const [
        '/mechanic_dashboard',
        '/mechanic_reparaciones',
        '/service_finalized',
      ],
      extraProviders: [
        ChangeNotifierProvider<AlertProvider>.value(
          value: AlertProviderSinTareas(
            firestore: db,
            storage: MockFirebaseStorage(),
          ),
        ),
      ],
    );
    await tester.pump();
    return router;
  }

  Future<void> pulsarFinalizar(WidgetTester tester) async {
    final boton = find.text('FINALIZAR SERVICIO');
    expect(boton, findsOneWidget);
    await tester.ensureVisible(boton);
    await tester.tap(boton, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sin tareas de mantenimiento, FINALIZAR SERVICIO registra el servicio',
    (tester) async {
      await pumpPantalla(tester);
      await pulsarFinalizar(tester);

      final servicios = await db
          .collection(FirestoreCollections.servicios)
          .get();

      expect(
        servicios.docs,
        isNotEmpty,
        reason:
            'la pantalla promete que el servicio "quedara registrado en el '
            'historial" aunque no haya tareas que marcar; sin un documento '
            'en `servicios` no lo ve ni el taller ni el propietario, y la '
            'Cloud Function que actualiza el kilometraje nunca se dispara',
      );
    },
  );

  testWidgets(
    'al finalizar se navega a una pantalla real, no se desapila una pila '
    'vacia (que dejaba la vista en blanco)',
    (tester) async {
      final router = await pumpPantalla(tester);
      await pulsarFinalizar(tester);

      expect(
        tester.takeException(),
        isNull,
        reason:
            'a esta pantalla se llega con `context.go`, que reemplaza la '
            'pila: desapilar la vacia y go_router deja de pintar nada',
      );
      expect(
        router.state.uri.toString(),
        isNot('/initiate_service/v1'),
        reason:
            'quedarse en esta URL es exactamente el sintoma: pantalla en '
            'blanco con el id del vehiculo todavia en la barra',
      );
      expect(
        find.byType(InitiateServiceScreen),
        findsNothing,
        reason: 'el servicio ya se cerro; la pantalla no debe seguir montada',
      );
    },
  );
}
