// test/features/profile/presentation/pages/user_profile_colors_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/profile/presentation/pages/user_profile_screen.dart';

import '../../../../support/contrast.dart';
import '../../../../support/entry_harness.dart';

void main() {
  testWidgets('cero colores literales en el fichero', (tester) async {
    final source = File(
      'lib/features/profile/presentation/pages/user_profile_screen.dart',
    ).readAsStringSync();

    final named = RegExp(
      r'Colors\.(white|black|grey|gray|blue|red|green|orange|purple|amber)',
    ).allMatches(source).map((m) => m.group(0)).toList();
    final hex = RegExp(r'Color\(0x').allMatches(source).length;

    expect(named, isEmpty, reason: 'quedan literales con nombre: $named');
    expect(hex, 0, reason: 'quedan $hex Color(0x…)');
  });

  testWidgets('editando en oscuro el nombre se lee (hoy da 1,00:1)', (
    tester,
  ) async {
    await pumpEntry(
      tester,
      const UserProfileScreen(),
      width: 375,
      brightness: Brightness.dark,
      profile: FakeUserProfileProvider(userData: testUser(nombre: 'Ada L.')),
    );

    await tester.tap(find.byKey(const ValueKey('profile-edit-toggle')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(UserProfileScreen));
    final colors = context.appColors;
    final field = tester.widget<AppTextField>(
      find.byKey(const ValueKey('profile-name-field')),
    );
    expect(field.enabled, isTrue);

    // El campo ya no pinta su propio relleno: hereda el del tema, asi que
    // basta comprobar el par textPrimary / surfaceVariant.
    expect(
      contrastRatio(colors.textPrimary, colors.surfaceVariant),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('los interruptores usan el color de marca, no #98FFD9', (
    tester,
  ) async {
    await pumpEntry(tester, const UserProfileScreen(), width: 375);
    final context = tester.element(find.byType(UserProfileScreen));
    final colors = context.appColors;

    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches, hasLength(3));
    for (final s in switches) {
      expect(s.activeTrackColor, colors.primary);
      expect(s.activeThumbColor, colors.onPrimary);
      expect(
        contrastRatio(colors.onPrimary, colors.primary),
        greaterThanOrEqualTo(3.0),
      );
    }
  });

  testWidgets('no quedan GoogleFonts', (tester) async {
    final source = File(
      'lib/features/profile/presentation/pages/user_profile_screen.dart',
    ).readAsStringSync();
    expect(source.contains('GoogleFonts'), isFalse);
  });

  testWidgets('el titulo del dialogo de borrado sale del ARB', (tester) async {
    final source = File(
      'lib/features/profile/presentation/pages/user_profile_screen.dart',
    ).readAsStringSync();
    expect(source.contains("Text('Eliminar Cuenta')"), isFalse);
    expect(source.contains('upDeleteAccountTitle'), isTrue);
  });
}
