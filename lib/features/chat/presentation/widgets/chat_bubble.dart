import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';

/// Burbuja de un mensaje del chat.
///
/// Es la única pieza que sabe qué significa `isMe` visualmente: alineación,
/// forma de la cola y color de fondo. **Ningún hijo debe volver a consultar
/// `isMe` para elegir colores de contenido** — ver §0.1 del plan de la Fase 6:
/// las tarjetas que lo hacían acababan pintando blanco sobre blanco porque
/// dibujaban su propia superficie opaca encima de la burbuja.
///
/// No anima: aparece una sola vez, dentro de una lista con `reverse: true`,
/// y animarla al entrar produce saltos al hacer scroll rápido (ver
/// `emil-design-eng`: sin propósito claro de animación, no se anima).
class ChatBubble extends StatelessWidget {
  /// Verdadero si el mensaje lo envía el usuario actual.
  final bool isMe;

  final Widget child;

  /// Mensaje borrado: se atenúa el fondo y se desactiva el acuse.
  final bool isDeleted;

  /// Fila inferior opcional (acuse de recibo, hora). Se alinea a la derecha.
  final Widget? footer;

  /// Etiqueta para lector de pantalla. Debe decir **quién** envía el mensaje:
  /// sin ella, la lista se lee como una sucesión de textos sin autor.
  ///
  /// **Ojo**: si además se pasa `footer` (p. ej. acuse de recibo), su
  /// semántica queda oculta por `excludeSemantics: true` más abajo — un
  /// consumidor que necesite anunciar el estado del footer debe construir
  /// un label combinado, no confiar en este wrapper.
  final String? semanticLabel;

  final EdgeInsetsGeometry? padding;

  const ChatBubble({
    super.key,
    required this.isMe,
    required this.child,
    this.isDeleted = false,
    this.footer,
    this.semanticLabel,
    this.padding,
  });

  /// Fracción del ancho disponible que ocupa como máximo una burbuja.
  /// 0.8 deja un margen visible en el lado contrario, que es lo que hace
  /// legible de un vistazo quién habla sin depender solo del color.
  static const double _fraccion = 0.8;

  /// Ancho máximo de la burbuja dado el ancho disponible y la clase de ventana.
  ///
  /// Público y estático a propósito: permite verificar la regla sin montar el
  /// árbol, y permite que `chat_screen` calcule el mismo valor para la lista.
  static double maxWidthFor(double availableWidth, WindowClass windowClass) {
    // Desde `expanded` el límite deja de ser el 80 % de la pantalla y pasa a
    // ser la legibilidad: una línea de 1100 px son ~200 caracteres, muy por
    // encima del rango de 45–75 que recomienda `ui-ux-pro-max`. Por debajo de
    // ese ancho de lectura, el tope es simplemente el ancho disponible: una
    // ventana estrecha en clase large (redimensionada a mano) no debe
    // producir una burbuja más angosta que el 80 % arbitrario de una clase
    // que ya no aplica esa regla.
    if (windowClass.isAtLeastExpanded) {
      return availableWidth < AppBreakpoints.maxReadingWidth
          ? availableWidth
          : AppBreakpoints.maxReadingWidth;
    }
    // Nunca más ancha que su contenedor, aunque en este rango el 80 % del
    // disponible ya nunca lo supera.
    final proporcional = availableWidth * _fraccion;
    return proporcional < availableWidth ? proporcional : availableWidth;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final windowClass = AppBreakpoints.of(context);

    final fondo = isMe
        ? (isDeleted
              ? colors.textSecondary.withValues(alpha: 0.5)
              : colors.primary)
        : colors.surfaceContainer;

    final burbuja = LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = maxWidthFor(constraints.maxWidth, windowClass);
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            key: const ValueKey('chat-bubble-surface'),
            margin: const EdgeInsets.only(bottom: 12, top: 2),
            padding:
                padding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                // La cola va del lado del emisor: sin esquina redondeada
                // abajo-derecha si el mensaje es propio.
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                child,
                if (footer != null && !isDeleted) ...[
                  const SizedBox(height: 4),
                  footer!,
                ],
              ],
            ),
          ),
        );
      },
    );

    if (semanticLabel == null) return burbuja;
    return Semantics(
      label: semanticLabel,
      container: true,
      // Sin esto el lector de pantalla concatena el label con el semántico
      // del contenido (p. ej. "Mensaje de Taller Escobar\nHola"): el label
      // ya identifica al emisor, así que sustituye el subárbol en vez de
      // fundirse con él.
      excludeSemantics: true,
      child: burbuja,
    );
  }
}
