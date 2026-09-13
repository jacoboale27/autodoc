import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:autodoc/core/utils/mensaje_de_error.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// UX-04: "ningun usuario ve un error tecnico".
///
/// El enunciado del plan nombra UN sitio —el `'Error: ${snapshot.error}'` de
/// `service_history_screen.dart:213`— pero al inventariar aparecieron unos
/// cuarenta, y el peor grupo no es el que se ve crudo a simple vista: es el de
/// las cadenas que YA estan localizadas y aun asi interpolan la excepcion
/// dentro (`adminError`, `upErrorUploadingImage`). Tener la frase traducida no
/// sirve de nada si el hueco lo rellena un `FirebaseException` con su codigo,
/// su plugin y a veces la consulta entera.
///
/// Lo que se afirma aqui es lo unico que importa de verdad: que el texto que
/// sale hacia la pantalla **no contiene** el detalle tecnico. Por eso los casos
/// no comparan contra una cadena concreta —eso solo probaria que el ARB dice lo
/// que dice— sino contra la ausencia del ruido: nada de `[cloud_firestore/...]`,
/// nada de `Exception`, nada del mensaje interno.
Future<AppLocalizations> cargarL10n(WidgetTester tester, Locale locale) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context)!;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return l10n;
}

void main() {
  testWidgets('un permission-denied no menciona permisos ni el codigo', (
    tester,
  ) async {
    final l10n = await cargarL10n(tester, const Locale('es'));

    final mensaje = mensajeDeError(
      l10n,
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      ),
    );

    expect(mensaje, isNotEmpty);
    expect(mensaje, isNot(contains('permission-denied')));
    expect(mensaje, isNot(contains('cloud_firestore')));
    expect(mensaje, isNot(contains('Missing or insufficient')));
  });

  testWidgets('un failed-precondition tampoco', (tester) async {
    final l10n = await cargarL10n(tester, const Locale('es'));

    // El caso real de este repo: una consulta sin indice compuesto. En
    // produccion el mensaje trae la consulta entera y un enlace a la consola
    // de Firebase — informacion de la estructura de la base de datos que no
    // tiene por que salir a la pantalla de nadie.
    final mensaje = mensajeDeError(
      l10n,
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message:
            'The query requires an index. You can create it here: '
            'https://console.firebase.google.com/project/autodoc/firestore/indexes?create_composite=Ci',
      ),
    );

    expect(mensaje, isNot(contains('console.firebase.google.com')));
    expect(mensaje, isNot(contains('index')));
  });

  testWidgets('un fallo de red se distingue de uno de permisos', (
    tester,
  ) async {
    final l10n = await cargarL10n(tester, const Locale('es'));

    final red = mensajeDeError(
      l10n,
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );
    final permisos = mensajeDeError(
      l10n,
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );

    // Si los dos dijeran lo mismo, el mensaje seria inutil: "algo fallo" no
    // deja a nadie hacer nada. Reintentar sirve en uno y no en el otro.
    expect(red, isNot(equals(permisos)));
  });

  testWidgets('una excepcion cualquiera no se filtra tal cual', (tester) async {
    final l10n = await cargarL10n(tester, const Locale('es'));

    final mensaje = mensajeDeError(l10n, StateError('null check on a null'));

    expect(mensaje, isNot(contains('null check')));
    expect(mensaje, isNot(contains('Bad state')));
  });

  testWidgets('un error nulo tambien da un mensaje util', (tester) async {
    final l10n = await cargarL10n(tester, const Locale('es'));

    final mensaje = mensajeDeError(l10n, null);

    expect(mensaje, isNotEmpty);
    expect(mensaje.toLowerCase(), isNot(contains('null')));
  });

  testWidgets('el mensaje sigue al idioma de la app', (tester) async {
    final es = await cargarL10n(tester, const Locale('es'));
    final enEs = mensajeDeError(
      es,
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );

    final en = await cargarL10n(tester, const Locale('en'));
    final enEn = mensajeDeError(
      en,
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );

    expect(enEs, isNot(equals(enEn)));
  });
}
