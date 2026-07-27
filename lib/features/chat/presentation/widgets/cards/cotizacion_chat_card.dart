import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class CotizacionChatCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final bool isMe;
  final String mensajeId;
  final String conversacionId;

  const CotizacionChatCard({
    super.key,
    required this.metadata,
    required this.isMe,
    required this.mensajeId,
    required this.conversacionId,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String descripcion =
        metadata['descripcion'] ?? 'Cotización sin detalles';
    final double precioRaw = metadata['total']?.toDouble() ?? 0.0;
    final String estado =
        metadata['estado'] ?? 'pendiente'; // pendiente, aceptada, rechazada

    Color badgeColor = Colors.orange;
    String badgeText = 'Pendiente';
    if (estado == 'aceptada') {
      badgeColor = Colors.green;
      badgeText = 'Aprobada';
    } else if (estado == 'rechazada') {
      badgeColor = Colors.red;
      badgeText = 'Rechazada';
    }

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.request_quote,
                      size: 16,
                      color: isMe ? Colors.white : colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cotización de Servicio',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
                  descripcion,
                  style: TextStyle(
                    color: isMe ? Colors.white : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.black12),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white70 : colors.textSecondary,
                      ),
                    ),
                    Text(
                      '\$${precioRaw.toStringAsFixed(2)}',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : colors.secondary,
                      ),
                    ),
                  ],
                ),
                if (estado == 'pendiente' && !isMe) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final newMeta = Map<String, dynamic>.from(metadata);
                            newMeta['estado'] = 'aceptada';
                            final provider = context.read<ChatProvider>();
                            provider.actualizarMetadatosMensaje(
                              conversacionId,
                              mensajeId,
                              newMeta,
                            );
                            if (metadata['id_cotizacion'] != null) {
                              provider.actualizarEstadoCotizacion(
                                metadata['id_cotizacion'],
                                'aceptada',
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(color: colors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(context.l10n.chatAccept),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final newMeta = Map<String, dynamic>.from(metadata);
                            newMeta['estado'] = 'rechazada';
                            final provider = context.read<ChatProvider>();
                            provider.actualizarMetadatosMensaje(
                              conversacionId,
                              mensajeId,
                              newMeta,
                            );
                            if (metadata['id_cotizacion'] != null) {
                              provider.actualizarEstadoCotizacion(
                                metadata['id_cotizacion'],
                                'rechazada',
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(context.l10n.chatReject),
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
