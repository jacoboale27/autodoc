import 'package:flutter/widgets.dart';

/// Clase de ventana según el ancho disponible, alineada a las window size
/// classes de Material 3.
///
/// Es la **única** fuente de verdad de tamaño en AutoDoc. Antes convivían dos
/// escalas contradictorias (`Responsive` con corte en 1200 y
/// `responsive_framework` con corte en 800), lo que hacía que a 900px una
/// pantalla se dibujara como desktop mientras el shell seguía en modo móvil.
enum WindowClass {
  /// < 600 — teléfono en vertical. Navegación inferior, 1 columna.
  compact,

  /// 600–839 — teléfono en horizontal o tablet en vertical. Rail colapsado.
  medium,

  /// 840–1199 — tablet en horizontal o laptop pequeño. Rail extendido.
  expanded,

  /// >= 1200 — desktop. Top nav o sidebar, contenido acotado y centrado.
  large,
}

class AppBreakpoints {
  AppBreakpoints._();

  // ── Cortes (ancho lógico en dp) ──
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;

  // ── Anchos máximos de contenido ──

  /// Ancho máximo del contenido general en pantallas grandes.
  static const double maxContentWidth = 1200;

  /// Ancho máximo para texto corrido (regla de "readable text measure":
  /// un párrafo de borde a borde en una tablet es ilegible).
  static const double maxReadingWidth = 720;

  /// Ancho máximo para formularios centrados.
  static const double maxFormWidth = 560;

  /// Clase de ventana para un ancho dado.
  ///
  /// Toma un `double` en vez de un `BuildContext` para poder alimentarse desde
  /// `LayoutBuilder`: dentro de un split view el ancho del panel no es el de la
  /// pantalla, y decidir con `MediaQuery` daría el layout equivocado.
  static WindowClass fromWidth(double width) {
    if (width >= large) return WindowClass.large;
    if (width >= expanded) return WindowClass.expanded;
    if (width >= medium) return WindowClass.medium;
    return WindowClass.compact;
  }

  /// Clase de ventana del `MediaQuery` ambiente.
  ///
  /// Úsalo solo para decisiones a nivel de pantalla completa (shell,
  /// navegación). Para contenido dentro de un panel usa
  /// `LayoutBuilder` + [fromWidth].
  static WindowClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  /// Padding horizontal del contenido para cada clase de ventana.
  static double gutter(WindowClass windowClass) => switch (windowClass) {
    WindowClass.compact => 16,
    WindowClass.medium => 24,
    WindowClass.expanded => 32,
    WindowClass.large => 40,
  };
}

extension WindowClassX on WindowClass {
  bool get isCompact => this == WindowClass.compact;
  bool get isLarge => this == WindowClass.large;
  bool get isAtLeastMedium => index >= WindowClass.medium.index;
  bool get isAtLeastExpanded => index >= WindowClass.expanded.index;
}
