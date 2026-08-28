import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';

import '../../support/contrast.dart';

const double kAaBody = 4.5;
const double kAaLarge = 3.0;

void main() {
  group('el helper de contraste está calibrado', () {
    test('negro sobre blanco da 21:1 y un color contra sí mismo da 1:1', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.01));
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1.0, 0.001));
    });
  });

  group('light mode', () {
    test('el texto primario pasa AA en ambas superficies', () {
      expect(
        contrastRatio(AppPalette.lightTextPrimary, AppPalette.lightSurface),
        greaterThanOrEqualTo(kAaBody),
      );
      expect(
        contrastRatio(
          AppPalette.lightTextPrimary,
          AppPalette.lightSurfaceContainer,
        ),
        greaterThanOrEqualTo(kAaBody),
      );
    });

    test('el texto secundario pasa AA en ambas superficies', () {
      expect(
        contrastRatio(AppPalette.lightTextSecondary, AppPalette.lightSurface),
        greaterThanOrEqualTo(kAaBody),
      );
      expect(
        contrastRatio(
          AppPalette.lightTextSecondary,
          AppPalette.lightSurfaceContainer,
        ),
        greaterThanOrEqualTo(kAaBody),
      );
    });

    test('onPrimary sobre primary pasa AA', () {
      expect(
        contrastRatio(AppPalette.lightOnPrimary, AppPalette.lightPrimary),
        greaterThanOrEqualTo(kAaBody),
      );
    });

    test('el outline es visible sobre la superficie (3:1 de glifo grande)', () {
      expect(
        contrastRatio(AppPalette.lightOutline, AppPalette.lightSurface),
        greaterThanOrEqualTo(1.3),
      );
    });
  });

  group('dark mode', () {
    test('el texto primario pasa AA en ambas superficies', () {
      expect(
        contrastRatio(AppPalette.darkTextPrimary, AppPalette.darkSurface),
        greaterThanOrEqualTo(kAaBody),
      );
      expect(
        contrastRatio(
          AppPalette.darkTextPrimary,
          AppPalette.darkSurfaceContainer,
        ),
        greaterThanOrEqualTo(kAaBody),
      );
    });

    test('el texto secundario pasa AA en ambas superficies', () {
      expect(
        contrastRatio(AppPalette.darkTextSecondary, AppPalette.darkSurface),
        greaterThanOrEqualTo(kAaBody),
      );
      expect(
        contrastRatio(
          AppPalette.darkTextSecondary,
          AppPalette.darkSurfaceContainer,
        ),
        greaterThanOrEqualTo(kAaBody),
      );
    });

    test('onPrimary sobre primary pasa AA', () {
      expect(
        contrastRatio(AppPalette.darkOnPrimary, AppPalette.darkPrimary),
        greaterThanOrEqualTo(kAaBody),
      );
    });
  });

  group('colores semánticos de estado', () {
    test('error, warning y success son distinguibles como glifo grande', () {
      for (final pair in [
        (AppPalette.lightError, AppPalette.lightSurface),
        (AppPalette.lightWarning, AppPalette.lightSurface),
        (AppPalette.lightSuccess, AppPalette.lightSurface),
        (AppPalette.darkError, AppPalette.darkSurface),
        (AppPalette.darkWarning, AppPalette.darkSurface),
        (AppPalette.darkSuccess, AppPalette.darkSurface),
      ]) {
        expect(
          contrastRatio(pair.$1, pair.$2),
          greaterThanOrEqualTo(kAaLarge),
          reason: 'el par ${pair.$1} sobre ${pair.$2} no llega a 3:1',
        );
      }
    });
  });

  group('overlays derivados', () {
    const colors = AppColors(
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

    test('derivan de primary y el de press es más fuerte que el de hover', () {
      expect(colors.hoverOverlay.a, closeTo(0.06, 0.001));
      expect(colors.pressedOverlay.a, closeTo(0.12, 0.001));
      expect(colors.pressedOverlay.a, greaterThan(colors.hoverOverlay.a));
      expect(colors.hoverOverlay.r, colors.primary.r);
      expect(colors.hoverOverlay.g, colors.primary.g);
      expect(colors.hoverOverlay.b, colors.primary.b);
    });
  });
}
