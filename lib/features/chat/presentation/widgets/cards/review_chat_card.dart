import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

/// La solicitud de reseña que el taller manda al cerrar un servicio.
///
/// Observaciones del 2026-09-19: ya no trae su propio botón de calificar. La
/// única forma de reseñar desde el chat es el aviso de encima de la barra de
/// escribir (`AvisoReseniaChat`), que solo aparece cuando hay algo que
/// reseñar; con un botón aquí, cada solicitud era una opción más y todas
/// llevaban a lo mismo.
class ReviewChatCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final bool isMe;
  final String tallerId;
  final String mensajeId;
  final String conversacionId;

  const ReviewChatCard({
    super.key,
    required this.metadata,
    required this.isMe,
    required this.tallerId,
    required this.mensajeId,
    required this.conversacionId,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Las solicitudes viejas guardaban aquí si ya se había reseñado.
    final String estado = metadata['estado'] ?? 'pendiente';

    return ChatCardShell(
      icon: Icons.star,
      title: 'Servicio Finalizado',
      semanticLabel: estado == 'completada'
          ? 'Servicio finalizado, reseña enviada'
          : 'Servicio finalizado, solicitud de reseña',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMe
                ? 'Le pediste al cliente que reseñe el servicio.'
                : 'Por favor califica el servicio que has recibido para '
                      'ayudar a otros usuarios. Hazlo con el botón «Calificar '
                      'servicio» de abajo, junto a la barra de escribir.',
          ),
          if (estado == 'completada' && !isMe) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle, color: colors.success, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    context.l10n.chatReviewThanks,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
