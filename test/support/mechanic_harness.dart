// test/support/mechanic_harness.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:autodoc/core/models/app_notification_model.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import 'vehicle_fixtures.dart';

/// Doble de `NotificationCenterProvider` para pantallas que montan
/// `NotificationBellButton`. Mismo motivo que `FakeUserProfileProvider`:
/// el real toca `FirebaseFirestore.instance` en su inicializador.
class FakeNotificationCenterProvider extends ChangeNotifier
    implements NotificationCenterProvider {
  @override
  bool get hasUnread => false;
  @override
  int get unreadCount => 0;
  @override
  bool get isLoading => false;
  @override
  List<AppNotification> get notifications => [];
  @override
  String? get error => null;
  @override
  void initialize(String userId) {}
  @override
  Future<void> markAsRead(String userId, String notificationId) async {}
  @override
  Future<void> markAllAsRead(String userId) async {}
  @override
  Future<void> deleteNotification(String userId, String notificationId) async {}
}

/// Doble de `UserProfileProvider` para los tests del panel de taller.
///
/// **Implementa** en vez de extender, y no es una preferencia de estilo:
/// `UserProfileProvider` inicializa `final UserService _userService =
/// UserService()` en la declaración del campo, y `UserService` hace
/// `FirebaseFirestore.instance` en la suya. Extender la clase real ejecuta
/// ambos inicializadores y lanza en un widget test sin
/// `Firebase.initializeApp()`. Los tres tests que ya existían en este módulo
/// usan este mismo patrón por el mismo motivo.
class FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  FakeUserProfileProvider({this.user});

  final UserModel? user;

  @override
  UserModel? get userData => user;
  @override
  bool get isLoading => false;
  @override
  bool get hasAttemptedFetch => true;
  @override
  String? get fetchedUserId => user?.idUsuario;
  @override
  String? get error => null;
  @override
  bool hasAttemptedFetchFor(String userId) => true;
  @override
  Future<void> fetchUserData(String userId) async {}
  @override
  Future<bool> updateProfile(
    UserModel updatedUser, {
    XFile? imageFile,
    bool isNewUser = false,
  }) async => true;
  @override
  void clearUserData() {}
}

/// Cuenta de taller dueña. Pasa [idTallerPropietario] para simular una
/// sub-cuenta de empleado (`MechanicSidebar` le oculta "Empleados" y
/// `EmpleadosScreen` le muestra "Acceso restringido").
UserModel fakeTaller({
  String id = 't1',
  String nombre = 'Taller Escobar',
  String? idTallerPropietario,
  String estado = 'activo',
}) => UserModel(
  idUsuario: id,
  nombreCompleto: nombre,
  correo: 'taller@example.com',
  rol: 'Mecanico',
  fechaRegistro: DateTime(2026, 1, 1),
  estado: estado,
  idTallerPropietario: idTallerPropietario,
);

/// Monta [screen] en la ruta [location] con los providers mínimos que
/// `MechanicSidebar` y las pantallas del panel necesitan, a un ancho fijo.
///
/// Fija el ancho con `tester.view` en vez de con `MediaQuery` a mano para
/// que `AppBreakpoints.of(context)` vea el mismo valor que en producción.
Future<void> pumpMechanicScreen(
  WidgetTester tester,
  Widget screen, {
  required double width,
  double height = 1000,
  String location = '/mechanic_dashboard',
  UserModel? user,
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  // `List<SingleChildWidget>`, no `List<ChangeNotifierProvider>`: un
  // parámetro tipado como el genérico crudo `ChangeNotifierProvider`
  // instancia a su cota (`ChangeNotifierProvider<ChangeNotifier>`) por
  // "instantiate-to-bound", y ese tipo de contexto gana en la inferencia
  // sobre el literal `ChangeNotifierProvider(create: (_) => Foo())` de la
  // lista — registra el provider como `ChangeNotifierProvider<ChangeNotifier>`
  // en vez de `ChangeNotifierProvider<Foo>`, y `Provider.of<Foo>()` deja de
  // encontrarlo. `SingleChildWidget` (la clase base sin genéricos) no fija
  // ninguna cota, así que cada elemento infiere su propio `T` desde `create`.
  List<SingleChildWidget> extraProviders = const [],
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Desmonta del todo antes de reconstruir: sin esto, una segunda llamada a
  // pumpMechanicScreen en el mismo test (mismo tester, misma forma de
  // árbol: MaterialApp.router > MultiProvider > ...) hace que Flutter
  // reconcilie los elementos existentes en vez de recrearlos, y el
  // `ChangeNotifierProvider<UserProfileProvider>` reutiliza la instancia
  // creada en la primera llamada — el nuevo `user` pasado aquí nunca llega
  // a la pantalla. Mismo patrón que `pumpAtWidth` en responsive_harness.dart.
  await tester.pumpWidget(const SizedBox.shrink());

  final router = GoRouter(
    initialLocation: location,
    routes: [GoRoute(path: location, builder: (context, state) => screen)],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // `TranslatedText` (usada por `MechanicReviewsScreen`) llama
        // `context.watch<LanguageProvider>()` incondicionalmente en su
        // primer build. Sin este provider, cualquier pantalla del panel que
        // la monte lanza `ProviderNotFoundException` en vez de fallar por su
        // propia lógica.
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider<UserProfileProvider>(
          create: (_) => FakeUserProfileProvider(user: user ?? fakeTaller()),
        ),
        // `VehicleSearchScreen` (búsquedas recientes) es la primera pantalla
        // del panel de taller que lee `VehicleProvider`. `VehicleProvider()`
        // real toca `FirebaseFirestore.instance` en el inicializador de
        // `VehicleService`, así que sin este doble cualquier pantalla que lo
        // consuma lanza `ProviderNotFoundException` (si falta del todo) o un
        // error de Firebase no inicializado (si se instancia el real). Mismo
        // patrón que `FakeUserProfileProvider` arriba.
        ChangeNotifierProvider<VehicleProvider>(
          create: (_) => FakeVehicleProvider(const []),
        ),
        // Mismo motivo que arriba, para pantallas que montan
        // `NotificationBellButton` (lee `NotificationCenterProvider` con
        // `Consumer`, no lo declara como dependencia opcional).
        ChangeNotifierProvider<NotificationCenterProvider>(
          create: (_) => FakeNotificationCenterProvider(),
        ),
        ...extraProviders,
      ],
      child: MaterialApp.router(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
      ),
    ),
  );
}
