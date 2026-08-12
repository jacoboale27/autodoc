import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_spacing.dart';

/// Rejilla cuyo número de columnas se declara por [WindowClass].
///
/// Sustituye al patrón `crossAxisCount: isDesktop ? 4 : 2`, que salta de golpe
/// y deja sin tratamiento propio toda la franja 600–1199 px.
///
/// Decide por `constraints.maxWidth`, no por `MediaQuery`: en un panel de
/// 900 px dentro de una ventana de 1300 px deben salir las columnas de 900.
class AppGrid extends StatelessWidget {
  final List<Widget> children;
  final int compactColumns;
  final int mediumColumns;
  final int expandedColumns;
  final int largeColumns;
  final double spacing;
  final double childAspectRatio;

  const AppGrid({
    super.key,
    required this.children,
    this.compactColumns = 1,
    this.mediumColumns = 2,
    this.expandedColumns = 3,
    this.largeColumns = 4,
    this.spacing = AppSpacing.base,
    this.childAspectRatio = 1.0,
  });

  /// Columnas declaradas para [windowClass]. Público para poder testearlo sin
  /// montar el widget, y para que una pantalla pueda consultarlo al calcular
  /// alturas.
  int columnsFor(WindowClass windowClass) => switch (windowClass) {
    WindowClass.compact => compactColumns,
    WindowClass.medium => mediumColumns,
    WindowClass.expanded => expandedColumns,
    WindowClass.large => largeColumns,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: columnsFor(
            AppBreakpoints.fromWidth(constraints.maxWidth),
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
          children: children,
        );
      },
    );
  }
}
