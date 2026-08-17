import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_severity.dart';
import 'package:autodoc/core/theme/app_theme.dart';

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
  // `AppTheme.light` (usado por el nuevo test de `forAlertPriority`) resuelve
  // `AppTextStyles.*`, que llama a `GoogleFonts.inter(...)`: sin el binding
  // inicializado, `google_fonts` intenta tocar `ServicesBinding.instance`
  // para cargar la fuente y lanza antes de que el test corra. Mismo patrón
  // que el resto de la suite (`theme_test.dart`, etc.) cuando un test toca
  // `AppTheme.light`/`.dark` fuera de un `testWidgets`.
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('AppSeverity.forReservaEstado', () {
    // Usa `_colors` (el mismo const de arriba) en vez de
    // `AppTheme.light.extension<AppColors>()!`: ambos resuelven a los
    // mismos valores de `AppPalette.light*` (ver `AppTheme.light`), pero
    // `AppTheme.light` reconstruye el `TextTheme` completo vía
    // `google_fonts` en cada evaluación. Con tres `test()` planos llamando a
    // eso, el fetch de red (bloqueado por `TestWidgetsFlutterBinding`) deja
    // un `Future` sin awaitar cuyo error termina atribuido al siguiente test
    // en ejecutarse — un `test()` plano, a diferencia de `testWidgets()`, no
    // sincroniza pendientes antes de continuar. `forStatus`/`forExpiry` ya
    // evitan esto mismo usando `_colors` en vez de `AppTheme.light`.
    AppSeverityStyle estilo(String estado) => AppSeverity.forReservaEstado(
      estado,
      _colors,
      pendienteLabel: 'Pendiente',
      confirmadaLabel: 'Confirmada',
      rechazadaLabel: 'Rechazada',
      cotizadaLabel: 'Cotización Enviada',
    );

    test('mapea los cuatro estados conocidos a color, icono y etiqueta', () {
      expect(estilo('confirmada').color, _colors.success);
      expect(estilo('rechazada').color, _colors.error);
      expect(estilo('cotizada').color, _colors.primary);
      expect(estilo('pendiente').color, _colors.warning);
    });

    test(
      'cada estado tiene un icono distinto: el color no es el único canal',
      () {
        final iconos = [
          'pendiente',
          'confirmada',
          'rechazada',
          'cotizada',
        ].map((e) => estilo(e).icon).toSet();
        expect(iconos.length, 4);
      },
    );

    test('un estado desconocido cae en pendiente y no lanza', () {
      // El campo `estado` viene de Firestore como String libre; un valor
      // nuevo introducido por una Cloud Function no debe romper la pantalla.
      expect(estilo('estado_futuro_desconocido').label, 'Pendiente');
    });
  });

  test('forAlertPriority da icono distinto por prioridad, no solo color', () {
    final colors = AppTheme.light.extension<AppColors>()!;

    final alta = AppSeverity.forAlertPriority(
      AlertPriority.high,
      colors,
      altaLabel: 'Crítica',
      mediaLabel: 'Media',
      bajaLabel: 'Informativa',
    );
    final media = AppSeverity.forAlertPriority(
      AlertPriority.medium,
      colors,
      altaLabel: 'Crítica',
      mediaLabel: 'Media',
      bajaLabel: 'Informativa',
    );

    expect(alta.color, colors.error);
    expect(media.color, colors.warning);
    expect(
      alta.icon,
      isNot(media.icon),
      reason: 'con protanopia el color no distingue: la forma sí',
    );
  });
}
