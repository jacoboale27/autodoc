import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';

/// Scaffold base de una pantalla de AutoDoc.
///
/// La navegación principal la pone [MainScaffold]; este widget solo aporta el
/// fondo, el gutter opcional y una barra inferior propia de la pantalla (p.ej.
/// una barra de acciones), que solo tiene sentido en `compact`.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;

  /// Barra inferior **propia de la pantalla**. Se oculta fuera de `compact`,
  /// donde la navegación ya vive en el rail o en la barra superior.
  final Widget? bottomNavigationBar;

  final Widget? floatingActionButton;
  final bool useGradient;

  /// Envuelve [body] en [AppPageBody] (gutter por clase de ventana + ancho
  /// máximo centrado). Por defecto `false` para no alterar las pantallas que
  /// aún gestionan su propio padding; cada fase de módulo lo activa al
  /// migrar su pantalla.
  final bool applyGutter;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.useGradient = false,
    this.applyGutter = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isCompact = AppBreakpoints.of(context).isCompact;

    Widget content = applyGutter ? AppPageBody(child: body) : body;

    if (useGradient) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surface, colors.surface.withValues(alpha: 0.95)],
          ),
        ),
        child: content,
      );
    }

    return Scaffold(
      appBar: appBar,
      body: content,
      bottomNavigationBar: isCompact ? bottomNavigationBar : null,
      floatingActionButton: floatingActionButton,
    );
  }
}
