import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_radius.dart';
import '../widgets/navigation/app_bottom_nav.dart';

class AppTheme {
  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      displayMedium: AppTextStyles.displayMedium,
      displaySmall: AppTextStyles.displaySmall,
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      headlineSmall: AppTextStyles.headlineSmall,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      titleSmall: AppTextStyles.titleSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
      labelMedium: AppTextStyles.labelMedium,
      labelSmall: AppTextStyles.labelSmall,
    );
  }

  static ThemeData get light {
    final textTheme = _buildTextTheme();
    const appColors = AppColors(
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
      surfaceVariant: AppPalette.lightSurfaceVariant,
      outline: AppPalette.lightOutline,
      shimmerBase: AppPalette.lightShimmerBase,
      shimmerHighlight: AppPalette.lightShimmerHighlight,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppPalette.lightPrimary,
        primary: AppPalette.lightPrimary,
        secondary: AppPalette.lightSecondary,
        surface: AppPalette.lightSurface,
        error: AppPalette.lightError,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppPalette.lightSurface,
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: AppPalette.lightSurfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppPalette.lightOutline, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        elevation: 8,
        actionTextColor: AppPalette.lightPrimary,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      ),
      navigationBarTheme: appBottomNavTheme(appColors),
      extensions: <ThemeExtension<dynamic>>[appColors],
    );
  }

  static ThemeData get dark {
    final textTheme = _buildTextTheme().apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );
    const appColors = AppColors(
      primary: AppPalette.darkPrimary,
      secondary: AppPalette.darkSecondary,
      surface: AppPalette.darkSurface,
      surfaceContainer: AppPalette.darkSurfaceContainer,
      error: AppPalette.darkError,
      warning: AppPalette.darkWarning,
      success: AppPalette.darkSuccess,
      textPrimary: AppPalette.darkTextPrimary,
      textSecondary: AppPalette.darkTextSecondary,
      onPrimary: AppPalette.darkOnPrimary,
      onSecondary: AppPalette.darkOnSecondary,
      surfaceVariant: AppPalette.darkSurfaceVariant,
      outline: AppPalette.darkOutline,
      shimmerBase: AppPalette.darkShimmerBase,
      shimmerHighlight: AppPalette.darkShimmerHighlight,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppPalette
            .lightPrimary, // Keep same seed for harmony, override primary
        primary: AppPalette.darkPrimary,
        secondary: AppPalette.darkSecondary,
        surface: AppPalette.darkSurface,
        error: AppPalette.darkError,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppPalette.darkSurface,
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: AppPalette.darkSurfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppPalette.darkOutline, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF334155),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        elevation: 8,
        actionTextColor: AppPalette.darkPrimary,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      ),
      navigationBarTheme: appBottomNavTheme(appColors),
      extensions: <ThemeExtension<dynamic>>[appColors],
    );
  }
}
