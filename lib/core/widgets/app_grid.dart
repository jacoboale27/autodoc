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

  /// Alto fijo de cada fila, en vez de [childAspectRatio].
  ///
  /// Observaciones del 2026-09-19 («en computadora las tarjetas del perfil del
  /// carro se ven deformes, todo grande»): con una proporción fija el alto de
  /// la celda crece con su ancho, así que una tarjeta de tres líneas de texto
  /// que a 375 px medía 120 de alto pasaba de 240 en escritorio, casi toda
  /// vacía. Una tarjeta cuyo contenido no crece con el ancho debe usar esto.
  ///
  /// Se escala con el tamaño de texto del sistema: un alto fijo pensado para
  /// el texto al 100 % recortaría el contenido con el texto agrandado.
  final double? mainAxisExtent;

  /// Cada tarjeta mide lo que su contenido, en vez de todas el mismo alto.
  ///
  /// Para tarjetas cuyo contenido cambia de una a otra (alertas con o sin
  /// barra de progreso, servicios con o sin reseña): ni una proporción ni un
  /// alto fijo les sirven, y con `childAspectRatio` la de dos líneas quedaba
  /// en una caja de 400 px. Ignora [childAspectRatio] y [mainAxisExtent].
  final bool sizeToContent;

  const AppGrid({
    super.key,
    required this.children,
    this.compactColumns = 1,
    this.mediumColumns = 2,
    this.expandedColumns = 3,
    this.largeColumns = 4,
    this.spacing = AppSpacing.base,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent,
    this.sizeToContent = false,
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
        final columnas = columnsFor(
          AppBreakpoints.fromWidth(constraints.maxWidth),
        );
        if (sizeToContent) {
          // Wrap con ancho de columna calculado: cada fila toma la altura de
          // sus hijos. Se redondea hacia abajo para que la suma de anchos no
          // supere el disponible por un error de coma flotante y el Wrap
          // parta la fila antes de tiempo.
          final ancho =
              ((constraints.maxWidth - spacing * (columnas - 1)) / columnas)
                  .floorToDouble();
          // SizedBox con el ancho entero: dentro de un `Center` (AppPageBody)
          // el Wrap se encogería a su contenido y una sola tarjeta saldría
          // centrada en vez de en la primera columna.
          return SizedBox(
            width: constraints.maxWidth,
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final child in children)
                  SizedBox(width: ancho, child: child),
              ],
            ),
          );
        }
        final alto = mainAxisExtent;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
            mainAxisExtent: alto == null
                ? null
                : MediaQuery.textScalerOf(context).scale(alto),
          ),
          children: children,
        );
      },
    );
  }
}
