import 'package:flutter/material.dart';
import 'package:autodoc/core/utils/responsive.dart';

/// Un contenedor responsivo que aplica padding horizontal adaptativo.
/// En móvil no agrega padding extra, en desktop agrega márgenes
/// laterales proporcionales para que el contenido no se estire al 100%.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;

  const ResponsiveContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) {
      return child;
    }

    return Padding(
      padding: Responsive.horizontalEdgeInsets(context),
      child: child,
    );
  }
}
