// test/support/entry_harness_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';

import 'entry_harness.dart';

void main() {
  testWidgets('pumpEntry monta con AppColors, l10n y el ancho pedido', (
    tester,
  ) async {
    late BuildContext captured;
    await pumpEntry(
      tester,
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
      width: 375,
    );

    expect(captured.appColors.primary, AppPalette.lightPrimary);
    expect(MediaQuery.sizeOf(captured).width, 375);
    expect(Localizations.localeOf(captured), const Locale('es'));
  });

  testWidgets('pumpEntry acepta locale en', (tester) async {
    late BuildContext captured;
    await pumpEntry(
      tester,
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
      width: 375,
      locale: const Locale('en'),
    );
    expect(Localizations.localeOf(captured), const Locale('en'));
  });

  testWidgets('collectLayoutErrors devuelve los DOS desbordamientos', (
    tester,
  ) async {
    final errors = await pumpEntryCollecting(
      tester,
      const _TwoOverflows(),
      width: 200,
    );
    expect(errors, hasLength(2));
    expect(
      errors.every((e) => e.exception.toString().contains('overflowed')),
      isTrue,
    );
  });

  testWidgets('FakeUserProfileProvider expone userData y notifica', (
    tester,
  ) async {
    final fake = FakeUserProfileProvider(userData: testUser(nombre: 'Ada'));
    var notified = 0;
    fake.addListener(() => notified++);
    expect(fake.userData!.nombreCompleto, 'Ada');
    expect(await fake.updateProfile(testUser(nombre: 'Grace')), isTrue);
    expect(fake.userData!.nombreCompleto, 'Grace');
    expect(notified, 1);
  });

  testWidgets('pumpEntryNoSettle monta un widget con animacion infinita', (
    tester,
  ) async {
    await pumpEntryNoSettle(tester, const _ForeverSpinner(), width: 320);
    expect(find.byType(_ForeverSpinner), findsOneWidget);
    // Sin asentar: si alguien cambia pumpEntryNoSettle por pumpEntry,
    // este test se cuelga en vez de fallar, y eso es la senal.
  });
}

class _TwoOverflows extends StatelessWidget {
  const _TwoOverflows();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(
          width: 100,
          child: Row(children: [SizedBox(width: 300, height: 10)]),
        ),
        SizedBox(
          width: 100,
          child: Row(children: [SizedBox(width: 400, height: 10)]),
        ),
      ],
    );
  }
}

class _ForeverSpinner extends StatefulWidget {
  const _ForeverSpinner();
  @override
  State<_ForeverSpinner> createState() => _ForeverSpinnerState();
}

class _ForeverSpinnerState extends State<_ForeverSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(seconds: 2),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _c,
    child: const SizedBox(width: 10, height: 10),
  );
}
