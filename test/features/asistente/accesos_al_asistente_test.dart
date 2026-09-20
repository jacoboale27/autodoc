import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/dashboard/presentation/pages/alerts_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../helpers/test_helpers.mocks.dart';
import '../../support/mechanic_harness.dart';
import '../../support/shell_harness.dart';
import '../../support/vehicle_fixtures.dart';

/// IA-01 — las dos puertas de entrada al asistente.
///
/// **Una funcionalidad a la que no se puede llegar no existe**, y esa es la
/// razon literal por la que el juez de `AUDITORIA_CREA_J_2026_FINAL.md` bajo
/// la nota de INNO-01: el backend estaba entero y «no hay pantalla de
/// emision/lectura». El asistente tiene el mismo riesgo — un callable
/// desplegado, unas reglas escritas y ningun sitio desde donde preguntarle.
///
/// Se afirma **el destino**, no que se pinte algo: lo que importa es que el
/// boton lleva a `/asistente`. Que la pantalla funcione ya lo cubre
/// `asistente_screen_test.dart`.
class _Alertas extends AlertProvider {
  _Alertas()
    : super(firestore: FakeFirebaseFirestore(), storage: MockFirebaseStorage());

  @override
  Future<void> fetchAlertsForVehicles(List<VehicleModel> vehicles) async {}
}

Future<GoRouter> pumpAlertas(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/alerts',
    routes: [
      GoRoute(
        path: '/alerts',
        pageBuilder: (context, state) =>
            const MaterialPage(child: AlertsScreen()),
      ),
      // Destino vacio a proposito: lo que se observa es el `uri` al que llega
      // el enrutador, no lo que pinta el destino.
      GoRoute(
        path: '/asistente',
        pageBuilder: (context, state) =>
            const MaterialPage(child: Scaffold(body: SizedBox.shrink())),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(
          value: FakeVehicleProvider([fakeVehicle(0)]),
        ),
        ChangeNotifierProvider<AlertProvider>.value(value: _Alertas()),
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: FakeProfileProvider('Propietario'),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// El tooltip es lo UNICO que anuncia un `IconButton` a un lector de
/// pantalla, asi que aqui se comprueba dos cosas a la vez: que existe y que
/// sale del ARB.
///
/// Se resuelve contra el idioma que tiene montado el arbol, no contra un
/// `es` fijo: el harness del panel de taller no fija locale, asi que hereda
/// el del sistema — la misma trampa que INNO-01 documento cuando el bundle
/// E2E se renderizo entero en ingles y los rotulos del ARB dejaron de casar
/// mientras los literales sueltos seguian en castellano.
Future<void> esperarRotuloTraducido(WidgetTester tester, Finder boton) async {
  final locale = Localizations.localeOf(tester.element(boton));
  final l10n = await AppLocalizations.delegate.load(locale);
  expect(tester.widget<IconButton>(boton).tooltip, l10n.asistenteAbrir);
  expect(find.byTooltip(l10n.asistenteAbrir), findsOneWidget);
}

void main() {
  testWidgets('el propietario llega al asistente desde /alerts', (
    tester,
  ) async {
    final router = await pumpAlertas(tester);

    final boton = find.byKey(const Key('alerts-abrir-asistente'));
    expect(boton, findsOneWidget);
    await esperarRotuloTraducido(tester, boton);

    await tester.tap(boton);
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/asistente');
  });

  testWidgets('el taller llega al asistente desde su panel', (tester) async {
    // La agenda del taller son sus citas confirmadas. Sin esta entrada, la
    // mitad server-side de `construirAgenda` —la rama de taller, con su
    // `actuaPorTaller` y su estado— no la podria ejercer nadie.
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('usuarios').doc('t1').set({
      'calificacion_promedio': 4.5,
      'total_resenias': 12,
    });

    final router = await pumpMechanicScreen(
      tester,
      MechanicDashboardScreen(firestore: firestore),
      width: 1440,
      location: '/mechanic_dashboard',
      disableAnimations: true,
      rutasExtra: const ['/asistente'],
    );
    await tester.pumpAndSettle();

    final boton = find.byKey(const Key('mechanic-abrir-asistente'));
    expect(boton, findsOneWidget);
    await esperarRotuloTraducido(tester, boton);

    await tester.tap(boton);
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/asistente');
  });
}
