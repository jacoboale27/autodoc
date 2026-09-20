import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/asistente/data/services/asistente_service.dart';
import 'package:autodoc/features/asistente/presentation/pages/asistente_screen.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// IA-01 — doble envio en el asistente, con el formato de la tanda GAPS-07.
///
/// **Aqui el doble envio cuesta dinero y cupo, no solo un duplicado.** Cada
/// toque de mas es una consulta menos de las diez que tiene la persona ese
/// dia, una llamada mas al proveedor y una escritura mas en el contador
/// global, que es un documento caliente compartido por toda la app.
///
/// **Las dos capas, y hacen falta las dos.** La leccion medida de GAPS-07 es
/// que `onPressed: null` solo surte efecto **en el frame siguiente**: entre el
/// `setState` y el siguiente `build`, el boton que hay en pantalla sigue
/// llevando el callback viejo. Los dos toques de `envioDoble` ocurren sin
/// pump intermedio, o sea en ese hueco exacto, asi que **lo que atrapa al
/// segundo es el guard de reentrada**, no la deshabilitacion. El tercer test
/// cubre la otra capa: ya con un frame dibujado, el boton no acepta el toque.
class _AsistenteColgado {
  final Completer<Map<String, dynamic>> pendiente =
      Completer<Map<String, dynamic>>();
  int llamadas = 0;

  /// Cierra la consulta en vuelo. **No es cosmetico:** con `isLoading: true`
  /// el boton deja un temporizador vivo (la animacion de `flutter_animate`) y
  /// el binding aborta el test con «A Timer is still pending even after the
  /// widget tree was disposed». Es el reverso de la nota de GAPS-07 sobre
  /// `AppButton(isLoading: true)` envenenando `pumpAndSettle`.
  Future<void> soltar(WidgetTester tester) async {
    if (!pendiente.isCompleted) {
      pendiente.complete({'intencion': 'agenda', 'texto': 'Listo.'});
    }
    await tester.pumpAndSettle();
  }

  AsistenteService get servicio => AsistenteService(
    preguntar: (pregunta, idioma) {
      llamadas += 1;
      return pendiente.future;
    },
  );
}

Widget envolver(AsistenteService servicio) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('es'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: AsistenteScreen(servicio: servicio),
);

void main() {
  testWidgets('dos toques en el mismo frame envian UNA consulta', (
    tester,
  ) async {
    final falso = _AsistenteColgado();
    await tester.pumpWidget(envolver(falso.servicio));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('asistente-pregunta')),
      'que vence esta semana',
    );
    await tester.pump();

    final boton = find.byKey(const Key('asistente-enviar'));
    // Sin pump entre los dos: es el hueco donde `onPressed: null` todavia no
    // ha llegado a la pantalla.
    await tester.tap(boton);
    await tester.tap(boton, warnIfMissed: false);
    await tester.pump();

    expect(
      falso.llamadas,
      1,
      reason:
          'el segundo toque gasto otra consulta del cupo diario y otra '
          'llamada al proveedor',
    );

    await falso.soltar(tester);
  });

  testWidgets('con la consulta en vuelo el boton ya no acepta toques', (
    tester,
  ) async {
    final falso = _AsistenteColgado();
    await tester.pumpWidget(envolver(falso.servicio));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('asistente-pregunta')),
      'que vence esta semana',
    );
    await tester.pump();

    final boton = find.byKey(const Key('asistente-enviar'));
    await tester.tap(boton);
    // Un frame: ahora si esta dibujado el estado de carga.
    await tester.pump();
    expect(find.byKey(const Key('asistente-cargando')), findsOneWidget);

    // Capa 1, afirmada directamente. Sin esto, quitar la deshabilitacion no
    // pondria rojo ningun test: el guard de reentrada tapa su ausencia en
    // todos los casos observables desde fuera, y el centinela se volveria
    // decoracion.
    expect(
      tester.widget<AppButton>(boton).onPressed,
      isNull,
      reason: 'el boton sigue vivo con una consulta en vuelo',
    );

    await tester.tap(boton, warnIfMissed: false);
    await tester.tap(boton, warnIfMissed: false);
    await tester.pump();

    expect(falso.llamadas, 1);

    await falso.soltar(tester);
  });

  testWidgets('el campo se bloquea mientras se espera respuesta', (
    tester,
  ) async {
    // La otra via de doble envio de esta pantalla: `onSubmitted` del campo
    // tambien envia, asi que un Enter repetido haria lo mismo que el boton.
    final falso = _AsistenteColgado();
    await tester.pumpWidget(envolver(falso.servicio));
    await tester.pumpAndSettle();

    final campo = find.byKey(const Key('asistente-pregunta'));
    await tester.enterText(campo, 'que vence esta semana');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(falso.llamadas, 1);

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(
      falso.llamadas,
      1,
      reason: 'un segundo Enter mientras se espera gasto otra consulta',
    );

    await falso.soltar(tester);
  });
}
