import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/widgets/app_card.dart';

import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

class MechanicServiceHistoryScreen extends StatefulWidget {
  const MechanicServiceHistoryScreen({super.key});

  @override
  State<MechanicServiceHistoryScreen> createState() =>
      _MechanicServiceHistoryScreenState();
}

class _MechanicServiceHistoryScreenState
    extends State<MechanicServiceHistoryScreen> {
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = !AppBreakpoints.of(context).isAtLeastExpanded;
    final colors = context.appColors;
    final userSession = context.watch<UserProfileProvider>();
    final userData = userSession.userData;

    if (userData == null || userData.idUsuario.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String mechanicId = userData.idUsuario;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isMobile
          ? AppBar(
              title: Text(
                'Mis Servicios Realizados',
                style: GoogleFonts.inter(
                  color: colors.primary,
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: IconThemeData(color: colors.primary),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
            )
          : null,
      drawer: isMobile ? const Drawer(child: MechanicSidebar()) : null,
      body: Row(
        children: [
          if (!isMobile) const MechanicSidebar(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMobile)
                  Container(
                    height: 64,
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 32),
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: colors.textSecondary.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'MIS SERVICIOS REALIZADOS',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: Responsive.fontSize(context, 20),
                            color: colors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
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
                              ? 'Filtrar por Fechas'
                              : '${DateFormat('dd/MM/yy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_dateRange!.end)}',
                        ),
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
                      if (_dateRange != null)
                        IconButton(
                          icon: Icon(Icons.clear, color: colors.error),
                          onPressed: () => setState(() => _dateRange = null),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
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
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: TextStyle(color: colors.textPrimary),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            'No has realizado ningún servicio aún.',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        );
                      }

                      final allRecords = snapshot.data!.docs
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
                        return Center(
                          child: Text(
                            'No hay servicios en este rango de fechas.',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = filteredRecords[index];
                          return _buildMechanicServiceCard(record, colors);
                        },
                      );
                    },
                  ),
                ),
              ],
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
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detalleRow(
                  'Fecha',
                  DateFormat('dd MMM yyyy').format(record.fecha),
                ),
                _detalleRow(
                  'Kilometraje',
                  '${record.kilometrajeServicio ?? '--'} km',
                ),
                if (record.costo != null && record.costo! > 0)
                  _detalleRow('Costo', '\$${record.costo!.toStringAsFixed(2)}'),
                if (record.manoDeObra != null && record.manoDeObra! > 0)
                  _detalleRow(
                    'Mano de obra',
                    '\$${record.manoDeObra!.toStringAsFixed(2)}',
                  ),
                if (record.descripcion != null &&
                    record.descripcion!.isNotEmpty)
                  _detalleRow('Descripción', record.descripcion!),
                if (record.materiales != null &&
                    record.materiales!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Materiales',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
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

  Widget _detalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildMechanicServiceCard(
    ServiceRecordModel record,
    AppColors colors,
  ) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: () => _mostrarDetalleServicio(record, colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                record.tipoServicio ?? 'Servicio Generico',
                style: GoogleFonts.inter(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
          const SizedBox(height: 8),
          Text(
            '${DateFormat('dd MMM yyyy').format(record.fecha)} • ${record.kilometrajeServicio ?? '--'} km',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
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
        ],
      ),
    );
  }
}
