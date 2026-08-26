import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `web/index.html` no pasa por ningun motor de plantillas.
///
/// `flutter build web` sustituye **unicamente** `$FLUTTER_BASE_HREF` en este
/// archivo. Cualquier otro `$ALGO` que alguien escriba aqui esperando que se
/// rellene en el build llega literal al navegador — que es lo que le pasaba a
/// `$GOOGLE_SIGNIN_CLIENT_ID_WEB` en el meta `google-signin-client_id`.
void main() {
  final fuente = File('web/index.html').readAsStringSync();

  test('el unico placeholder es el que Flutter sabe sustituir', () {
    final placeholders = RegExp(
      r'\$[A-Z_][A-Z0-9_]*',
    ).allMatches(fuente).map((m) => m.group(0)!).toSet();

    expect(
      placeholders.difference({r'$FLUTTER_BASE_HREF'}),
      isEmpty,
      reason:
          'Flutter solo sustituye \$FLUTTER_BASE_HREF; el resto se sirve tal '
          'cual al navegador. Escribe el valor literal o inyectalo en el '
          'pipeline de build.',
    );
  });

  test('el client_id de Google es un client ID de verdad', () {
    final meta = RegExp(
      r'name="google-signin-client_id"\s+content="([^"]*)"',
    ).firstMatch(fuente);

    expect(meta, isNotNull, reason: 'desaparecio el meta tag');
    expect(
      meta!.group(1),
      endsWith('.apps.googleusercontent.com'),
      reason: 'el meta sigue teniendo un placeholder, no un client ID',
    );
  });
}
