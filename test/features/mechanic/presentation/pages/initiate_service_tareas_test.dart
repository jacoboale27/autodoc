// Observaciones del 2026-09-19: «si o si hay que seleccionar una tarea de las
// que aparece en el menú de tareas a realizar cuando no debería de ser así
// porque la tarea ya la asigno yo en las especificaciones de la cotización».
//
// Y al mirarlo apareció algo peor: cada tarea marcada escribía su PROPIO
// documento en `servicios` con el importe entero. Tres tareas en un servicio
// de $588 salían en el historial como tres servicios de $588, con tres
// reseñas posibles.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
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

List<MaintenanceTask> _tareas() => [
  for (final (id, nombre) in [
    ('t_aceite', 'Cambio de Aceite'),
    ('t_frenos', 'Pastillas de Freno'),
    ('t_bujias', 'Bujías'),
  ])
    MaintenanceTask(
      id: id,
      vehicleId: 'v1',
      nombre: nombre,
      ultimoKm: 40000,
      fechaUltimoServicio: DateTime(2026, 1, 1),
      frecuenciaKm: 5000,
      frecuenciaMeses: 6,
    ),
];

/// `AlertProvider` real (las escrituras son las de producción) con tres
/// tareas cargadas, sembradas también en `mantenimientos` para que el
/// `update` de ponerlas al día tenga documento.
class _AlertProviderConTareas extends AlertProvider {
  _AlertProviderConTareas({required super.firestore, required super.storage});

  final _lista = _tareas();

  @override
  List<MaintenanceTask> get maintenanceTasks => _lista;

  @override
  Future<void> fetchAlerts(String vehicleId, VehicleModel vehicle) async {}
}

VehicleModel _vehiculo() => VehicleModel(
  idVehiculo: 'v1',
  idPropietario: 'p1',
  placa: 'P123-456',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2020,
  kilometrajeActual: 50000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  late FakeFirebaseFirestore db;

  Future<void> montar(WidgetTester tester) async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    db = FakeFirebaseFirestore();
    for (final t in _tareas()) {
      await db.collection(FirestoreCollections.mantenimientos).doc(t.id).set({
        'id_vehiculo': 'v1',
        'nombre': t.nombre,
        'ultimo_km': 40000,
      });
    }
    await pumpMechanicScreen(
      tester,
      InitiateServiceScreen(
        reparacionId: 'r1',
        vehiculoPrecargado: _vehiculo(),
        firestore: FakeFirebaseFirestore(),
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
          value: _AlertProviderConTareas(
            firestore: db,
            storage: MockFirebaseStorage(),
          ),
        ),
        ChangeNotifierProvider<ReparacionProvider>.value(
          value: FakeReparacionProvider(),
        ),
      ],
    );
    await tester.pump();
  }

  Future<void> finalizar(WidgetTester tester) async {
    final boton = find.text('FINALIZAR SERVICIO');
    await tester.ensureVisible(boton);
    await tester.tap(boton, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> servicios() async =>
      (await db.collection(FirestoreCollections.servicios).get()).docs;

  testWidgets('con tareas disponibles, se puede cerrar sin marcar ninguna', (
    tester,
  ) async {
    await montar(tester);
    // Plegadas: no estorban a quien solo quiere cerrar lo cotizado.
    expect(find.text('Cambio de Aceite'), findsNothing);
    await finalizar(tester);

    expect(find.text('Selecciona al menos una tarea realizada'), findsNothing);
    expect(await servicios(), hasLength(1));
  });

  testWidgets(
    'marcar dos tareas da UN servicio y pone al día las dos del cliente',
    (tester) async {
      await montar(tester);
      await tester.tap(find.byKey(const Key('tareas_opcionales_toggle')));
      await tester.pumpAndSettle();
      for (final nombre in ['Cambio de Aceite', 'Pastillas de Freno']) {
        await tester.ensureVisible(find.text(nombre));
        await tester.tap(find.text(nombre));
        await tester.pump();
      }
      await finalizar(tester);

      final docs = await servicios();
      expect(
        docs,
        hasLength(1),
        reason: 'antes: un servicio por tarea, cada uno con el importe entero',
      );
      expect(
        docs.single.data()['tipo_servicio'],
        'Cambio de Aceite, Pastillas de Freno',
      );

      for (final id in ['t_aceite', 't_frenos']) {
        final t = await db
            .collection(FirestoreCollections.mantenimientos)
            .doc(id)
            .get();
        expect(t.data()!['ultimo_km'], 50000, reason: '$id al día');
      }
      final sinTocar = await db
          .collection(FirestoreCollections.mantenimientos)
          .doc('t_bujias')
          .get();
      expect(sinTocar.data()!['ultimo_km'], 40000);
      final historial = await db
          .collection(FirestoreCollections.historialMantenimientos)
          .get();
      expect(historial.docs, hasLength(2));
    },
  );
}
