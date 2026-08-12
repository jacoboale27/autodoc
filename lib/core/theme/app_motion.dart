import 'package:flutter/widgets.dart';

/// Lenguaje de movimiento de AutoDoc: fuente única de curvas, duraciones y
/// escalas de interacción.
///
/// Las curvas son variantes "fuertes" de las estándar. Las built-in de Flutter
/// (`Curves.easeOut`, `Curves.easeInOut`) son demasiado suaves y hacen que el
/// movimiento se lea como accidental en vez de intencional.
///
/// No existe ninguna constante `easeIn`: una curva que arranca lenta retrasa el
/// movimiento justo en el instante en que el usuario está mirando, y hace que
/// la interfaz se sienta lenta aunque dure lo mismo.
///
/// Las duraciones "generales" de transición de página siguen viviendo en
/// [AppTransitions]; aquí vive todo lo que responde a una interacción.
class AppMotion {
  AppMotion._();

  // ── Curvas ──

  /// Entradas y respuestas directas a input. Arranca rápido.
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Movimiento o morph de un elemento ya visible en pantalla.
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// Sheets y drawers. Curva de Ionic; da la sensación de iOS.
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);

  // ── Duraciones ──

  static const Duration press = Duration(milliseconds: 160);
  static const Duration hover = Duration(milliseconds: 150);
  static const Duration tooltip = Duration(milliseconds: 150);
  static const Duration dropdown = Duration(milliseconds: 200);
  static const Duration sheetEnter = Duration(milliseconds: 300);

  /// Siempre más corta que [sheetEnter]: al cerrar, el usuario ya decidió;
  /// esperar la animación es fricción pura.
  static const Duration sheetExit = Duration(milliseconds: 200);

  // ── Escalas de interacción ──

  /// Encogimiento al presionar. Confirma que la interfaz "oyó" el toque.
  static const double pressedScale = 0.97;

  /// Lift al pasar el puntero (solo se dispara con puntero real).
  static const double hoverScale = 1.02;

  // ── Stagger ──

  /// Retardo entre elementos consecutivos al entrar una lista.
  static const Duration staggerStep = Duration(milliseconds: 50);

  /// Tope de elementos escalonados: más allá, el último tarda tanto en
  /// aparecer que la lista se siente lenta.
  static const int staggerMaxItems = 8;

  // ── Reduced motion ──

  /// `true` cuando el sistema pide reducir el movimiento.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Duración para animaciones de **transformación** (posición, escala).
  ///
  /// Con reduced motion activo devuelve [Duration.zero]. Las transiciones de
  /// opacidad y color NO deben pasar por aquí: reducir el movimiento significa
  /// menos desplazamiento, no ausencia total de transición — un cambio de
  /// estado instantáneo y sin cross-fade se lee como un glitch.
  static Duration transformDuration(BuildContext context, Duration value) =>
      reduced(context) ? Duration.zero : value;

  /// Escala de press efectiva: 1.0 (sin movimiento) con reduced motion.
  static double pressScaleFor(BuildContext context) =>
      reduced(context) ? 1.0 : pressedScale;

  /// Escala de hover efectiva: 1.0 (sin movimiento) con reduced motion.
  static double hoverScaleFor(BuildContext context) =>
      reduced(context) ? 1.0 : hoverScale;
}
