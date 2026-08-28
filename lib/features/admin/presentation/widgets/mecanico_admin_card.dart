import 'package:flutter/material.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_estado_cuenta.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';

class MecanicoAdminCard extends StatelessWidget {
  final UserModel usuario;
  final double? calificacionPromedio;
  final int totalResenias;

  const MecanicoAdminCard({
    super.key,
    required this.usuario,
    this.calificacionPromedio,
    this.totalResenias = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // Mismo semaforo que AccountRow y que el resto del panel de admin.
    final estadoStyle = AppEstadoCuenta.style(usuario.estado, colors);

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                child: Text(
                  usuario.nombreCompleto.isNotEmpty
                      ? usuario.nombreCompleto[0].toUpperCase()
                      : 'T',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario.nombreCompleto,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      usuario.correo,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _chip(
                usuario.rol,
                colors.primary.withValues(alpha: 0.1),
                colors.primary,
              ),
              const SizedBox(width: 6),
              _chip(
                estadoStyle.label,
                estadoStyle.color.withValues(alpha: 0.1),
                estadoStyle.color,
                icon: estadoStyle.icon,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (usuario.especialidad != null)
                _info(
                  context,
                  Icons.build_circle_outlined,
                  usuario.especialidad!,
                ),
              if (usuario.ubicacionMunicipio != null)
                _info(
                  context,
                  Icons.location_on_outlined,
                  usuario.ubicacionMunicipio!,
                ),
              if (usuario.telefono != null)
                _info(context, Icons.phone_outlined, usuario.telefono!),
              _info(
                context,
                Icons.star_outline,
                totalResenias > 0
                    ? '${calificacionPromedio?.toStringAsFixed(1) ?? '0'} ($totalResenias reseñas)'
                    : 'Sin reseñas',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String text) {
    final colors = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 12,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
