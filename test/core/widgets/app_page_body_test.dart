import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';

void main() {
  Future<Size> pumpAndMeasure(
    WidgetTester tester,
    double width, {
    double maxWidth = AppBreakpoints.maxContentWidth,
  }) async {
    // El viewport de test por defecto mide 800x600 lógicos; lo ampliamos
    // para que quepan los anchos >800 usados en estos casos (el widget
    // decide por las constraints del SizedBox, no por este tamaño).
    tester.view.physicalSize = Size(width + 200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: AppPageBody(
              maxWidth: maxWidth,
              child: Container(key: const Key('content')),
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byKey(const Key('content')));
  }

  testWidgets('aplica el gutter de cada window class', (tester) async {
    // compact (375): gutter 16 a cada lado.
    expect((await pumpAndMeasure(tester, 375)).width, 375 - 16 * 2);
    // medium (768): gutter 24.
    expect((await pumpAndMeasure(tester, 768)).width, 768 - 24 * 2);
    // expanded (1024): gutter 32.
    expect((await pumpAndMeasure(tester, 1024)).width, 1024 - 32 * 2);
  });

  testWidgets('acota el contenido a maxWidth en pantallas grandes', (
    tester,
  ) async {
    // large (1600): se acota a maxContentWidth (1200) y luego gutter 40.
    final size = await pumpAndMeasure(tester, 1600);
    expect(size.width, AppBreakpoints.maxContentWidth - 40 * 2);
  });

  testWidgets('respeta un maxWidth de lectura más estrecho', (tester) async {
    final size = await pumpAndMeasure(
      tester,
      1440,
      maxWidth: AppBreakpoints.maxReadingWidth,
    );
    expect(size.width, AppBreakpoints.maxReadingWidth - 40 * 2);
  });

  testWidgets('decide por las constraints, no por el MediaQuery', (
    tester,
  ) async {
    // Ventana grande (1400) pero panel estrecho (500): debe usar el gutter
    // compact (16), no el large (40).
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 500,
                child: AppPageBody(child: Container(key: const Key('panel'))),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('panel'))).width, 500 - 16 * 2);
  });
}
