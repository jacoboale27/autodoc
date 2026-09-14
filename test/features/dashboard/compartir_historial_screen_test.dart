import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/dashboard/data/services/pase_historial_service.dart';
import 'package:autodoc/features/dashboard/presentation/pages/compartir_historial_screen.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// INNO-01 — la pantalla con la que el propietario emite el pase.
///
/// **`pumpAndSettle` no se puede usar aqui y no es un detalle.** La cuenta
/// atras es un `Timer.periodic` de un segundo, y `pumpAndSettle` avanza el
/// reloj hasta que no quede trabajo pendiente: con un temporizador periodico
/// vivo eso no pasa nunca, asi que expira a los diez minutos de reloj virtual
/// en vez de fallar por lo que se este probando. Aqui se bombea a mano.
const String _token =
    'a3f9c1d2e4b50617a8b9c0d1e2f30415a6b7c8d9e0f102132435465768798a0b1';

/// Reloj que avanza SOLO cuando el test lo mueve.
///
/// Hace falta porque `tester.pump(Duration)` avanza el reloj falso del binding
/// y no el de `DateTime.now()`: con la hora real, un pase de dos segundos
/// sigue "vivo" para siempre dentro del test, y la pantalla que se niega a
/// retirar un QR muerto pasaria igual de verde. El reloj se adelanta a mano en
/// el mismo salto que el `pump`, que es lo que hace comparable lo que ve el
/// temporizador con lo que ve la cuenta atras.
class RelojFalso {
  DateTime ahora = DateTime(2026, 9, 13, 12);

  DateTime call() => ahora;

  void avanzar(Duration d) => ahora = ahora.add(d);
}

class ServicioFalso {
  ServicioFalso({
    required this.reloj,
    this.fallo,
    this.vigencia = const Duration(minutes: 15),
  });

  final RelojFalso reloj;

  Object? fallo;
  Duration vigencia;
  int emisiones = 0;
  final List<String> revocados = <String>[];

  PaseHistorialService get servicio => PaseHistorialService(
    crear: (idVehiculo) async {
      emisiones += 1;
      if (fallo != null) throw fallo!;
      return {
        'token': _token,
        'expira_en': reloj.ahora.add(vigencia).millisecondsSinceEpoch,
      };
    },
    revocar: (token) async {
      revocados.add(token);
    },
  );
}

Widget envolver(ServicioFalso falso) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('es'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: CompartirHistorialScreen(
    vehiculoId: 'v1',
    servicio: falso.servicio,
    reloj: falso.reloj.call,
  ),
);

/// Deja que resuelva el future de emision sin dejar correr el temporizador
/// mas de lo necesario.
Future<void> asentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Avanza a la vez el reloj del binding y el de la pantalla.
Future<void> avanzar(WidgetTester tester, RelojFalso reloj, Duration d) async {
  reloj.avanzar(d);
  await tester.pump(d);
}

void main() {
  testWidgets('al abrirse emite un pase y pinta su QR', (tester) async {
    final falso = ServicioFalso(reloj: RelojFalso());
    await tester.pumpWidget(envolver(falso));
    await asentar(tester);

    expect(falso.emisiones, 1);

    final qr = tester.widget<QrDelPase>(find.byType(QrDelPase));
    expect(
      qr.payload,
      '$prefijoPaseHistorial$_token',
      reason:
          'el QR tiene que llevar el prefijo, que es lo unico que permite al '
          'escaner distinguir un pase de una placa',
    );

    // El codigo tambien en texto: un QR no se puede leer por telefono ni por
    // un lector de pantalla.
    expect(find.textContaining(_token), findsOneWidget);
    // Cuenta atras visible.
    expect(find.textContaining('Caduca en'), findsOneWidget);
  });

  testWidgets('la cuenta atras avanza contra el reloj', (tester) async {
    final falso = ServicioFalso(
      reloj: RelojFalso(),
      vigencia: const Duration(minutes: 2),
    );
    await tester.pumpWidget(envolver(falso));
    await asentar(tester);

    expect(find.text('Caduca en 02:00'), findsOneWidget);

    await avanzar(tester, falso.reloj, const Duration(seconds: 61));
    expect(find.text('Caduca en 00:59'), findsOneWidget);
  });

  testWidgets('cuando el pase vence deja de ensenar el QR', (tester) async {
    final falso = ServicioFalso(
      reloj: RelojFalso(),
      vigencia: const Duration(seconds: 2),
    );
    await tester.pumpWidget(envolver(falso));
    await asentar(tester);
    expect(find.byType(QrDelPase), findsOneWidget);

    await avanzar(tester, falso.reloj, const Duration(seconds: 3));

    expect(
      find.byType(QrDelPase),
      findsNothing,
      reason:
          'seguir ensenando un QR que ya no sirve manda a la otra persona a '
          'escanear algo que solo puede fallar',
    );
    expect(find.textContaining('caduco'), findsOneWidget);
    expect(find.text('Generar otro pase'), findsOneWidget);
  });

  testWidgets('revocar anula el pase y retira el QR', (tester) async {
    final falso = ServicioFalso(reloj: RelojFalso());
    await tester.pumpWidget(envolver(falso));
    await asentar(tester);

    // El boton queda por debajo del alto de la ventana de prueba: sin esto el
    // tap no impacta en nada y el test falla diciendo que no se revoco.
    await tester.ensureVisible(find.text('Revocar ahora'));
    await tester.tap(find.text('Revocar ahora'));
    await asentar(tester);

    expect(falso.revocados, [_token]);
    expect(find.byType(QrDelPase), findsNothing);
    expect(find.textContaining('revocado'), findsOneWidget);

    await tester.tap(find.text('Generar otro pase'));
    await asentar(tester);
    expect(falso.emisiones, 2);
    expect(find.byType(QrDelPase), findsOneWidget);
  });

  testWidgets(
    'un fallo del servidor no ensena detalle tecnico y deja reintentar',
    (tester) async {
      final falso = ServicioFalso(
        reloj: RelojFalso(),
        fallo: FirebaseFunctionsException(
          code: 'unavailable',
          message:
              'INTERNAL: upstream connect error 503 at firestore.googleapis.com',
        ),
      );
      await tester.pumpWidget(envolver(falso));
      await asentar(tester);

      expect(find.textContaining('INTERNAL'), findsNothing);
      expect(find.textContaining('googleapis'), findsNothing);
      expect(find.byType(QrDelPase), findsNothing);

      final reintentar = find.text('Reintentar');
      expect(reintentar, findsOneWidget);

      falso.fallo = null;
      await tester.tap(reintentar);
      await asentar(tester);

      expect(falso.emisiones, 2);
      expect(find.byType(QrDelPase), findsOneWidget);
    },
  );
}
