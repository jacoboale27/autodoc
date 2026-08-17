import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/empleados_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> seedEmpleados({int count = 4}) async {
  final firestore = FakeFirebaseFirestore();
  for (var i = 0; i < count; i++) {
    await firestore
        .collection('talleres')
        .doc('t1')
        .collection('empleados')
        .doc('e$i')
        .set({
          'id_taller_propietario': 't1',
          'nombre_completo': 'Empleado $i',
          'correo': 'empleado$i@taller.com',
          'rol': i.isEven ? 'Mecanico' : 'Recepcionista',
          'activo': true,
        });
  }
  return firestore;
}

Future<void> pumpEmpleados(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
  String? idTallerPropietario,
}) async {
  await pumpMechanicScreen(
    tester,
    const EmpleadosScreen(idTaller: 't1'),
    width: width,
    location: '/mechanic/empleados',
    disableAnimations: true,
    user: fakeTaller(idTallerPropietario: idTallerPropietario),
    extraProviders: [
      ChangeNotifierProvider(
        create: (_) => EmpleadoProvider(
          repository: EmpleadoRepository(firestore: firestore),
        ),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('los empleados se distribuyen en rejilla en escritorio', (
    tester,
  ) async {
    final firestore = await seedEmpleados();
    await pumpEmpleados(tester, width: 1440, firestore: firestore);

    expect(find.byType(AppGrid), findsOneWidget);
    final lefts = tester
        .widgetList<Text>(find.textContaining('Empleado '))
        .map((t) => tester.getTopLeft(find.text(t.data!)).dx)
        .toSet();
    expect(lefts.length, greaterThan(1));
  });

  testWidgets('desactivar es un botón, no un Switch', (tester) async {
    final firestore = await seedEmpleados(count: 1);
    await pumpEmpleados(tester, width: 375, firestore: firestore);

    expect(
      find.byType(Switch),
      findsNothing,
      reason: 'un Switch promete dos sentidos; esta acción solo va en uno',
    );
    expect(
      find.widgetWithIcon(IconButton, Icons.person_off_outlined),
      findsOneWidget,
    );
  });

  testWidgets('los dos estados vacíos usan AppEmptyState', (tester) async {
    final vacio = await seedEmpleados(count: 0);
    await pumpEmpleados(tester, width: 375, firestore: vacio);
    expect(find.byType(AppEmptyState), findsOneWidget);

    final conDatos = await seedEmpleados();
    await pumpEmpleados(
      tester,
      width: 375,
      firestore: conDatos,
      idTallerPropietario: 'otro-taller',
    );
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('Acceso restringido'), findsOneWidget);
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedEmpleados();
      await pumpEmpleados(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  test('el fichero no repite el shell ni fija anchos de diálogo', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/empleados_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
    expect(source.contains('SizedBox(width: 420)'), isFalse);
    expect(
      'MechanicScaffold('.allMatches(source).length,
      1,
      reason: 'el shell se declara una vez, no dos',
    );
  });
}
