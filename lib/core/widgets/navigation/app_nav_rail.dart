import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

/// Navegación principal en `WindowClass.medium` y `WindowClass.expanded`.
///
/// Cubre la franja 600–1199 px, que hasta ahora recibía la barra inferior de
/// teléfono estirada a lo ancho de una tablet. Mover la navegación al lateral
/// devuelve ese ancho al contenido.
///
/// [extended] lo decide el shell: `false` en `medium` (solo iconos, ~80 dp),
/// `true` en `expanded` (icono + etiqueta, ~200 dp).
class AppNavRail extends StatelessWidget {
  final List<AppNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  const AppNavRail({
    super.key,
    this.destinations = AppNavDestinations.owner,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.extended,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      extended: extended,
      backgroundColor: colors.surfaceContainer,
      indicatorColor: colors.primary.withValues(alpha: 0.15),
      // Colapsado no hay etiqueta visible, así que el tooltip de cada destino
      // es la única forma de saber a dónde lleva: obligatorio, no opcional.
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      minWidth: 72,
      minExtendedWidth: 200,
      selectedIconTheme: IconThemeData(color: colors.primary),
      unselectedIconTheme: IconThemeData(color: colors.textSecondary),
      selectedLabelTextStyle: AppTextStyles.labelMedium.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: AppTextStyles.labelMedium.copyWith(
        color: colors.textSecondary,
      ),
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Tooltip(
              message: destination.semanticLabel,
              child: Icon(destination.icon),
            ),
            selectedIcon: Tooltip(
              message: destination.semanticLabel,
              child: Icon(destination.selectedIcon),
            ),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
