import 'package:flutter/material.dart';

import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

/// Avisa de que el tablero llegó a [maxTicketsTablero] y hay tickets vivos que
/// no se están mostrando.
///
/// Existe porque el tope no puede ser silencioso. El stream del tablero no
/// tenía ninguno y traía el conjunto entero en cada apertura (residual 7.6 de
/// FUNC-02); ponerle uno acota el coste, pero una tarjeta que falta se lee
/// exactamente igual que un ticket que no existe, y en un tablero de taller esa
/// confusión es cara: un coche que nadie ve es un coche que nadie atiende.
///
/// El mensaje dice además qué hacer, porque hay algo que hacer: los tickets que
/// sobran son visitas que nunca se cerraron.
class AvisoTableroTruncado extends StatelessWidget {
  const AvisoTableroTruncado({super.key});

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
              'Se muestran los $maxTicketsTablero servicios con actividad más '
              'reciente. Hay más abiertos que no caben aquí: entrega o cancela '
              'los que ya terminaron para volver a verlos todos.',
              style: AppTextStyles.labelLarge.copyWith(color: colors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
