import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

/// Navegación principal en `WindowClass.compact`.
///
/// Usa el `NavigationBar` de Material 3 en vez de una `Row` de `GestureDetector`
/// hecha a mano: trae gratis las etiquetas visibles, el indicador de selección,
/// el ripple, el tamaño mínimo de destino y la semántica de accesibilidad.
class AppBottomNav extends StatelessWidget {
  final List<AppNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppBottomNav({
    super.key,
    this.destinations = AppNavDestinations.owner,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: colors.surfaceContainer,
      indicatorColor: colors.primary.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon, color: colors.textSecondary),
            selectedIcon: Icon(destination.selectedIcon, color: colors.primary),
            label: destination.label,
            tooltip: destination.semanticLabel,
          ),
      ],
    );
  }
}

/// Tema de la barra inferior. Se aplica en `AppTheme` para no repetir estilos
/// en cada instancia.
NavigationBarThemeData appBottomNavTheme(AppColors colors) {
  return NavigationBarThemeData(
    height: 72,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return AppTextStyles.labelSmall.copyWith(
        color: selected ? colors.primary : colors.textSecondary,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      );
    }),
  );
}
