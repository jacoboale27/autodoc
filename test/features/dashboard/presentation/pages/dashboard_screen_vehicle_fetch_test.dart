import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import '../../../../helpers/test_helpers.mocks.dart';

class _LateUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  UserModel? _userData;
  @override
  UserModel? get userData => _userData;
  @override
  bool get isLoading => _userData == null;
  @override
  bool get hasAttemptedFetch => true;
  @override
  String? get fetchedUserId => _userData?.idUsuario;
  @override
  String? get error => null;
  @override
  bool hasAttemptedFetchFor(String userId) => true;
  @override
  Future<void> fetchUserData(String userId) async {}
  @override
  Future<bool> updateProfile(
    UserModel u, {
    dynamic imageFile,
    bool isNewUser = false,
  }) async => true;
  @override
  void clearUserData() {}

  void arriveLate(UserModel data) {
    _userData = data;
    notifyListeners();
  }
}

// VehicleProvider real construye un VehicleService que toca
// FirebaseFirestore.instance en su inicializacion, lo que no existe en un
// widget test sin Firebase.initializeApp(). Inyectamos mocks de Mockito
// (generados en test_helpers.mocks.dart) para evitar esa dependencia.
class _SpyVehicleProvider extends VehicleProvider {
  int fetchCallCount = 0;
  String? lastOwnerId;

  _SpyVehicleProvider()
    : super(
        vehicleService: MockVehicleService(),
        imageService: MockVehicleImageService(),
      );

  @override
  Future<void> fetchVehicles(String ownerId) async {
    fetchCallCount++;
    lastOwnerId = ownerId;
  }
}

// Registra cada llamada a fetchAlertsForVehicles (incluida la lista vacia,
// que es justo la que el guard original se saltaba) y delega en la
// implementacion real para comprobar que _alerts termina vacio.
class _SpyAlertProvider extends AlertProvider {
  _SpyAlertProvider({required super.firestore, required super.storage});

  final List<List<VehicleModel>> fetchCalls = [];

  @override
  Future<void> fetchAlertsForVehicles(List<VehicleModel> vehicles) {
    fetchCalls.add(vehicles);
    return super.fetchAlertsForVehicles(vehicles);
  }
}

void main() {
  // DashboardScreen._buildNearbyServices instancia WorkshopService()
  // directamente en build() (no inyectable), y su constructor toca
  // FirebaseFirestore.instance. setupFirebaseCoreMocks() + Firebase.
  // initializeApp() registran una app Firebase "[DEFAULT]" falsa por canal
  // de metodo para que ese getter no lance; las llamadas reales de Firestore
  // (snapshots()) que disparen luego solo generan un error async capturado
  // por el propio StreamBuilder, no un crash de build.
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  testWidgets(
    'fetches vehicles once UserProfileProvider.userData arrives after the initial build',
    (tester) async {
      await Firebase.initializeApp();
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profileProvider = _LateUserProfileProvider();
      final vehicleProvider = _SpyVehicleProvider();

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const DashboardScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(
              create: (_) => AuthProvider(
                authService: MockAuthService(),
                adminAuthService: MockAdminAuthService(),
              ),
            ),
            ChangeNotifierProvider<UserProfileProvider>.value(
              value: profileProvider,
            ),
            ChangeNotifierProvider<VehicleProvider>.value(
              value: vehicleProvider,
            ),
            ChangeNotifierProvider(
              create: (_) => AlertProvider(
                firestore: MockFirebaseFirestore(),
                storage: MockFirebaseStorage(),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => NotificationCenterProvider(
                firestore: MockFirebaseFirestore(),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      // pumpAndSettle() never returns here: DashboardScreen's "nearby
      // workshops" StreamBuilder listens on a real (mocked-core-only, not
      // mocked-platform) Firestore stream that never emits, so it keeps
      // showing a CircularProgressIndicator, which schedules frames forever.
      // Bounded pumps let the widget tree (and the didChangeDependencies /
      // post-frame-callback fetch chain under test) settle without waiting
      // on that unrelated spinner.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // First build: userData is still null, so no fetch should have happened yet.
      expect(vehicleProvider.fetchCallCount, 0);

      // Profile finishes loading after the initial frame — this is the
      // exact race the reported bug hits (post-login profile fetch lands
      // after DashboardScreen has already mounted once).
      profileProvider.arriveLate(
        UserModel(
          idUsuario: 'owner-1',
          nombreCompleto: 'Owner Uno',
          correo: 'owner@test.com',
          rol: 'Propietario',
          fechaRegistro: DateTime(2024, 1, 1),
          estado: 'aprobado',
        ),
      );
      // pumpAndSettle() never returns here: DashboardScreen's "nearby
      // workshops" StreamBuilder listens on a real (mocked-core-only, not
      // mocked-platform) Firestore stream that never emits, so it keeps
      // showing a CircularProgressIndicator, which schedules frames forever.
      // Bounded pumps let the widget tree (and the didChangeDependencies /
      // post-frame-callback fetch chain under test) settle without waiting
      // on that unrelated spinner.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(vehicleProvider.fetchCallCount, 1);
      expect(vehicleProvider.lastOwnerId, 'owner-1');
    },
  );

  testWidgets(
    'con el garaje vacio se piden alertas igualmente, para limpiar las del '
    'usuario anterior',
    (tester) async {
      await Firebase.initializeApp();
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeFirestore = FakeFirebaseFirestore();
      // Alerta dejada por la sesion anterior: un SOAT vencido de un
      // vehiculo que no pertenece al usuario que va a iniciar sesion ahora.
      await fakeFirestore.collection('alertas').add({
        'id_vehiculo': 'vehiculo-usuario-anterior',
        'estado': 'Pendiente',
        'titulo': 'SOAT vencido',
        'descripcion': 'Tu SOAT vencio hace 29 dias',
      });

      final alertProvider = _SpyAlertProvider(
        firestore: fakeFirestore,
        storage: MockFirebaseStorage(),
      );
      // Precarga alertProvider.alerts como si las hubiera dejado la sesion
      // del usuario anterior (simula lo que dashboard_screen ya habia
      // pedido para esa cuenta antes del logout).
      await alertProvider.fetchAlertsForVehicles([
        VehicleModel(
          idVehiculo: 'vehiculo-usuario-anterior',
          idPropietario: 'owner-anterior',
          placa: 'ABC-123',
          marca: 'Toyota',
          modelo: 'Corolla',
          kilometrajeActual: 10000,
        ),
      ]);
      expect(
        alertProvider.alerts,
        isNotEmpty,
        reason:
            'sanity check: la alerta del usuario anterior debe quedar '
            'cargada antes de simular el cambio de cuenta',
      );
      // Solo nos interesan las llamadas que dispara el montaje del
      // dashboard para la cuenta nueva, no la precarga de arriba.
      alertProvider.fetchCalls.clear();

      final profileProvider = _LateUserProfileProvider();
      // fetchVehicles no rellena `vehicles`: representa fielmente a un
      // usuario recien creado, con el garaje vacio.
      final vehicleProvider = _SpyVehicleProvider();

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const DashboardScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(
              create: (_) => AuthProvider(
                authService: MockAuthService(),
                adminAuthService: MockAdminAuthService(),
              ),
            ),
            ChangeNotifierProvider<UserProfileProvider>.value(
              value: profileProvider,
            ),
            ChangeNotifierProvider<VehicleProvider>.value(
              value: vehicleProvider,
            ),
            ChangeNotifierProvider<AlertProvider>.value(value: alertProvider),
            ChangeNotifierProvider(
              create: (_) => NotificationCenterProvider(
                firestore: MockFirebaseFirestore(),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Llega el usuario nuevo, con garaje vacio.
      profileProvider.arriveLate(
        UserModel(
          idUsuario: 'owner-nuevo',
          nombreCompleto: 'Owner Nuevo',
          correo: 'nuevo@test.com',
          rol: 'Propietario',
          fechaRegistro: DateTime(2024, 1, 1),
          estado: 'aprobado',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(vehicleProvider.fetchCallCount, 1);
      expect(
        alertProvider.fetchCalls,
        [<VehicleModel>[]],
        reason:
            'fetchAlertsForVehicles([]) vacia la lista; no llamarlo deja '
            'las alertas del usuario anterior en pantalla',
      );
      expect(alertProvider.alerts, isEmpty);
    },
  );
}
