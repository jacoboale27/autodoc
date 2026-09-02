// test/core/widgets/app_image_viewer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/app_image_viewer.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// `AppImageViewer` está pensado para empujarse con `Navigator.push` (así lo
/// va a usar tanto la bandeja del admin como, más adelante, la pantalla del
/// taller), así que el montaje reproduce ese caso: una pantalla con un botón
/// que abre el visor, no el visor como `home` directo.
Future<void> _pumpConBotonParaAbrir(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppImageViewer(
                    imageUrl: 'https://example.com/nit.jpg',
                    semanticLabel: 'NIT del taller',
                  ),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _abrirVisor(WidgetTester tester) async {
  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('se monta con una URL y muestra un InteractiveViewer', (
    tester,
  ) async {
    await _pumpConBotonParaAbrir(tester);

    expect(find.byType(InteractiveViewer), findsNothing);

    await _abrirVisor(tester);

    expect(find.byType(AppImageViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('el botón de cierre saca el InteractiveViewer del árbol', (
    tester,
  ) async {
    await _pumpConBotonParaAbrir(tester);
    await _abrirVisor(tester);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
  });
}
