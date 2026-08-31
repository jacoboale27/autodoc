// test/features/dashboard/presentation/pages/dashboard_screen_semaforo_test.dart
//
// Mismo mecanismo del hallazgo QA §16, vivo en otra pantalla: el semaforo
// de mantenimiento del dashboard (_buildMaintenanceSemaphore) gradua
// `provider.maintenanceTasks` contra el odometro del vehiculo SELECCIONADO.
// Si esas tareas pertenecen a otro vehiculo, el semaforo miente sobre el
// estado del vehiculo que el usuario tiene delante.
//
// Desde que `fetchAlertsForVehicles` FUSIONA las tareas de todos los
// vehiculos, `maintenanceTasks` trae las de todos mezcladas y el filtro por
// `vehicleId` del semaforo es lo unico que evita graduar una tarea ajena.
// Aqui se cubren los dos lados del contrato:
//   1. una tarea de OTRO vehiculo no decide el semaforo del seleccionado;
//   2. una tarea PROPIA si lo pinta, y con el estado correcto.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/shell_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

/// Tarea de OTRO vehiculo ('v-otro'), presente en la lista fusionada que
/// deja `fetchAlertsForVehicles`. Graduada contra el odometro de 'v0'
/// (6000 km: ultimo_km 100 + frecuencia 5000 -> kmRestantes < 0) daria
/// CRITICO; graduada contra su propio vehiculo seguiria optima.
final _tareaDeOtroVehiculo = MaintenanceTask(
  id: 't-otro',
  vehicleId: 'v-otro',
  nombre: 'Bujías',
  ultimoKm: 100,
  fechaUltimoServicio: DateTime.now(),
  frecuenciaKm: 5000,
  frecuenciaMeses: 24,
);

/// Tarea PROPIA de 'v0' (6000 km): ultimo_km 5900 -> kmRestantes 4900 y
/// dos años de margen temporal -> OPTIMO.
final _tareaPropia = MaintenanceTask(
  id: 't-propia',
  vehicleId: 'v0',
  nombre: 'Cambio de Aceite',
  ultimoKm: 5900,
  fechaUltimoServicio: DateTime.now(),
  frecuenciaKm: 5000,
  frecuenciaMeses: 24,
);

/// AlertProvider con una lista fija de tareas, sin tocar Firestore.
class _FixedTasksAlertProvider extends AlertProvider {
  _FixedTasksAlertProvider(this._tasks)
    : super(firestore: FakeFirebaseFirestore(), storage: MockFirebaseStorage());

  final List<MaintenanceTask> _tasks;

  @override
  List<MaintenanceTask> get maintenanceTasks => _tasks;

  @override
  List<AlertModel> get activeAlerts => [];

  @override
  bool get isLoading => false;
}

Future<void> pumpScreen(
  WidgetTester tester,
  List<MaintenanceTask> tasks,
) async {
  await Firebase.initializeApp();
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(
          value: FakeVehicleProvider([
            VehicleModel(
              idVehiculo: 'v0',
              idPropietario: 'u1',
              placa: 'P001-123',
              marca: 'Toyota',
              modelo: 'Corolla',
              // 6000km: contra la tarea ajena (ultimo_km 100, frecuencia
              // 5000) da kmDesdeUltimo=5900 >= 5000 -> CRITICO. La propia
              // tarea, si se gradua contra SU vehiculo, seguiria optima
              // (100 -> apenas usada); el "critico" solo aparece si se
              // gradua contra el odometro equivocado.
              kilometrajeActual: 6000,
            ),
          ]),
        ),
        ChangeNotifierProvider<AlertProvider>(
          create: (_) => _FixedTasksAlertProvider(tasks),
        ),
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: FakeProfileProvider('Propietario'),
        ),
        ChangeNotifierProvider<NotificationCenterProvider>(
          create: (_) =>
              NotificationCenterProvider(firestore: FakeFirebaseFirestore()),
        ),
      ],
      child: const DashboardScreen(),
    ),
    width: 375,
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  testWidgets(
    'el semaforo no gradua una tarea de otro vehiculo contra el odometro '
    'del vehiculo seleccionado',
    (tester) async {
      await pumpScreen(tester, [_tareaDeOtroVehiculo]);

      final element = tester.element(find.byType(DashboardScreen));
      final l10n = AppLocalizations.of(element)!;

      // La unica tarea que conoce el provider es de 'v-otro'. Si el
      // semaforo la usa igual (el bug), pinta CRITICO para 'v0' -que no
      // tiene ninguna tarea propia cargada- en vez de no mostrar nada.
      expect(
        find.text(l10n.dashMaintCritical),
        findsNothing,
        reason:
            'una tarea de otro vehiculo no puede decidir el semaforo del '
            'vehiculo seleccionado',
      );
    },
  );

  testWidgets(
    'el semaforo si se pinta, y con el estado correcto, cuando el vehiculo '
    'seleccionado tiene tareas propias entre las de otros vehiculos',
    (tester) async {
      // Estado realista tras la fusion de fetchAlertsForVehicles: tareas de
      // varios vehiculos en la misma lista.
      await pumpScreen(tester, [_tareaDeOtroVehiculo, _tareaPropia]);

      final element = tester.element(find.byType(DashboardScreen));
      final l10n = AppLocalizations.of(element)!;

      // El filtro no puede apagar el semaforo: 'v0' tiene tarea propia.
      expect(
        find.text(l10n.dashMaintStatusLabel),
        findsOneWidget,
        reason: 'el semaforo debe seguir visible si el vehiculo tiene tareas',
      );
      // Y el estado sale de SU tarea (OPTIMO), no de la ajena (CRITICO).
      expect(find.text(l10n.dashMaintOptimal), findsOneWidget);
      expect(find.text(l10n.dashMaintCritical), findsNothing);
    },
  );
}
