import 'package:flutter/widgets.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';

/// Envuelve el contenido de una pantalla con el gutter horizontal de su
/// [WindowClass] y lo acota a un ancho máximo, centrado.
///
/// Resuelve tres reglas de una vez: gutters adaptativos por breakpoint, ancho
/// de contenido predecible por clase de dispositivo, y medida de lectura
/// legible (un párrafo de borde a borde en una tablet es ilegible).
///
/// Decide por `constraints.maxWidth`, no por `MediaQuery`: dentro de un split
/// view el ancho del panel no es el de la ventana.
class AppPageBody extends StatelessWidget {
  final Widget child;

  /// Ancho máximo del contenido. Usa [AppBreakpoints.maxReadingWidth] para
  /// texto corrido y [AppBreakpoints.maxFormWidth] para formularios.
  final double maxWidth;

  const AppPageBody({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = AppBreakpoints.gutter(
          AppBreakpoints.fromWidth(constraints.maxWidth),
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
