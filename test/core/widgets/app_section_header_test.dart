import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';

import '../../support/responsive_harness.dart';

void main() {
  testWidgets('muestra título y subtítulo', (tester) async {
    await pumpAtWidth(
      tester,
      const AppSectionHeader(
        title: 'Frecuencia de mantenimiento',
        subtitle: 'Ajusta cada cuántos kilómetros se realiza.',
      ),
      width: 375,
    );

    expect(find.text('Frecuencia de mantenimiento'), findsOneWidget);
    expect(
      find.text('Ajusta cada cuántos kilómetros se realiza.'),
      findsOneWidget,
    );
  });

  testWidgets('la variante uppercase transforma el título', (tester) async {
    await pumpAtWidth(
      tester,
      const AppSectionHeader(title: 'Detalles del servicio', uppercase: true),
      width: 375,
    );

    expect(find.text('DETALLES DEL SERVICIO'), findsOneWidget);
  });

  testWidgets('renderiza el trailing a la derecha del título', (tester) async {
    await pumpAtWidth(
      tester,
      AppSectionHeader(
        title: 'Alertas activas',
        trailing: TextButton(onPressed: () {}, child: const Text('Ver todo')),
      ),
      width: 375,
    );

    final titleX = tester.getCenter(find.text('Alertas activas')).dx;
    final trailingX = tester.getCenter(find.text('Ver todo')).dx;
    expect(trailingX, greaterThan(titleX));
  });

  testWidgets('el título se anuncia como encabezado', (tester) async {
    await pumpAtWidth(
      tester,
      const AppSectionHeader(title: 'Alertas activas'),
      width: 375,
    );

    final semantics = tester.getSemantics(find.text('Alertas activas'));
    expect(
      semantics.flagsCollection.isHeader,
      isTrue,
      reason:
          'sin flag de header, un lector de pantalla no puede saltar '
          'entre secciones',
    );
  });

  testWidgets('no desborda con un título largo en ningún ancho', (
    tester,
  ) async {
    await forEachAuditWidth(tester, (width) async {
      await pumpAtWidth(
        tester,
        AppSectionHeader(
          title: 'Documentación y alertas del vehículo registrado',
          trailing: TextButton(onPressed: () {}, child: const Text('Ver todo')),
        ),
        width: width,
      );
      expectNoOverflow(tester);
    });
  });
}
