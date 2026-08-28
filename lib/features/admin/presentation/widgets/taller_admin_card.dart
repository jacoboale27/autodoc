import 'package:flutter/material.dart';
import '../../../../core/models/workshop_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_estado_cuenta.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class TallerAdminCard extends StatelessWidget {
  final WorkshopModel taller;

  /// Reactivar una cuenta SUSPENDIDA. Ya no aprueba altas: un taller
  /// pendiente se aprueba desde la bandeja de verificacion y en ningun otro
  /// sitio (ver [onVerExpediente]).
  final VoidCallback onReactivar;

  final VoidCallback onRechazar;
  final VoidCallback onSuspender;

  /// Lleva a la bandeja de verificacion, que es donde vive la evidencia.
  ///
  /// Sustituye al boton "Aprobar" que habia aqui para los talleres
  /// pendientes. Aquel escribia `usuarios.estado` directamente sin mirar una
  /// sola foto y sin tocar `verificaciones/{uid}`, que es justo el agujero
  /// que la coleccion de expedientes existe para cerrar. Ademas dejaba el
  /// expediente sin llegar nunca a 'aprobada', y `reabrirVerificacion` solo
  /// actua sobre ese valor: un taller aprobado por aqui quedaba exento de
  /// por vida de la re-revision.
  final VoidCallback onVerExpediente;

  const TallerAdminCard({
    super.key,
    required this.taller,
    required this.onReactivar,
    required this.onRechazar,
    required this.onSuspender,
    required this.onVerExpediente,
  });

  @override
  Widget build(BuildContext context) {
    // El semaforo sale de AppEstadoCuenta y no de comparar el texto crudo:
    // `estado` arrastra dos vocabularios ('activo' y 'aprobado') para el mismo
    // si, y `VerificacionService.aprobar` escribe 'activo'. Comparando
    // literales, un taller aprobado desde la bandeja se pintaba en naranja y
    // seguia ofreciendo los botones de una cuenta pendiente.
    final estado = AppEstadoCuenta.parse(taller.estado);
    final estilo = AppEstadoCuenta.style(taller.estado, context.appColors);

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  taller.nombre,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.appColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusChip(estilo),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                context,
                Icons.build_circle_outlined,
                taller.especialidad ?? 'General',
              ),
              _buildInfoChip(
                context,
                Icons.location_on_outlined,
                taller.ubicacionMunicipio ?? 'S.S.',
              ),
              _buildInfoChip(
                context,
                Icons.phone_outlined,
                taller.telefono ?? 'N/A',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (estado == EstadoCuenta.pendiente) ...[
                AppButton(
                  text: context.l10n.adminReject,
                  type: AppButtonType.danger,
                  size: AppButtonSize.small,
                  onPressed: onRechazar,
                ),
                AppButton(
                  text: 'Ver expediente',
                  size: AppButtonSize.small,
                  icon: const Icon(Icons.fact_check_outlined),
                  onPressed: onVerExpediente,
                ),
              ] else if (estado == EstadoCuenta.aprobada) ...[
                AppButton(
                  text: context.l10n.adminSuspend,
                  type: AppButtonType.danger,
                  size: AppButtonSize.small,
                  icon: const Icon(Icons.block_flipped),
                  onPressed: onSuspender,
                ),
              ] else if (estado == EstadoCuenta.suspendida) ...[
                AppButton(
                  text: context.l10n.adminReactivate,
                  size: AppButtonSize.small,
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: onReactivar,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(EstadoCuentaStyle estilo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: estilo.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estilo.label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: estilo.color,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 13,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
