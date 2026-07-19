import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_radius.dart';

void main() {
  group('Theme Constants Tests', () {
    test('AppSpacing sm exists', () {
      expect(AppSpacing.sm, 8.0);
    });
    test('AppSpacing md exists', () {
      expect(AppSpacing.md, 12.0);
    });
    test('AppRadius sm exists', () {
      expect(AppRadius.sm, 8.0);
    });
    test('AppRadius md exists', () {
      expect(AppRadius.md, 12.0);
    });
  });
}
