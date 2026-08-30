import 'package:flutter/material.dart';
import 'package:autodoc/core/utils/role_utils.dart';
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
    // Mismo criterio que `_normalizeRole` en app_router.dart: ambos delegan ya
    // en `role_utils.dart`. La comparación exacta anterior (`== 'Mecanico'`)
    // dejaba fuera a `'Taller'`, así que el router mandaba esas cuentas al
    // panel de taller mientras este shell les montaba la navegación de
    // propietario.
    final isMecanico = isMechanicRole(
      context.watch<UserProfileProvider>().userData?.rol,
    );

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
            // Mismo defecto que en `WindowClass.large` (ver el comentario de
            // esa rama mas abajo): el `Navigator` anidado de la `ShellRoute`
            // (este `child`), sin su propio limite semantico explicito, se
            // traga el arbol de accesibilidad de su hermano — aqui,
            // `AppNavRail`. Demostrado en rojo con
            // `nav_rail_semantics_test.dart` a 768px y 1024px antes de tocar
            // esta rama.
            Expanded(
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: child,
              ),
            ),
          ],
        ),
      ),
      WindowClass.large => Scaffold(
        body: Column(
          children: [
            // La hipotesis original (y la del brief de esta tarea) era que a
            // `AppTopNavBar` le faltaba un limite semantico explicito.
            // Verificado con un repro minimo de Flutter puro (sin go_router):
            // un `Column` con un hijo etiquetado junto a un `Expanded` que
            // envuelve un `Navigator` sin su propio limite semantico ya
            // pierde el label del hermano, con o sin ese wrap. La causa real
            // es que el `Navigator` anidado de la `ShellRoute` (el `child`
            // de aqui abajo), al no tener su propio limite semantico
            // explicito, absorbe el arbol de accesibilidad de SU HERMANO —
            // sin importar cual sea ese hermano. Se probo explicitamente
            // envolver *solo* este lado (sin tocar `AppTopNavBar`) contra el
            // test de regresion (`top_nav_semantics_test.dart`) y sigue en
            // verde: el wrap de la barra es innecesario, por eso no esta.
            // Sin el wrap de este lado, a 1440 px el arbol de /dashboard
            // tenia 34 nodos y todos eran de contenido: la navegacion
            // principal era inalcanzable con teclado y con lector de
            // pantalla, y los tests E2E tenian que ir por coordenadas.
            const AppTopNavBar(),
            Expanded(
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: child,
              ),
            ),
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
