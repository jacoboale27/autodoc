// El titulo de una pantalla no puede quedar truncado por sus propias acciones.
//
// **Lo levanto una captura, no una suite.** Con el viewport de telefono
// (360 dp) la pantalla del asistente mostraba «Asiste…»: la cabecera amontona
// flecha atras + tema + idioma + campana + avatar, y al titulo le quedaban
// ~88 px. Compila, analiza limpio y pasa todos los tests — solo se ve mirando.
//
// **No es un defecto del asistente.** Son 25 las pantallas que montan
// `AccionesDeCabecera`, y varias con titulos mas largos («Nueva cotizacion»,
// «Compartir historial»). El asistente fue donde se vio porque fue donde se
// miro; el centinela vive aqui, en el widget compartido, para que el arreglo
// se mida donde esta la causa.
//
// Se afirma sobre `didExceedMaxLines` del parrafo REAL, no sobre anchuras
// calculadas a mano: es lo que decide si Flutter pinta la elipsis, o sea lo
// mismo que ve la persona.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:autodoc/core/widgets/titulo_de_cabecera.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../support/mechanic_harness.dart';

/// El propietario es el caso peor: es el unico que ademas lleva avatar.
UserModel _propietario() => UserModel(
  idUsuario: 'p1',
  nombreCompleto: 'Oscar Isaac',
  correo: 'oscar@example.com',
  rol: 'Propietario',
  fechaRegistro: DateTime(2026, 1, 1),
);

Future<void> _montar(WidgetTester tester, String titulo) async {
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
          create: (_) => FakeUserProfileProvider(user: _propietario()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: Scaffold(
          appBar: AppBar(
            // La flecha atras es parte del caso: estas pantallas se abren
            // empujadas, no desde la barra de navegacion.
            leading: const BackButton(),
            title: TituloDeCabecera(titulo),
            actions: const [AccionesDeCabecera()],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Sin esto `ThemeProvider.listo` no resuelve nunca y el test se cuelga los
  // 10 minutos del timeout — no falla la asercion, no llega a ejecutarse.
  // Ademas fija el idioma: sin nada guardado `LanguageProvider` toma el del
  // dispositivo, que en la suite es ingles, y «Assistant» no mide lo mismo.
  setUp(() => SharedPreferences.setMockInitialValues({'app_locale': 'es'}));

  testWidgets('a 360 dp el titulo de la pantalla no se trunca', (tester) async {
    // 360 dp es el ancho logico mas comun de Android, no un caso extremo.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _montar(tester, 'Asistente');

    final parrafo = tester.renderObject<RenderParagraph>(
      find.text('Asistente'),
    );
    expect(
      parrafo.didExceedMaxLines,
      isFalse,
      reason:
          'El titulo se trunca a 360 dp: la persona lee «Asiste…». Las '
          'acciones de cabecera no dejan sitio.',
    );
  });

  testWidgets('tampoco se trunca un titulo largo, que es el caso peor', (
    tester,
  ) async {
    // «Asistente» sola no prueba el widget: con bajar a 16 sp casi cabria. El
    // caso que obliga al escalado es un titulo de pantalla de verdad, y hay
    // varios en la app — este es literal de `compartir_historial_screen`.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _montar(tester, 'Compartir historial');

    final parrafo = tester.renderObject<RenderParagraph>(
      find.text('Compartir historial'),
    );
    expect(
      parrafo.didExceedMaxLines,
      isFalse,
      reason: 'Un titulo largo vuelve a la elipsis: el escalado no actua.',
    );
  });

  testWidgets('fuera de compact el titulo NO se encoge', (tester) async {
    // La otra mitad, y sin ella el arreglo podria empeorar el escritorio sin
    // que nadie lo viera: ahi sobra sitio, asi que el titulo tiene que seguir
    // siendo el normal de la barra.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _montar(tester, 'Asistente');

    expect(
      find.byType(FittedBox),
      findsNothing,
      reason: 'A 1280 dp no hay nada que escalar: sobra ancho de sobra.',
    );
  });
}
