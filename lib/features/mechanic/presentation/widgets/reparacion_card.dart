import 'package:flutter/material.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';

class ReparacionCard extends StatelessWidget {
  final ReparacionModel reparacion;
  final VoidCallback? onAvanzar;
  final bool esUltimoEstado;

  /// Nombre visible del estado al que lleva [onAvanzar]. Sin esto el botón
  /// decía solo "Avanzar" y el usuario no sabía a dónde.
  final String? siguienteEstadoLabel;

  const ReparacionCard({
    super.key,
    required this.reparacion,
    this.onAvanzar,
    this.esUltimoEstado = false,
    this.siguienteEstadoLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dias = DateTime.now()
        .difference(reparacion.fechaActualizacion)
        .inDays;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reparacion.placa,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            dias == 0
                ? 'Actualizado hoy'
                : 'Hace $dias ${dias == 1 ? 'día' : 'días'}',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (!esUltimoEstado && siguienteEstadoLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAvanzar,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text('Avanzar a $siguienteEstadoLabel'),
                style: TextButton.styleFrom(foregroundColor: colors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
