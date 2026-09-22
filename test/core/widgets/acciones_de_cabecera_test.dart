// Observaciones del 2026-09-19: el cambio de tema, el de idioma y la campana
// solo estaban en el dashboard de cada rol. Se pidieron en TODAS las
// pantallas: el taller con tema, idioma y campana; el propietario, además,
// con su avatar.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/acciones_de_cabecera.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../support/mechanic_harness.dart';

UserModel _propietario() => UserModel(
  idUsuario: 'p1',
  nombreCompleto: 'Oscar Isaac',
  correo: 'oscar@example.com',
  rol: 'Propietario',
  fechaRegistro: DateTime(2026, 1, 1),
);

/// Monta la barra con el tema que [ThemeProvider] diga, igual que la app.
Future<ThemeProvider> _montar(
  WidgetTester tester, {
  required UserModel usuario,
  Widget acciones = const AccionesDeCabecera(),
}) async {
  final tema = ThemeProvider();
  await tema.listo;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: tema),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider<NotificationCenterProvider>(
          create: (_) => FakeNotificationCenterProvider(),
        ),
        ChangeNotifierProvider<UserProfileProvider>(
          create: (_) => FakeUserProfileProvider(user: usuario),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, t, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: t.themeMode,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: Scaffold(appBar: AppBar(actions: [acciones])),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tema;
}

void main() {
  // Idioma fijado en español: sin nada guardado, `LanguageProvider` toma el
  // del dispositivo, que en la suite es inglés.
  setUp(() => SharedPreferences.setMockInitialValues({'app_locale': 'es'}));

  testWidgets('el taller lleva tema, idioma y campana, sin avatar', (
    tester,
  ) async {
    await _montar(tester, usuario: fakeTaller());

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(find.text('ES'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('el propietario lleva además su avatar', (tester) async {
    await _montar(tester, usuario: _propietario());

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(find.text('ES'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('O'), findsOneWidget, reason: 'inicial del nombre');
  });

  testWidgets('la pantalla de notificaciones puede prescindir de la campana', (
    tester,
  ) async {
    await _montar(
      tester,
      usuario: fakeTaller(),
      acciones: const AccionesDeCabecera(mostrarCampana: false),
    );
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
  });

  testWidgets('un toque invierte el tema que se VE y lo deja guardado', (
    tester,
  ) async {
    final binding = tester.binding;
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);

    // Modo del dispositivo, y el dispositivo en oscuro: se ve oscuro y el
    // botón ofrece el sol.
    final tema = await _montar(tester, usuario: fakeTaller());
    expect(tema.themeMode, ThemeMode.system);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();

    expect(tema.themeMode, ThemeMode.light);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('theme_mode'), ThemeMode.light.index);
  });

  testWidgets('el botón de idioma cambia entre ES y EN', (tester) async {
    await _montar(tester, usuario: fakeTaller());
    await tester.tap(find.text('ES'));
    await tester.pumpAndSettle();
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('sin providers (pantalla aislada en un test) no revienta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(appBar: AppBar(actions: const [AccionesDeCabecera()])),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  // Centinela: que ninguna pantalla nueva se quede sin las acciones. Es la
  // forma en que se perdieron: cada pantalla ponía (o no) las suyas.
  test('todas las pantallas llevan las acciones de cabecera', () {
    // Pantallas que NO las llevan, cada una con su razón.
    const exentas = <String, String>{
      // Antes de iniciar sesión: no hay notificaciones ni perfil.
      'auth_screen.dart': 'antes de iniciar sesión',
      'email_verification_screen.dart': 'antes de verificar el correo',
      'onboarding_screen.dart': 'antes de iniciar sesión',
      'splash_screen.dart': 'arranque',
      'profile_setup_screen.dart': 'alta del perfil, antes de tener rol',
      // Panel de administración: no forma parte de lo pedido (taller y
      // propietario) y ya lleva su propio conmutador de tema.
      'admin_dashboard_screen.dart': 'panel de administración',
      'admin_usuarios_screen.dart': 'panel de administración',
      'admin_talleres_screen.dart': 'panel de administración',
      'admin_verificaciones_screen.dart': 'panel de administración',
      'admin_resenias_screen.dart': 'panel de administración',
      'admin_logs_screen.dart': 'panel de administración',
      'admin_seed_screen.dart': 'panel de administración',
      // Pantalla modal de un solo propósito (elegir un punto en el mapa), con
      // su propio botón Confirmar arriba a la derecha.
      'selector_ubicacion_taller_screen.dart': 'selector modal del mapa',
      // Igual que el selector del mapa: modal de un solo propósito (encuadrar
      // el banner) que se abre DESDE el panel de taller y vuelve a él.
      'ajustar_banner_screen.dart': 'modal de encuadre del banner',
    };

    final sinAcciones = <String>[];
    final paginas = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.replaceAll(r'\', '/').contains('/pages/') &&
              f.path.endsWith('_screen.dart'),
        );
    for (final pagina in paginas) {
      final nombre = pagina.uri.pathSegments.last;
      if (exentas.containsKey(nombre)) continue;
      final fuente = pagina.readAsStringSync();
      final pintaPantalla =
          fuente.contains('Scaffold(') || fuente.contains('AppScaffold(');
      if (!pintaPantalla) continue;
      final lasLleva =
          fuente.contains('AccionesDeCabecera') ||
          fuente.contains('MechanicScaffold(');
      if (!lasLleva) sinAcciones.add(nombre);
    }

    expect(
      sinAcciones,
      isEmpty,
      reason:
          'Estas pantallas no llevan tema/idioma/campana. Pon '
          '`AccionesDeCabecera` en su barra (o usa `MechanicScaffold`), o '
          'añádelas a `exentas` con su razón.',
    );
  });
}
