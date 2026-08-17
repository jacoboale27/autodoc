import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart';

import '../../../../support/contrast.dart';
import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> seedTaller() async {
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('usuarios').doc('t1').set({
    'calificacion_promedio': 4.5,
    'total_resenias': 12,
  });
  for (var i = 0; i < 3; i++) {
    await firestore.collection('servicios').doc('s$i').set({
      'id_taller': 't1',
      'id_vehiculo': 'v$i',
      'tipo_servicio': 'Servicio $i',
      'fecha': DateTime(2026, 8, 1 + i),
      'costo': 100.0 + i,
    });
  }
  return firestore;
}

Future<void> pumpDashboard(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
  Brightness brightness = Brightness.light,
}) async {
  await pumpMechanicScreen(
    tester,
    MechanicDashboardScreen(firestore: firestore),
    width: width,
    location: '/mechanic_dashboard',
    brightness: brightness,
    disableAnimations: true,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('los 6 KPIs salen en 3 columnas a 1440 px', (tester) async {
    final firestore = await seedTaller();
    await pumpDashboard(tester, width: 1440, firestore: firestore);

    expect(find.byType(AppGrid), findsOneWidget);

    final lefts = <double>{};
    for (final titulo in [
      'Ingresos (Mes)',
      'Servicios (Mes)',
      'Total Servicios',
      'Vehículos Atendidos',
      'Calificación',
      'Reseñas',
    ]) {
      lefts.add(tester.getTopLeft(find.text(titulo)).dx);
    }
    expect(
      lefts.length,
      3,
      reason:
          'el Wrap + SizedBox anterior solo llegaba a 2 columnas: la '
          'tarjeta medía cardWidth + 55 px de padding que el cálculo ignoraba',
    );
  });

  testWidgets('el texto de "Atención Rápida" es legible en dark', (
    tester,
  ) async {
    final firestore = await seedTaller();
    await pumpDashboard(
      tester,
      width: 375,
      firestore: firestore,
      brightness: Brightness.dark,
    );

    final context = tester.element(find.byType(MechanicDashboardScreen));
    final colors = context.appColors;
    final texto = tester.widget<Text>(
      find.text('Inicia un nuevo servicio buscando la placa del vehículo.'),
    );

    expect(
      contrastRatio(texto.style!.color!, colors.primary),
      greaterThanOrEqualTo(4.5),
      reason: 'Colors.white sobre el teal de dark daba 1,47:1',
    );
  });

  testWidgets('la gráfica de ingresos tiene alternativa textual', (
    tester,
  ) async {
    final firestore = await seedTaller();
    await pumpDashboard(tester, width: 1024, firestore: firestore);

    expect(
      find.bySemanticsLabel(RegExp('Tendencia de ingresos')),
      findsOneWidget,
      reason:
          'fl_chart pinta en canvas: sin Semantics la sección está vacía '
          'para un lector de pantalla',
    );
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedTaller();
      await pumpDashboard(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  test('el fichero está tokenizado y no duplica la barra de acciones', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source.contains('Colors.white'), isFalse);
    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
    expect(
      'Consumer2<ThemeProvider, LanguageProvider>'.allMatches(source).length,
      1,
      reason: 'los conmutadores de tema e idioma estaban escritos dos veces',
    );
  });
}
