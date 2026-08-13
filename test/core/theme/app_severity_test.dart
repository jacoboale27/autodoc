import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_severity.dart';

const _colors = AppColors(
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

AppSeverityStyle styleFor(MaintenanceStatus status) => AppSeverity.forStatus(
  status,
  _colors,
  optimalLabel: 'Óptimo',
  preventiveLabel: 'Revisión pronta',
  criticalLabel: 'Atención requerida',
);

void main() {
  group('forStatus', () {
    test('cada estado usa su token de marca, nunca un color de Material', () {
      expect(styleFor(MaintenanceStatus.critical).color, _colors.error);
      expect(styleFor(MaintenanceStatus.preventive).color, _colors.warning);
      expect(styleFor(MaintenanceStatus.optimal).color, _colors.secondary);
    });

    test(
      'cada estado tiene un icono distinto: el color no es el único indicador',
      () {
        final icons = MaintenanceStatus.values
            .map((s) => styleFor(s).icon)
            .toSet();
        expect(
          icons.length,
          MaintenanceStatus.values.length,
          reason:
              'dos estados comparten icono: se distinguirían solo por color',
        );
      },
    );

    test('cada estado tiene una etiqueta no vacía', () {
      for (final status in MaintenanceStatus.values) {
        expect(styleFor(status).label, isNotEmpty, reason: '$status');
      }
    });

    test('los colores de los tres estados son distintos entre sí', () {
      final palette = MaintenanceStatus.values
          .map((s) => styleFor(s).color)
          .toSet();
      expect(palette.length, MaintenanceStatus.values.length);
    });
  });

  group('forExpiry', () {
    AppSeverityStyle expiry(int days) => AppSeverity.forExpiry(
      days,
      _colors,
      expiredLabel: 'Vencido',
      soonLabel: 'Vence pronto',
      okLabel: 'Vigente',
    );

    test('vencido usa error', () {
      expect(expiry(-1).color, _colors.error);
      expect(expiry(-100).color, _colors.error);
    });

    test('menos de 30 días usa warning', () {
      expect(expiry(0).color, _colors.warning);
      expect(expiry(29).color, _colors.warning);
    });

    test('30 días o más usa secondary', () {
      expect(expiry(30).color, _colors.secondary);
      expect(expiry(365).color, _colors.secondary);
    });

    test('los tres tramos tienen iconos distintos', () {
      final icons = {expiry(-1).icon, expiry(10).icon, expiry(90).icon};
      expect(icons.length, 3);
    });
  });
}
