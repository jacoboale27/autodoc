// test/features/auth/auth_screen_verify_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/app_button.dart';
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
/// El camino de login depende de `AuthProvider.needsEmailVerification`, que
/// ahora pregunta a `_authService.isCurrentUserSignedIn` (Ruling 31) en vez
/// de leer `FirebaseAuth.instance.currentUser` directamente, asi que basta
/// con mockear `AuthService` — sin tocar Firebase real ni su plataforma.
Future<void> pumpVerifyDialog(
  WidgetTester tester, {
  required bool isRegistration,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final mockAuthService = MockAuthService();
  when(mockAuthService.isEmailPasswordUser).thenReturn(true);
  when(mockAuthService.isCurrentUserEmailVerified).thenReturn(false);
  when(mockAuthService.isCurrentUserSignedIn).thenReturn(!isRegistration);

  final mockCredential = _MockUserCredential();
  final mockUser = _MockUser();
  when(mockCredential.user).thenReturn(mockUser);

  if (isRegistration) {
    when(
      mockAuthService.registerWithEmail(any, any),
    ).thenAnswer((_) async => mockCredential);
    when(mockAuthService.sendEmailVerification()).thenAnswer((_) async {});
  } else {
    when(
      mockAuthService.signInWithEmail(any, any),
    ).thenAnswer((_) async => mockCredential);
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
  testWidgets(
    'en el alta el texto no menciona un boton que el dialogo no dibuja',
    (tester) async {
      await pumpVerifyDialog(tester, isRegistration: true);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ya verifiqué'), findsNothing);
      expect(find.text('Entendido'), findsOneWidget);
    },
  );

  testWidgets(
    'en el login el texto SI menciona "Ya verifiqué" y el boton existe',
    (tester) async {
      await pumpVerifyDialog(tester, isRegistration: false);
      await tester.pumpAndSettle();

      // Las dos mitades de lo que hace correcto este texto en login: el
      // cuerpo lo menciona Y el boton realmente esta en el arbol. Afirmar
      // solo una de las dos deja a la otra libre de desviarse sin que
      // ningun test lo note.
      expect(
        find.textContaining('Ya verifiqué'),
        findsWidgets,
        reason:
            'En login el dialogo debe seguir citando "Ya verifiqué" '
            '(authOpenLinkThenVerify): ese boton si existe en esta rama.',
      );
      expect(
        find.widgetWithText(AppButton, 'Ya verifiqué'),
        findsOneWidget,
        reason:
            'El boton "Ya verifiqué" (authAlreadyVerified) debe seguir '
            'dibujandose en la rama de login.',
      );
    },
  );
}
