import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/review_sheet.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/ui_utils.dart';

class ReviewChatCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final bool isMe;
  final String tallerId; // Para poder enviar el review real
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

  Future<void> _onRatePressed(BuildContext context) async {
    final userId = context.read<UserProfileProvider>().userData?.idUsuario;
    if (userId == null) return;

    final idServicio = await ReviewService().findReviewableServiceId(
      userId,
      tallerId,
    );
    if (!context.mounted) return;

    if (idServicio == null) {
      UiUtils.showErrorSnackbar(
        context,
        'Debes completar un servicio con este taller antes de reseñarlo.',
      );
      return;
    }

    final result = await showReviewBottomSheet(
      context,
      tallerId: tallerId,
      tallerNombre: metadata['tallerNombre'] ?? 'Taller',
      idServicio: idServicio,
    );
    if (result == true) {
      if (!context.mounted) return;
      final newMeta = Map<String, dynamic>.from(metadata);
      newMeta['estado'] = 'completada';
      context.read<ChatProvider>().actualizarMetadatosMensaje(
        conversacionId,
        mensajeId,
        newMeta,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final String estado =
        metadata['estado'] ?? 'pendiente'; // pendiente, completada

    return ChatCardShell(
      icon: Icons.star,
      title: 'Servicio Finalizado',
      semanticLabel: estado == 'completada'
          ? 'Servicio finalizado, reseña enviada'
          : 'Servicio finalizado, pendiente de calificar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Por favor califica el servicio que has recibido para ayudar a '
            'otros usuarios.',
          ),
          if (estado == 'pendiente' && !isMe) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: context.l10n.chatRateService,
                onPressed: () => _onRatePressed(context),
              ),
            ),
          ] else if (estado == 'completada' && !isMe) ...[
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
