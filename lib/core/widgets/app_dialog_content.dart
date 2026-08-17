import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_breakpoints.dart';

/// Contenido de un `AlertDialog` que ni desborda en teléfono ni se estira en
/// escritorio.
///
/// Sustituye al patrón `SizedBox(width: 380)` / `SizedBox(width: 420)`, que
/// desborda a 320 px (un `AlertDialog` reserva 40 px de `insetPadding` a cada
/// lado, así que el contenido dispone de 240).
///
/// Son dos capas y el orden importa: el `ConstrainedBox` acota por arriba y
/// el `SizedBox(width: double.maxFinite)` llena lo que quede por debajo. Solo
/// el `SizedBox` haría que el diálogo midiera 1.360 px en una ventana de
/// 1440; solo el `ConstrainedBox` dejaría el ancho al mínimo intrínseco de
/// los campos.
class AppDialogContent extends StatelessWidget {
  final Widget child;

  /// Por defecto la medida de formulario del design system.
  final double maxWidth;

  const AppDialogContent({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxFormWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.maxFinite, child: child),
    );
  }
}
