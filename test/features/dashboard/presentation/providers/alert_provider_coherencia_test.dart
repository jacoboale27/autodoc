// test/features/dashboard/presentation/providers/alert_provider_coherencia_test.dart
//
// Hallazgo QA §16: en /alerts la misma tarea aparecia a la vez en PRIORIDAD
// ALTA como "¡CRITICO!" y en SUGERENCIAS como "OPTIMO". El vehiculo
// seleccionado tenia 254 km de odometro y la tarea decia ultimo servicio a
// 54.621 km.
//
// La causa NO esta en `_generateSmartAlerts` (ya deriva la alerta critica y
// el estado de la tarjeta del mismo `task.getStatus(km)`, ver
// alert_provider.dart ~L210-231): esta ENTRE VEHICULOS. Ese caso se cubre en
// un test de widget sobre AlertsScreen (el filtro vive en el punto de
// render de /alerts, no en el provider) -- ver
// test/features/dashboard/presentation/pages/alerts_screen_test.dart.
//
// Este archivo cubre el segundo defecto real, dentro de un mismo vehiculo:
// si el odometro actual es menor que el ultimo_km registrado de una tarea,
// `getStatus()` interpreta el km negativo como "faltan decenas de miles de
// km" y la tarea sale OPTIMA -- ocultando que el dato esta mal. Eso no es un
// fallo de carga (`_error` es para cuando la peticion a Firestore revienta),
// es un dato inconsistente de ESA tarea.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import '../../../../helpers/test_helpers.mocks.dart';

void main() {
  test('un odometro por debajo del ultimo servicio se marca como dato '
      'inconsistente, no como "proximo servicio" absurdo ni como error de '
      'carga', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('mantenimientos').add({
      'id_vehiculo': 'v1',
      'nombre': 'Rotación de Llantas',
      'ultimo_km': 54621,
      'fecha_ultimo_servicio': Timestamp.fromDate(DateTime(2024, 1, 1)),
      'frecuencia_km': 10000,
      'frecuencia_meses': 12,
    });

    final provider = AlertProvider(
      firestore: firestore,
      storage: MockFirebaseStorage(),
    );
    final vehicle = VehicleModel(
      idVehiculo: 'v1',
      idPropietario: 'owner-1',
      placa: 'P111-111',
      marca: 'Toyota',
      modelo: 'Corolla',
      kilometrajeActual: 254,
    );

    await provider.fetchAlerts('v1', vehicle);

    // Un dato inconsistente de UNA tarea no debe apagar la pantalla
    // entera de alertas.
    expect(provider.error, isNull);

    final taskId = provider.maintenanceTasks.single.id;

    final inconsistentes = provider.alerts.where(
      (a) => a.tipoAlerta == 'MantenimientoInconsistente',
    );
    expect(
      inconsistentes.length,
      1,
      reason:
          'debe marcarse como dato inconsistente y ofrecer corregir el '
          'kilometraje, en vez de calcular un "proximo servicio" que no '
          'tiene sentido',
    );
    expect(inconsistentes.first.idVehiculo, 'v1');
    expect(inconsistentes.first.prioridad, AlertPriority.high);
    expect(inconsistentes.first.metadata?['ultimo_km'], 54621);

    // No debe generarse ademas la alerta normal de la tarea (saldria
    // "OPTIMO": 254 - 54621 es negativo, asi que getStatus() cree que
    // faltan decenas de miles de km para el proximo servicio).
    expect(provider.alerts.any((a) => a.idAlerta == 'task_$taskId'), isFalse);
  });
}
