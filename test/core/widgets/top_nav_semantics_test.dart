// test/core/widgets/top_nav_semantics_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

import '../../support/shell_harness.dart';

/// Regresión del hallazgo QA §13: sobre `/dashboard` a 1440 px, el árbol de
/// accesibilidad tenía 34 nodos y todos eran de contenido — ni un solo nodo
/// pertenecía a la barra superior (ni los enlaces de navegación, ni el botón
/// de tema, ni el de idioma, ni la campana). La navegación principal era
/// inalcanzable con teclado y con lector de pantalla.
void main() {
  testWidgets(
    'a 1440px los cinco destinos de la barra superior son alcanzables '
    'en el arbol de accesibilidad',
    (tester) async {
      final handle = tester.ensureSemantics();

      await pumpShell(tester, width: 1440, rol: 'Propietario');

      for (final destination in AppNavDestinations.owner) {
        // `bySemanticsLabel` con un String exige igualdad exacta, pero
        // `_TopNavLink` fusiona el label explicito con el label implicito
        // del `Text` hijo (queda "<semanticLabel>\n<label>"). Por eso se
        // busca el `semanticLabel` como substring vía RegExp: lo que importa
        // aqui es que el nodo sea *alcanzable*, no el formato exacto de su
        // texto.
        expect(
          find.bySemanticsLabel(
            RegExp(RegExp.escape(destination.semanticLabel)),
          ),
          findsOneWidget,
          reason:
              'sobre /dashboard a 1440px no habia NINGUN nodo semantico de '
              'la barra superior: ni los enlaces, ni tema, ni idioma, ni la '
              'campana. Falta "${destination.semanticLabel}" '
              '(${destination.route}).',
        );
      }

      handle.dispose();
    },
  );
}
