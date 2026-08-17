// test/features/profile/presentation/pages/user_profile_layout_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/profile/presentation/pages/user_profile_screen.dart';

import '../../../../support/entry_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('se puede editar el perfil en TODAS las clases de ventana', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pumpEntry(
        tester,
        const UserProfileScreen(),
        width: width,
        height: 900,
        profile: FakeUserProfileProvider(userData: testUser()),
      );

      final toggle = find.byKey(const ValueKey('profile-edit-toggle'));
      expect(
        toggle,
        findsOneWidget,
        reason: 'no hay forma de entrar en edicion a $width px',
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-save')),
        findsOneWidget,
        reason: 'no hay forma de guardar a $width px',
      );
    }
  });

  testWidgets('en expanded hay dos columnas', (tester) async {
    await pumpEntry(
      tester,
      const UserProfileScreen(),
      width: 375,
      profile: FakeUserProfileProvider(userData: testUser()),
    );
    expect(find.byKey(const ValueKey('profile-side-column')), findsNothing);

    await pumpEntry(
      tester,
      const UserProfileScreen(),
      width: 1024,
      height: 900,
      profile: FakeUserProfileProvider(userData: testUser()),
    );
    final side = find.byKey(const ValueKey('profile-side-column'));
    final main = find.byKey(const ValueKey('profile-main-column'));
    expect(side, findsOneWidget);
    expect(tester.getTopLeft(side).dx, lessThan(tester.getTopLeft(main).dx));
  });

  testWidgets('no hay Navigator.pop en una ruta de shell', (tester) async {
    final source = File(
      'lib/features/profile/presentation/pages/user_profile_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('Navigator.pop(context)'),
      isFalse,
      reason: '/user_profile vive en el ShellRoute: no hay nada que desapilar',
    );
  });

  testWidgets('el controlador del dialogo de borrado se libera', (
    tester,
  ) async {
    await pumpEntry(
      tester,
      const UserProfileScreen(),
      width: 375,
      profile: FakeUserProfileProvider(userData: testUser()),
    );
    // El boton vive al final de una columna con scroll propio: hay que
    // desplazarlo a la vista antes de poder tocarlo (mismo patron que
    // `auth_screen_form_test.dart`).
    await tester.ensureVisible(
      find.byKey(const ValueKey('profile-delete-account')),
    );
    await tester.tap(find.byKey(const ValueKey('profile-delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-delete-cancel')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('la camara de la foto de perfil mide 48x48', (tester) async {
    await pumpEntry(
      tester,
      const UserProfileScreen(),
      width: 375,
      profile: FakeUserProfileProvider(userData: testUser()),
    );

    // El boton de camara solo aparece en modo edicion.
    await tester.tap(find.byKey(const ValueKey('profile-edit-toggle')));
    await tester.pumpAndSettle();

    final camera = find.byKey(const ValueKey('profile-photo-camera'));
    expect(camera, findsOneWidget);
    final size = tester.getSize(camera);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('no desborda en ningun ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      final errors = await pumpEntryCollecting(
        tester,
        const UserProfileScreen(),
        width: width,
        height: 900,
        profile: FakeUserProfileProvider(userData: testUser()),
      );
      expect(errors, isEmpty, reason: 'desborda a $width px');
    }
  });
}
