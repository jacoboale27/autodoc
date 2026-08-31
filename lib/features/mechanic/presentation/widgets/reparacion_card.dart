import 'package:flutter/material.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';

class ReparacionCard extends StatelessWidget {
  final ReparacionModel reparacion;
  final VoidCallback? onAvanzar;
  final bool esUltimoEstado;

  /// Nombre visible del estado al que lleva [onAvanzar]. Sin esto el botón
  /// decía solo "Avanzar" y el usuario no sabía a dónde.
  final String? siguienteEstadoLabel;

  /// Cancela el ticket. Null oculta la acción por completo (p. ej. si la
  /// pantalla que embebe la tarjeta no quiere ofrecerla). Se ofrece en
  /// cualquier columna, no solo en la primera: a diferencia de "Avanzar",
  /// cancelar no depende de la posición en `estadosReparacion`.
  final VoidCallback? onCancelar;

  const ReparacionCard({
    super.key,
    required this.reparacion,
    this.onAvanzar,
    this.esUltimoEstado = false,
    this.siguienteEstadoLabel,
    this.onCancelar,
  });

  /// Confirma antes de cancelar: es una acción destructiva e irreversible
  /// (el ticket cancelado desaparece del tablero, ver
  /// `ReparacionRepository.cambiarEstado`), así que un toque accidental en
  /// la tarjeta equivocada no debe bastar para perderlo.
  Future<void> _confirmarCancelar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar ticket'),
        content: AppDialogContent(
          child: Text(
            '¿Seguro que deseas cancelar el ticket de "${reparacion.placa}"? '
            'Esta acción no se puede deshacer.',
          ),
        ),
        actions: [
          AppButton(
            text: 'Volver',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppButton(
            text: 'Cancelar ticket',
            type: AppButtonType.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmado == true) onCancelar?.call();
  }

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
              child: AppButton(
                text: 'Avanzar a $siguienteEstadoLabel',
                type: AppButtonType.text,
                size: AppButtonSize.small,
                icon: const Icon(Icons.arrow_forward),
                onPressed: onAvanzar,
              ),
            ),
          ],
          if (onCancelar != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              // Sin icono y sin fondo (a diferencia de "Avanzar"), para que
              // pese menos visualmente aunque use colors.error: es la
              // acción secundaria de la tarjeta, no la sugerida.
              child: AppButton(
                text: 'Cancelar',
                type: AppButtonType.text,
                size: AppButtonSize.small,
                onPressed: () => _confirmarCancelar(context),
                child: Text(
                  'Cancelar',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
