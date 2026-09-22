import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/widgets/app_grid.dart';

void main() {
  test('columnsFor devuelve la columna declarada para cada window class', () {
    const grid = AppGrid(
      compactColumns: 1,
      mediumColumns: 2,
      expandedColumns: 3,
      largeColumns: 4,
      children: [],
    );

    expect(grid.columnsFor(WindowClass.compact), 1);
    expect(grid.columnsFor(WindowClass.medium), 2);
    expect(grid.columnsFor(WindowClass.expanded), 3);
    expect(grid.columnsFor(WindowClass.large), 4);
  });

  Future<int> renderedColumns(WidgetTester tester, double width) async {
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
            child: AppGrid(
              children: List.generate(
                8,
                (i) => Container(key: ValueKey('cell$i')),
              ),
            ),
          ),
        ),
      ),
    );
    final delegate =
        tester.widget<GridView>(find.byType(GridView)).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    return delegate.crossAxisCount;
  }

  testWidgets('cambia el número de columnas al cruzar cada corte', (
    tester,
  ) async {
    expect(await renderedColumns(tester, 375), 1);
    expect(await renderedColumns(tester, 768), 2);
    expect(await renderedColumns(tester, 1024), 3);
    expect(await renderedColumns(tester, 1440), 4);
  });

  testWidgets('no desborda a 320px con 8 celdas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: AppGrid(
                children: List.generate(8, (i) => Text('celda $i')),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  // Observaciones del 2026-09-19: «en computadora las tarjetas se ven
  // deformes, todo grande». Con `childAspectRatio` el alto de la celda crece
  // con su ancho.
  Future<void> montar(WidgetTester tester, double ancho, AppGrid grid) async {
    tester.view.physicalSize = Size(ancho + 200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: ancho, child: grid),
          ),
        ),
      ),
    );
  }

  testWidgets('mainAxisExtent fija el alto de la fila a cualquier ancho', (
    tester,
  ) async {
    AppGrid grid() => AppGrid(
      compactColumns: 2,
      mediumColumns: 2,
      expandedColumns: 2,
      largeColumns: 2,
      mainAxisExtent: 72,
      children: [for (var i = 0; i < 4; i++) Container(key: ValueKey('c$i'))],
    );
    for (final ancho in [360.0, 1400.0]) {
      await montar(tester, ancho, grid());
      expect(tester.getSize(find.byKey(const ValueKey('c0'))).height, 72);
    }
  });

  testWidgets('mainAxisExtent crece con el texto agrandado del sistema', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await montar(
      tester,
      400,
      AppGrid(
        compactColumns: 2,
        mainAxisExtent: 72,
        children: [Container(key: const ValueKey('c0'))],
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('c0'))).height, 144);
  });

  testWidgets('sizeToContent: cada celda mide lo que su contenido', (
    tester,
  ) async {
    await montar(
      tester,
      1000,
      const AppGrid(
        compactColumns: 2,
        mediumColumns: 2,
        expandedColumns: 2,
        largeColumns: 2,
        spacing: 10,
        sizeToContent: true,
        children: [
          SizedBox(key: ValueKey('baja'), height: 40),
          SizedBox(key: ValueKey('alta'), height: 120),
          SizedBox(key: ValueKey('sola'), height: 40),
        ],
      ),
    );
    final baja = tester.getRect(find.byKey(const ValueKey('baja')));
    final alta = tester.getRect(find.byKey(const ValueKey('alta')));
    final sola = tester.getRect(find.byKey(const ValueKey('sola')));
    expect(baja.height, 40, reason: 'no se estira al alto de su vecina');
    expect(alta.height, 120);
    expect(baja.width, 495, reason: 'la mitad de 1000 menos el espacio');
    expect(alta.left, greaterThan(baja.right), reason: 'dos columnas');
    expect(
      sola.left,
      baja.left,
      reason: 'la celda suelta va a la primera columna, no centrada',
    );
    expect(sola.top, alta.bottom + 10);
  });
}
