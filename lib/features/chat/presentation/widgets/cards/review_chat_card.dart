import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/review_sheet.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String estado =
        metadata['estado'] ?? 'pendiente'; // pendiente, completada

    return Container(
      width: 280,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? Colors.white30
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.black12
                  : (isDark ? Colors.black26 : Colors.grey.shade100),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star,
                  size: 16,
                  color: isMe ? Colors.white : colors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  'Servicio Finalizado',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Por favor califica el servicio que has recibido para ayudar a otros usuarios.',
                  style: TextStyle(
                    color: isMe ? Colors.white : colors.textPrimary,
                  ),
                ),
                if (estado == 'pendiente' && !isMe) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _onRatePressed(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        context.l10n.chatRateService,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else if (estado == 'completada' && !isMe) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.chatReviewThanks,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
