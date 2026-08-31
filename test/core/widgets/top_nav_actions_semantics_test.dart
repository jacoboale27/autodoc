// test/core/widgets/top_nav_actions_semantics_test.dart
//
// Los tres envoltorios `Semantics(button: true, label: ...)` de las acciones
// de la barra superior (idioma, campana, avatar) envuelven widgets que YA
// llevan `Tooltip` -y, en la campana, un `IconButton`-. `Tooltip` publica el
// nombre en el campo `tooltip` del nodo, asi que anadir un `label` con la
// MISMA cadena produce el patron de "etiquetas duplicadas (Ayuda Ayuda)" que
// el informe de QA lista como defecto en su §2.13.
//
// Este test lee el arbol semantico de verdad -no asume por analogia- y fija
// lo unico que cada envoltorio tiene que aportar: el rol de boton donde el
// widget de dentro no lo da (InkWell), y ni una cadena repetida.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_top_nav_bar.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../support/shell_harness.dart';

/// Nodo semantico que cubre la barra (o su ancestro mas cercano si la barra
/// no publica uno propio): desde ahi se alcanza todo su subarbol.
SemanticsNode _raiz(WidgetTester tester) =>
    tester.getSemantics(find.byType(AppTopNavBar));

List<SemanticsNode> _todosLosNodos(SemanticsNode raiz) {
  final out = <SemanticsNode>[raiz];
  raiz.visitChildren((hijo) {
    out.addAll(_todosLosNodos(hijo));
    return true;
  });
  return out;
}

/// Cuantos nodos anuncian [texto], ya sea por `label` o por `tooltip`.
int _nodosQueAnuncian(WidgetTester tester, String texto) {
  return _todosLosNodos(
    _raiz(tester),
  ).where((n) => n.label == texto || n.tooltip == texto).length;
}

void main() {
  testWidgets(
    'cada accion de la barra superior se anuncia una sola vez y conserva el '
    'rol de boton',
    (tester) async {
      final handle = tester.ensureSemantics();

      await pumpTopNav(tester, width: 1440);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AppTopNavBar)),
      )!;

      // --- Campana: el IconButton ya trae isButton, tap y su nombre en
      // `tooltip`. El envoltorio anadia un nodo padre sin acciones con la
      // misma cadena: dos paradas seguidas que dicen lo mismo.
      expect(
        _nodosQueAnuncian(tester, l10n.notifications),
        1,
        reason:
            'la campana no puede anunciarse dos veces (nodo padre del '
            'envoltorio + nodo del IconButton)',
      );

      // --- Idioma y cuenta: son InkWell, que NO aporta isButton, asi que
      // el envoltorio sigue haciendo falta para el rol. Lo que sobra es el
      // `label` que repite la cadena del Tooltip en el mismo nodo.
      for (final texto in [
        l10n.topNavLanguageTooltip,
        l10n.topNavAccountTooltip,
      ]) {
        final nodos = _todosLosNodos(
          _raiz(tester),
        ).where((n) => n.label == texto || n.tooltip == texto).toList();

        expect(nodos.length, 1, reason: '"$texto" se anuncia una sola vez');
        expect(
          nodos.single.label == texto && nodos.single.tooltip == texto,
          isFalse,
          reason:
              '"$texto" no puede estar a la vez en label y en tooltip del '
              'mismo nodo: es la etiqueta duplicada del §2.13',
        );
        final datos = nodos.single.getSemanticsData();
        expect(
          datos.flagsCollection.isButton,
          isTrue,
          reason: '"$texto" tiene que seguir anunciandose como boton',
        );
        expect(
          datos.hasAction(SemanticsAction.tap),
          isTrue,
          reason: '"$texto" tiene que seguir siendo activable',
        );
      }

      // La campana tambien: su nodo unico conserva rol y accion.
      final campana = tester.getSemantics(
        find.byIcon(Icons.notifications_none_rounded),
      );
      expect(campana.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(campana.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    },
  );
}
