// test/features/mechanic/presentation/pages/vehicle_gating_test.dart
//
// A3/B2: un mecanico sin ticket de reparacion aceptado para un vehiculo solo
// puede ver su ficha publica (nombre, placa, kilometraje, imagen) — nunca
// "Recibir vehiculo", "Iniciar servicio" ni el historial. `Buscar vehiculo` y
// la tarjeta de vehiculo del chat deben decidir esto exactamente igual,
// porque ya paso una vez que solo una de las dos entradas se corrigio.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/vehiculo_chat_card.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/vehicle_public_view_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/vehicle_search_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/mechanic_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

VehicleModel _vehiculoFake() => VehicleModel(
  idVehiculo: 'v1',
  idPropietario: 'p1',
  placa: 'P123456',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2020,
  kilometrajeActual: 50000,
);

/// Doble de `VehicleProvider` que siempre resuelve la misma placa buscada al
/// vehículo fijo de este archivo, sin tocar Firestore.
class _FakeVehicleProviderConPlaca extends FakeVehicleProvider {
  _FakeVehicleProviderConPlaca(this._vehiculo) : super(const []);
  final VehicleModel _vehiculo;

  @override
  Future<VehicleModel?> findVehicleByPlate(String plate) async => _vehiculo;
}

/// Rutas de destino reales que `abrirVehiculoComoMecanico` puede elegir —
/// espejo de `app_router.dart`, sin auth guard ni transiciones (no hacen
/// falta para comprobar a qué pantalla se llega). [chatHome], si se da,
/// reemplaza `/mechanic_search` como pantalla inicial: lo usa el test del
/// chat para arrancar en la tarjeta de vehículo en vez del buscador.
GoRouter _router({Widget? chatHome}) => GoRouter(
  initialLocation: chatHome != null ? '/chat_test' : '/mechanic_search',
  routes: [
    if (chatHome != null)
      GoRoute(
        path: '/chat_test',
        pageBuilder: (context, state) => MaterialPage(child: chatHome),
      ),
    GoRoute(
      path: '/mechanic_search',
      pageBuilder: (context, state) =>
          const MaterialPage(child: VehicleSearchScreen()),
    ),
    GoRoute(
      path: '/initiate_service/:reparacionId',
      pageBuilder: (context, state) {
        final id = state.pathParameters['reparacionId'];
        return MaterialPage(
          child: id == null || id.isEmpty
              ? const MissingArgumentScreen(
                  mensaje: 'No se indicó ningún servicio.',
                  rutaVuelta: '/mechanic_dashboard',
                )
              : InitiateServiceScreen(
                  reparacionId: id,
                  vehiculoPrecargado: state.extra is VehicleModel
                      ? state.extra as VehicleModel
                      : null,
                ),
        );
      },
    ),
    GoRoute(
      path: '/vehiculo_publico/:vehiculoId',
      pageBuilder: (context, state) {
        final id = state.pathParameters['vehiculoId'];
        return MaterialPage(
          child: id == null || id.isEmpty
              ? const MissingArgumentScreen(
                  mensaje: 'No se indicó ningún vehículo.',
                  rutaVuelta: '/mechanic_search',
                )
              : VehiclePublicViewScreen(
                  vehiculoId: id,
                  vehiculoPrecargado: state.extra is VehicleModel
                      ? state.extra as VehicleModel
                      : null,
                ),
        );
      },
    ),
  ],
);

/// Árbol de providers común: el mecánico opera bajo el taller 't1'
/// (`fakeTaller`). [reparacionProvider] decide qué ve `abrirVehiculoComoMecanico`
/// al resolver v1+t1 — normalmente el doble [FakeReparacionProvider] (control
/// directo del id devuelto), pero los tests del filtro `cancelado` pasan el
/// `ReparacionProvider` **real** (respaldado por un `FakeFirebaseFirestore`
/// sembrado) para ejercitar de verdad la lógica de "vigente" que vive en esa
/// clase, no en un doble que la saltaría. Cubre tanto `VehicleSearchScreen`
/// como lo que `InitiateServiceScreen`/`VehiclePublicViewScreen` necesitan
/// una vez que `abrirVehiculoComoMecanico` navega ahí.
Widget _appDeGating({
  required GoRouter router,
  required ReparacionProvider reparacionProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider<UserProfileProvider>(
        create: (_) => FakeUserProfileProvider(user: fakeTaller(id: 't1')),
      ),
      ChangeNotifierProvider<VehicleProvider>(
        create: (_) => _FakeVehicleProviderConPlaca(_vehiculoFake()),
      ),
      ChangeNotifierProvider<ReparacionProvider>.value(
        value: reparacionProvider,
      ),
      ChangeNotifierProvider<NotificationCenterProvider>(
        create: (_) => FakeNotificationCenterProvider(),
      ),
      ChangeNotifierProvider<AlertProvider>(
        create: (_) => AlertProvider(
          firestore: FakeFirebaseFirestore(),
          storage: MockFirebaseStorage(),
        ),
      ),
      ChangeNotifierProvider<CatalogoProvider>(
        create: (_) => CatalogoProvider(
          repository: CatalogoRepository(firestore: FakeFirebaseFirestore()),
        ),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<GoRouter> _pumpBuscarVehiculo(
  WidgetTester tester, {
  required String? reparacionActivaId,
}) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  final router = _router();
  await tester.pumpWidget(
    _appDeGating(
      router: router,
      reparacionProvider: FakeReparacionProvider(
        reparacionActivaId: reparacionActivaId,
      ),
    ),
  );
  await tester.pump();
  return router;
}

/// Igual que [_pumpBuscarVehiculo], pero con el `ReparacionProvider` **real**
/// (no el doble), respaldado por un `FakeFirebaseFirestore` con un ticket
/// 'r1' de v1+t1 ya sembrado en [estadoReparacion]. Sirve para probar el
/// filtro de "vigente" (`cancelado` cuenta como "no hay ticket") de
/// verdad, no contra un doble que lo saltearía.
Future<GoRouter> _pumpBuscarVehiculoConTicketReal(
  WidgetTester tester, {
  required String estadoReparacion,
}) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  final firestore = FakeFirebaseFirestore();
  final ahora = DateTime.now();
  await firestore
      .collection('reparaciones')
      .doc('r1')
      .set(
        ReparacionModel(
          idReparacion: 'r1',
          idVehiculo: 'v1',
          idTaller: 't1',
          idPropietario: 'p1',
          placa: 'P123456',
          estado: estadoReparacion,
          historialEstados: [
            {'estado': estadoReparacion, 'timestamp': ahora},
          ],
          fechaCreacion: ahora,
          fechaActualizacion: ahora,
        ).toMap(),
      );

  final router = _router();
  await tester.pumpWidget(
    _appDeGating(
      router: router,
      reparacionProvider: ReparacionProvider(
        repository: ReparacionRepository(
          firestore: firestore,
          functions: MockFirebaseFunctions(),
        ),
      ),
    ),
  );
  await tester.pump();
  return router;
}

/// Igual que [_pumpBuscarVehiculo], pero arrancando en una `VehiculoChatCard`
/// real (`isMe: false`, con `id_vehiculo` en sus metadatos) en vez del
/// buscador — la otra entrada que `abrirVehiculoComoMecanico` debe gatear
/// exactamente igual. `firestore` precargado con `vehiculos/v1`: es lo que
/// la tarjeta lee para construir el `VehicleModel` antes de decidir a dónde
/// navegar.
Future<GoRouter> _pumpChatConTarjetaVehiculo(
  WidgetTester tester, {
  required String? reparacionActivaId,
}) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  final firestoreChat = FakeFirebaseFirestore();
  await firestoreChat
      .collection('vehiculos')
      .doc('v1')
      .set(_vehiculoFake().toMap());

  final router = _router(
    chatHome: VehiculoChatCard(
      metadata: const {
        'marca': 'Toyota',
        'modelo': 'Corolla',
        'anio': 2020,
        'placa': 'P123456',
        'id_vehiculo': 'v1',
      },
      isMe: false,
      firestore: firestoreChat,
    ),
  );
  await tester.pumpWidget(
    _appDeGating(
      router: router,
      reparacionProvider: FakeReparacionProvider(
        reparacionActivaId: reparacionActivaId,
      ),
    ),
  );
  await tester.pump();
  return router;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  testWidgets(
    'sin reparacion aceptada, buscar vehiculo lleva a la vista publica',
    (tester) async {
      final router = await _pumpBuscarVehiculo(
        tester,
        reparacionActivaId: null,
      );

      await tester.enterText(find.byType(TextField), 'P123456');
      await tester.tap(find.text('BUSCAR AUTO'));
      await tester.pumpAndSettle();

      expect(find.byType(VehiclePublicViewScreen), findsOneWidget);
      expect(find.text('P123456'), findsOneWidget);
      expect(find.text('Recibir vehículo'), findsNothing);
      expect(find.text('Iniciar servicio'), findsNothing);
      expect(find.text('Historial'), findsNothing);
      expect(router.state.uri.toString(), '/vehiculo_publico/v1');
    },
  );

  testWidgets('con reparacion en pendiente_recepcion, se desbloquea recibir', (
    tester,
  ) async {
    final router = await _pumpBuscarVehiculo(tester, reparacionActivaId: 'r1');

    await tester.enterText(find.byType(TextField), 'P123456');
    await tester.tap(find.text('BUSCAR AUTO'));
    await tester.pumpAndSettle();

    expect(find.byType(InitiateServiceScreen), findsOneWidget);
    expect(find.text('Recibir vehículo'), findsOneWidget);
    expect(router.state.uri.toString(), '/initiate_service/r1');
  });

  testWidgets('el gating es identico llegando desde el chat', (tester) async {
    // Misma fuente de verdad en ambas entradas: lo exige el plan y es lo
    // unico que evita que este bug reaparezca por un solo lado (A3/B2 solo
    // se habia corregido en `vehicle_search_screen.dart`).
    final router = await _pumpChatConTarjetaVehiculo(
      tester,
      reparacionActivaId: null,
    );

    await tester.tap(find.text('Ver vehículo'));
    await tester.pumpAndSettle();

    expect(find.byType(VehiclePublicViewScreen), findsOneWidget);
    expect(router.state.uri.toString(), '/vehiculo_publico/v1');
  });

  testWidgets(
    'un ticket cancelado cuenta como si no hubiera ticket: vista publica, no el servicio',
    (tester) async {
      // Antes de la Tarea 5 esta consulta era un insumo mas dentro de
      // InitiateServiceScreen (solo para "Recibir vehiculo"); ahora es la
      // UNICA puerta a toda la pantalla. Sin excluir 'cancelado' aqui, un
      // ticket cancelado abria igual el formulario completo de
      // materiales/cotizacion/finalizar — justo lo que A3/B2 prohibe.
      final router = await _pumpBuscarVehiculoConTicketReal(
        tester,
        estadoReparacion: 'cancelado',
      );

      await tester.enterText(find.byType(TextField), 'P123456');
      await tester.tap(find.text('BUSCAR AUTO'));
      await tester.pumpAndSettle();

      expect(find.byType(VehiclePublicViewScreen), findsOneWidget);
      expect(find.byType(InitiateServiceScreen), findsNothing);
      expect(router.state.uri.toString(), '/vehiculo_publico/v1');
    },
  );

  testWidgets(
    'un ticket legado ya recibido (previo a A4b) sigue desbloqueando el servicio',
    (tester) async {
      // El filtro de 'cancelado' no debe volverse una regresion para el
      // caso que ya funcionaba: un ticket 'recibido' (incluido uno legado,
      // anterior a A4b, que nunca paso por 'pendiente_recepcion') sigue
      // contando como vigente.
      final router = await _pumpBuscarVehiculoConTicketReal(
        tester,
        estadoReparacion: 'recibido',
      );

      await tester.enterText(find.byType(TextField), 'P123456');
      await tester.tap(find.text('BUSCAR AUTO'));
      await tester.pumpAndSettle();

      expect(find.byType(InitiateServiceScreen), findsOneWidget);
      expect(router.state.uri.toString(), '/initiate_service/r1');
    },
  );
}
