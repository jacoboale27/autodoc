import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/widgets/review_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class ServiceHistoryScreen extends StatefulWidget {
  final String vehicleId;
  const ServiceHistoryScreen({super.key, required this.vehicleId});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  String _filter = 'Todos'; // 'Todos', 'Manual', 'Taller'
  DateTimeRange? _dateRange;

  String _sortOption = 'Fecha (Reciente)'; // 'Fecha (Reciente)', 'Fecha (Antiguo)', 'Costo (Mayor)', 'Costo (Menor)'

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
          style: GoogleFonts.inter(
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
                      side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
                    ),
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(_dateRange == null 
                        ? 'Fechas' 
                        : '${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}'),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        initialDateRange: _dateRange,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: colors.primary,
                                onPrimary: Colors.white,
                                surface: colors.surface,
                                onSurface: colors.textPrimary,
                              ),
                            ),
                            child: child!,
                          );
                        },
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
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
                      ),
                      filled: true,
                      fillColor: colors.surface,
                    ),
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    items: ['Fecha (Reciente)', 'Fecha (Antiguo)', 'Costo (Mayor)', 'Costo (Menor)']
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
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
              stream: FirebaseFirestore.instance
                  .collection(FirestoreCollections.servicios)
                  .where('id_vehiculo', isEqualTo: widget.vehicleId)
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
                  if (_filter != context.l10n.histTabAll && _filter != 'Todos') {
                    final isManual = record.idTaller == 'Manual (Propietario)';
                    if ((_filter == context.l10n.histTabManual || _filter == 'Manual') && !isManual) return false;
                    if ((_filter == context.l10n.histTabWorkshop || _filter == 'Taller') && isManual) return false;
                  }
                  
                  // Date range
                  if (_dateRange != null) {
                    final date = record.fecha;
                    if (date.isBefore(_dateRange!.start) || date.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
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
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = filteredRecords[index];
                          return _buildServiceCard(record, colors, context);
                        },
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

    double totalCost = records.fold(0, (acc, record) => acc + (record.costo ?? 0));
    double avgCost = totalCost / records.length;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total gastado',
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${totalCost.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              color: colors.primary,
              fontSize: 24,
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
                    'Servicios',
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
                    'Promedio',
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 64,
            color: colors.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.histNoServices,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.histNoServicesDesc,
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String title, AppColors colors) {
    final isSelected = _filter == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = title),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : colors.textSecondary,
            ),
          ),
        ),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                      style: GoogleFonts.inter(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                  style: GoogleFonts.inter(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
                      ? Colors.blueGrey.withValues(alpha: 0.1)
                      : colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isManual ? Icons.person : Icons.store,
                      size: 14,
                      color: isManual ? Colors.blueGrey : colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isManual ? context.l10n.histOwner : context.l10n.histWorkshop,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isManual ? Colors.blueGrey : colors.primary,
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
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.histEvidence,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _resenarTaller(context, record),
                icon: Icon(Icons.star_outline, size: 18, color: colors.warning),
                label: Text(
                  context.l10n.histReviewWorkshop,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _resenarTaller(
    BuildContext context,
    ServiceRecordModel record,
  ) async {
    final tallerId = record.idTaller!;
    final snap = await FirebaseFirestore.instance
        .collection(FirestoreCollections.usuarios)
        .doc(tallerId)
        .get();
    final nombre =
        snap.data()?['nombre_completo'] as String? ?? 'Taller';
    if (!context.mounted) return;
    await showReviewBottomSheet(
      context,
      tallerId: tallerId,
      tallerNombre: nombre,
      idServicio: record.idServicio,
    );
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
