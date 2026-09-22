// Observaciones del 2026-09-19, punto 3: «En la pantalla de mis servicios del
// mecánico no aparecen los servicios rechazados, aceptados (en proceso), ni
// los finalizados». Solo listaba los servicios ya registrados.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:autodoc/features/mechanic/presentation/pages/mechanic_service_history_screen.dart';

import '../../../../support/mechanic_harness.dart';

Future<FakeFirebaseFirestore> _sembrar({String idTaller = 't1'}) async {
  final db = FakeFirebaseFirestore();
  Future<void> cotizacion(String id, String estado, String material) =>
      db.collection('cotizaciones').doc(id).set({
        'id_vehiculo': 'v1',
        'id_taller': idTaller,
        'id_mecanico': idTaller,
        'id_propietario': 'p1',
        'estado': estado,
        'fecha': Timestamp.fromDate(DateTime(2026, 9, 10)),
        'items': [
          {'material': material, 'cantidad': 1, 'costo': 10},
        ],
        'vehiculo_resumen': {
          'marca': 'Nissan',
          'modelo': 'Rogue',
          'placa': 'P180-030',
        },
      });
  await cotizacion('c1', 'aceptada', 'Frenos');
  await cotizacion('c2', 'pendiente', 'Aceite');
  await cotizacion('c3', 'rechazada', 'Llantas');
  // Finalizada: su servicio registrado ES ese trabajo; no se lista aparte.
  await cotizacion('c4', 'finalizada', 'Batería');
  await cotizacion('c5', 'draft', 'Borrador');
  await db.collection('servicios').doc('s1').set({
    'id_vehiculo': 'v1',
    'id_taller': idTaller,
    'tipo_servicio': 'Cambio de batería',
    'fecha': Timestamp.fromDate(DateTime(2026, 9, 1)),
    'costo': 80.0,
  });
  // De otro taller: nada de esto es suyo.
  await db.collection('cotizaciones').doc('ajena').set({
    'id_vehiculo': 'v9',
    'id_taller': 'otro',
    'id_mecanico': 'otro',
    'id_propietario': 'p9',
    'estado': 'aceptada',
    'fecha': Timestamp.fromDate(DateTime(2026, 9, 11)),
    'items': [
      {'material': 'Motor ajeno', 'cantidad': 1, 'costo': 10},
    ],
  });
  return db;
}

Future<GoRouter> _montar(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  String? idTallerPropietario,
}) async {
  final router = await pumpMechanicScreen(
    tester,
    MechanicServiceHistoryScreen(firestore: db),
    width: 1280,
    location: '/mechanic_service_history',
    user: fakeTaller(
      id: idTallerPropietario == null ? 't1' : 'empleado1',
      idTallerPropietario: idTallerPropietario,
    ),
    disableAnimations: true,
    rutasExtra: const ['/vehiculo_publico/v1'],
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets(
    '"Todos" junta en proceso, pendientes, finalizados y rechazados',
    (tester) async {
      await _montar(tester, await _sembrar());

      expect(find.text('Todos (4)'), findsOneWidget);
      expect(find.text('En proceso (1)'), findsOneWidget);
      expect(find.text('Pendientes (1)'), findsOneWidget);
      expect(find.text('Finalizados (1)'), findsOneWidget);
      expect(find.text('Rechazados (1)'), findsOneWidget);

      expect(find.text('ACEPTADA · EN PROCESO'), findsOneWidget);
      expect(find.text('ESPERANDO RESPUESTA'), findsOneWidget);
      expect(find.text('RECHAZADA'), findsOneWidget);
      expect(find.text('Cambio de batería'), findsOneWidget);
      // Ni borradores ni trabajo de otro taller.
      expect(find.textContaining('Borrador'), findsNothing);
      expect(find.textContaining('Motor ajeno'), findsNothing);
      // Y dice de qué coche es cada cotización.
      expect(find.text('Nissan Rogue · P180-030'), findsNWidgets(3));
    },
  );

  testWidgets('cada pestaña enseña solo lo suyo', (tester) async {
    await _montar(tester, await _sembrar());

    await tester.tap(find.byKey(const Key('mis_servicios_rechazados')));
    await tester.pumpAndSettle();
    expect(find.text('RECHAZADA'), findsOneWidget);
    expect(find.text('ACEPTADA · EN PROCESO'), findsNothing);
    expect(find.text('Cambio de batería'), findsNothing);

    await tester.tap(find.byKey(const Key('mis_servicios_enProceso')));
    await tester.pumpAndSettle();
    expect(find.text('ACEPTADA · EN PROCESO'), findsOneWidget);
    expect(find.text('RECHAZADA'), findsNothing);

    await tester.tap(find.byKey(const Key('mis_servicios_finalizados')));
    await tester.pumpAndSettle();
    expect(find.text('Cambio de batería'), findsOneWidget);
    expect(find.text('ACEPTADA · EN PROCESO'), findsNothing);
  });

  testWidgets('tocar una cotización abre el perfil de su vehículo', (
    tester,
  ) async {
    final router = await _montar(tester, await _sembrar());

    await tester.tap(find.byKey(const Key('mis_servicios_enProceso')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACEPTADA · EN PROCESO'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/vehiculo_publico/v1');
  });

  testWidgets('un empleado ve el trabajo de SU taller, no una lista vacía', (
    tester,
  ) async {
    // Antes la pantalla consultaba por el uid de la sesión, que para un
    // empleado no es el `id_taller` con el que se registra el trabajo.
    await _montar(tester, await _sembrar(), idTallerPropietario: 't1');

    expect(find.text('Todos (4)'), findsOneWidget);
    expect(find.text('Cambio de batería'), findsOneWidget);
  });
}
