// test/core/widgets/main_scaffold_large_content_semantics_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/shell_harness.dart';

/// Cobertura del efecto colateral del limite semantico explicito que envuelve
/// el `child` de la `ShellRoute` en `main_scaffold.dart`
/// (`Semantics(container: true, explicitChildNodes: true)`). Ese wrap no
/// envuelve solo la navegacion (la barra en `large`, el rail en
/// `medium`/`expanded`): envuelve el `child` completo — es decir, TODAS las
/// pantallas de contenido de la app, en las tres ramas que lo tienen
/// (600-1199 px con `AppNavRail`, >=1200 px con `AppTopNavBar`).
///
/// Esto no prueba que ese wrap arregla el hallazgo QA §13 (eso lo hacen
/// `top_nav_semantics_test.dart` y `nav_rail_semantics_test.dart`); prueba lo
/// contrario: que ese wrap, de radio de impacto mucho mayor que el hallazgo
/// original, no tiene el efecto secundario de aplanar o tragarse la
/// semantica del propio contenido en NINGUNO de los anchos donde existe. Si
/// el wrap fusionara los nodos del contenido en uno solo (perdiendo
/// granularidad) o los excluyera del arbol, este test lo detectaria — se
/// parametriza por ancho porque `main_scaffold.dart` tiene el mismo wrap
/// duplicado en dos ramas distintas (medium/expanded y large), y cada una es
/// codigo que podria romperse por separado.
void main() {
  for (final width in [768.0, 1024.0, 1440.0]) {
    testWidgets(
      'a ${width.toInt()}px el contenido de una pantalla sigue anunciando '
      'sus nodos semanticos por separado, no fusionados ni tragados por el '
      'limite semantico explicito que envuelve el child de la ShellRoute',
      (tester) async {
        final handle = tester.ensureSemantics();

        await pumpShell(
          tester,
          width: width,
          rol: 'Propietario',
          bodyBuilder: (path) => Column(
            children: [
              Semantics(
                label: 'Contenido A de $path',
                child: const SizedBox(width: 40, height: 40),
              ),
              Semantics(
                label: 'Contenido B de $path',
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
        );

        expect(
          find.bySemanticsLabel('Contenido A de /dashboard'),
          findsOneWidget,
          reason:
              'a ${width.toInt()}px el primer nodo de contenido no es '
              'alcanzable: el limite semantico que envuelve el child esta '
              'tragando o fusionando el contenido de la pantalla.',
        );
        expect(
          find.bySemanticsLabel('Contenido B de /dashboard'),
          findsOneWidget,
          reason:
              'a ${width.toInt()}px el segundo nodo de contenido no es '
              'alcanzable por separado: si apareciera fusionado con el '
              'primero (p. ej. como un solo nodo con ambos labels), este '
              '`bySemanticsLabel` exacto no lo encontraria — la '
              'granularidad del contenido se habria perdido.',
        );

        handle.dispose();
      },
    );
  }
}
