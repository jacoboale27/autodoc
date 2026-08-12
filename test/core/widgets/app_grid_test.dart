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
}
