import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/add_vehicle_form.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../../../support/responsive_harness.dart';

/// Fakes NHTSA `getallmakes`/`getmodelsformake` responses with empty result
/// sets so [AddVehicleForm]'s brand/model steps immediately land on their
/// "not found, enter manually" affordance instead of waiting on real network
/// access (unavailable in the test sandbox). Mirrors
/// `test/features/dashboard/add_vehicle_form_test.dart`.
http.Client _emptyResultsClientFactory() {
  return MockClient((request) async {
    return http.Response(jsonEncode({'Results': <dynamic>[]}), 200);
  });
}

/// Fuerza el locale español bajo el `MaterialApp` que monta [pumpAtWidth],
/// que no expone un parámetro `locale` propio: envuelve [child] en un
/// `Localizations.override` descendente para que `context.l10n` y las
/// aserciones de texto sean deterministas sin tocar la firma del harness.
Widget _spanish(Widget child) {
  return Builder(
    builder: (context) => Localizations.override(
      context: context,
      locale: const Locale('es'),
      child: child,
    ),
  );
}

/// Drives the wizard from the initial brand step through to the "Detalles"
/// step (index 2, the one that hosts the año/color fields) via the manual
/// "no lo encuentro" entry path, which does not depend on the (faked,
/// empty) NHTSA lookup results. Same flow as the sibling
/// `add_vehicle_form_test.dart`.
Future<void> _advanceToDetailsStep(WidgetTester tester) async {
  await tester.pumpAndSettle();

  expect(find.text('No encuentro mi marca...'), findsOneWidget);
  await tester.tap(find.text('No encuentro mi marca...'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    'Toyota',
  );
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();

  expect(find.text('No encuentro mi modelo...'), findsOneWidget);
  await tester.tap(find.text('No encuentro mi modelo...'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    'Corolla',
  );
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();

  expect(find.text('Número de Placa'), findsOneWidget);
}

void main() {
  testWidgets('el placeholder de año se pinta con textSecondary y sin negrita; '
      'un año elegido se pinta con textPrimary y en negrita', (tester) async {
    await http.runWithClient(() async {
      await pumpAtWidth(
        tester,
        _spanish(
          AddVehicleForm(onFinish: (_) async {}, primaryColor: Colors.blue),
        ),
        width: 1440,
        height: 1400,
      );

      await _advanceToDetailsStep(tester);

      final element = tester.element(find.byType(AddVehicleForm));
      final colors = Theme.of(element).extension<AppColors>()!;
      final hint = AppLocalizations.of(element)!.addVehicleYearHint;

      // Con el campo vacío, el placeholder no puede pesar visualmente
      // como un valor ya elegido: hasta 2026-08-28 aquí se pintaba el
      // literal '2024' en textPrimary/bold, indistinguible de un año
      // real, y el submit fallaba señalando un campo que a la vista
      // parecía correcto.
      final placeholder = find.text(hint);
      expect(placeholder, findsOneWidget);
      final placeholderStyle = tester.widget<Text>(placeholder).style!;
      expect(
        placeholderStyle.color,
        colors.textSecondary,
        reason:
            'un placeholder no puede tener el mismo peso visual que un valor real',
      );
      expect(placeholderStyle.fontWeight, isNot(FontWeight.bold));

      // Elegir un año real invierte el estilo: ahora sí debe leerse como
      // un valor relleno. Se elige el año actual (primer ítem de la lista,
      // generada como `currentYear - index`) porque es el único que la
      // `ListView` de 300px de alto garantiza tener ya construido sin
      // necesidad de hacer scroll.
      final currentYear = DateTime.now().year.toString();
      await tester.tap(find.widgetWithText(InkWell, hint));
      await tester.pumpAndSettle();
      await tester.tap(find.text(currentYear).last);
      await tester.pumpAndSettle();

      final chosen = find.text(currentYear);
      expect(chosen, findsOneWidget);
      final chosenStyle = tester.widget<Text>(chosen).style!;
      expect(chosenStyle.color, colors.textPrimary);
      expect(chosenStyle.fontWeight, FontWeight.bold);
    }, _emptyResultsClientFactory);
  });

  testWidgets(
    'un año fuera de rango marca el error en el propio campo, sin snackbar',
    (tester) async {
      await http.runWithClient(() async {
        await pumpAtWidth(
          tester,
          _spanish(
            AddVehicleForm(onFinish: (_) async {}, primaryColor: Colors.blue),
          ),
          width: 1440,
          height: 1400,
        );

        await _advanceToDetailsStep(tester);

        await tester.enterText(find.byType(TextFormField).at(0), 'P1A23B4');
        // El año se deja vacío a propósito: int.tryParse('') falla el
        // 1900/currentYear check en el onPressed de "Finalizar Registro".
        await tester.enterText(find.byType(TextFormField).at(1), 'Rojo');
        await tester.enterText(find.byType(TextFormField).at(2), '15000');
        await tester.pump();

        await tester.tap(find.text('Finalizar Registro'));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(AddVehicleForm));
        final l10n = AppLocalizations.of(element)!;

        expect(find.text(l10n.addVehicleYearInvalid), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        // No avanzó de paso: el error se quedó en el campo.
        expect(find.text('Número de Placa'), findsOneWidget);
      }, _emptyResultsClientFactory);
    },
  );
}
