import 'dart:typed_data';
import 'dart:async';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/dashboard/data/services/vehicle_photo_service.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/share_vehicle_sheet.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/vehicle_gallery_widget.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

const _colors = AppColors(
  primary: Colors.blue,
  secondary: Colors.teal,
  surface: Colors.white,
  surfaceContainer: Colors.white,
  error: Colors.red,
  warning: Colors.orange,
  success: Colors.green,
  textPrimary: Colors.black,
  textSecondary: Colors.grey,
  onPrimary: Colors.white,
  onSecondary: Colors.white,
  onError: Colors.white,
  surfaceVariant: Colors.white,
  outline: Colors.grey,
  shimmerBase: Colors.grey,
  shimmerHighlight: Colors.white,
  scrim: Colors.black,
  onScrim: Colors.white,
);

// El tema de AutoDoc registra AppColors como ThemeExtension; sin el,
// `context.appColors` de ShareVehicleSheet muere con un null check.
Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('es'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'dos taps en aceptar invitacion no se llevan la pantalla de debajo',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showVehicleInvitationAcceptance(
                context,
                acceptInvitation: (_) {
                  calls++;
                  return pending.future;
                },
              ),
              child: const Text('Abrir invitacion'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir invitacion'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'CODIGO-1');

      // El boton de aceptar hace Navigator.pop de inmediato. Dos taps en el
      // mismo frame hacian DOS pops: el segundo se llevaba la ruta de debajo,
      // dejando al usuario fuera de la pantalla en la que estaba.
      // El unico TextButton del arbol es la accion de aceptar del dialogo.
      final aceptar = find.byType(TextButton);
      await tester.tap(aceptar);
      await tester.tap(aceptar);
      await tester.pumpAndSettle();

      expect(calls, 1);
      // La pantalla de debajo sigue en pie.
      expect(find.text('Abrir invitacion'), findsOneWidget);

      pending.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dos taps en revocar acceso producen una sola escritura pendiente',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      final vehicle = VehicleModel(
        idVehiculo: 'vehiculo-1',
        idPropietario: 'dueno-1',
        placa: 'ABC-123',
        sharedWith: const ['usuario-1'],
      );

      await tester.pumpWidget(
        _app(
          ShareVehicleSheet(
            vehicle: vehicle,
            onUpdated: (_) {},
            loadSharedUsers: () async => const [
              {'uid': 'usuario-1', 'email': 'u@example.com', 'name': 'Ana'},
            ],
            revokeAccess: (_) {
              calls++;
              return pending.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final revoke = find.byTooltip('Revocar acceso');
      await tester.tap(revoke);
      await tester.tap(revoke);
      await tester.pump();

      expect(calls, 1);

      pending.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dos taps en subir foto producen una sola seleccion y una sola subida',
    (tester) async {
      final pending = Completer<void>();
      var pickerCalls = 0;
      var uploadCalls = 0;
      final image = XFile.fromData(
        Uint8List.fromList(const [1, 2, 3]),
        name: 'foto.jpg',
      );

      await tester.pumpWidget(
        _app(
          VehicleGalleryWidget(
            vehicleId: 'vehiculo-1',
            colors: _colors,
            photos: const Stream<List<VehiclePhotoModel>>.empty(),
            pickPhoto: () async {
              pickerCalls++;
              return image;
            },
            addPhoto: (_, __) {
              uploadCalls++;
              return pending.future;
            },
          ),
        ),
      );
      await tester.pump();

      final upload = find.byIcon(Icons.add_a_photo);
      await tester.tap(upload);
      await tester.pump();
      await tester.tap(upload);
      await tester.pump();

      expect(pickerCalls, 1);
      expect(uploadCalls, 1);

      pending.complete();
      await tester.pumpAndSettle();
    },
  );
}
