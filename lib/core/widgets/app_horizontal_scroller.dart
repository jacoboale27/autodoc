import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';

/// `ScrollBehavior` que acepta arrastre con raton y trackpad, no solo con dedo.
///
/// `ScrollBehavior.dragDevices` excluye `PointerDeviceKind.mouse` por defecto
/// (arrastrar con el cursor se considera un gesto de seleccion, no de scroll),
/// asi que en desktop una fila horizontal no se puede mover ni arrastrando.
class _ArrastreConPuntero extends MaterialScrollBehavior {
  const _ArrastreConPuntero();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

/// Fila con scroll horizontal y flechas de desplazamiento en pantallas anchas.
///
/// En desktop una `SingleChildScrollView` horizontal a secas es una trampa: el
/// contenido se ve cortado y **no hay forma de llegar a el**. Se juntan tres
/// cosas:
///
/// 1. La rueda del raton emite delta vertical, y `Scrollable` solo consume la
///    componente del eje que coincide con su direccion: para un scroll
///    horizontal lee `scrollDelta.dx`, que en una rueda normal es siempre 0.
/// 2. El arrastre con raton viene desactivado (ver [_ArrastreConPuntero]).
/// 3. `MaterialScrollBehavior.buildScrollbar` devuelve el hijo sin tocar en el
///    eje horizontal, asi que tampoco hay barra que arrastrar.
///
/// Con un dedo las tres desaparecen, y por eso el problema solo se ve en
/// desktop. Este widget anade las tres piezas que faltan.
class AppHorizontalScroller extends StatefulWidget {
  /// Elementos de la fila, en orden.
  final List<Widget> children;

  /// Separacion horizontal entre elementos.
  final double spacing;

  /// Padding interno del area desplazable.
  final EdgeInsetsGeometry padding;

  /// Cuanto avanza una pulsacion de flecha. Por defecto, el 80 % del ancho
  /// visible: deja a la vista el ultimo elemento de la "pagina" anterior, que
  /// es lo que evita perder el hilo al desplazarse.
  final double? scrollStep;

  /// Que hay dentro, para el tooltip de las flechas ("Ver mas alertas").
  final String? semanticLabel;

  const AppHorizontalScroller({
    super.key,
    required this.children,
    this.spacing = AppSpacing.base,
    this.padding = EdgeInsets.zero,
    this.scrollStep,
    this.semanticLabel,
  });

  @override
  State<AppHorizontalScroller> createState() => _AppHorizontalScrollerState();
}

class _AppHorizontalScrollerState extends State<AppHorizontalScroller> {
  /// Margen para no encender una flecha por un resto de sub-pixel al final del
  /// recorrido.
  static const double _tolerancia = 1.0;

  final ScrollController _controller = ScrollController();
  bool _hayIzquierda = false;
  bool _hayDerecha = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_alDesplazar);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _alDesplazar() {
    if (_controller.hasClients) _sincronizarFlechas(_controller.position);
  }

  /// Enciende o apaga cada flecha segun lo que quede por recorrer.
  void _sincronizarFlechas(ScrollMetrics metrics) {
    final izquierda = metrics.pixels > metrics.minScrollExtent + _tolerancia;
    final derecha = metrics.pixels < metrics.maxScrollExtent - _tolerancia;
    if (izquierda == _hayIzquierda && derecha == _hayDerecha) return;

    // Las metricas tambien cambian *durante* el layout —cuando llegan alertas
    // nuevas y el contenido crece—, y un setState en esa fase lanza
    // "setState() called during build". Diferirlo un frame no se nota: las
    // flechas solo cambian cuando el booleano se invierte, no en cada pixel.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _hayIzquierda = izquierda;
        _hayDerecha = derecha;
      });
    });
  }

  void _desplazar(int direccion) {
    if (!_controller.hasClients) return;
    final posicion = _controller.position;
    final paso = widget.scrollStep ?? posicion.viewportDimension * 0.8;
    _controller.animateTo(
      (posicion.pixels + paso * direccion).clamp(
        posicion.minScrollExtent,
        posicion.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  List<Widget> _conSeparadores() {
    final resultado = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      if (i > 0) resultado.add(SizedBox(width: widget.spacing));
      resultado.add(widget.children[i]);
    }
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final fila = NotificationListener<ScrollMetricsNotification>(
      // El listener del controller cubre el desplazamiento; esta notificacion
      // cubre el otro caso, que es cuando cambian las medidas sin que nadie
      // haya hecho scroll (se anade una alerta, se redimensiona la ventana).
      onNotification: (aviso) {
        _sincronizarFlechas(aviso.metrics);
        return false;
      },
      child: ScrollConfiguration(
        behavior: const _ArrastreConPuntero(),
        child: Scrollbar(
          controller: _controller,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            child: Row(children: _conSeparadores()),
          ),
        ),
      ),
    );

    // En compact y medium hay dedo: las flechas sobrarian y taparian contenido
    // justo en la clase de ventana donde menos ancho sobra.
    if (!AppBreakpoints.of(context).isAtLeastExpanded) return fila;

    final que = widget.semanticLabel ?? 'contenido';
    return Stack(
      children: [
        fila,
        if (_hayIzquierda)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _Flecha(
              key: const ValueKey('horizontal-scroller-flecha-izquierda'),
              icono: Icons.chevron_left,
              tooltip: 'Ver $que anterior',
              colors: colors,
              onPressed: () => _desplazar(-1),
            ),
          ),
        if (_hayDerecha)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _Flecha(
              key: const ValueKey('horizontal-scroller-flecha-derecha'),
              icono: Icons.chevron_right,
              tooltip: 'Ver mas $que',
              colors: colors,
              onPressed: () => _desplazar(1),
            ),
          ),
      ],
    );
  }
}

class _Flecha extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final AppColors colors;
  final VoidCallback onPressed;

  const _Flecha({
    super.key,
    required this.icono,
    required this.tooltip,
    required this.colors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        // Va encima de las tarjetas, asi que necesita fondo propio y una
        // sombra que lo despegue: un icono suelto sobre una tarjeta clara se
        // pierde.
        color: colors.surface,
        shape: CircleBorder(
          side: BorderSide(color: colors.outline.withValues(alpha: 0.4)),
        ),
        elevation: 3,
        shadowColor: colors.textPrimary.withValues(alpha: 0.3),
        child: IconButton(
          icon: Icon(icono, color: colors.textPrimary),
          iconSize: 20,
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
