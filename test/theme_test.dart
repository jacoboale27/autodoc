import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('AppTheme.dark is properly defined and does not crash', () {
    final darkTheme = AppTheme.dark;
    expect(darkTheme.brightness, Brightness.dark);
    expect(darkTheme.scaffoldBackgroundColor, isNotNull);
    expect(darkTheme.colorScheme.brightness, Brightness.dark);
  });
}
