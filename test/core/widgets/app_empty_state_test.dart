import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';

import '../../support/responsive_harness.dart';

void main() {
  const longDescription =
      'Todavía no has registrado ningún vehículo en tu garaje. Cuando añadas '
      'el primero, verás aquí su historial de mantenimiento, sus alertas y '
      'los servicios realizados por los talleres.';

  testWidgets('la descripción no se estira de borde a borde en desktop', (
    tester,
  ) async {
    await pumpAtWidth(
      tester,
      const AppEmptyState(title: 'Sin vehículos', description: longDescription),
      width: 1440,
    );

    final width = tester.getSize(find.text(longDescription)).width;
    expect(
      width,
      lessThanOrEqualTo(AppBreakpoints.maxReadingWidth),
      reason: 'la descripción mide ${width}px; medida de lectura ilegible',
    );
  });

  testWidgets('no desborda en ningún ancho de auditoría', (tester) async {
    await forEachAuditWidth(tester, (width) async {
      await pumpAtWidth(
        tester,
        const AppEmptyState(
          title: 'Sin vehículos',
          description: longDescription,
        ),
        width: width,
      );
      expectNoOverflow(tester);
    });
  });

  testWidgets('el bloque se anuncia como una unidad', (tester) async {
    await pumpAtWidth(
      tester,
      const AppEmptyState(title: 'Sin vehículos', description: 'Añade uno.'),
      width: 375,
    );

    expect(
      find.bySemanticsLabel(RegExp('Sin vehículos')),
      findsWidgets,
      reason: 'el estado vacío no se anuncia como región con su título',
    );
  });

  testWidgets('el icono decorativo se excluye de la semántica', (tester) async {
    await pumpAtWidth(
      tester,
      const AppEmptyState(title: 'Sin vehículos', description: 'Añade uno.'),
      width: 375,
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(
      icon.semanticLabel,
      isNull,
      reason: 'el icono es decorativo: el título ya dice lo mismo',
    );
  });

  testWidgets('renderiza la acción cuando se pasa', (tester) async {
    await pumpAtWidth(
      tester,
      AppEmptyState(
        title: 'Sin vehículos',
        description: 'Añade uno.',
        action: ElevatedButton(onPressed: () {}, child: const Text('Añadir')),
      ),
      width: 375,
    );

    expect(find.text('Añadir'), findsOneWidget);
  });

  testWidgets('renderiza en ambos temas sin excepciones', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpAtWidth(
        tester,
        const AppEmptyState(title: 'Sin vehículos', description: 'Añade uno.'),
        width: 375,
        brightness: brightness,
      );
      expectNoOverflow(tester);
    }
  });
}
