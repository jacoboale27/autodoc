// lib/features/mechanic/presentation/widgets/mechanic_scaffold.dart
import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

/// Shell único del rol taller.
///
/// Sustituye al bloque `MediaQuery.of(context).size.width < 700` +
/// `Row([if (!isMobile) MechanicSidebar(), Expanded(...)])` que estaba
/// copiado en ocho pantallas del módulo, cada una con su propia barra
/// superior de 64 dp y su propio título.
///
/// Implementa la matriz de navegación del rol mecánico fijada en la Fase 2:
///
/// | `WindowClass` | Navegación             |
/// |---------------|------------------------|
/// | `compact`     | `AppBar` + `Drawer`    |
/// | `medium`      | `AppBar` + `Drawer`    |
/// | `expanded`    | `MechanicSidebar` fijo |
/// | `large`       | `MechanicSidebar` fijo |
///
/// El corte está en `expanded` (840) y no en los 700 anteriores porque el
/// sidebar mide 280 dp fijos: a 700 px dejaba 420 px de contenido, menos que
/// un teléfono.
class MechanicScaffold extends StatelessWidget {
  /// Nombre de **esta** pantalla, no del panel. Se usa tal cual en el
  /// `AppBar` de teléfono y en mayúsculas en la barra de escritorio; antes
  /// dos pantallas distintas ponían ambas `'Panel de Taller'` en móvil.
  final String title;

  final Widget body;

  /// Acciones de la barra (tema, idioma, notificaciones). Se pintan en la
  /// barra que corresponda a la clase de ventana, nunca en las dos.
  final List<Widget> actions;

  final Widget? floatingActionButton;

  const MechanicScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final windowClass = AppBreakpoints.of(context);
    final showFixedSidebar = windowClass.isAtLeastExpanded;
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showFixedSidebar
          ? null
          : AppBar(
              backgroundColor: colors.surface,
              elevation: 0,
              iconTheme: IconThemeData(color: colors.primary),
              title: Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              actions: actions,
            ),
      drawer: showFixedSidebar ? null : const Drawer(child: MechanicSidebar()),
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          if (showFixedSidebar) const MechanicSidebar(),
          Expanded(
            child: Column(
              children: [
                if (showFixedSidebar)
                  _MechanicTopBar(title: title, actions: actions),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra superior de escritorio del panel de taller.
///
/// Era un `Container(height: 64, ...)` repetido en seis pantallas con cinco
/// textos distintos y el mismo borde inferior dibujado a mano.
class _MechanicTopBar extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const _MechanicTopBar({required this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(
        horizontal: AppBreakpoints.gutter(AppBreakpoints.of(context)),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outline.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.primary,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
