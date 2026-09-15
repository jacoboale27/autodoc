import 'dart:async';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/features/dashboard/data/services/vehicle_photo_service.dart';
import 'package:autodoc/features/dashboard/presentation/pages/vehicle_profile_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'helpers/test_helpers.mocks.dart';
import 'support/responsive_harness.dart';

class _ActualizacionesPendientes extends VehicleProvider {
  _ActualizacionesPendientes()
    : super(
        vehicleService: MockVehicleService(),
        imageService: MockVehicleImageService(),
      );

  Completer<bool> pendiente = Completer<bool>();
  final actualizaciones = <VehicleModel>[];

  @override
  Future<bool> updateVehicle(VehicleModel vehicle) {
    actualizaciones.add(vehicle);
    return pendiente.future;
  }
}

class _AuthSession extends Mock implements AuthSessionProvider {}

const _sinFotos = Stream<List<VehiclePhotoModel>>.empty();

VehicleModel _vehiculo() => VehicleModel(
  idVehiculo: 'vehiculo-1',
  idPropietario: 'dueno-1',
  placa: 'ABC123',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2020,
  color: 'Azul',
  kilometrajeActual: 1000,
);

Future<void> _montar(
  WidgetTester tester, {
  required VehicleProvider provider,
  required MockVehicleService service,
}) async {
  when(service.getExpenseSummary(any)).thenAnswer((_) async => {});
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(value: provider),
        ChangeNotifierProvider<AuthSessionProvider>.value(
          value: _AuthSession(),
        ),
      ],
      child: VehicleProfileScreen(
        vehiculoId: 'vehiculo-1',
        vehiculoPrecargado: _vehiculo(),
        vehicleService: service,
        galleryPhotos: _sinFotos,
      ),
    ),
    width: 800,
    height: 2400,
    disableAnimations: true,
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'dos taps en guardar kilometraje producen una sola actualizacion pendiente',
    (tester) async {
      final provider = _ActualizacionesPendientes();
      final service = MockVehicleService();
      await _montar(tester, provider: provider, service: service);

      // El tap va a la AppCard y no al Text: el onTap vive en la tarjeta, y
      // tocar el texto no lo alcanza.
      final km = find.widgetWithText(AppCard, '1000 km');
      await tester.ensureVisible(km);
      await tester.tap(km);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '1200');

      await tester.tap(find.text('Guardar'));
      await tester.pump();

      // Con la escritura en vuelo `AppButton` pasa a `isLoading`, que SUSTITUYE
      // el rotulo por un spinner: que "Guardar" ya no exista es la prueba de
      // que el boton dejo de aceptar taps. (Y por eso no se puede usar
      // pumpAndSettle aqui: el spinner no deja de animar nunca.)
      expect(find.text('Guardar'), findsNothing);
      expect(provider.actualizaciones, hasLength(1));
      expect(provider.actualizaciones.single.kilometrajeActual, 1200);

      // Se completa con `false` a proposito: la rama de exito llama a
      // `context.pop()` de go_router, que este harness no monta. La de error
      // recorre el `finally`, que es lo que hay que comprobar.
      provider.pendiente.complete(false);
      await tester.pump();
      expect(
        find.text('Guardar'),
        findsOneWidget,
        reason: 'la bandera tiene que reponerse aunque la escritura falle',
      );
      // El snackbar de error deja un Timer de auto-cierre; sin agotarlo el
      // binding falla con "A Timer is still pending".
      await tester.pumpAndSettle(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'dos taps en actualizar fecha producen una sola actualizacion pendiente',
    (tester) async {
      final provider = _ActualizacionesPendientes();
      final service = MockVehicleService();
      await _montar(tester, provider: provider, service: service);

      final actualizar = find.text('Actualizar').first;
      await tester.ensureVisible(actualizar);
      await tester.tap(actualizar);
      await tester.pumpAndSettle();
      // El rotulo de aceptar del picker lo pone GlobalMaterialLocalizations y
      // cambia con el idioma: se confirma por posicion.
      final picker = find.byType(DatePickerDialog);
      expect(picker, findsOneWidget);
      await tester.tap(
        find.descendant(of: picker, matching: find.byType(TextButton)).last,
      );
      await tester.pumpAndSettle();

      // Con la escritura en vuelo el boton de esa fecha esta deshabilitado, asi
      // que el segundo tap no puede abrir otro picker.
      await tester.tap(actualizar, warnIfMissed: false);
      await tester.pump();
      expect(find.byType(DatePickerDialog), findsNothing);

      expect(provider.actualizaciones, hasLength(1));

      provider.pendiente.complete(true);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dos taps en guardar nota producen una sola escritura pendiente',
    (tester) async {
      final provider = _ActualizacionesPendientes();
      final service = MockVehicleService();
      final pendiente = Completer<void>();
      var llamadas = 0;
      when(service.addNote(any, any)).thenAnswer((_) {
        llamadas++;
        return pendiente.future;
      });
      await _montar(tester, provider: provider, service: service);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Revisar frenos');
      final guardar = find.widgetWithText(TextButton, 'Guardar');
      await tester.tap(guardar);
      await tester.pump();
      await tester.tap(guardar);
      await tester.pump();

      expect(llamadas, 1);

      pendiente.complete();
      await tester.pumpAndSettle();
    },
  );
}
