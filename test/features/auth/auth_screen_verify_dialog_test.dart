// test/features/auth/auth_screen_verify_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../helpers/test_helpers.mocks.dart';
import '../../support/entry_harness.dart';

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUser extends Mock implements User {}

/// Monta `AuthScreen` (alta o login), completa el formulario con datos
/// validos y lo envia con un `AuthService` mockeado que siempre tiene exito,
/// para dejar en pantalla el mismo dialogo de verificacion de correo que
/// dispara `_handleEmailRegister`/`_navigateAfterAuth` en produccion
/// (`auth_screen.dart:551` y `:516`).
///
/// No existe forma de invocar `_showEmailVerificationDialog` directamente
/// (es privado a `_AuthScreenState`), asi que este helper recorre el camino
/// real: llenar el formulario y tocar el boton de envio.
///
/// El camino de login pasa por `AuthProvider.needsEmailVerification`, que lee
/// `FirebaseAuth.instance.currentUser` directamente (no es inyectable). Con
/// `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` (mismo patron que
/// `service_history_screen_test.dart:26-32`) existe una app `"[DEFAULT]"`
/// registrada y `FirebaseAuth.instance` deja de lanzar, pero eso por si solo
/// NO produce un usuario autenticado: `currentUser` sigue siendo `null`
/// porque `setupFirebaseCoreMocks()` solo mockea el canal de
/// `firebase_core`, no el de `firebase_auth` — nada en este repo hoy mockea
/// `FirebaseAuthPlatform.instance` (verificado con
/// `grep -rl FirebaseAuthPlatform test/`, sin resultados). Para que
/// `needsEmailVerification` de `true` haria falta ademas asignar
/// `FirebaseAuthPlatform.instance` a una implementacion falsa de esa interfaz
/// de plataforma (ver `package:firebase_auth/test/firebase_auth_test.dart`
/// en el paquete, que hace exactamente eso con un `Mock implements
/// FirebaseAuthPlatform`), que es una pieza nueva y mas pesada que este
/// helper no construye. Por eso el escenario de login se cubre abajo
/// dejando `currentUser` en `null` (mismo estado que produce
/// `needsEmailVerification == false` en produccion cuando no hay sesion) y
/// documentando la limitacion en el propio test.
Future<void> pumpVerifyDialog(
  WidgetTester tester, {
  required bool isRegistration,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final mockAuthService = MockAuthService();
  when(mockAuthService.isEmailPasswordUser).thenReturn(true);
  when(mockAuthService.isCurrentUserEmailVerified).thenReturn(false);

  if (isRegistration) {
    final mockCredential = _MockUserCredential();
    final mockUser = _MockUser();
    when(mockCredential.user).thenReturn(mockUser);
    when(
      mockAuthService.registerWithEmail(any, any),
    ).thenAnswer((_) async => mockCredential);
    when(mockAuthService.sendEmailVerification()).thenAnswer((_) async {});
  } else {
    final mockCredential = _MockUserCredential();
    final mockUser = _MockUser();
    when(mockCredential.user).thenReturn(mockUser);
    when(
      mockAuthService.signInWithEmail(any, any),
    ).thenAnswer((_) async => mockCredential);
    await Firebase.initializeApp();
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            authService: mockAuthService,
            adminAuthService: MockAdminAuthService(),
          ),
        ),
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: FakeUserProfileProvider(userData: testUser()),
        ),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AuthScreen(isLogin: !isRegistration),
      ),
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 50));

  await tester.enterText(
    find.byKey(const ValueKey('auth-email-field')),
    'nueva@autodoc.app',
  );
  await tester.enterText(
    find.byKey(const ValueKey('auth-password-field')),
    'secreta123',
  );
  await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
  await tester.tap(find.byKey(const ValueKey('auth-submit')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  testWidgets(
    'en el alta el texto no menciona un boton que el dialogo no dibuja',
    (tester) async {
      await pumpVerifyDialog(tester, isRegistration: true);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ya verifiqué'), findsNothing);
      expect(find.text('Entendido'), findsOneWidget);
    },
  );

  // NOTA para quien retome esto (ver Fix round 1 en task-10-report.md):
  //
  // Se intento un test hermano para el login ("en el login el texto SI
  // menciona 'Ya verifiqué' y el boton existe") reusando exactamente el
  // patron pedido en la revision (`setupFirebaseCoreMocks()` +
  // `Firebase.initializeApp()`, como en
  // `service_history_screen_test.dart:26-32`). `pumpVerifyDialog` de arriba
  // ya soporta `isRegistration: false` con ese mismo patron (mockea
  // `AuthService.signInWithEmail` para que el login "tenga exito" e
  // inicializa Firebase para que `FirebaseAuth.instance` no lance).
  //
  // Resultado real, verbatim (ver el reporte): el test fallo — NO con una
  // excepcion, sino con `find.textContaining('Ya verifiqué')` devolviendo 0
  // widgets. El dialogo nunca se abre. Causa: `_navigateAfterAuth` solo
  // llama a `_showEmailVerificationDialog` cuando
  // `AuthProvider.needsEmailVerification` es `true`, y ese getter mira
  // `FirebaseAuth.instance.currentUser` — no el `AuthService` inyectado.
  // `setupFirebaseCoreMocks()` mockea unicamente el canal de
  // `firebase_core` (registra la app `"[DEFAULT]"` para que
  // `FirebaseAuth.instance` no explote), pero no mockea el canal de
  // `firebase_auth`: sin una sesion real, `currentUser` se queda en `null`
  // pase lo que pase con `AuthService`, asi que `needsEmailVerification`
  // nunca da `true` y el dialogo de login jamas aparece en este entorno de
  // test. Esto es exactamente lo que ya hacen los 10 archivos citados en la
  // revision (`service_history_screen_test.dart` entre ellos): usan ese
  // patron para que `currentUser == null` no explote, no para simular una
  // sesion iniciada — su propio comentario lo dice ("cubren eso sin
  // necesitar un usuario autenticado real").
  //
  // Para que `currentUser` devuelva un usuario falso haria falta mockear
  // `FirebaseAuthPlatform.instance` (la interfaz de plataforma de
  // `firebase_auth`, no `FirebaseAuth` en si). El propio paquete
  // `firebase_auth` lo hace en su suite (`test/firebase_auth_test.dart` +
  // `test/mock.dart` dentro de
  // `firebase_auth-6.4.0`), con una clase `MockFirebaseAuth extends Mock
  // with MockPlatformInterfaceMixin implements TestFirebaseAuthPlatform`
  // que implementa decenas de metodos de la plataforma (streams
  // `authStateChanges`/`idTokenChanges`/`userChanges`, `delegateFor`, etc.).
  // Ese patron no existe hoy en ningun test de este repo (`grep -rl
  // FirebaseAuthPlatform test/` no devuelve nada) y es una pieza de
  // infraestructura nueva y sustancialmente mas pesada que "seguir la forma
  // de `service_history_screen_test.dart`": no se construyo aqui a la
  // espera de la decision del coordinador (ver Fix round 1 del reporte).
}
