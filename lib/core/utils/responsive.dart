import 'package:flutter/material.dart';

/// Utilidades de responsividad para adaptar la UI de AutoDoc
/// a diferentes tamaños de pantalla (móvil, tablet, desktop).
///
/// Uso: `Responsive.fontSize(context, 28)` devuelve 28 en móvil,
/// escalado gradualmente hasta ~39 en desktop.
class Responsive {
  Responsive._();

  // ── Breakpoints ──
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  // ── Detección de dispositivo ──
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobile &&
      MediaQuery.of(context).size.width < desktop;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

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
  static int gridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktop) return 3;
    if (width >= mobile) return 2;
    return 1;
  }

  /// Padding horizontal adaptativo para el contenido principal.
  /// En móvil: 24px fijo. En tablet: 4% del ancho. En desktop: 8% del ancho.
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
