import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Avisa de que una lista acotada llegó a su tope y hay documentos que no se
/// están mostrando.
///
/// Existe porque un tope no puede ser silencioso: un elemento que falta se lee
/// exactamente igual que uno que no existe. Es el mismo contrato que
/// `AvisoTableroTruncado` —que nació antes, para el tablero Kanban— pero con
/// el mensaje inyectado, porque aquí lo pone el ARB (`bandejaTruncada`,
/// `hiloTruncado`) y no un literal de la propia tarjeta.
class AvisoListaTruncada extends StatelessWidget {
  const AvisoListaTruncada({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list_off_outlined, color: colors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              mensaje,
              style: AppTextStyles.labelLarge.copyWith(color: colors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
