import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color surfaceContainer;
  final Color error;
  final Color warning;
  final Color success;
  final Color textPrimary;
  final Color textSecondary;
  final Color onPrimary;
  final Color onSecondary;
  final Color onError;
  final Color surfaceVariant;
  final Color outline;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppColors({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.surfaceContainer,
    required this.error,
    required this.warning,
    required this.success,
    required this.textPrimary,
    required this.textSecondary,
    required this.onPrimary,
    required this.onSecondary,
    required this.onError,
    required this.surfaceVariant,
    required this.outline,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  @override
  AppColors copyWith({
    Color? primary,
    Color? secondary,
    Color? surface,
    Color? surfaceContainer,
    Color? error,
    Color? warning,
    Color? success,
    Color? textPrimary,
    Color? textSecondary,
    Color? onPrimary,
    Color? onSecondary,
    Color? onError,
    Color? surfaceVariant,
    Color? outline,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      onPrimary: onPrimary ?? this.onPrimary,
      onSecondary: onSecondary ?? this.onSecondary,
      onError: onError ?? this.onError,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      outline: outline ?? this.outline,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
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
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(
        shimmerHighlight,
        other.shimmerHighlight,
        t,
      )!,
    );
  }

  /// Overlay derivado de [primary] para estado hover (puntero real).
  Color get hoverOverlay => primary.withValues(alpha: 0.06);

  /// Overlay derivado de [primary] para estado de press.
  Color get pressedOverlay => primary.withValues(alpha: 0.12);
}

extension AppColorsExtension on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

class AppPalette {
  // Light Mode Colors
  static const Color lightPrimary = Color(0xFF522C81);
  static const Color lightSecondary = Color(0xFF81E6D9);
  static const Color lightSurface = Color(0xFFF7F6F8);
  static const Color lightSurfaceContainer = Color(0xFFEEEDF0);
  // Antes: static const Color lightError = Color(0xFFFC8181);
  // 2.27:1 sobre lightSurface — falla el 3:1 de WCAG AA para glifo grande.
  // Un escalón más oscuro en la misma familia de tono (rojo coral cálido,
  // hue 0°): 3.17:1.
  static const Color lightError = Color(0xFFE85D5D);
  // Antes: static const Color lightWarning = Color(0xFFF6AD55);
  // 1.77:1 sobre lightSurface — falla el 3:1 de WCAG AA para glifo grande.
  // Un escalón más oscuro en la misma familia de tono (ámbar/naranja,
  // hue ~33°): 3.27:1.
  static const Color lightWarning = Color(0xFFC17817);
  // Antes: static const Color lightSuccess = Color(0xFF48BB78);
  // 2.25:1 sobre lightSurface — falla el 3:1 de WCAG AA para glifo grande.
  // Un escalón más oscuro en la misma familia de tono (verde): 4.22:1.
  static const Color lightSuccess = Color(0xFF2F855A);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  // Antes: static const Color lightTextSecondary = Color(0xFF64748B);
  // 4.42:1 sobre lightSurface y 4.08:1 sobre lightSurfaceContainer — falla
  // WCAG AA. Un escalón más oscuro en la misma familia de tono: 5.05:1 y
  // 4.67:1 respectivamente.
  static const Color lightTextSecondary = Color(0xFF5B6B80);
  static const Color lightOnPrimary = Colors.white;
  static const Color lightOnSecondary = Color(0xFF0F172A);
  static const Color lightOnError = Color(0xFF0F172A);
  static const Color lightSurfaceVariant = Color(0xFFE2E8F0);
  static const Color lightOutline = Color(0xFFCBD5E1);
  static const Color lightShimmerBase = Color(0xFFE2E8F0);
  static const Color lightShimmerHighlight = Color(0xFFF1F5F9);

  // Dark Mode Colors
  static const Color darkPrimary = Color(0xFF81E6D9);
  static const Color darkSecondary = Color(0xFF522C81);
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkSurfaceContainer = Color(0xFF141E36);
  static const Color darkError = Color(0xFFFC8181);
  static const Color darkWarning = Color(0xFFF6AD55);
  static const Color darkSuccess = Color(0xFF48BB78);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white60;
  static const Color darkOnPrimary = Color(0xFF0F172A);
  static const Color darkOnSecondary = Colors.white;
  static const Color darkOnError = Color(0xFF0F172A);
  static const Color darkSurfaceVariant = Color(0xFF1E293B);
  static const Color darkOutline = Color(0xFF334155);
  static const Color darkShimmerBase = Color(0xFF1E293B);
  static const Color darkShimmerHighlight = Color(0xFF334155);
}
