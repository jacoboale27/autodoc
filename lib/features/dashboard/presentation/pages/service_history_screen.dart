import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:autodoc/core/widgets/review_sheet.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class ServiceHistoryScreen extends StatefulWidget {
  final String vehiculoId;
  final FirebaseFirestore? firestore;
  const ServiceHistoryScreen({
    super.key,
    required this.vehiculoId,
    this.firestore,
  });

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  final _reviewService = ReviewService();
  String _filter = 'Todos'; // 'Todos', 'Manual', 'Taller'
  DateTimeRange? _dateRange;

  String _sortOption =
      'Fecha (Reciente)'; // 'Fecha (Reciente)', 'Fecha (Antiguo)', 'Costo (Mayor)', 'Costo (Menor)'

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppScaffold(
      useGradient: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          context.l10n.histTitle,
          style: AppTextStyles.titleLarge.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.fontSize(context, 18),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: EdgeInsets.all(Responsive.padding(context, 16.0)),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildFilterTab(context.l10n.histTabAll, colors),
                  _buildFilterTab(context.l10n.histTabManual, colors),
                  _buildFilterTab(context.l10n.histTabWorkshop, colors),
                ],
              ),
            ),
          ),

          // Advanced Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.surface,
                      foregroundColor: colors.primary,
                      elevation: 0,
                      side: BorderSide(
                        color: colors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _dateRange == null
                          ? 'Fechas'
                          : '${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}',
                    ),
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
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sortOption,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      filled: true,
                      fillColor: colors.surface,
                    ),
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    items:
                        [
                              'Fecha (Reciente)',
                              'Fecha (Antiguo)',
                              'Costo (Mayor)',
                              'Costo (Menor)',
                            ]
                            .map(
                              (o) => DropdownMenuItem(
                                value: o,
                                child: Text(
                                  o,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _sortOption = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (_dateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _dateRange = null),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Limpiar fechas'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.error,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                  ),
                ),
              ),
            ),

          // List & Stats
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: (widget.firestore ?? FirebaseFirestore.instance)
                  .collection(FirestoreCollections.servicios)
                  .where('id_vehiculo', isEqualTo: widget.vehiculoId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AppSkeletonLayouts.listCards(
                    itemCount: 5,
                    cardHeight: 96,
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(colors);
                }

                final docs = snapshot.data!.docs;
                final allRecords = docs
                    .map(
                      (doc) => ServiceRecordModel.fromMap(
                        doc.data() as Map<String, dynamic>,
                        doc.id,
                      ),
                    )
                    .toList();

                // Filter
                final filteredRecords = allRecords.where((record) {
                  // Tab filter
                  if (_filter != context.l10n.histTabAll &&
                      _filter != 'Todos') {
                    final isManual = record.idTaller == 'Manual (Propietario)';
                    if ((_filter == context.l10n.histTabManual ||
                            _filter == 'Manual') &&
                        !isManual) {
                      return false;
                    }
                    if ((_filter == context.l10n.histTabWorkshop ||
                            _filter == 'Taller') &&
                        isManual) {
                      return false;
                    }
                  }

                  // Date range
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

                // Sort
                filteredRecords.sort((a, b) {
                  switch (_sortOption) {
                    case 'Fecha (Antiguo)':
                      return a.fecha.compareTo(b.fecha);
                    case 'Costo (Mayor)':
                      return (b.costo ?? 0).compareTo(a.costo ?? 0);
                    case 'Costo (Menor)':
                      return (a.costo ?? 0).compareTo(b.costo ?? 0);
                    case 'Fecha (Reciente)':
                    default:
                      return b.fecha.compareTo(a.fecha);
                  }
                });

                if (filteredRecords.isEmpty) {
                  return Column(
                    children: [
                      _buildStatistics(filteredRecords, colors),
                      Expanded(child: _buildEmptyState(colors)),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildStatistics(filteredRecords, colors),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.padding(context, AppSpacing.sm),
                        ),
                        child: AppPageBody(
                          child: AppGrid(
                            compactColumns: 1,
                            mediumColumns: 1,
                            expandedColumns: 2,
                            largeColumns: 2,
                            childAspectRatio: 1.3,
                            children: filteredRecords
                                .map(
                                  (record) => _buildServiceCard(
                                    record,
                                    colors,
                                    context,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(List<ServiceRecordModel> records, AppColors colors) {
    if (records.isEmpty) return const SizedBox.shrink();

    double totalCost = records.fold(
      0,
      (acc, record) => acc + (record.costo ?? 0),
    );
    double avgCost = totalCost / records.length;

    return AppCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Text(
            context.l10n.histTotalSpent,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${totalCost.toStringAsFixed(2)}',
            style: AppTextStyles.headlineSmall.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    context.l10n.histServicesCount,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${records.length}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    context.l10n.histAverage,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${avgCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return AppEmptyState(
      icon: Icons.history_toggle_off,
      title: context.l10n.histNoServices,
      description: context.l10n.histNoServicesDesc,
    );
  }

  Widget _buildFilterTab(String title, AppColors colors) {
    final isSelected = _filter == title;
    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: () => setState(() => _filter = title),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              title,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? colors.onPrimary : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleServicio(ServiceRecordModel record, AppColors colors) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(record.tipoServicio ?? 'Servicio'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detalleRow(
                  'Fecha',
                  DateFormat('dd MMM yyyy').format(record.fecha),
                  colors,
                ),
                _detalleRow(
                  'Kilometraje',
                  '${record.kilometrajeServicio ?? '--'} km',
                  colors,
                ),
                if (record.idTaller != null)
                  _detalleRow('Taller', record.idTaller!, colors),
                if (record.costo != null && record.costo! > 0)
                  _detalleRow(
                    'Costo',
                    '\$${record.costo!.toStringAsFixed(2)}',
                    colors,
                  ),
                if (record.manoDeObra != null && record.manoDeObra! > 0)
                  _detalleRow(
                    'Mano de obra',
                    '\$${record.manoDeObra!.toStringAsFixed(2)}',
                    colors,
                  ),
                if (record.descripcion != null &&
                    record.descripcion!.isNotEmpty)
                  _detalleRow('Descripción', record.descripcion!, colors),
                if (record.materiales != null &&
                    record.materiales!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Materiales',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...record.materiales!.map(
                    (m) => Text(
                      '• ${m['nombre'] ?? m['descripcion'] ?? m.toString()}',
                    ),
                  ),
                ],
                if (record.fotoFacturaUrl != null &&
                    record.fotoFacturaUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(record.fotoFacturaUrl!),
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

  Widget _detalleRow(String label, String value, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 96, maxWidth: 130),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    ServiceRecordModel record,
    AppColors colors,
    BuildContext context,
  ) {
    final isManual = record.idTaller == 'Manual (Propietario)';

    // Select Icon based on service type
    IconData serviceIcon = Icons.build;
    final lowerName = record.tipoServicio?.toLowerCase() ?? '';
    if (lowerName.contains('aceite')) {
      serviceIcon = Icons.oil_barrel_outlined;
    } else if (lowerName.contains('llanta') ||
        lowerName.contains('neumático') ||
        lowerName.contains('alineación') ||
        lowerName.contains('balanceo')) {
      serviceIcon = Icons.tire_repair_outlined;
    } else if (lowerName.contains('freno') || lowerName.contains('pastilla')) {
      serviceIcon = Icons.stop_circle_outlined;
    } else if (lowerName.contains('batería')) {
      serviceIcon = Icons.battery_charging_full_outlined;
    } else if (lowerName.contains('líquido') ||
        lowerName.contains('refrigerante') ||
        lowerName.contains('anticongelante')) {
      serviceIcon = Icons.water_drop_outlined;
    }

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      onTap: () => _mostrarDetalleServicio(record, colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(serviceIcon, color: colors.primary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.tipoServicio ?? 'Servicio',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(record.fecha)} • ${record.kilometrajeServicio ?? '--'} ${context.l10n.vpKm}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isManual
                      ? colors.textSecondary.withValues(alpha: 0.1)
                      : colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isManual ? Icons.person : Icons.store,
                      size: 14,
                      color: isManual ? colors.textSecondary : colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isManual
                          ? context.l10n.histOwner
                          : context.l10n.histWorkshop,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isManual ? colors.textSecondary : colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (record.fotoFacturaUrl != null &&
                  record.fotoFacturaUrl!.isNotEmpty)
                GestureDetector(
                  onTap: () =>
                      _showImageDialog(context, record.fotoFacturaUrl!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 14,
                          color: colors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.histEvidence,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (record.descripcion != null && record.descripcion!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              record.descripcion!,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (!isManual &&
              record.idTaller != null &&
              record.idTaller!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildReviewAction(record, colors),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewAction(ServiceRecordModel record, AppColors colors) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder(
      future: _reviewService.getUserReviewForService(userId, record.idServicio),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final alreadyReviewed = snapshot.data != null;
        return Align(
          alignment: Alignment.centerRight,
          child: alreadyReviewed
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: colors.secondary),
                    const SizedBox(width: 4),
                    Text(
                      'Ya reseñado',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              : TextButton.icon(
                  onPressed: () => _resenarTaller(context, record),
                  icon: Icon(
                    Icons.star_outline,
                    size: 18,
                    color: colors.warning,
                  ),
                  label: Text(
                    context.l10n.histReviewWorkshop,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _resenarTaller(
    BuildContext context,
    ServiceRecordModel record,
  ) async {
    final tallerId = record.idTaller!;
    // I1 (Fase C, revision de correcciones): 'usuarios' quedo cerrada a solo
    // lectura del propio documento (Tarea 8); el perfil publico del taller
    // (incluido su nombre) vive en 'talleres', proyectado por
    // publishTallerProfile. Se protege con try/catch: si la lectura falla
    // (p. ej. taller aun no proyectado) igual se abre la hoja de resenia.
    String nombre = 'Taller';
    try {
      final snap = await (widget.firestore ?? FirebaseFirestore.instance)
          .collection(FirestoreCollections.talleres)
          .doc(tallerId)
          .get();
      nombre = snap.data()?['nombre'] as String? ?? 'Taller';
    } catch (_) {
      // Se conserva el nombre por defecto; no bloquea la resenia.
    }
    if (!context.mounted) return;
    final result = await showReviewBottomSheet(
      context,
      tallerId: tallerId,
      tallerNombre: nombre,
      idServicio: record.idServicio,
    );
    if (result == true && mounted) setState(() {});
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
