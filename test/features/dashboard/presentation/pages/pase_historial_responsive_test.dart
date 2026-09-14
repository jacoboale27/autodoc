import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/dashboard/data/services/pase_historial_service.dart';
import 'package:autodoc/features/dashboard/presentation/pages/compartir_historial_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/historial_compartido_screen.dart';

import '../../../../support/responsive_harness.dart';

/// INNO-01 — las dos pantallas del pase, en los ocho anchos de auditoria y en
/// los dos temas.
///
/// El QR mide 220 px de lado y va dentro de una tarjeta con su padding: a
/// 320 px de ancho no sobra tanto como parece, y es justo el telefono donde se
/// va a usar esto —alguien ensenando el coche en la calle—.
const String _token =
    'a3f9c1d2e4b50617a8b9c0d1e2f30415a6b7c8d9e0f102132435465768798a0b1';

PaseHistorialService _emisor() => PaseHistorialService(
  crear: (_) async => {
    'token': _token,
    'expira_en': DateTime(2026, 9, 13, 12, 15).millisecondsSinceEpoch,
  },
);

PaseHistorialService _lector() => PaseHistorialService(
  leer: (_) async => {
    'placa': 'ABC-123',
    'marca': 'Toyota',
    'modelo': 'Corolla',
    'anio': 2020,
    'kilometraje_actual': 45000,
    'expira_en': DateTime(2026, 9, 13, 12, 15).millisecondsSinceEpoch,
    'servicios': [
      {
        'tipo_servicio': 'Cambio de aceite con filtro y revision general',
        'fecha': DateTime(2026, 3, 1).millisecondsSinceEpoch,
        'kilometraje_servicio': 40000,
        'descripcion':
            'Aceite sintetico 5W30, filtro de aceite y revision de frenos, '
            'suspension y niveles',
        'id_taller': 'taller-1',
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
  },
);

void main() {
  for (final ruta in const [
    'lib/features/dashboard/presentation/pages/compartir_historial_screen.dart',
    'lib/features/dashboard/presentation/pages/historial_compartido_screen.dart',
  ]) {
    test('$ruta no usa GoogleFonts ni colores fuera de la paleta', () {
      final fuente = File(ruta).readAsStringSync();
      expect(fuente.contains('GoogleFonts.'), isFalse);
      for (final prohibido in [
        'Colors.grey',
        'Colors.green',
        'Colors.blueGrey',
      ]) {
        expect(fuente.contains(prohibido), isFalse, reason: prohibido);
      }
    });
  }

  testWidgets('emitir el pase no desborda en ningun ancho, en ambos temas', (
    tester,
  ) async {
    for (final brillo in [Brightness.light, Brightness.dark]) {
      await forEachAuditWidth(tester, (width) async {
        await pumpAtWidth(
          tester,
          CompartirHistorialScreen(
            vehiculoId: 'v1',
            servicio: _emisor(),
            // Reloj fijo justo antes de la caducidad: asi la pantalla monta el
            // estado con QR, que es el que puede desbordar. Con el reloj real
            // el pase estaria vencido (la fecha es del pasado) y se mediria el
            // estado terminal, que no prueba nada de esto.
            reloj: () => DateTime(2026, 9, 13, 12, 5),
          ),
          width: width,
          brightness: brillo,
        );
        // `pumpAndSettle` no sirve: la cuenta atras es un Timer.periodic y
        // nunca deja de haber trabajo pendiente.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expectNoOverflow(tester);
      });
    }
  });

  testWidgets('el historial compartido no desborda en ningun ancho', (
    tester,
  ) async {
    for (final brillo in [Brightness.light, Brightness.dark]) {
      await forEachAuditWidth(tester, (width) async {
        await pumpAtWidth(
          tester,
          HistorialCompartidoScreen(token: _token, servicio: _lector()),
          width: width,
          brightness: brillo,
        );
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });
    }
  });

  testWidgets('en ingles las dos pantallas siguen sin desbordar', (
    tester,
  ) async {
    // La localizacion no es solo traducir: los rotulos ingleses cambian de
    // largo y el sitio donde rompen es el sello de origen del servicio, que va
    // en una fila con su icono.
    await pumpAtWidth(
      tester,
      HistorialCompartidoScreen(token: _token, servicio: _lector()),
      width: 320,
      // Alto generoso a proposito: el historial va en un `ListView`, que solo
      // construye los hijos visibles. A 320x900 la segunda ficha —la
      // auto-declarada, que es justo la que hay que comprobar— cae por debajo
      // del pliegue y `find.text` no la ve, porque no existe en el arbol de
      // elementos. Con un viewport corto este test afirmaria que el sello no
      // esta cuando lo que pasa es que no se ha pintado todavia.
      height: 1600,
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recorded by a workshop'), findsOneWidget);
    expect(find.text('Declared by the owner'), findsOneWidget);
    expectNoOverflow(tester);

    await pumpAtWidth(
      tester,
      CompartirHistorialScreen(
        vehiculoId: 'v1',
        servicio: _emisor(),
        reloj: () => DateTime(2026, 9, 13, 12, 5),
      ),
      width: 320,
      locale: const Locale('en'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Expires in'), findsOneWidget);
    expectNoOverflow(tester);
  });
}
