// test/features/mechanic/presentation/pages/reparaciones_kanban_responsive_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

/// Siembra [count] reparaciones en el estado [estado] para que la columna
/// tenga más tarjetas de las que caben en el viewport.
Future<FakeFirebaseFirestore> seedReparaciones({
  int count = 8,
  String estado = 'recibido',
}) async {
  final firestore = FakeFirebaseFirestore();
  for (var i = 0; i < count; i++) {
    await firestore.collection('reparaciones').doc('r$i').set({
      'id_vehiculo': 'v$i',
      'id_taller': 't1',
      'id_propietario': 'p$i',
      'placa': 'ABC${100 + i}',
      'estado': estado,
      'historial_estados': <Map<String, dynamic>>[],
      'fecha_creacion': DateTime(2026, 8, 1),
      'fecha_actualizacion': DateTime(2026, 8, 5),
    });
  }
  return firestore;
}

Future<void> pumpKanban(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
  double height = 800,
}) async {
  await pumpMechanicScreen(
    tester,
    const ReparacionesKanbanScreen(idTaller: 't1'),
    width: width,
    height: height,
    location: '/mechanic_reparaciones',
    disableAnimations: true,
    extraProviders: [
      ChangeNotifierProvider(
        create: (_) => ReparacionProvider(
          repository: ReparacionRepository(
            firestore: firestore,
            functions: MockFirebaseFunctions(),
          ),
        ),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('una columna con 8 tarjetas no desborda en vertical', (
    tester,
  ) async {
    final firestore = await seedReparaciones(count: 8);
    await pumpKanban(tester, width: 1440, firestore: firestore);

    expectNoOverflow(tester);
  });

  testWidgets('a 375 px cada estado es un tab, no una columna', (tester) async {
    final firestore = await seedReparaciones(count: 2);
    await pumpKanban(tester, width: 375, firestore: firestore);

    expect(find.byType(TabBar), findsOneWidget);
    for (final label in etiquetasEstado.values) {
      expect(find.text(label), findsOneWidget, reason: 'falta el tab $label');
    }
    // Solo la lista del tab activo está montada.
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('a 1440 px todas las columnas caben sin scroll horizontal', (
    tester,
  ) async {
    final firestore = await seedReparaciones(count: 2);
    await pumpKanban(tester, width: 1440, firestore: firestore);

    expect(find.byType(TabBar), findsNothing);
    // Una columna por estado del pipeline: el kanban itera
    // `estadosReparacion`, asi que 'pendiente_recepcion' (A4b) estrena
    // columna sin tocar esta pantalla. Se cuenta contra la lista y no contra
    // un numero fijo justamente para que el proximo estado tampoco lo toque.
    expect(
      find.byType(ListView),
      findsNWidgets(estadosReparacion.length),
      reason: 'cada estado debe tener su propia lista con scroll vertical',
    );

    final xs = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => etiquetasEstado.values.contains(t.data))
        .length;
    expect(
      xs,
      estadosReparacion.length,
      reason: 'cada estado debe tener su encabezado de columna',
    );
  });

  testWidgets('un ticket recien aceptado aparece en la columna "Por recibir"', (
    tester,
  ) async {
    // A4b: el ticket nace en 'pendiente_recepcion' (lo abre
    // `onCotizacionAceptada`), que es la PRIMERA columna del tablero. A 375
    // px solo esta montada la lista del tab activo, que es esa primera, asi
    // que encontrar la placa aqui prueba que la tarjeta cae en esa columna y
    // no en otra.
    final firestore = await seedReparaciones(
      count: 1,
      estado: 'pendiente_recepcion',
    );
    await pumpKanban(tester, width: 375, firestore: firestore);

    expect(find.text('Por recibir'), findsOneWidget);
    expect(find.text('ABC100'), findsOneWidget);
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedReparaciones(count: 5);
      await pumpKanban(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  testWidgets('el botón de avanzar dice a qué estado avanza', (tester) async {
    final firestore = await seedReparaciones(count: 1);
    await pumpKanban(tester, width: 1440, firestore: firestore);

    expect(find.text('Avanzar a En Revisión'), findsOneWidget);
    expect(find.text('Avanzar'), findsNothing);
  });
}
