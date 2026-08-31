// test/core/widgets/nav_rail_semantics_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

import '../../support/shell_harness.dart';

/// Analogo de `top_nav_semantics_test.dart` para `WindowClass.medium` y
/// `WindowClass.expanded` (el `AppNavRail`). `main_scaffold.dart:73-86` tiene
/// la misma forma estructural que el codigo roto que se arreglo en `large`
/// (un hermano sin envoltorio semantico junto al `Expanded(child: child)` de
/// la `ShellRoute`), asi que hay motivo para sospechar el mismo defecto —
/// pero NO se asume por analogia: este test tiene que demostrarlo en rojo
/// antes de tocar nada.
void main() {
  testWidgets(
    'a 768px (medium) los destinos del AppNavRail son alcanzables en el '
    'arbol de accesibilidad',
    (tester) async {
      final handle = tester.ensureSemantics();

      await pumpShell(tester, width: 768, rol: 'Propietario');

      for (final destination in AppNavDestinations.owner) {
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(destination.label))),
          findsOneWidget,
          reason:
              'a 768px no se encuentra ningun nodo semantico para '
              '"${destination.label}" (${destination.route}) en el '
              'AppNavRail.',
        );
      }

      handle.dispose();
    },
  );

  testWidgets(
    'a 1024px (expanded) los destinos del AppNavRail son alcanzables en el '
    'arbol de accesibilidad',
    (tester) async {
      final handle = tester.ensureSemantics();

      await pumpShell(tester, width: 1024, rol: 'Propietario');

      for (final destination in AppNavDestinations.owner) {
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(destination.label))),
          findsOneWidget,
          reason:
              'a 1024px no se encuentra ningun nodo semantico para '
              '"${destination.label}" (${destination.route}) en el '
              'AppNavRail.',
        );
      }

      handle.dispose();
    },
  );
}
