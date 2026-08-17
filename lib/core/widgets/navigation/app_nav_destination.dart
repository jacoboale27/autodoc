import 'package:flutter/material.dart';

/// Un destino de la navegación principal.
///
/// Lo consumen las tres presentaciones (bottom bar en `compact`, rail en
/// `medium`/`expanded`, top bar en `large`) para que no puedan divergir.
@immutable
class AppNavDestination {
  /// Ruta de go_router a la que navega.
  final String route;

  /// Icono en reposo (outline).
  final IconData icon;

  /// Icono activo (filled). Debe diferir de [icon]: el estado activo no puede
  /// depender solo del color.
  final IconData selectedIcon;

  /// Texto visible.
  final String label;

  /// Descripción para lector de pantalla. Más explícita que [label], que está
  /// optimizado para caber.
  final String semanticLabel;

  const AppNavDestination({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.semanticLabel,
  });
}

class AppNavDestinations {
  AppNavDestinations._();

  /// Navegación principal del rol Propietario.
  ///
  /// Exactamente 5 destinos: es el máximo de una bottom nav. Añadir un sexto
  /// exige mover otro a un menú secundario, no ampliar la lista.
  static const List<AppNavDestination> owner = [
    AppNavDestination(
      route: '/dashboard',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_filled,
      label: 'Inicio',
      semanticLabel: 'Inicio, resumen de tus vehículos',
    ),
    AppNavDestination(
      route: '/garage',
      icon: Icons.directions_car_outlined,
      selectedIcon: Icons.directions_car,
      label: 'Garaje',
      semanticLabel: 'Garaje, tus vehículos registrados',
    ),
    AppNavDestination(
      route: '/chat_list',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      label: 'Chat',
      semanticLabel: 'Chat, conversaciones con talleres',
    ),
    AppNavDestination(
      route: '/workshop_directory',
      icon: Icons.build_circle_outlined,
      selectedIcon: Icons.build_circle,
      label: 'Talleres',
      semanticLabel: 'Talleres, directorio de talleres',
    ),
    AppNavDestination(
      route: '/user_profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Perfil',
      semanticLabel: 'Perfil, tu cuenta y ajustes',
    ),
  ];

  /// Índice del destino que corresponde a [location].
  ///
  /// Acepta sub-rutas (`/garage/123` → Garaje) sin confundir prefijos parciales
  /// (`/user_profile_setup` **no** es `/user_profile`). Una ruta desconocida
  /// cae al primer destino.
  static int indexForLocation(
    String location, {
    List<AppNavDestination> destinations = owner,
  }) {
    final path = location.split('?').first;

    for (var i = 0; i < destinations.length; i++) {
      final route = destinations[i].route;
      if (path == route || path.startsWith('$route/')) return i;
    }
    return 0;
  }
}
