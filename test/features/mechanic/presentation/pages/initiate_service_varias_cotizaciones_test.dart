// Observaciones del 2026-09-19.
//
// 1. Captura 7: «No se pudo comprobar si el cliente aprobó una cotización
//    para este vehículo». La consulta pedía las cotizaciones aceptadas del
//    coche solo por `id_vehiculo` + `estado`, y las reglas de `/cotizaciones`
//    rechazan una consulta que no pueden acotar a lo que el taller tiene
//    derecho a leer: fallaba SIEMPRE. Ahora filtra por `id_taller` (la prueba
//    de que las reglas la aceptan vive en `test_rules/cotizaciones.test.js`;
//    aquí se prueba que la pantalla la hace).
// 2. Un coche puede tener varias cotizaciones aceptadas a la vez (la extra
//    que el taller manda desde el perfil del vehículo): el servicio las cobra
//    todas y las marca todas como `finalizada`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/mechanic_harness.dart';

/// Mismo doble que `initiate_service_finalizar_test.dart`: un walk-in sin
/// vínculo no puede leer `mantenimientos`, así que la pantalla no tiene
/// tareas que exigir.
class _AlertProviderSinTareas extends AlertProvider {
  _AlertProviderSinTareas({required super.firestore, required super.storage});

  @override
  List<MaintenanceTask> get maintenanceTasks => const [];
}

VehicleModel _vehiculo() => VehicleModel(
  idVehiculo: 'v1',
  idPropietario: 'p1',
  placa: 'ABC123',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2020,
  kilometrajeActual: 50000,
);

Future<String> _cotizacion(
  FakeFirebaseFirestore db, {
  required String idTaller,
  required double manoDeObra,
  required DateTime fecha,
  String estado = 'aceptada',
  String material = 'Aceite',
  double costo = 10,
}) async {
  final ref = await db.collection('cotizaciones').add({
    'id_vehiculo': 'v1',
    'id_taller': idTaller,
    'id_mecanico': idTaller,
    'id_propietario': 'p1',
    'estado': estado,
    'fecha': Timestamp.fromDate(fecha),
    'items': [
      {'material': material, 'cantidad': 1, 'costo': costo},
    ],
    'mano_de_obra': manoDeObra,
  });
  return ref.id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  late FakeFirebaseFirestore servicios;

  Future<void> montar(WidgetTester tester, FakeFirebaseFirestore db) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    servicios = FakeFirebaseFirestore();
    await pumpMechanicScreen(
      tester,
      InitiateServiceScreen(
        reparacionId: 'r1',
        vehiculoPrecargado: _vehiculo(),
        firestore: db,
      ),
      width: 1024,
      location: '/initiate_service/r1',
      disableAnimations: true,
      rutasExtra: const [
        '/mechanic_dashboard',
        '/mechanic_reparaciones',
        '/service_finalized',
      ],
      extraProviders: [
        ChangeNotifierProvider<AlertProvider>.value(
          value: _AlertProviderSinTareas(
            firestore: servicios,
            storage: MockFirebaseStorage(),
          ),
        ),
        ChangeNotifierProvider<ReparacionProvider>.value(
          value: FakeReparacionProvider(),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('solo cuenta las cotizaciones aceptadas de ESTE taller', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    // Aceptada, del mismo coche, pero de OTRO taller: no es de este servicio.
    await _cotizacion(
      db,
      idTaller: 't2',
      manoDeObra: 80,
      fecha: DateTime(2026, 9, 1),
    );

    await montar(tester, db);

    expect(find.textContaining('El cliente aprobó'), findsNothing);
    expect(find.text('MATERIALES / REPUESTOS'), findsOneWidget);
    expect(find.textContaining('No se pudo comprobar'), findsNothing);
  });

  testWidgets('con dos cotizaciones aceptadas, el banner suma las dos', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await _cotizacion(
      db,
      idTaller: 't1',
      manoDeObra: 90,
      fecha: DateTime(2026, 9, 1),
    );
    await _cotizacion(
      db,
      idTaller: 't1',
      manoDeObra: 40,
      fecha: DateTime(2026, 9, 10),
      material: 'Filtro',
    );
    // Una ya cobrada no se vuelve a sumar.
    await _cotizacion(
      db,
      idTaller: 't1',
      manoDeObra: 500,
      fecha: DateTime(2026, 8, 1),
      estado: 'finalizada',
    );

    await montar(tester, db);

    // (90 + 10) + (40 + 10) = 150
    expect(
      find.textContaining('aprobó 2 cotizaciones por \$150.00'),
      findsOneWidget,
    );
    expect(find.textContaining('Aceite'), findsOneWidget);
    expect(find.textContaining('Filtro'), findsOneWidget);
    expect(find.text('MATERIALES / REPUESTOS'), findsNothing);
  });

  testWidgets(
    'al finalizar, el servicio cobra la suma y las dos quedan finalizadas',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final primera = await _cotizacion(
        db,
        idTaller: 't1',
        manoDeObra: 90,
        fecha: DateTime(2026, 9, 1),
      );
      final extra = await _cotizacion(
        db,
        idTaller: 't1',
        manoDeObra: 40,
        fecha: DateTime(2026, 9, 10),
        material: 'Filtro',
      );

      await montar(tester, db);
      final boton = find.text('FINALIZAR SERVICIO');
      await tester.ensureVisible(boton);
      await tester.tap(boton, warnIfMissed: false);
      await tester.pumpAndSettle();

      final registrados = await servicios
          .collection(FirestoreCollections.servicios)
          .get();
      expect(registrados.docs, hasLength(1));
      final servicio = registrados.docs.single.data();
      expect(servicio['costo'], 150.0);
      expect(servicio['mano_de_obra'], 130.0);
      expect(
        (servicio['materiales'] as List).map((m) => (m as Map)['nombre']),
        ['Aceite', 'Filtro'],
      );

      for (final id in [primera, extra]) {
        final doc = await db.collection('cotizaciones').doc(id).get();
        expect(doc.data()!['estado'], 'finalizada', reason: id);
      }
    },
  );
}
