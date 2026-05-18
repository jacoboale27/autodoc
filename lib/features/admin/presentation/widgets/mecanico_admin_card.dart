import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
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
    final estadoColor = usuario.estado == 'activo'
        ? colors.secondary
        : usuario.estado == 'suspendido'
            ? colors.error
            : colors.warning;

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
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      usuario.correo,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _chip(usuario.rol, colors.primary.withValues(alpha: 0.1), colors.primary),
              const SizedBox(width: 6),
              _chip(usuario.estado, estadoColor.withValues(alpha: 0.1), estadoColor),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (usuario.especialidad != null)
                _info(Icons.build_circle_outlined, usuario.especialidad!),
              if (usuario.ubicacionMunicipio != null)
                _info(Icons.location_on_outlined, usuario.ubicacionMunicipio!),
              if (usuario.telefono != null)
                _info(Icons.phone_outlined, usuario.telefono!),
              _info(
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

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
