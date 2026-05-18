import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light {
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
      textTheme: GoogleFonts.interTextTheme(),
      extensions: const <ThemeExtension<dynamic>>[
        AppColors(
          primary: AppPalette.lightPrimary,
          secondary: AppPalette.lightSecondary,
          surface: AppPalette.lightSurface,
          surfaceContainer: AppPalette.lightSurfaceContainer,
          error: AppPalette.lightError,
          warning: AppPalette.lightWarning,
          textPrimary: AppPalette.lightTextPrimary,
          textSecondary: AppPalette.lightTextSecondary,
        ),
      ],
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppPalette.lightPrimary, // Keep same seed for harmony, override primary
        primary: AppPalette.darkPrimary,
        secondary: AppPalette.darkSecondary,
        surface: AppPalette.darkSurface,
        error: AppPalette.darkError,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppPalette.darkSurface,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      extensions: const <ThemeExtension<dynamic>>[
        AppColors(
          primary: AppPalette.darkPrimary,
          secondary: AppPalette.darkSecondary,
          surface: AppPalette.darkSurface,
          surfaceContainer: AppPalette.darkSurfaceContainer,
          error: AppPalette.darkError,
          warning: AppPalette.darkWarning,
          textPrimary: AppPalette.darkTextPrimary,
          textSecondary: AppPalette.darkTextSecondary,
        ),
      ],
    );
  }
}
