// Observación del 2026-09-20: «los mecánicos deberían poder poner si su
// especialidad son los carros, o las motos, e igual con los otros 4, y según
// eso tener sugerencias del catálogo».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/mechanic/presentation/pages/workshop_settings_screen.dart';

import '../../../../support/mechanic_harness.dart';

void main() {
  testWidgets('los seis tipos de vehículo se pueden marcar', (tester) async {
    await pumpMechanicScreen(
      tester,
      const WorkshopSettingsScreen(),
      width: 1440,
      location: '/workshop_settings',
      disableAnimations: true,
    );
    await tester.pumpAndSettle();

    for (final id in [
      'automovil',
      'camioneta',
      'motocicleta',
      'camion',
      'microbus',
      'autobus',
    ]) {
      expect(
        find.byKey(Key('taller_atiende_$id')),
        findsOneWidget,
        reason: 'falta el tipo $id',
      );
    }
  });

  testWidgets('marcar un tipo lo deja seleccionado', (tester) async {
    await pumpMechanicScreen(
      tester,
      const WorkshopSettingsScreen(),
      width: 1440,
      location: '/workshop_settings',
      disableAnimations: true,
    );
    await tester.pumpAndSettle();

    final moto = find.byKey(const Key('taller_atiende_motocicleta'));
    expect(tester.widget<FilterChip>(moto).selected, isFalse);

    await tester.tap(moto);
    await tester.pumpAndSettle();

    expect(tester.widget<FilterChip>(moto).selected, isTrue);
  });

  testWidgets('los tipos ya guardados salen marcados al abrir', (tester) async {
    await pumpMechanicScreen(
      tester,
      const WorkshopSettingsScreen(),
      width: 1440,
      location: '/workshop_settings',
      disableAnimations: true,
      user: fakeTaller().copyWith(tiposAtendidos: const ['camion']),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilterChip>(find.byKey(const Key('taller_atiende_camion')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(find.byKey(const Key('taller_atiende_automovil')))
          .selected,
      isFalse,
    );
  });
}
