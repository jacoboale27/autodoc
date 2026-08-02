import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';

class ReparacionCard extends StatelessWidget {
  final ReparacionModel reparacion;
  final VoidCallback? onAvanzar;
  final bool esUltimoEstado;

  const ReparacionCard({
    super.key,
    required this.reparacion,
    this.onAvanzar,
    this.esUltimoEstado = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reparacion.placa,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (!esUltimoEstado)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAvanzar,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Avanzar'),
                style: TextButton.styleFrom(foregroundColor: colors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
