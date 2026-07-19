import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

class VehiculoChatCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final bool isMe;

  const VehiculoChatCard({
    super.key,
    required this.metadata,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final String marca = metadata['marca'] ?? 'Marca desconocida';
    final String modelo = metadata['modelo'] ?? 'Modelo desconocido';
    final String anio = metadata['anio']?.toString() ?? 'N/A';
    final String placa = metadata['placa'] ?? 'Sin placa';

    return Container(
      width: 250,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isMe ? colors.primary.withValues(alpha: 0.1) : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? colors.primary.withValues(alpha: 0.2) : colors.surfaceContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car, size: 16, color: isMe ? colors.surface : colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Vehículo Compartido',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isMe ? colors.surface : colors.textPrimary,
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
                  '$marca $modelo',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isMe ? colors.surface : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Año: $anio',
                      style: TextStyle(
                        fontSize: 13,
                        color: isMe ? colors.surface.withValues(alpha: 0.7) : colors.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMe ? colors.surface.withValues(alpha: 0.2) : colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        placa,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMe ? colors.surface : colors.primary,
                        ),
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
