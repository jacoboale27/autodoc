import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';

import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';

class MechanicServiceHistoryScreen extends StatefulWidget {
  /// Inyectable **solo** para tests: el `StreamBuilder` de esta pantalla
  /// consulta Firestore directamente, así que sin esto no se puede montar
  /// en un widget test. En producción se deja sin pasar.
  final FirebaseFirestore? firestore;

  const MechanicServiceHistoryScreen({super.key, this.firestore});

  @override
  State<MechanicServiceHistoryScreen> createState() =>
      _MechanicServiceHistoryScreenState();
}

class _MechanicServiceHistoryScreenState
    extends State<MechanicServiceHistoryScreen> {
  DateTimeRange? _dateRange;

  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final userSession = context.watch<UserProfileProvider>();
    final userData = userSession.userData;

    if (userData == null || userData.idUsuario.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String mechanicId = userData.idUsuario;

    return MechanicScaffold(
      title: 'Mis Servicios',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              children: [
                AppButton(
                  type: AppButtonType.secondary,
                  size: AppButtonSize.small,
                  icon: const Icon(Icons.date_range, size: 18),
                  text: _dateRange == null
                      ? 'Filtrar por Fechas'
                      : '${DateFormat('dd/MM/yy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_dateRange!.end)}',
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDateRange: _dateRange,
                    );
                    if (picked != null) {
                      setState(() => _dateRange = picked);
                    }
                  },
                ),
                if (_dateRange != null)
                  IconButton(
                    icon: Icon(Icons.clear, color: colors.error),
                    tooltip: 'Quitar el filtro de fechas',
                    onPressed: () => setState(() => _dateRange = null),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection(FirestoreCollections.servicios)
                  .where('id_taller', isEqualTo: mechanicId)
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AppSkeletonLayouts.listCards(
                    itemCount: 5,
                    cardHeight: 120,
                  );
                }
                if (snapshot.hasError) {
                  return const AppEmptyState(
                    title: 'No se pudo cargar tu historial',
                    description: 'Revisa tu conexión e inténtalo de nuevo.',
                    icon: Icons.cloud_off_outlined,
                  );
                }

                final allRecords = (snapshot.data?.docs ?? [])
                    .map(
                      (doc) => ServiceRecordModel.fromMap(
                        doc.data() as Map<String, dynamic>,
                        doc.id,
                      ),
                    )
                    .toList();

                final filteredRecords = allRecords.where((record) {
                  if (_dateRange != null) {
                    final date = record.fecha;
                    if (date.isBefore(_dateRange!.start) ||
                        date.isAfter(
                          _dateRange!.end.add(const Duration(days: 1)),
                        )) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                if (filteredRecords.isEmpty) {
                  return AppEmptyState(
                    title: _dateRange == null
                        ? 'No has realizado ningún servicio aún'
                        : 'No hay servicios en este rango de fechas',
                    description: _dateRange == null
                        ? 'Los servicios que registres desde "Buscar Vehículo" aparecerán aquí.'
                        : 'Prueba a ampliar el rango o a quitar el filtro.',
                    icon: Icons.receipt_long_outlined,
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: AppPageBody(
                    child: AppGrid(
                      compactColumns: 1,
                      mediumColumns: 1,
                      expandedColumns: 2,
                      largeColumns: 2,
                      childAspectRatio: 2.8,
                      children: filteredRecords
                          .map(
                            (record) =>
                                _buildMechanicServiceCard(record, colors),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleServicio(ServiceRecordModel record, AppColors colors) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(record.tipoServicio ?? 'Servicio Genérico'),
        content: AppDialogContent(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detalleRow(
                  context,
                  'Fecha',
                  DateFormat('dd MMM yyyy').format(record.fecha),
                ),
                _detalleRow(
                  context,
                  'Kilometraje',
                  '${record.kilometrajeServicio ?? '--'} km',
                ),
                if (record.costo != null && record.costo! > 0)
                  _detalleRow(
                    context,
                    'Costo',
                    '\$${record.costo!.toStringAsFixed(2)}',
                  ),
                if (record.manoDeObra != null && record.manoDeObra! > 0)
                  _detalleRow(
                    context,
                    'Mano de obra',
                    '\$${record.manoDeObra!.toStringAsFixed(2)}',
                  ),
                if (record.descripcion != null &&
                    record.descripcion!.isNotEmpty)
                  _detalleRow(context, 'Descripción', record.descripcion!),
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

  Widget _detalleRow(BuildContext context, String label, String value) {
    final colors = context.appColors;
    final apilado = AppBreakpoints.of(context).isCompact;
    final etiqueta = Text(
      label,
      style: AppTextStyles.labelMedium.copyWith(
        fontWeight: FontWeight.bold,
        color: colors.textSecondary,
      ),
    );
    final valor = Text(
      value,
      style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: apilado
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [etiqueta, valor],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 110, child: etiqueta),
                Expanded(child: valor),
              ],
            ),
    );
  }

  Widget _buildMechanicServiceCard(
    ServiceRecordModel record,
    AppColors colors,
  ) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      onTap: () => _mostrarDetalleServicio(record, colors),
      semanticLabel:
          '${record.tipoServicio ?? 'Servicio Genérico'}, '
          '${DateFormat('dd MMM yyyy').format(record.fecha)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  record.tipoServicio ?? 'Servicio Genérico',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (record.costo != null && record.costo! > 0)
                Text(
                  '\$${record.costo!.toStringAsFixed(2)}',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${DateFormat('dd MMM yyyy').format(record.fecha)} • ${record.kilometrajeServicio ?? '--'} km',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (record.descripcion != null && record.descripcion!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              record.descripcion!,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
