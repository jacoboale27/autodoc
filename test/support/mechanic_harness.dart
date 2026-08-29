// test/support/mechanic_harness.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:autodoc/core/models/app_notification_model.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../helpers/test_helpers.mocks.dart';
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
  @override
  void clear() {}
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

/// Doble de `ReparacionProvider` para comprobar que crear el ticket Kanban
/// de "Reparaciones" (y con él, el push al propietario) es una acción
/// explícita del taller — el botón "Recibir vehículo" en
/// `InitiateServiceScreen` — y no un efecto secundario de simplemente cargar
/// esa pantalla al buscar una placa.
///
/// **Implementa** en vez de extender por el mismo motivo que
/// `FakeUserProfileProvider`: `ReparacionProvider()` real instancia
/// `ReparacionRepository()`, que a su vez cae en `FirebaseFirestore.instance`
/// y `FirebaseFunctions.instance` en los inicializadores de sus campos.
///
/// [llamadasIniciar] cuenta las tres vías que escriben el ticket
/// (`iniciar`/`iniciarOReutilizar`/`iniciarOReutilizarPorVehiculo`) en un
/// solo contador: cuál de las tres usa la pantalla depende de si el
/// vehículo trae `id_propietario` (ver
/// `InitiateServiceScreen._iniciarTicketReparacion`), y a los tests de este
/// doble solo les importa si se llamó a alguna, no a cuál.
class FakeReparacionProvider extends ChangeNotifier
    implements ReparacionProvider {
  FakeReparacionProvider({this.idReparacion = 'r1'});

  final String idReparacion;

  int llamadasIniciar = 0;

  @override
  List<ReparacionModel> get reparaciones => const [];
  @override
  bool get isLoading => false;
  @override
  String? get error => null;

  @override
  void watchTaller(String idTaller) {}

  @override
  Future<String?> iniciar({
    required String idVehiculo,
    required String idTaller,
    required String idPropietario,
    required String placa,
  }) async {
    llamadasIniciar++;
    return idReparacion;
  }

  @override
  Future<String?> iniciarOReutilizar({
    required String idVehiculo,
    required String idTaller,
    required String idPropietario,
    required String placa,
  }) async {
    llamadasIniciar++;
    return idReparacion;
  }

  @override
  Future<String?> iniciarOReutilizarPorVehiculo({
    required String idVehiculo,
    required String idTaller,
  }) async {
    llamadasIniciar++;
    return idReparacion;
  }

  @override
  Future<void> cambiarEstado(String idReparacion, String nuevoEstado) async {}

  @override
  Future<bool> cancelar(String idReparacion) async => true;
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
        // `InitiateServiceScreen` (Task 11) es la primera pantalla del panel
        // de taller que consume estos tres providers a la vez: `AlertProvider`
        // (alertas/tareas de mantenimiento del vehículo en servicio),
        // `ReparacionProvider` (ticket Kanban que se crea/reutiliza al recibir
        // el vehículo) y `CatalogoProvider` (catálogo rápido del taller). Los
        // tres son clases concretas, no interfaces, así que en vez de un doble
        // que las implemente se instancian de verdad con un
        // `FakeFirebaseFirestore` (y los mocks de `FirebaseStorage`/
        // `FirebaseFunctions` ya generados para `test_helpers.mocks.dart`)
        // detrás, igual que `reparacion_provider_test.dart`/
        // `catalogo_provider_test.dart` — mismo patrón que `FakeVehicleProvider`
        // arriba, adaptado a que aquí sí se puede construir la clase real.
        ChangeNotifierProvider<AlertProvider>(
          create: (_) => AlertProvider(
            firestore: FakeFirebaseFirestore(),
            storage: MockFirebaseStorage(),
          ),
        ),
        ChangeNotifierProvider<ReparacionProvider>(
          create: (_) => ReparacionProvider(
            repository: ReparacionRepository(
              firestore: FakeFirebaseFirestore(),
              functions: MockFirebaseFunctions(),
            ),
          ),
        ),
        ChangeNotifierProvider<CatalogoProvider>(
          create: (_) => CatalogoProvider(
            repository: CatalogoRepository(firestore: FakeFirebaseFirestore()),
          ),
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
