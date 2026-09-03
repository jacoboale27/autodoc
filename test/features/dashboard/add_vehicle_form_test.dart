import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/add_vehicle_form.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// Fakes NHTSA `getallmakes`/`getmodelsformake` responses with empty result
/// sets so [AddVehicleForm]'s brand/model steps immediately land on their
/// "not found, enter manually" affordance instead of waiting on real network
/// access (unavailable in the test sandbox).
http.Client _emptyResultsClientFactory() {
  return MockClient((request) async {
    return http.Response(jsonEncode({'Results': <dynamic>[]}), 200);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('es'),
    home: Scaffold(body: child),
  );
}

/// Drives the wizard from the initial brand step through to the "Detalles"
/// step (index 2, the one that hosts the plate `Form`) by using the manual
/// "no lo encuentro" entry path for both brand and model, which does not
/// depend on the (faked, empty) NHTSA lookup results.
Future<void> _advanceToDetailsStep(WidgetTester tester) async {
  await tester.pumpAndSettle();

  // Brand step: with no makes returned, only the "not found" tile shows.
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

  // Model step: same "not found" manual path.
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

  // Now on the Details step: the plate field's Form should be visible.
  expect(find.text('Número de Placa'), findsOneWidget);
}

Future<void> _fillYear(WidgetTester tester, String year) async {
  // El placeholder ya no es el literal '2024' (ver
  // add_vehicle_form_anio_test.dart): con el campo vacío se pinta el hint
  // localizado.
  await tester.tap(find.widgetWithText(InkWell, 'Selecciona el año'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(year).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('invalid/incomplete plate blocks submission and shows the plate '
      'validator error, without calling onFinish', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    VehicleModel? finishedVehicle;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        _wrap(
          AddVehicleForm(
            onFinish: (v) async {
              finishedVehicle = v;
            },
            primaryColor: Colors.blue,
          ),
        ),
      );

      await _advanceToDetailsStep(tester);

      // Incomplete plate: formatter yields 'P12', which does not match
      // placaElSalvadorPattern (needs P + 1-3 digits + '-' + 3 hex).
      await tester.enterText(find.byType(TextFormField).at(0), 'P12');
      await _fillYear(tester, '2026');
      await tester.enterText(find.byType(TextFormField).at(1), 'Rojo');
      await tester.enterText(find.byType(TextFormField).at(2), '15000');
      await tester.pump();

      await tester.tap(find.text('Finalizar Registro'));
      await tester.pumpAndSettle();

      // The plate validator's error text is shown inline...
      expect(
        find.text('Formato inválido. Ej: P123-456 o P12-345'),
        findsOneWidget,
      );
      // ...submission did not proceed past the Details step...
      expect(find.text('Número de Placa'), findsOneWidget);
      expect(find.text('¡Vehículo Registrado!'), findsNothing);
      // ...and onFinish was never invoked.
      expect(finishedVehicle, isNull);
    }, _emptyResultsClientFactory);
  });

  testWidgets('valid plate and valid other fields let submission proceed and '
      'eventually invoke onFinish', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    VehicleModel? finishedVehicle;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        _wrap(
          AddVehicleForm(
            onFinish: (v) async {
              finishedVehicle = v;
            },
            primaryColor: Colors.blue,
          ),
        ),
      );

      await _advanceToDetailsStep(tester);

      // Raw digits/letters typed by the user; PlateFormatter inserts the
      // 'P' prefix and '-' separator as-you-type, producing 'P123-00A'.
      await tester.enterText(find.byType(TextFormField).at(0), 'P12300A');
      await _fillYear(tester, '2026');
      await tester.enterText(find.byType(TextFormField).at(1), 'Rojo');
      await tester.enterText(find.byType(TextFormField).at(2), '15000');
      await tester.pump();

      await tester.tap(find.text('Finalizar Registro'));
      await tester.pumpAndSettle();

      // No plate validation error, and the wizard advanced to the
      // success step.
      expect(
        find.text('Formato inválido. Ej: P123-456 o P12-345'),
        findsNothing,
      );
      expect(find.text('¡Vehículo Registrado!'), findsOneWidget);

      // Completing the success step's CTA invokes onFinish with the
      // correctly-formatted plate. The button shows an indefinite spinner
      // afterwards (the caller is expected to dismiss the widget on
      // success), so pump a bounded number of frames instead of
      // pumpAndSettle to avoid hanging on that animation.
      await tester.tap(find.text('Ir al Dashboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(finishedVehicle, isNotNull);
      expect(finishedVehicle!.placa, 'P123-00A');
    }, _emptyResultsClientFactory);
  });

  testWidgets('una placa de cinco caracteres (P12-345) se registra igual que '
      'una de seis: hay vehículos cuyo correlativo no llega a 100.000', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    VehicleModel? finishedVehicle;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        _wrap(
          AddVehicleForm(
            onFinish: (v) async {
              finishedVehicle = v;
            },
            primaryColor: Colors.blue,
          ),
        ),
      );

      await _advanceToDetailsStep(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'P12345');
      await _fillYear(tester, '2026');
      await tester.enterText(find.byType(TextFormField).at(1), 'Rojo');
      await tester.enterText(find.byType(TextFormField).at(2), '15000');
      await tester.pump();

      await tester.tap(find.text('Finalizar Registro'));
      await tester.pumpAndSettle();

      expect(find.text('¡Vehículo Registrado!'), findsOneWidget);

      await tester.tap(find.text('Ir al Dashboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Se guarda tal cual, sin rellenar con un cero que no está estampado
      // en la placa real.
      expect(finishedVehicle, isNotNull);
      expect(finishedVehicle!.placa, 'P12-345');
    }, _emptyResultsClientFactory);
  });

  testWidgets('se puede registrar una moto eligiendo el tipo de placa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    VehicleModel? finishedVehicle;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        _wrap(
          AddVehicleForm(
            onFinish: (v) async {
              finishedVehicle = v;
            },
            primaryColor: Colors.blue,
          ),
        ),
      );

      await _advanceToDetailsStep(tester);

      await tester.tap(find.text('Moto'));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).at(0), '12345');
      await _fillYear(tester, '2026');
      await tester.enterText(find.byType(TextFormField).at(1), 'Rojo');
      await tester.enterText(find.byType(TextFormField).at(2), '15000');
      await tester.pump();

      await tester.tap(find.text('Finalizar Registro'));
      await tester.pumpAndSettle();

      expect(find.text('¡Vehículo Registrado!'), findsOneWidget);

      await tester.tap(find.text('Ir al Dashboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(finishedVehicle, isNotNull);
      expect(finishedVehicle!.placa, 'M12-345');
    }, _emptyResultsClientFactory);
  });

  testWidgets('cambiar de tipo reescribe el prefijo sin borrar lo tecleado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await http.runWithClient(() async {
      await tester.pumpWidget(
        _wrap(
          AddVehicleForm(onFinish: (v) async {}, primaryColor: Colors.blue),
        ),
      );

      await _advanceToDetailsStep(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '12345');
      await tester.pump();
      expect(find.text('P12-345'), findsOneWidget);

      await tester.tap(find.text('Carga'));
      await tester.pump();
      expect(find.text('C12-345'), findsOneWidget);
      expect(find.text('P12-345'), findsNothing);

      // Y de vuelta, sin perder el correlativo por el camino.
      await tester.tap(find.text('Alquiler'));
      await tester.pump();
      expect(find.text('A12-345'), findsOneWidget);
    }, _emptyResultsClientFactory);
  });
}
