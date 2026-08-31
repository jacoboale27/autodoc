// test/features/dashboard/presentation/pages/garage_star_semantics_test.dart
//
// `AppCard` pone `excludeSemantics: true` siempre que hay `onTap`, lo que
// borra la semantica de TODOS sus hijos. El `IconButton` de "Hacer
// Principal" vive dentro de una `AppCard` pulsable del garaje y ademas
// perdio su texto visible, asi que hoy es una estrella sin etiqueta para
// quien ve y un boton invisible para quien usa lector de pantalla — justo
// el "boton sin nombre" que el `assert` de `semanticLabel` existe para
// evitar.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/services/push_notification_service.dart';
import 'package:autodoc/features/dashboard/presentation/pages/garage_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/shell_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

class _FakePushNotificationService extends Fake
    implements PushNotificationService {
  @override
  Future<void> updateUserToken(String userId) async {}
}

AuthSessionProvider _fakeAuthSessionProvider() {
  PushNotificationService.setInstanceForTesting(_FakePushNotificationService());
  final mockAuth = MockFirebaseAuth();
  final mockUser = MockUser();
  when(mockUser.uid).thenReturn('u1');
  when(mockAuth.idTokenChanges()).thenAnswer((_) => Stream.value(mockUser));
  return AuthSessionProvider(firebaseAuth: mockAuth);
}

void main() {
  testWidgets(
    'el boton "Hacer Principal" de cada tarjeta del garaje tiene nombre en '
    'el arbol de accesibilidad',
    (tester) async {
      final handle = tester.ensureSemantics();

      await pumpAtWidth(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<VehicleProvider>.value(
              value: fakeVehicleProvider(count: 2),
            ),
            ChangeNotifierProvider<AlertProvider>(
              create: (_) => AlertProvider(
                firestore: FakeFirebaseFirestore(),
                storage: MockFirebaseStorage(),
              ),
            ),
            ChangeNotifierProvider<AuthSessionProvider>.value(
              value: _fakeAuthSessionProvider(),
            ),
            ChangeNotifierProvider<UserProfileProvider>.value(
              value: FakeProfileProvider('Propietario'),
            ),
          ],
          child: const GarageScreen(),
        ),
        width: 1024,
      );
      // `FadeInAnimation` arranca en opacidad 0, y un `Opacity(0)` no
      // publica semantica: hay que dejar terminar la animacion de entrada.
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(GarageScreen)),
      )!;

      final estrellas = find.ancestor(
        of: find.byIcon(Icons.star_border),
        matching: find.byType(IconButton),
      );
      expect(
        estrellas,
        findsNWidgets(2),
        reason: 'sanity: los dos vehiculos ofrecen "Hacer Principal"',
      );

      // El nodo semantico propio del boton: `excludeSemantics` de AppCard lo
      // borraba, y `getSemantics` devolvia entonces la celda del grid (sin
      // tooltip, sin flag de boton y sin accion de tap).
      final nodo = tester.getSemantics(estrellas.first);
      expect(
        nodo.tooltip,
        l10n.garageMakePrimary,
        reason:
            'el boton tiene que llegar al arbol con su nombre: hoy es una '
            'estrella sin texto para quien ve, asi que sin este nodo es un '
            'boton sin nombre para quien usa lector de pantalla',
      );
      expect(nodo.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        nodo.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'y tiene que poder activarse, no solo anunciarse',
      );

      // La tarjeta sigue teniendo su propio nombre: exponer a los hijos no
      // puede costar el label de la tarjeta.
      expect(
        find.bySemanticsLabel(RegExp('Toyota Corolla, placa P000-123')),
        findsOneWidget,
      );

      handle.dispose();
    },
  );
}
