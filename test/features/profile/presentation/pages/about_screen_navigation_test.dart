import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/profile/presentation/pages/about_screen.dart';

void main() {
  testWidgets(
    'Profile settings "Acerca de AutoDoc" action pushes AboutScreen',
    (tester) async {
      final lightColors = const AppColors(
        primary: AppPalette.lightPrimary,
        secondary: AppPalette.lightSecondary,
        surface: AppPalette.lightSurface,
        surfaceContainer: AppPalette.lightSurfaceContainer,
        error: AppPalette.lightError,
        warning: AppPalette.lightWarning,
        success: AppPalette.lightSuccess,
        textPrimary: AppPalette.lightTextPrimary,
        textSecondary: AppPalette.lightTextSecondary,
        onPrimary: AppPalette.lightOnPrimary,
        onSecondary: AppPalette.lightOnSecondary,
        onError: AppPalette.lightOnError,
        surfaceVariant: AppPalette.lightSurfaceVariant,
        outline: AppPalette.lightOutline,
        shimmerBase: AppPalette.lightShimmerBase,
        shimmerHighlight: AppPalette.lightShimmerHighlight,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: <ThemeExtension<dynamic>>[lightColors]),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
                child: const Text('Acerca de AutoDoc'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Acerca de AutoDoc'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutScreen), findsOneWidget);
    },
  );
}
