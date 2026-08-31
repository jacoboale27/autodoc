import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/services/push_notification_service.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/dashboard/presentation/pages/garage_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/shell_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

/// No-op: evita que `AuthSessionProvider` dispare
/// `PushNotificationService().updateUserToken(...)` contra Firebase
/// Messaging real cuando el stream emite un usuario autenticado (mismo
/// patrón que `test/core/providers/auth_session_provider_test.dart`).
class _FakePushNotificationService extends Fake
    implements PushNotificationService {
  @override
  Future<void> updateUserToken(String userId) async {}
}

/// `AuthSessionProvider()` por defecto cae en `FirebaseAuth.instance`, que
/// lanza sin `Firebase.initializeApp()`; se inyecta un `MockFirebaseAuth`,
/// igual que en `auth_session_provider_test.dart`.
///
/// Por defecto emite un usuario autenticado con uid `'u1'`: es el
/// `idPropietario` fijo de `fakeVehicle` (`test/support/vehicle_fixtures.dart`),
/// así que las acciones de "dueño" de cada tarjeta del garaje (p.ej. el
/// botón "Hacer Principal") se pintan como en producción en vez de quedar
/// ocultas por un `currentUserId` nulo. Pasa `uid: null` para simular una
/// sesión sin usuario.
///
/// Usa `Stream.value(...)` (de un solo valor), no un `StreamController` con
/// `await Future.delayed(...)`: `testWidgets` corre en la zona `FakeAsync`
/// del binding de test, donde un `Future.delayed` no se resuelve hasta que
/// algo avanza el reloj falso con `tester.pump(...)` — awaitarlo aquí, antes
/// de que exista un `tester` para pumpear, deja el listener de
/// `idTokenChanges()` colgado para siempre y cuelga el test (y con él, cada
/// test siguiente del archivo). `AuthSessionProvider` ya se suscribe en su
/// propio constructor (`lib/core/providers/auth_session_provider.dart:19`),
/// así que basta con dejar que el primer `pumpAndSettle`/`pump` de cada test
/// recoja el evento.
AuthSessionProvider _fakeAuthSessionProvider({String? uid = 'u1'}) {
  PushNotificationService.setInstanceForTesting(_FakePushNotificationService());

  final mockAuth = MockFirebaseAuth();
  if (uid == null) {
    when(mockAuth.idTokenChanges()).thenAnswer((_) => const Stream.empty());
  } else {
    final mockUser = MockUser();
    when(mockUser.uid).thenReturn(uid);
    when(mockAuth.idTokenChanges()).thenAnswer((_) => Stream.value(mockUser));
  }

  return AuthSessionProvider(firebaseAuth: mockAuth);
}

Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  int vehicleCount = 4,
  Brightness brightness = Brightness.light,
}) async {
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(
          value: fakeVehicleProvider(count: vehicleCount),
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
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

int renderedColumns(WidgetTester tester) {
  final grid = tester.widget<GridView>(find.byType(GridView).first);
  return (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
      .crossAxisCount;
}

void main() {
  test('no usa GoogleFonts ni colores literales', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/garage_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);

    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('//')) continue;
      if (lines[i].contains('Colors.transparent')) continue;
      if (RegExp(
        r'Color\(0x[0-9a-fA-F]{8}\)|Colors\.(white|black|grey|amber|red|green)',
      ).hasMatch(lines[i])) {
        offenders.add('${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('usa AppGrid y cambia de columnas en cada corte', (tester) async {
    await pumpScreen(tester, 375);
    expect(find.byType(AppGrid), findsOneWidget);
    expect(renderedColumns(tester), 1);

    await pumpScreen(tester, 768);
    expect(renderedColumns(tester), 2);

    await pumpScreen(tester, 1024);
    expect(renderedColumns(tester), 3);

    // No 4: AppGrid decide por el ancho real del panel (LayoutBuilder), no
    // por el viewport — es su diseño documentado a propósito, para que un
    // panel de 900px dentro de una ventana de 1300px use las columnas de
    // 900. El grid vive dentro de AppPageBody, que acota el contenido a
    // AppBreakpoints.maxContentWidth (1200) y le resta su gutter (40 en
    // `large`): a 1440px de viewport el panel real mide 1200 - 2*40 =
    // 1120px, que cae en `expanded` (840-1199), no en `large`. Por eso el
    // techo alcanzable es 3 columnas, no 4, en cualquier ancho de viewport.
    await pumpScreen(tester, 1440);
    expect(renderedColumns(tester), 3);
  });

  testWidgets('sin vehículos muestra AppEmptyState con acción', (tester) async {
    await pumpScreen(tester, 375, vehicleCount: 0);

    expect(find.byType(AppEmptyState), findsOneWidget);
    // AppButton ya no delega en el TextButton nativo de Flutter (Fase 3
    // Task 1 lo reescribió con Material+InkWell propios), así que se
    // localiza por su propio tipo en vez de TextButton.
    expect(
      find.descendant(
        of: find.byType(AppEmptyState),
        matching: find.byType(AppButton),
      ),
      findsWidgets,
      reason:
          'el estado vacío debe ofrecer añadir un vehículo, no solo '
          'informar de que no hay ninguno',
    );
  });

  testWidgets('la pestaña del shell no muestra botón de volver', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    expect(
      find.byIcon(Icons.arrow_back),
      findsNothing,
      reason: 'garage es una pestaña del ShellRoute: no hay a dónde volver',
    );
  });

  testWidgets('el badge de estado usa el icono de su severidad', (
    tester,
  ) async {
    await pumpScreen(tester, 375);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byIcon(Icons.check_circle_rounded),
      findsWidgets,
      reason: 'el estado óptimo se comunicaba solo con un punto de color',
    );
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });

  testWidgets('a 768 px el nombre del vehiculo no se recorta', (tester) async {
    await pumpScreen(tester, 768, vehicleCount: 4);
    await tester.pumpAndSettle();

    final l10n = tester.element(find.byType(GarageScreen)).l10n;

    // Ruling 17: sin el botón "Hacer Principal" en el árbol no hay nada
    // compitiendo por el ancho del Expanded del nombre, y la prueba de
    // ancho de abajo pasaría en verde aunque el bug siguiera sin corregir.
    // Se comprueba primero que el botón sí se pinta. Se usa el icono
    // (`Icons.star_border`), no el tooltip: lo comparten el `AppButton`
    // pre-fix (garage_screen.dart:317) y el `IconButton` post-fix, así que
    // este guard vale en ambos árboles y no hace que el red-run falle aquí
    // en vez de en la aserción de ancho de abajo.
    expect(
      find.byIcon(Icons.star_border),
      findsWidgets,
      reason:
          'sin "Hacer Principal" en el árbol la prueba de ancho del '
          'título sería vacía: nada compite por el espacio del Expanded',
    );

    // Ruling 16: la fixture (test/support/vehicle_fixtures.dart) siempre
    // arma 'Toyota'/'Corolla', nunca 'NISSAN GT-R'.
    final tituloFinder = find.text('Toyota Corolla').first;
    final titulo = tester.widget<Text>(tituloFinder);
    final render = tester.renderObject<RenderBox>(tituloFinder);
    final pintado = render.size.width;

    expect(
      pintado,
      greaterThan(120),
      reason:
          'con "Hacer Principal" sin restricción el Expanded se queda con '
          'las sobras y el título cae a dos letras ("To...")',
    );
    expect(titulo.overflow, TextOverflow.ellipsis);

    // Post-fix: el nombre accesible ("Hacer Principal") debe sobrevivir el
    // cambio de AppButton a IconButton (protege contra la Task 14, que es
    // justamente sobre nombres accesibles).
    expect(find.byTooltip(l10n.garageMakePrimary), findsWidgets);
  });
}
