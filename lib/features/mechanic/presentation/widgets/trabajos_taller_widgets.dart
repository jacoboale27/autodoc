import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_status_badge.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';

/// Piezas comunes del trabajo del taller: el perfil del vehículo y "Mis
/// Servicios" enseñan las mismas cotizaciones y los mismos servicios, y
/// tienen que decir lo mismo de ellos (observaciones del 2026-09-19).

/// Cómo se llama y se pinta cada estado de una cotización para el taller.
///
/// El estado va SIEMPRE en texto además de en color: al daltónico el verde y
/// el rojo le llegan igual.
({String etiqueta, AppStatusType tipo, IconData icono}) estiloEstadoCotizacion(
  String estado,
) => switch (estado) {
  'pendiente' => (
    etiqueta: 'Esperando respuesta',
    tipo: AppStatusType.warning,
    icono: Icons.hourglass_top_rounded,
  ),
  'aceptada' => (
    etiqueta: 'Aceptada · en proceso',
    tipo: AppStatusType.info,
    icono: Icons.build_circle_outlined,
  ),
  'rechazada' => (
    etiqueta: 'Rechazada',
    tipo: AppStatusType.error,
    icono: Icons.cancel_outlined,
  ),
  'finalizada' => (
    etiqueta: 'Finalizada',
    tipo: AppStatusType.success,
    icono: Icons.check_circle_outline,
  ),
  _ => (
    etiqueta: estado,
    tipo: AppStatusType.info,
    icono: Icons.description_outlined,
  ),
};

/// «Toyota Corolla · P123-456», del resumen que la cotización guarda desde el
/// 2026-09-19. `null` si no lo trae (cotizaciones anteriores).
String? vehiculoDeLaCotizacion(CotizacionModel cotizacion) {
  final r = cotizacion.vehiculoResumen;
  if (r == null) return null;
  String? texto(String clave) {
    final v = r[clave]?.toString().trim();
    return v == null || v.isEmpty ? null : v;
  }

  final nombre = [
    texto('marca'),
    texto('modelo'),
  ].whereType<String>().join(' ');
  final placa = texto('placa');
  final partes = [if (nombre.isNotEmpty) nombre, ?placa];
  return partes.isEmpty ? null : partes.join(' · ');
}

final _fecha = DateFormat('dd/MM/yyyy');

/// Una cotización del taller en una lista.
class CotizacionTallerTile extends StatelessWidget {
  final CotizacionModel cotizacion;

  /// Qué coche es. `null` cuando la lista ya es de un solo coche (el perfil).
  final String? vehiculo;

  final VoidCallback? onTap;

  const CotizacionTallerTile({
    super.key,
    required this.cotizacion,
    this.vehiculo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final estilo = estiloEstadoCotizacion(cotizacion.estado);
    final titulo = vehiculo ?? cotizacion.resumen;
    final detalle = vehiculo == null ? null : cotizacion.resumen;
    final total = '\$${cotizacion.total.toStringAsFixed(2)}';

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      semanticLabel: onTap == null
          ? null
          : '$titulo, ${estilo.etiqueta}, $total, '
                '${_fecha.format(cotizacion.fecha)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.request_quote_outlined,
              color: colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                if (detalle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppStatusBadge(
                      text: estilo.etiqueta,
                      type: estilo.tipo,
                      icon: estilo.icono,
                    ),
                    Text(
                      _fecha.format(cotizacion.fecha),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            total,
            style: AppTextStyles.titleSmall.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un servicio ya registrado por el taller.
class ServicioRealizadoTile extends StatelessWidget {
  final ServiceRecordModel servicio;

  /// Qué coche es. `null` cuando la lista ya es de un solo coche (el perfil).
  final String? vehiculo;

  const ServicioRealizadoTile({
    super.key,
    required this.servicio,
    this.vehiculo,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tipo = servicio.tipoServicio ?? 'Servicio';
    final km = servicio.kilometrajeServicio;
    final detalle = [
      _fecha.format(servicio.fecha),
      if (km != null) '$km km',
      ?vehiculo,
    ].join(' · ');

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => mostrarDetalleDeServicio(context, servicio),
      semanticLabel: '$tipo, $detalle',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.task_alt, color: colors.success, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (servicio.descripcion != null &&
                    servicio.descripcion!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    servicio.descripcion!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (servicio.costo != null && servicio.costo! > 0) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              '\$${servicio.costo!.toStringAsFixed(2)}',
              style: AppTextStyles.titleSmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// El desglose de un servicio registrado: fecha, kilometraje, importes,
/// materiales y la factura, si la hay.
Future<void> mostrarDetalleDeServicio(
  BuildContext context,
  ServiceRecordModel record,
) {
  final colors = context.appColors;

  Widget fila(BuildContext context, String etiqueta, String valor) {
    final apilado = AppBreakpoints.of(context).isCompact;
    final e = Text(
      etiqueta,
      style: AppTextStyles.labelMedium.copyWith(
        fontWeight: FontWeight.bold,
        color: colors.textSecondary,
      ),
    );
    final v = Text(
      valor,
      style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: apilado
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [e, v],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 110, child: e),
                Expanded(child: v),
              ],
            ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(record.tipoServicio ?? 'Servicio Genérico'),
      content: AppDialogContent(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fila(
                dialogContext,
                'Fecha',
                DateFormat('dd MMM yyyy').format(record.fecha),
              ),
              fila(
                dialogContext,
                'Kilometraje',
                '${record.kilometrajeServicio ?? '--'} km',
              ),
              if (record.costo != null && record.costo! > 0)
                fila(
                  dialogContext,
                  'Costo',
                  '\$${record.costo!.toStringAsFixed(2)}',
                ),
              if (record.manoDeObra != null && record.manoDeObra! > 0)
                fila(
                  dialogContext,
                  'Mano de obra',
                  '\$${record.manoDeObra!.toStringAsFixed(2)}',
                ),
              if (record.descripcion != null && record.descripcion!.isNotEmpty)
                fila(dialogContext, 'Descripción', record.descripcion!),
              if (record.materiales != null &&
                  record.materiales!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Materiales',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ...record.materiales!.map(
                  (m) => Text(
                    '• ${m['nombre'] ?? m['descripcion'] ?? m.toString()}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
              if (record.fotoFacturaUrl != null &&
                  record.fotoFacturaUrl!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.network(
                    record.fotoFacturaUrl!,
                    semanticLabel: 'Factura del servicio',
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const SizedBox(
                            height: 160,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    errorBuilder: (context, error, stack) => Padding(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: Text(
                        'No se pudo cargar la factura.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
