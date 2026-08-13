import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/widgets/app_top_nav_bar.dart';
import 'package:autodoc/core/widgets/navigation/app_bottom_nav.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_rail.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';

/// Shell de la aplicación: elige la presentación de la navegación principal
/// según la [WindowClass] y el rol del usuario.
///
/// | WindowClass | Propietario        | Mecánico          |
/// |-------------|--------------------|-------------------|
/// | compact     | barra inferior     | drawer            |
/// | medium      | rail colapsado     | drawer            |
/// | expanded    | rail extendido     | sidebar fijo      |
/// | large       | barra superior     | sidebar fijo      |
class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final windowClass = AppBreakpoints.of(context);
    // Comparación exacta heredada de la Fase 2. El repo tiene tres criterios
    // de rol distintos (`_normalizeRole` en app_router.dart, `isMechanicRole`
    // en role_utils.dart, y `mechanicFirestoreRoles`), y `rol == 'Taller'`
    // también identifica sub-cuentas de empleado (mechanic_sidebar.dart).
    // Cuál es el correcto es una pregunta de modelo de datos, no de UI: no se
    // toca aquí, ver nota de la Task 1 de la Fase 5 (mechanic) en el PR.
    final isMecanico =
        context.watch<UserProfileProvider>().userData?.rol == 'Mecanico';

    return isMecanico
        ? _MechanicShell(child: child)
        : _OwnerShell(windowClass: windowClass, child: child);
  }
}

class _OwnerShell extends StatelessWidget {
  final WindowClass windowClass;
  final Widget child;

  const _OwnerShell({required this.windowClass, required this.child});

  void _onDestinationSelected(BuildContext context, int index) {
    final destination = AppNavDestinations.owner[index];
    if (GoRouterState.of(context).uri.path != destination.route) {
      context.go(destination.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = AppNavDestinations.indexForLocation(
      GoRouterState.of(context).uri.toString(),
    );

    return switch (windowClass) {
      WindowClass.compact => Scaffold(
        body: child,
        bottomNavigationBar: AppBottomNav(
          currentIndex: currentIndex,
          onDestinationSelected: (index) =>
              _onDestinationSelected(context, index),
        ),
      ),
      WindowClass.medium || WindowClass.expanded => Scaffold(
        body: Row(
          children: [
            AppNavRail(
              currentIndex: currentIndex,
              extended: windowClass == WindowClass.expanded,
              onDestinationSelected: (index) =>
                  _onDestinationSelected(context, index),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      ),
      WindowClass.large => Scaffold(
        body: Column(
          children: [
            const AppTopNavBar(),
            Expanded(child: child),
          ],
        ),
      ),
    };
  }
}

class _MechanicShell extends StatelessWidget {
  final Widget child;

  const _MechanicShell({required this.child});

  /// Títulos de las rutas del `ShellRoute` alcanzables por un mecánico.
  /// Hoy solo `/chat_list`: es la única ruta del shell exenta del redirect
  /// por rol ([app_router.dart:246-250]). Las otras nueve rutas del panel de
  /// taller son `GoRoute` de primer nivel y montan `MechanicScaffold`
  /// directamente.
  static const Map<String, String> _titles = {'/chat_list': 'Mensajes'};

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return MechanicScaffold(
      title: _titles[path] ?? 'AutoDoc Taller',
      body: child,
    );
  }
}
