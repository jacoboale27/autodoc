import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/utils/responsive.dart';

/// Superficie de contenido de AutoDoc.
///
/// Si [onTap] es `null` es una superficie **estática**: no anima nada. Mover o
/// elevar algo que no se puede pulsar es una promesa falsa. El feedback de
/// press y el lift de hover solo existen cuando la tarjeta es interactiva.
///
/// A diferencia de [AppButton], el hover aquí **solo** eleva la sombra, sin
/// escalar: una tarjeta es una superficie grande y un 2 % de escala la
/// desalinea visiblemente de sus vecinas en una rejilla. El botón es pequeño y
/// ahí el mismo 2 % se lee como respuesta, no como desalineación.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  /// Descripción de la tarjeta para lector de pantalla. Solo se aplica cuando
  /// [onTap] no es `null`.
  final String? semanticLabel;

  /// Pon `true` cuando la tarjeta pulsable contenga **controles propios**
  /// (un `IconButton` con su propia acción, p. ej.).
  ///
  /// Por defecto una tarjeta pulsable excluye la semántica de sus hijos: es
  /// lo correcto cuando el contenido es solo información, porque así el
  /// lector de pantalla anuncia un único botón con [semanticLabel] en vez de
  /// deletrear cada `Text` de dentro.
  ///
  /// Pero eso también borra a los hijos **interactivos**, y una acción no se
  /// puede plegar en una etiqueta: hay que poder activarla. Con este flag la
  /// tarjeta conserva su propio nodo (etiquetado) y expone a sus hijos como
  /// nodos hermanos alcanzables, en vez de tragárselos.
  ///
  /// No relaja el `assert`: [semanticLabel] sigue siendo obligatorio siempre
  /// que haya [onTap], en los dos modos.
  final bool interactiveChildren;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    this.onTap,
    this.semanticLabel,
    this.interactiveChildren = false,
  }) : assert(
         onTap == null || semanticLabel != null,
         'Una AppCard pulsable necesita semanticLabel: excludeSemantics borra '
         'el texto de los hijos, asi que sin label queda un boton sin nombre. '
         'En el garaje se anunciaban cinco "boton" seguidos, sin decir cual '
         'es cual.',
       );

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  bool get _interactive => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = Responsive.size(context, AppRadius.lg);

    final resting = isDark ? AppShadows.darkSm : AppShadows.lightSm;
    final hovered = isDark ? AppShadows.darkHover : AppShadows.lightHover;

    final surface = AnimatedContainer(
      duration: AppMotion.hover,
      curve: AppMotion.easeOut,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _interactive && _isHovered ? hovered : resting,
        border: Border.all(
          color: colors.outline.withValues(alpha: isDark ? 0.2 : 0.4),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(radius),
          hoverColor: colors.hoverOverlay,
          highlightColor: colors.pressedOverlay,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    if (!_interactive) return surface;

    return Semantics(
      button: true,
      focusable: true,
      label: widget.semanticLabel,
      // Evita que el Text hijo ("Contenido") se concatene al label propio de
      // la tarjeta; se reexponen tap y foco, que quedarían excluidos también.
      //
      // Con [interactiveChildren] se invierte: los hijos conservan su
      // semántica y se publican como nodos explícitos, para que un control
      // propio de la tarjeta (p. ej. el "Hacer Principal" del garaje) siga
      // teniendo nombre y siga siendo activable con lector de pantalla.
      excludeSemantics: !widget.interactiveChildren,
      explicitChildNodes: widget.interactiveChildren,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        // `mounted` antes de cada setState: MouseRegion puede disparar
        // onExit (y el Listener onPointerUp/Cancel) despues de que la
        // tarjeta ya se desmonto -p. ej. al navegar mientras el puntero
        // seguia encima- lo que tumbaba la pantalla con "setState() called
        // after dispose()".
        onEnter: (_) {
          if (mounted) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (mounted) setState(() => _isHovered = false);
        },
        child: Listener(
          onPointerDown: (_) {
            if (mounted) setState(() => _isPressed = true);
          },
          onPointerUp: (_) {
            if (mounted) setState(() => _isPressed = false);
          },
          onPointerCancel: (_) {
            if (mounted) setState(() => _isPressed = false);
          },
          child: AnimatedScale(
            scale: _isPressed ? AppMotion.pressScaleFor(context) : 1.0,
            duration: AppMotion.transformDuration(context, AppMotion.press),
            curve: AppMotion.easeOut,
            child: surface,
          ),
        ),
      ),
    );
  }
}
