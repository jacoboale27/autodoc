// test/core/widgets/main_scaffold_large_content_semantics_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/shell_harness.dart';

/// Cobertura del efecto colateral de `main_scaffold.dart:110-116`: en la
/// rama `WindowClass.large`, el limite semantico explicito
/// (`Semantics(container: true, explicitChildNodes: true)`) no envuelve solo
/// la barra superior, envuelve el `child` completo de la `ShellRoute` — es
/// decir, TODAS las pantallas de contenido de la app a >=1200 px.
///
/// Esto no prueba que ese wrap arregla el hallazgo QA §13 (eso lo hace
/// `top_nav_semantics_test.dart`); prueba lo contrario: que ese wrap, de
/// radio de impacto mucho mayor que el hallazgo original, no tiene el efecto
/// secundario de aplanar o tragarse la semantica del propio contenido. Si el
/// wrap fusionara los nodos del contenido en uno solo (perdiendo granularidad)
/// o los excluyera del arbol, este test lo detectaria.
void main() {
  testWidgets(
    'a 1440px el contenido de una pantalla sigue anunciando sus nodos '
    'semanticos por separado, no fusionados ni tragados por el limite '
    'semantico explicito que envuelve el child de la ShellRoute',
    (tester) async {
      final handle = tester.ensureSemantics();

      await pumpShell(
        tester,
        width: 1440,
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
            'el primer nodo de contenido no es alcanzable: el limite '
            'semantico que envuelve el child en WindowClass.large esta '
            'tragando o fusionando el contenido de la pantalla.',
      );
      expect(
        find.bySemanticsLabel('Contenido B de /dashboard'),
        findsOneWidget,
        reason:
            'el segundo nodo de contenido no es alcanzable por separado: si '
            'apareciera fusionado con el primero (p. ej. como un solo nodo '
            'con ambos labels), este `bySemanticsLabel` exacto no lo '
            'encontraria — la granularidad del contenido se habria perdido.',
      );

      handle.dispose();
    },
  );
}
