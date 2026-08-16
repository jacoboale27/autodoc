import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';

import '../../support/entry_harness.dart';

void main() {
  test('no queda ninguna pantalla fuera de pages/', () {
    final offenders = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_screen.dart'))
        .where((f) => f.path.replaceAll(r'\', '/').contains('/screens/'))
        .map((f) => f.path)
        .toList();
    expect(
      offenders,
      isEmpty,
      reason: 'CONVENTIONS.md §1: las pantallas viven en presentation/pages/',
    );
  });

  testWidgets('la ruta de acceso renderiza AuthScreen en modo login', (
    tester,
  ) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    final screen = tester.widget<AuthScreen>(find.byType(AuthScreen));
    expect(screen.isLogin, isTrue);
  });

  testWidgets('en horizontal de telefono el acceso hace scroll y no desborda', (
    tester,
  ) async {
    // Este es el contrato que el comentario de LoginScreen prometia
    // y que ningun test comprobaba: 800x400 es un telefono girado.
    final errors = await pumpEntryCollecting(
      tester,
      const AuthScreen(isLogin: true),
      width: 800,
      height: 400,
    );
    // AuthBackgroundBlobs (widget decorativo, fuera del alcance de esta
    // tarea) anima con flutter_animate durante 2.5s reales. pumpEntryCollecting
    // solo asienta un frame (para poder capturar errores de layout del
    // primer pump), asi que hay que agotar ese timer aqui antes de que el
    // arbol se destruya o el binding revienta con '!timersPending'. Mismo
    // patron que test/features/auth/auth_screen_form_test.dart.
    await tester.pump(const Duration(seconds: 3));
    expect(errors, isEmpty);
    expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));
  });
}
