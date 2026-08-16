// test/support/entry_harness.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../helpers/test_helpers.mocks.dart';

/// Los dos idiomas soportados. Un desbordamiento de este modulo solo
/// aparece en `en`: toda tarea de pantalla debe recorrer esta lista, no
/// asumir `es`.
const List<Locale> kEntryLocales = <Locale>[Locale('es'), Locale('en')];

/// Usuario de prueba con valores estables (nada de `DateTime.now()`, que
/// haria los tests dependientes del reloj).
UserModel testUser({
  String id = 'u-1',
  String nombre = 'Usuario De Prueba',
  String correo = 'prueba@autodoc.app',
  String rol = 'Propietario',
  String? fotoPerfilUrl,
}) {
  return UserModel(
    idUsuario: id,
    nombreCompleto: nombre,
    correo: correo,
    rol: rol,
    fechaRegistro: DateTime.utc(2024, 3, 15),
    fotoPerfilUrl: fotoPerfilUrl,
  );
}

/// Doble de prueba de `UserProfileProvider`.
///
/// **Usa `implements`, no `extends`.** `UserProfileProvider` inicializa
/// `UserService()` como campo, y `UserService` toca
/// `FirebaseFirestore.instance` al construirse: heredar de el hace estallar
/// el test antes del primer `pump`. Misma leccion que la Fase 6.
class FakeUserProfileProvider
    with ChangeNotifier
    implements UserProfileProvider {
  FakeUserProfileProvider({
    UserModel? userData,
    this.isLoading = false,
    this.error,
    this.updateSucceeds = true,
  }) : _userData = userData;

  UserModel? _userData;
  @override
  bool isLoading;
  @override
  String? error;

  /// Controla el valor que devuelve [updateProfile], para poder ejercitar
  /// la rama de error de la pantalla de perfil sin tocar Firebase.
  bool updateSucceeds;

  /// Ultima llamada recibida, para aserciones.
  UserModel? lastUpdated;
  XFile? lastImageFile;

  @override
  UserModel? get userData => _userData;

  @override
  bool get hasAttemptedFetch => true;

  @override
  String? get fetchedUserId => _userData?.idUsuario;

  @override
  bool hasAttemptedFetchFor(String userId) => _userData?.idUsuario == userId;

  @override
  Future<void> fetchUserData(String userId) async {}

  @override
  Future<bool> updateProfile(
    UserModel updatedUser, {
    XFile? imageFile,
    bool isNewUser = false,
  }) async {
    lastUpdated = updatedUser;
    lastImageFile = imageFile;
    if (!updateSucceeds) return false;
    _userData = updatedUser;
    notifyListeners();
    return true;
  }

  @override
  void clearUserData() {
    _userData = null;
    notifyListeners();
  }
}

Widget _wrap(
  Widget child, {
  required Brightness brightness,
  required Locale locale,
  required bool disableAnimations,
  UserProfileProvider? profile,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(
          authService: MockAuthService(),
          adminAuthService: MockAdminAuthService(),
        ),
      ),
      ChangeNotifierProvider<UserProfileProvider>.value(
        value: profile ?? FakeUserProfileProvider(userData: testUser()),
      ),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(),
      ),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: textScaler,
          ),
          child: child,
        ),
      ),
    ),
  );
}

void _sizeView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Monta [child] y **asienta** las animaciones.
///
/// Necesario para `onboarding_screen`: con `pump()` a secas deja
/// temporizadores vivos y el test revienta en el teardown con
/// `Failed assertion: '!timersPending'`.
///
/// **No lo uses con `SplashScreen`** — su `AnimationController` usa
/// `..repeat()` y `pumpAndSettle` no termina nunca. Para el splash existe
/// [pumpEntryNoSettle].
Future<void> pumpEntry(
  WidgetTester tester,
  Widget child, {
  double width = 375,
  double height = 812,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('es'),
  bool disableAnimations = false,
  UserProfileProvider? profile,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  _sizeView(tester, width, height);
  await tester.pumpWidget(
    _wrap(
      child,
      brightness: brightness,
      locale: locale,
      disableAnimations: disableAnimations,
      profile: profile,
      textScaler: textScaler,
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

/// Igual que [pumpEntry] pero avanza el reloj un tiempo acotado en vez de
/// asentar. Es la unica forma de montar `SplashScreen` en un test.
Future<void> pumpEntryNoSettle(
  WidgetTester tester,
  Widget child, {
  double width = 375,
  double height = 812,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('es'),
  bool disableAnimations = false,
  UserProfileProvider? profile,
  Duration advance = const Duration(milliseconds: 500),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  _sizeView(tester, width, height);
  await tester.pumpWidget(
    _wrap(
      child,
      brightness: brightness,
      locale: locale,
      disableAnimations: disableAnimations,
      profile: profile,
    ),
  );
  await tester.pump(advance);
}

/// Ejecuta [body] capturando **todos** los `FlutterErrorDetails` de layout.
///
/// `tester.takeException()` solo devuelve el primero; cuando hay dos o mas
/// los colapsa en `Multiple exceptions (N) were detected`, que no dice ni
/// cuantos pixeles ni donde. `profile_setup_screen` produce exactamente dos,
/// asi que el criterio de aceptacion de su tarea necesita esta funcion.
List<FlutterErrorDetails> collectLayoutErrors(void Function() body) {
  final captured = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = captured.add;
  try {
    body();
  } finally {
    FlutterError.onError = previous;
  }
  return captured;
}

/// Monta [child] y devuelve todos los errores de layout que produjo.
Future<List<FlutterErrorDetails>> pumpEntryCollecting(
  WidgetTester tester,
  Widget child, {
  double width = 375,
  double height = 812,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('es'),
  bool disableAnimations = false,
  UserProfileProvider? profile,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final captured = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = captured.add;
  try {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _sizeView(tester, width, height);
    await tester.pumpWidget(
      _wrap(
        child,
        brightness: brightness,
        locale: locale,
        disableAnimations: disableAnimations,
        profile: profile,
        textScaler: textScaler,
      ),
    );
    await tester.pump();
  } finally {
    FlutterError.onError = previous;
  }
  return captured;
}

/// Extrae los pixeles de un desbordamiento, para aserciones legibles.
/// Devuelve `null` si el error no es un `RenderFlex overflowed`.
double? overflowPixels(FlutterErrorDetails details) {
  final match = RegExp(
    r'overflowed by ([\d.]+) pixels',
  ).firstMatch(details.exception.toString());
  return match == null ? null : double.parse(match.group(1)!);
}
