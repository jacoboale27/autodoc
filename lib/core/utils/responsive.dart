import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_breakpoints.dart';

/// Utilidades de responsividad para adaptar la UI de AutoDoc
/// a diferentes tamaños de pantalla (móvil, tablet, desktop).
///
/// Uso: `Responsive.fontSize(context, 28)` devuelve 28 en móvil,
/// escalado gradualmente hasta ~39 en desktop.
class Responsive {
  Responsive._();

  // ── Breakpoints ──
  //
  // Conservados solo por compatibilidad con las llamadas existentes. La fuente
  // de verdad es AppBreakpoints; estos valores se derivan de allí para que no
  // puedan divergir.
  static const double mobile = AppBreakpoints.medium;
  static const double tablet = AppBreakpoints.expanded;
  static const double desktop = AppBreakpoints.large;

  // ── Detección de dispositivo (legacy) ──

  @Deprecated(
    'Usa AppBreakpoints.of(context) == WindowClass.compact, o mejor '
    'LayoutBuilder + AppBreakpoints.fromWidth(constraints.maxWidth). '
    'Ver docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md §3.',
  )
  static bool isMobile(BuildContext context) =>
      AppBreakpoints.of(context) == WindowClass.compact;

  @Deprecated(
    'Usa AppBreakpoints.of(context).isAtLeastMedium y .isAtLeastExpanded para '
    'distinguir las dos clases que este predicado mezcla. '
    'Ver docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md §3.',
  )
  static bool isTablet(BuildContext context) {
    final windowClass = AppBreakpoints.of(context);
    return windowClass == WindowClass.medium ||
        windowClass == WindowClass.expanded;
  }

  @Deprecated(
    'Usa AppBreakpoints.of(context).isLarge. '
    'Ver docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md §3.',
  )
  static bool isDesktop(BuildContext context) =>
      AppBreakpoints.of(context) == WindowClass.large;

  // ── Factor de escala global ──
  // 1.0 en móvil (≤600px), sube linealmente hasta 1.15 en ≥1400px
  static double scaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width <= mobile) return 1.0;
    return 1.0 + ((width - mobile) / (1400 - mobile)).clamp(0.0, 1.0) * 0.15;
  }

  // ── Escaladores específicos ──

  /// Escala font sizes. En móvil devuelve [base], en desktop hasta base * 1.15
  static double fontSize(BuildContext context, double base) {
    return (base * scaleFactor(context)).clamp(base, base * 1.15);
  }

  /// Escala paddings/margins. En móvil devuelve [base], en desktop hasta base * 1.2
  static double padding(BuildContext context, double base) {
    return (base * scaleFactor(context)).clamp(base, base * 1.2);
  }

  /// Escala icon sizes. En móvil devuelve [base], en desktop hasta base * 1.15
  static double iconSize(BuildContext context, double base) {
    return (base * scaleFactor(context)).clamp(base, base * 1.15);
  }

  /// Escala dimensiones fijas (avatars, badges, containers).
  /// En móvil devuelve [base], en desktop hasta base * 1.15
  static double size(BuildContext context, double base) {
    return (base * scaleFactor(context)).clamp(base, base * 1.15);
  }

  /// Número de columnas para grids adaptativos.
  @Deprecated('Usa AppGrid, que declara columnas por WindowClass.')
  static int gridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktop) return 3;
    if (width >= mobile) return 2;
    return 1;
  }

  /// Padding horizontal adaptativo para el contenido principal.
  /// En móvil: 24px fijo. En tablet: 4% del ancho. En desktop: 8% del ancho.
  @Deprecated('Usa AppPageBody, que aplica el gutter de AppBreakpoints.')
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktop) return width * 0.08;
    if (width >= mobile) return width * 0.04;
    return 24;
  }

  /// EdgeInsets simétrico horizontal adaptativo.
  static EdgeInsets horizontalEdgeInsets(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: horizontalPadding(context));
  }

  /// Escala un SizedBox height para spacing vertical.
  static double spacing(BuildContext context, double base) {
    return (base * scaleFactor(context)).clamp(base, base * 1.15);
  }

  /// Altura adaptativa para hero images / banners.
  static double heroHeight(BuildContext context, double base) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktop) return base * 1.2;
    if (width >= mobile) return base * 1.1;
    return base;
  }
}
