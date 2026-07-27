import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';

class HistorialChatCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final bool isMe;

  const HistorialChatCard({
    super.key,
    required this.metadata,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String tipoServicio =
        metadata['tipo_servicio'] ?? 'Servicio anterior';
    final double costo = metadata['costo']?.toDouble() ?? 0.0;
    final String fechaRaw = metadata['fecha'] ?? '';

    DateTime? fecha;
    if (fechaRaw.isNotEmpty) {
      fecha = DateTime.tryParse(fechaRaw);
    }

    return Container(
      width: 260,
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
                  Icons.history,
                  size: 16,
                  color: isMe ? Colors.white : colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Historial Adjunto',
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
                  tipoServicio,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fecha != null
                          ? DateFormat('dd MMM yyyy').format(fecha)
                          : 'Fecha sin definir',
                      style: TextStyle(
                        fontSize: 13,
                        color: isMe ? Colors.white70 : colors.textSecondary,
                      ),
                    ),
                    if (costo > 0)
                      Text(
                        '\$${costo.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white : colors.secondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
