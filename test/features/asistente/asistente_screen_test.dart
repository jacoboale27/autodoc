import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/asistente/data/services/asistente_service.dart';
import 'package:autodoc/features/asistente/presentation/pages/asistente_screen.dart';
import 'package:autodoc/features/asistente/presentation/utils/mensaje_de_asistente.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// IA-01 — los estados de la pantalla del asistente.
///
/// **Lo que NO se afirma aqui: la prosa.** El texto lo redacta un modelo, y un
/// test que compare texto generado se pone rojo solo el dia que Google cambia
/// de version — y entonces nadie sabe si se rompio el codigo o el modelo
/// cambio de humor. Lo que se afirma es lo determinista: que se pide, en que
/// idioma, y que se pinta con lo que vuelve.
class _AsistenteFalso {
  Map<String, dynamic>? respuesta;
  Object? fallo;

  /// Si se rellena, la llamada se queda colgada hasta completarlo. Es la unica
  /// forma de ver el estado de carga: un `Future` ya resuelto lo atraviesa
  /// entre dos frames.
  Completer<Map<String, dynamic>>? pendiente;

  final List<({String pregunta, String idioma})> llamadas = [];

  AsistenteService get servicio => AsistenteService(
    preguntar: (pregunta, idioma) async {
      llamadas.add((pregunta: pregunta, idioma: idioma));
      if (pendiente != null) return pendiente!.future;
      if (fallo != null) throw fallo!;
      return respuesta ?? {'intencion': 'agenda', 'texto': 'Todo en orden.'};
    },
  );
}

Widget envolver(
  AsistenteService servicio, {
  Locale locale = const Locale('es'),
}) => MaterialApp(
  theme: AppTheme.light,
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: AsistenteScreen(servicio: servicio),
);

Future<void> preguntar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(const Key('asistente-pregunta')), texto);
  await tester.pump();
  await tester.tap(find.byKey(const Key('asistente-enviar')));
}

void main() {
  testWidgets('arranca vacia y sin haber llamado a nadie', (tester) async {
    final falso = _AsistenteFalso();
    await tester.pumpWidget(envolver(falso.servicio));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asistente-vacio')), findsOneWidget);
    expect(find.byKey(const Key('asistente-respuesta')), findsNothing);
    expect(falso.llamadas, isEmpty);
  });

  testWidgets('con el campo vacio el boton no puede enviar', (tester) async {
    // Importa mas de lo que parece: el servidor responde `invalid-argument` a
    // una pregunta vacia, y esa peticion gasta cupo antes de rechazarla.
    final falso = _AsistenteFalso();
    await tester.pumpWidget(envolver(falso.servicio));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('asistente-enviar')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(falso.llamadas, isEmpty);
  });

  testWidgets('solo espacios tampoco viaja', (tester) async {
    final falso = _AsistenteFalso();
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, '    ');
    await tester.pumpAndSettle();

    expect(falso.llamadas, isEmpty);
  });

  testWidgets('manda la pregunta recortada y el idioma activo', (tester) async {
    final falso = _AsistenteFalso();
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, '  que vence esta semana  ');
    await tester.pumpAndSettle();

    expect(falso.llamadas.single.pregunta, 'que vence esta semana');
    expect(falso.llamadas.single.idioma, 'es');
  });

  testWidgets('en ingles pide la respuesta en ingles', (tester) async {
    // La cicatriz de INNO-01: la app se renderiza en el idioma del navegador.
    // Si el idioma no se pasara, el servidor contestaria en castellano a
    // alguien que esta viendo la app entera en ingles.
    final falso = _AsistenteFalso();
    await tester.pumpWidget(
      envolver(falso.servicio, locale: const Locale('en')),
    );
    await preguntar(tester, 'what expires this week');
    await tester.pumpAndSettle();

    expect(falso.llamadas.single.idioma, 'en');
  });

  testWidgets('pinta el estado de carga mientras el servidor piensa', (
    tester,
  ) async {
    final falso = _AsistenteFalso()
      ..pendiente = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'que vence');
    await tester.pump();

    expect(find.byKey(const Key('asistente-cargando')), findsOneWidget);

    falso.pendiente!.complete({'intencion': 'agenda', 'texto': 'Listo.'});
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asistente-cargando')), findsNothing);
    expect(find.text('Listo.'), findsOneWidget);
  });

  testWidgets('pinta la respuesta que manda el servidor, tal cual', (
    tester,
  ) async {
    final falso = _AsistenteFalso()
      ..respuesta = {
        'intencion': 'agenda',
        'texto': 'Tu SOAT vence en 5 dias.',
        'items': 1,
      };
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'que vence');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asistente-respuesta')), findsOneWidget);
    expect(find.text('Tu SOAT vence en 5 dias.'), findsOneWidget);
    expect(find.byKey(const Key('asistente-vacio')), findsNothing);
  });

  testWidgets('una agenda vacia es una respuesta, no un error', (tester) async {
    // `items: 0` es el camino en el que el servidor contesta un texto fijo sin
    // llamar al modelo. Pintarlo como error seria decir que algo fallo cuando
    // la respuesta correcta es "no tienes nada pendiente".
    final falso = _AsistenteFalso()
      ..respuesta = {
        'intencion': 'agenda',
        'texto': 'No tienes nada pendiente en los proximos dias.',
        'items': 0,
      };
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'que vence');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asistente-respuesta')), findsOneWidget);
    expect(find.byKey(const Key('asistente-error')), findsNothing);
  });

  testWidgets('el rechazo se distingue de una respuesta normal', (
    tester,
  ) async {
    // Sin el distintivo, un rechazo se lee como si el asistente hubiera
    // contestado a lo que se le pregunto. La etiqueta es lo que deja claro que
    // la pregunta quedo sin responder a proposito.
    final falso = _AsistenteFalso()
      ..respuesta = {
        'intencion': 'fuera_de_alcance',
        'texto': 'Solo puedo ayudarte con los vencimientos.',
      };
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'por que suena el motor');
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.text(l10n.asistenteEtiquetaFueraDeAlcance), findsOneWidget);
    expect(
      find.text('Solo puedo ayudarte con los vencimientos.'),
      findsOneWidget,
    );
  });

  testWidgets('una respuesta normal NO lleva el distintivo de rechazo', (
    tester,
  ) async {
    final falso = _AsistenteFalso();
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'que vence');
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.text(l10n.asistenteEtiquetaFueraDeAlcance), findsNothing);
  });

  testWidgets('el cupo agotado se explica y NO ofrece reintentar', (
    tester,
  ) async {
    final falso = _AsistenteFalso()
      ..fallo = FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'Alcanzaste tu limite de consultas de hoy.',
      );
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'que vence');
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.text(l10n.asistenteErrorCupo), findsOneWidget);
    // El boton se retira, no se deja gris: reintentar hoy no puede funcionar.
    expect(find.text(l10n.errorReintentar), findsNothing);
    // Y el mensaje del servidor no se pinta crudo (UX-04).
    expect(find.textContaining('limite de consultas de hoy'), findsNothing);
  });

  testWidgets('el interruptor apagado NO se disfraza de fallo de conexion', (
    tester,
  ) async {
    // Y no ofrece reintentar: reintentar no enciende nada. Antes de que el
    // servidor publicara el motivo, este caso y el de abajo compartian
    // codigo, asi que habia que elegir cual de los dos tratar mal.
    final falso = _AsistenteFalso()
      ..fallo = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'x',
        details: MotivoAsistente.apagado,
      );
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'que vence');
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.text(l10n.asistenteErrorApagado), findsOneWidget);
    expect(find.text(l10n.errorDatosConexion), findsNothing);
    expect(find.text(l10n.errorReintentar), findsNothing);
  });

  testWidgets('el proveedor caido SI ofrece reintentar', (tester) async {
    final falso = _AsistenteFalso()
      ..fallo = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'x',
        details: MotivoAsistente.proveedor,
      );
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'que vence');
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.text(l10n.asistenteErrorProveedor), findsOneWidget);
    expect(find.text(l10n.asistenteErrorApagado), findsNothing);
    expect(find.text(l10n.errorReintentar), findsOneWidget);
  });

  testWidgets('el cupo global no culpa a quien pregunta', (tester) async {
    final falso = _AsistenteFalso()
      ..fallo = FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'x',
        details: MotivoAsistente.cupoGlobal,
      );
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'que vence');
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.text(l10n.asistenteErrorCupoGlobal), findsOneWidget);
    expect(find.text(l10n.asistenteErrorCupo), findsNothing);
    expect(find.text(l10n.errorReintentar), findsNothing);
  });

  testWidgets('el taller sin aprobar recibe su motivo, no "inicia sesion"', (
    tester,
  ) async {
    final falso = _AsistenteFalso()
      ..fallo = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Taller con estado "pendiente": agenda denegada.',
      );
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'que citas tengo');
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.text(l10n.asistenteErrorTallerPendiente), findsOneWidget);
    expect(find.text(l10n.errorDatosPermiso), findsNothing);
    expect(find.text(l10n.errorReintentar), findsNothing);
  });

  testWidgets('reintentar vuelve a preguntar lo mismo', (tester) async {
    final falso = _AsistenteFalso()
      ..fallo = FirebaseFunctionsException(
        code: 'deadline-exceeded',
        message: 'x',
      );
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'que vence');
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    falso
      ..fallo = null
      ..respuesta = {'intencion': 'agenda', 'texto': 'A la segunda.'};
    // El estado de error cae por debajo del pliegue a 800x600 (el campo, el
    // aviso de alcance y el hueco del estado vacio ocupan la pantalla), asi
    // que sin esto el tap no acierta y el test pasaria a verde el dia que el
    // boton dejara de funcionar.
    await tester.ensureVisible(find.text(l10n.errorReintentar));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.errorReintentar));
    await tester.pumpAndSettle();

    expect(falso.llamadas.length, 2);
    expect(falso.llamadas.last.pregunta, 'que vence');
    expect(find.text('A la segunda.'), findsOneWidget);
  });

  testWidgets('«hacer otra pregunta» limpia respuesta y campo', (tester) async {
    final falso = _AsistenteFalso();
    await tester.pumpWidget(envolver(falso.servicio));
    await preguntar(tester, 'que vence');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('asistente-otra')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asistente-respuesta')), findsNothing);
    expect(find.byKey(const Key('asistente-vacio')), findsOneWidget);
    // El campo queda vacio: si no, el boton seguiria vivo con la pregunta
    // anterior y un toque distraido gastaria una consulta del cupo repitiendo
    // lo que ya se contesto.
    expect(falso.llamadas.length, 1);
    await tester.tap(
      find.byKey(const Key('asistente-enviar')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(falso.llamadas.length, 1);
  });
}
