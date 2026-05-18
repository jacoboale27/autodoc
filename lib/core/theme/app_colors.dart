import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color surfaceContainer;
  final Color error;
  final Color warning;
  final Color textPrimary;
  final Color textSecondary;

  const AppColors({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.surfaceContainer,
    required this.error,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  AppColors copyWith({
    Color? primary,
    Color? secondary,
    Color? surface,
    Color? surfaceContainer,
    Color? error,
    Color? warning,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

extension AppColorsExtension on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

class AppPalette {
  // Light Mode Colors
  static const Color lightPrimary = Color(0xFF522C81);
  static const Color lightSecondary = Color(0xFF81E6D9);
  static const Color lightSurface = Color(0xFFF7F6F8);
  static const Color lightSurfaceContainer = Color(0xFFF2F2F2); // ~95% white
  static const Color lightError = Color(0xFFEF4444);
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark Mode Colors
  static const Color darkPrimary = Color(0xFF81E6D9);
  static const Color darkSecondary = Color(0xFF522C81);
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkSurfaceContainer = Color(0xFF141E36); // ~8% white overlaid on surface
  static const Color darkError = Color(0xFFEF4444);
  static const Color darkWarning = Color(0xFFF59E0B);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white60;
}
