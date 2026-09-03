import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/add_vehicle_form.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../../../support/responsive_harness.dart';

/// Fakes NHTSA `getallmakes`/`getmodelsformake` responses with empty result
/// sets so [AddVehicleForm]'s brand/model steps immediately land on their
/// "not found, enter manually" affordance instead of waiting on real network
/// access (unavailable in the test sandbox). Mirrors
/// `add_vehicle_form_anio_test.dart`.
http.Client _emptyResultsClientFactory() {
  return MockClient((request) async {
    return http.Response(jsonEncode({'Results': <dynamic>[]}), 200);
  });
}

/// Fuerza el locale español bajo el `MaterialApp` que monta [pumpAtWidth].
/// Ver `add_vehicle_form_anio_test.dart` para el detalle de por qué.
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
/// "no lo encuentro" entry path. Same flow as
/// `add_vehicle_form_anio_test.dart`.
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
  testWidgets(
    // Hallazgo QA: "Gris13" llegó a producción porque el campo Color era
    // texto libre sin validar el formato.
    'un color con digitos marca el error en el propio campo, sin avanzar',
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

        await tester.enterText(find.byType(TextFormField).at(0), 'P12300A');
        final currentYear = DateTime.now().year.toString();
        await tester.tap(find.text('Año').hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text(currentYear).last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(1), 'Gris13');
        await tester.enterText(find.byType(TextFormField).at(2), '15000');
        await tester.pump();

        await tester.tap(find.text('Finalizar Registro'));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(AddVehicleForm));
        final l10n = AppLocalizations.of(element)!;

        expect(find.text(l10n.addVehicleColorInvalidChars), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        // No avanzó de paso: el error se quedó en el campo.
        expect(find.text('Número de Placa'), findsOneWidget);
      }, _emptyResultsClientFactory);
    },
  );

  testWidgets(
    'un color de solo letras y espacios pasa la validacion y avanza de paso',
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

        await tester.enterText(find.byType(TextFormField).at(0), 'P12300A');
        final currentYear = DateTime.now().year.toString();
        await tester.tap(find.text('Año').hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text(currentYear).last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(1), 'Gris Perla');
        await tester.enterText(find.byType(TextFormField).at(2), '15000');
        await tester.pump();

        await tester.tap(find.text('Finalizar Registro'));
        await tester.pumpAndSettle();

        // Avanzó al paso de éxito: ya no está en "Detalles".
        expect(find.text('Número de Placa'), findsNothing);
      }, _emptyResultsClientFactory);
    },
  );
}
