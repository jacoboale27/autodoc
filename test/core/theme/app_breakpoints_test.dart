import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';

void main() {
  group('AppBreakpoints.fromWidth', () {
    test('mapea cada frontera a su window class', () {
      expect(AppBreakpoints.fromWidth(320), WindowClass.compact);
      expect(AppBreakpoints.fromWidth(375), WindowClass.compact);
      expect(AppBreakpoints.fromWidth(599.9), WindowClass.compact);
      expect(AppBreakpoints.fromWidth(600), WindowClass.medium);
      expect(AppBreakpoints.fromWidth(768), WindowClass.medium);
      expect(AppBreakpoints.fromWidth(839.9), WindowClass.medium);
      expect(AppBreakpoints.fromWidth(840), WindowClass.expanded);
      expect(AppBreakpoints.fromWidth(1024), WindowClass.expanded);
      expect(AppBreakpoints.fromWidth(1199.9), WindowClass.expanded);
      expect(AppBreakpoints.fromWidth(1200), WindowClass.large);
      expect(AppBreakpoints.fromWidth(1440), WindowClass.large);
    });

    test(
      'los 4 anchos de la checklist de ui-ux-pro-max cubren las 4 clases',
      () {
        final classes = [
          375.0,
          768.0,
          1024.0,
          1440.0,
        ].map(AppBreakpoints.fromWidth).toList();
        expect(classes, WindowClass.values);
      },
    );
  });

  group('AppBreakpoints.gutter', () {
    test('crece monotónicamente con la clase de ventana', () {
      final gutters = WindowClass.values.map(AppBreakpoints.gutter).toList();
      expect(gutters, [16.0, 24.0, 32.0, 40.0]);
      for (var i = 1; i < gutters.length; i++) {
        expect(gutters[i], greaterThan(gutters[i - 1]));
      }
    });
  });

  group('WindowClassX', () {
    test('los helpers de umbral son inclusivos hacia arriba', () {
      expect(WindowClass.compact.isCompact, isTrue);
      expect(WindowClass.medium.isCompact, isFalse);

      expect(WindowClass.compact.isAtLeastMedium, isFalse);
      expect(WindowClass.medium.isAtLeastMedium, isTrue);
      expect(WindowClass.expanded.isAtLeastMedium, isTrue);
      expect(WindowClass.large.isAtLeastMedium, isTrue);

      expect(WindowClass.medium.isAtLeastExpanded, isFalse);
      expect(WindowClass.expanded.isAtLeastExpanded, isTrue);
      expect(WindowClass.large.isAtLeastExpanded, isTrue);

      expect(WindowClass.expanded.isLarge, isFalse);
      expect(WindowClass.large.isLarge, isTrue);
    });
  });

  group('AppBreakpoints.of', () {
    testWidgets('lee el ancho del MediaQuery ambiente', (tester) async {
      late WindowClass observed;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(900, 600)),
          child: Builder(
            builder: (context) {
              observed = AppBreakpoints.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(observed, WindowClass.expanded);
    });
  });
}
