// test/features/dashboard/presentation/pages/dashboard_screen_semaforo_test.dart
//
// Mismo mecanismo del hallazgo QA §16, vivo en otra pantalla: el semaforo
// de mantenimiento del dashboard (_buildMaintenanceSemaphore) gradua
// `provider.maintenanceTasks` -que tras fetchAlertsForVehicles se queda con
// las tareas del ULTIMO vehiculo procesado, no las del vehiculo seleccionado
// (ver el docstring de fetchAlertsForVehicles en alert_provider.dart)-
// contra el odometro del vehiculo SELECCIONADO. Si esas tareas pertenecen a
// otro vehiculo, el semaforo miente sobre el estado del vehiculo que el
// usuario tiene delante.
//
// El bug depende del ORDEN: si el vehiculo seleccionado resulta ser el
// ultimo procesado, no se manifiesta. Este test fuerza que NO lo sea: el
// AlertProvider fake solo conoce tareas de 'v-otro', nunca de 'v0'
// (seleccionado).

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

/// El provider solo conoce una tarea de 'v-otro' -nunca de 'v0', el
/// vehiculo seleccionado en este test-, igual que le pasaria de verdad a
/// `_maintenanceTasks` si 'v-otro' fue el ultimo vehiculo procesado por
/// `fetchAlertsForVehicles`.
class _OtherVehicleTasksAlertProvider extends AlertProvider {
  _OtherVehicleTasksAlertProvider()
    : super(firestore: FakeFirebaseFirestore(), storage: MockFirebaseStorage());

  @override
  List<MaintenanceTask> get maintenanceTasks => [
    MaintenanceTask(
      id: 't-otro',
      vehicleId: 'v-otro',
      nombre: 'Bujías',
      ultimoKm: 100,
      fechaUltimoServicio: DateTime.now(),
      frecuenciaKm: 5000,
      frecuenciaMeses: 24,
    ),
  ];

  @override
  List<AlertModel> get activeAlerts => [];

  @override
  bool get isLoading => false;
}

Future<void> pumpScreen(WidgetTester tester) async {
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
          create: (_) => _OtherVehicleTasksAlertProvider(),
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
      await pumpScreen(tester);

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
}
