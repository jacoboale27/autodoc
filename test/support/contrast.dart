import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compone [foreground] (posiblemente translúcido) sobre [background],
/// devolviendo el color opaco resultante.
///
/// Necesario porque tokens como `Colors.white60` tienen alfa 0.6: medir su
/// contraste sin componer primero da un resultado falso.
Color composite(Color foreground, Color background) {
  final alpha = foreground.a;
  return Color.from(
    alpha: 1.0,
    red: foreground.r * alpha + background.r * (1 - alpha),
    green: foreground.g * alpha + background.g * (1 - alpha),
    blue: foreground.b * alpha + background.b * (1 - alpha),
  );
}

double _linearize(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

/// Luminancia relativa según WCAG 2.1.
double relativeLuminance(Color color) =>
    0.2126 * _linearize(color.r) +
    0.7152 * _linearize(color.g) +
    0.0722 * _linearize(color.b);

/// Ratio de contraste WCAG 2.1 entre [foreground] y [background].
///
/// Si [foreground] es translúcido se compone sobre [background] primero.
/// Devuelve un valor entre 1.0 (idénticos) y 21.0 (negro sobre blanco).
double contrastRatio(Color foreground, Color background) {
  final fg = relativeLuminance(composite(foreground, background));
  final bg = relativeLuminance(background);
  final lighter = math.max(fg, bg);
  final darker = math.min(fg, bg);
  return (lighter + 0.05) / (darker + 0.05);
}
