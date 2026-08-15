import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

/// Carcasa común de las tarjetas enriquecidas del chat (cotización, reserva,
/// reseña, historial).
///
/// Dos decisiones que la separan de lo que había:
///
/// 1. **No tiene ancho fijo.** Las cuatro tarjetas usaban 260/280/300 px
///    literales, que desbordan a 320 px de ventana y no crecen nunca. Aquí el
///    ancho lo pone la burbuja (`ChatBubble` ya lo acota).
/// 2. **Sus colores no dependen de `isMe`.** La tarjeta pinta su propia
///    superficie opaca, así que el contenido va sobre *esa* superficie, no
///    sobre la burbuja. Mezclar las dos cosas es lo que producía texto blanco
///    sobre blanco puro (1,00:1) en tema claro — ver §0.1 del plan.
///
/// Correspondencia de estados → `AppStatusType`, común a reserva y cotización:
///
/// | estado        | AppStatusType | dónde                        |
/// |---------------|---------------|------------------------------|
/// | `pendiente`   | `warning`     | reserva, cotización          |
/// | `confirmada`  | `success`     | reserva                      |
/// | `aceptada`    | `success`     | cotización ("En Proceso")    |
/// | `rechazada`   | `error`       | reserva, cotización          |
/// | `cotizada`    | `info`        | reserva                      |
/// | `finalizada`  | `info`        | cotización                   |
class ChatCardShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  /// Normalmente un `AppStatusBadge`. Se encoge antes que el título.
  final Widget? trailing;

  final String? semanticLabel;

  const ChatCardShell({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final tarjeta = Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                // `Expanded` + `ellipsis` es lo que impide el desbordamiento
                // de 118 px que hoy tiene `reserva_chat_card`: sin un hijo
                // flexible, un `Row` con `spaceBetween` no cede nunca.
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  // `AppStatusBadge` no trunca su propio texto (no lleva
                  // ellipsis interno): envolverlo solo en `Flexible` le
                  // asigna un `maxWidth` que no puede respetar y desborda.
                  // `FittedBox` lo escala en vez de truncarlo — es preferible
                  // a un badge cortado a la mitad, y nunca ocurre a los
                  // anchos auditados salvo con título+badge extremos.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: trailing!,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: colors.textPrimary),
              child: child,
            ),
          ),
        ],
      ),
    );

    if (semanticLabel == null) return tarjeta;
    return Semantics(label: semanticLabel, container: true, child: tarjeta);
  }
}
