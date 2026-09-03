import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/add_vehicle_form.dart';
import 'package:autodoc/l10n/app_localizations.dart';

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

Future<void> _advanceToDetailsStep(WidgetTester tester) async {
  await tester.pumpAndSettle();
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

Future<void> _fillYear(WidgetTester tester, String year) async {
  final selector = find.widgetWithText(InkWell, 'Selecciona el año');
  // En las ventanas cortas de este archivo el selector nace fuera de la
  // parte visible del paso; hay que traerlo antes de poder tocarlo.
  await tester.ensureVisible(selector);
  await tester.pumpAndSettle();
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(find.text(year).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'kilometraje vacío bloquea el envío señalando el error en el propio campo',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      VehicleModel? finishedVehicle;

      await http.runWithClient(() async {
        await tester.pumpWidget(
          _wrap(
            AddVehicleForm(
              onFinish: (v) async => finishedVehicle = v,
              primaryColor: Colors.blue,
            ),
          ),
        );

        await _advanceToDetailsStep(tester);

        // Todo válido salvo el kilometraje, que se deja vacío: el hint es
        // '0' y el campo no se anuncia como obligatorio.
        await tester.enterText(find.byType(TextFormField).at(0), 'P12300A');
        await _fillYear(tester, '2026');
        await tester.enterText(find.byType(TextFormField).at(1), 'Rojo');
        await tester.pump();

        await tester.tap(find.text('Finalizar Registro'));
        await tester.pumpAndSettle();

        // No avanza (correcto), pero el usuario debe ver POR QUÉ, en el
        // campo. Hoy solo se dispara un SnackBar que en la app real queda
        // detrás del modal bottom sheet a pantalla completa.
        expect(find.text('¡Vehículo Registrado!'), findsNothing);
        expect(finishedVehicle, isNull);
        expect(
          find.text('Kilometraje inválido'),
          findsNothing,
          reason: 'el aviso no debe depender de un SnackBar tapado',
        );
        expect(
          find.descendant(
            of: find.byType(Form),
            matching: find.text(
              'Ingresa el kilometraje actual (0 si es nuevo)',
            ),
          ),
          findsOneWidget,
          reason: 'el error debe pintarse bajo el campo de kilometraje',
        );
      }, _emptyResultsClientFactory);
    },
  );

  testWidgets('kilometraje no numérico marca el error de formato en el campo', (
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
            onFinish: (v) async => finishedVehicle = v,
            primaryColor: Colors.blue,
          ),
        ),
      );

      await _advanceToDetailsStep(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'P12300A');
      await _fillYear(tester, '2026');
      await tester.enterText(find.byType(TextFormField).at(1), 'Rojo');
      await tester.enterText(find.byType(TextFormField).at(2), '-5');
      await tester.pump();

      await tester.tap(find.text('Finalizar Registro'));
      await tester.pumpAndSettle();

      expect(find.text('¡Vehículo Registrado!'), findsNothing);
      expect(finishedVehicle, isNull);
      expect(
        find.text('El kilometraje debe ser un número entero de 0 o más'),
        findsOneWidget,
      );
    }, _emptyResultsClientFactory);
  });

  testWidgets('kilometraje 0 es válido y deja avanzar al paso de éxito', (
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

      await tester.enterText(find.byType(TextFormField).at(0), 'P12300A');
      await _fillYear(tester, '2026');
      await tester.enterText(find.byType(TextFormField).at(1), 'Rojo');
      await tester.enterText(find.byType(TextFormField).at(2), '0');
      await tester.pump();

      await tester.tap(find.text('Finalizar Registro'));
      await tester.pumpAndSettle();

      expect(find.text('¡Vehículo Registrado!'), findsOneWidget);
    }, _emptyResultsClientFactory);
  });

  testWidgets('en una pantalla corta, una placa inválida se trae a la vista '
      'en vez de dejar el error fuera de pantalla', (tester) async {
    // Ventana corta: el botón queda abajo y la placa arriba, fuera de la
    // ventana visible. Sin desplazamiento, el usuario no ve el error.
    // (El ancho se mantiene ancho porque el Row del selector de año
    // desborda por debajo de ~250px de ancho disponible; ese es un defecto
    // de layout distinto y preexistente.)
    tester.view.physicalSize = const Size(1000, 380);
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

      await tester.enterText(find.byType(TextFormField).at(0), 'P12');
      await _fillYear(tester, '2026');
      await tester.enterText(find.byType(TextFormField).at(1), 'Rojo');
      await tester.enterText(find.byType(TextFormField).at(2), '15000');
      await tester.pump();

      // Desplázate hasta el botón, como hace cualquiera para pulsarlo.
      // Cada TextField trae su propio Scrollable; el del paso es el que
      // envuelve al Form.
      final scrollable = find
          .ancestor(of: find.byType(Form), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(
        find.text('Finalizar Registro'),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finalizar Registro'));
      await tester.pumpAndSettle();

      final errorFinder = find.text('Formato inválido. Ej: P123-456 o P12-345');
      expect(errorFinder, findsOneWidget);

      // El error tiene que caer dentro de la ventana visible.
      final rect = tester.getRect(errorFinder);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(rect.top, greaterThanOrEqualTo(0.0));
      expect(rect.bottom, lessThanOrEqualTo(screen.height));
    }, _emptyResultsClientFactory);
  });
}
