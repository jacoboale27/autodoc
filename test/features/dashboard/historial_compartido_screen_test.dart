import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/dashboard/data/services/pase_historial_service.dart';
import 'package:autodoc/features/dashboard/presentation/pages/historial_compartido_screen.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// INNO-01 — lo que ve quien escanea el pase.
///
/// El test que de verdad importa aqui es el de `auto_declarado`.
/// `firestore.rules:728-729` autoriza al propietario a registrar servicios
/// sobre su propio vehiculo con `id_taller == 'Manual (Propietario)'`, asi que
/// un vendedor puede escribirse diez mantenimientos inventados y ensenar el
/// QR. Si esta pantalla los pinta igual que los de un taller, la funcionalidad
/// deja de probar nada y pasa a ser la palabra del vendedor con el sello de
/// AutoDoc encima. El servidor ya manda la bandera; el defecto se cometeria
/// aqui, y solo un test de esta pantalla puede verlo.
const String _token =
    'a3f9c1d2e4b50617a8b9c0d1e2f30415a6b7c8d9e0f102132435465768798a0b1';

Map<String, dynamic> _respuesta({List<Map<String, dynamic>>? servicios}) => {
  'placa': 'E2E-AAA',
  'marca': 'Toyota',
  'modelo': 'Corolla',
  'anio': 2020,
  'kilometraje_actual': 45000,
  'expira_en': DateTime.now()
      .add(const Duration(minutes: 10))
      .millisecondsSinceEpoch,
  'servicios':
      servicios ??
      [
        {
          'tipo_servicio': 'Cambio de aceite',
          'fecha': DateTime(2026, 3, 1).millisecondsSinceEpoch,
          'kilometraje_servicio': 40000,
          'descripcion': 'Aceite sintetico 5W30',
          'id_taller': 'e2e-taller-a',
          'auto_declarado': false,
        },
        {
          'tipo_servicio': 'Rotacion de llantas',
          'fecha': DateTime(2026, 1, 15).millisecondsSinceEpoch,
          'kilometraje_servicio': 38000,
          'descripcion': 'Hecho en casa',
          'id_taller': 'Manual (Propietario)',
          'auto_declarado': true,
        },
      ],
};

class LectorFalso {
  LectorFalso({this.fallo, this.datos});

  Object? fallo;
  Map<String, dynamic>? datos;
  int lecturas = 0;

  PaseHistorialService get servicio => PaseHistorialService(
    leer: (token) async {
      lecturas += 1;
      if (fallo != null) throw fallo!;
      return datos ?? _respuesta();
    },
  );
}

Widget envolver(PaseHistorialService servicio) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('es'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: HistorialCompartidoScreen(token: _token, servicio: servicio),
);

void main() {
  testWidgets('canjea el pase y pinta el vehiculo y sus servicios', (
    tester,
  ) async {
    final falso = LectorFalso();
    await tester.pumpWidget(envolver(falso.servicio));
    await tester.pumpAndSettle();

    expect(falso.lecturas, 1);
    expect(find.textContaining('E2E-AAA'), findsOneWidget);
    expect(find.textContaining('Toyota'), findsOneWidget);
    expect(find.text('Cambio de aceite'), findsOneWidget);
    expect(find.text('Rotacion de llantas'), findsOneWidget);
  });

  testWidgets('distingue lo registrado por un taller de lo auto-declarado', (
    tester,
  ) async {
    await tester.pumpWidget(envolver(LectorFalso().servicio));
    await tester.pumpAndSettle();

    expect(
      find.text('Registrado por un taller'),
      findsOneWidget,
      reason: 'lo que un taller registro es lo unico que AutoDoc respalda',
    );
    expect(
      find.text('Declarado por el propietario'),
      findsOneWidget,
      reason:
          'sin esta etiqueta un vendedor puede inventarse el historial entero '
          'y ensenarlo con el sello de AutoDoc encima',
    );
    expect(
      find.textContaining('no puede verificar'),
      findsOneWidget,
      reason:
          'la etiqueta sola no dice lo que significa a quien no conoce la app',
    );
  });

  testWidgets('avisa de que el pase no trae importes', (tester) async {
    await tester.pumpWidget(envolver(LectorFalso().servicio));
    await tester.pumpAndSettle();

    expect(find.textContaining('no incluye importes'), findsOneWidget);
  });

  testWidgets('sin servicios lo dice, en vez de dejar la pantalla vacia', (
    tester,
  ) async {
    final falso = LectorFalso(datos: _respuesta(servicios: []));
    await tester.pumpWidget(envolver(falso.servicio));
    await tester.pumpAndSettle();

    expect(find.textContaining('no tiene mantenimientos'), findsOneWidget);
  });

  group('cada motivo de rechazo dice lo suyo', () {
    // El mapeo por defecto de UX-04 (`mensajeDeError`) NO sirve aqui, y ese es
    // justo el punto: manda `deadline-exceeded` al mensaje de conexion y
    // `permission-denied` a "vuelve a iniciar sesion". Los dos son falsos para
    // un pase —el primero significa que caduco y el segundo que el propietario
    // lo revoco— y los dos dejarian a la persona reintentando algo que no
    // puede funcionar.
    final casos = <String, String>{
      'deadline-exceeded': 'caduco',
      'permission-denied': 'revoco',
      'resource-exhausted': 'demasiadas veces',
      'not-found': 'no existe',
      'invalid-argument': 'no es un pase',
    };

    casos.forEach((codigo, esperado) {
      testWidgets(codigo, (tester) async {
        final falso = LectorFalso(
          fallo: FirebaseFunctionsException(
            code: codigo,
            message: 'INTERNAL detalle tecnico que nadie debe ver',
          ),
        );
        await tester.pumpWidget(envolver(falso.servicio));
        await tester.pumpAndSettle();

        expect(find.textContaining(esperado), findsOneWidget);
        expect(find.textContaining('INTERNAL'), findsNothing);
      });
    });
  });

  testWidgets(
    'un fallo de red deja reintentar, y reintentar vuelve a canjear',
    (tester) async {
      final falso = LectorFalso(
        fallo: FirebaseFunctionsException(code: 'unavailable', message: 'x'),
      );
      await tester.pumpWidget(envolver(falso.servicio));
      await tester.pumpAndSettle();

      final reintentar = find.text('Reintentar');
      expect(reintentar, findsOneWidget);

      falso.fallo = null;
      await tester.tap(reintentar);
      await tester.pumpAndSettle();

      expect(falso.lecturas, 2);
      expect(find.text('Cambio de aceite'), findsOneWidget);
    },
  );

  testWidgets('un pase caducado no ofrece reintentar', (tester) async {
    final falso = LectorFalso(
      fallo: FirebaseFunctionsException(
        code: 'deadline-exceeded',
        message: 'x',
      ),
    );
    await tester.pumpWidget(envolver(falso.servicio));
    await tester.pumpAndSettle();

    expect(
      find.text('Reintentar'),
      findsNothing,
      reason:
          'reintentar un pase vencido no puede funcionar nunca; ofrecerlo es '
          'mentir sobre lo que arregla el boton',
    );
  });
}
