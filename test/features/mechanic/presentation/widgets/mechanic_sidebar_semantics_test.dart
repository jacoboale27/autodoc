// test/features/mechanic/presentation/widgets/mechanic_sidebar_semantics_test.dart
//
// Segunda mitad del hallazgo QA §2.13: «Taller: la barra lateral sí está
// expuesta … excepto en `/chat_list`, donde desaparece del árbol. Es la ruta
// que pasa por `_MechanicShell`.»
//
// `MechanicScaffold` tiene la misma forma estructural que la rama `large` de
// `main_scaffold.dart` antes de arreglarse: `MechanicSidebar` es hermano de
// un `Expanded` que lleva el `Navigator` anidado de la `ShellRoute`, y ese
// `Navigator` -sin limite semantico explicito propio- se traga el arbol de
// accesibilidad de su hermano.
//
// El arreglo que funciono en el otro shell fue envolver el lado del
// `Navigator` (no la barra). Este test lo demuestra en rojo antes de tocar
// nada: 1024 px es `expanded`, la clase mas pequeña en la que
// `MechanicScaffold` pinta la barra lateral fija.

import 'package:flutter_test/flutter_test.dart';

import '../../../../support/shell_harness.dart';

const _destinosTaller = <String>[
  'Dashboard',
  'Buscar Vehículo',
  'Mis Servicios',
  'Reparaciones',
  'Mis Reseñas',
  'Mensajes',
  'Empleados',
  'Catálogo',
  'Fotos del taller',
  'Configuración',
  'Cerrar Sesión',
];

void main() {
  testWidgets(
    'a 1024px (expanded) los destinos de MechanicSidebar son alcanzables en '
    'el arbol de accesibilidad desde /chat_list',
    (tester) async {
      final handle = tester.ensureSemantics();

      await pumpShell(
        tester,
        width: 1024,
        rol: 'Mecanico',
        location: '/chat_list',
      );

      for (final label in _destinosTaller) {
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(label))),
          findsOneWidget,
          reason:
              'a 1024px no se encuentra ningun nodo semantico para "$label" '
              'en la MechanicSidebar de /chat_list.',
        );
      }

      handle.dispose();
    },
  );
}
