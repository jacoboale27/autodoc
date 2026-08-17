import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/utils/responsive.dart';

void main() {
  Future<T> probeAt<T>(
    WidgetTester tester,
    double width,
    T Function(BuildContext) read,
  ) async {
    late T value;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: Builder(
          builder: (context) {
            value = read(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return value;
  }

  group('los predicados legacy coinciden exactamente con WindowClass', () {
    testWidgets('en los 8 anchos de auditoría', (tester) async {
      for (final width in [
        320.0,
        375.0,
        600.0,
        768.0,
        840.0,
        1024.0,
        1200.0,
        1440.0,
      ]) {
        final expected = AppBreakpoints.fromWidth(width);

        final isMobile = await probeAt(tester, width, Responsive.isMobile);
        final isTablet = await probeAt(tester, width, Responsive.isTablet);
        final isDesktop = await probeAt(tester, width, Responsive.isDesktop);

        expect(
          isMobile,
          expected == WindowClass.compact,
          reason: 'isMobile @$width',
        );
        expect(
          isTablet,
          expected == WindowClass.medium || expected == WindowClass.expanded,
          reason: 'isTablet @$width',
        );
        expect(
          isDesktop,
          expected == WindowClass.large,
          reason: 'isDesktop @$width',
        );

        // Exactamente uno de los tres es verdadero: no hay huecos ni solapes.
        expect(
          [isMobile, isTablet, isDesktop].where((v) => v).length,
          1,
          reason: 'clases no exhaustivas/exclusivas @$width',
        );
      }
    });
  });

  group('los escaladores no cambian de comportamiento', () {
    testWidgets('fontSize devuelve la base en compact y como mucho x1.15', (
      tester,
    ) async {
      expect(
        await probeAt(tester, 375, (c) => Responsive.fontSize(c, 16)),
        16.0,
      );
      final atDesktop = await probeAt(
        tester,
        1440,
        (c) => Responsive.fontSize(c, 16),
      );
      expect(atDesktop, greaterThan(16.0));
      expect(atDesktop, lessThanOrEqualTo(16 * 1.15));
    });
  });
}
