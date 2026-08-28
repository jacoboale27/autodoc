import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_sidebar.dart';
import 'package:autodoc/core/models/admin_log_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/csv_export_util.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  /// Filters
  String? _filterModule;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;
  String _filterType = 'Todos'; // 'Todos', 'SUSPENDER', 'APROBAR', 'CAMBIAR'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchLogs();
    });
  }

  IconData _iconForAction(String accion) {
    switch (accion) {
      case 'SUSPENDER_USUARIO':
        return Icons.person_off;
      case 'REACTIVAR_USUARIO':
        return Icons.person_add;
      case 'CAMBIAR_ROL':
        return Icons.swap_horiz;
      case 'APROBAR_TALLER':
        return Icons.check_circle;
      case 'RECHAZAR_TALLER':
        return Icons.cancel;
      case 'SUSPENDER_TALLER':
        return Icons.block;
      case 'ELIMINAR_RESENIA':
        return Icons.delete;
      default:
        return Icons.history;
    }
  }

  Color _colorForAction(String accion, AppColors colors) {
    if (accion.contains('SUSPENDER') ||
        accion.contains('RECHAZAR') ||
        accion.contains('ELIMINAR')) {
      return colors.error;
    }
    if (accion.contains('REACTIVAR') || accion.contains('APROBAR')) {
      return colors.success;
    }
    if (accion.contains('CAMBIAR')) {
      return colors.warning;
    }
    return colors.primary;
  }

  /// Applies current filters to the full list of logs
  List<AdminLogModel> _filteredLogs(List<AdminLogModel> logs) {
    return logs.where((log) {
      if (_filterType != 'Todos' && !log.accion.contains(_filterType)) {
        return false;
      }
      if (_filterModule != null && log.modulo != _filterModule) {
        return false;
      }
      if (_filterDateFrom != null && log.fecha.isBefore(_filterDateFrom!)) {
        return false;
      }
      if (_filterDateTo != null &&
          log.fecha.isAfter(_filterDateTo!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Generates a CSV string from the logs and triggers a real file download
  Future<void> _exportToCsv(List<AdminLogModel> logs) async {
    final filtered = _filteredLogs(logs);
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }

    final csv = buildCsv(
      ['Fecha', 'Acción', 'Módulo', 'Referencia ID', 'Detalle'],
      [
        for (final log in filtered)
          [
            DateFormat('yyyy-MM-dd HH:mm:ss').format(log.fecha),
            log.accion,
            log.modulo,
            log.referenciaId,
            log.detalle,
          ],
      ],
    );

    await downloadCsv('logs_${DateTime.now().millisecondsSinceEpoch}.csv', csv);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${filtered.length} registros exportados a CSV.'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  Future<void> _pickDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _filterDateFrom ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _filterDateFrom = picked);
  }

  Future<void> _pickDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDateTo ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _filterDateTo = picked);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final colors = context.appColors;
    final filtered = _filteredLogs(provider.logs);
    final df = DateFormat('dd/MM/yy');

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminLogsTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Exportar CSV',
            onPressed: () => _exportToCsv(provider.logs),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filtros',
            onPressed: () => _showFilterSheet(),
          ),
        ],
      ),
      drawer: const AdminSidebar(),
      body: Column(
        children: [
          // Active filters chip row
          if (_filterType != 'Todos' ||
              _filterDateFrom != null ||
              _filterDateTo != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.padding(context, 12),
                vertical: Responsive.padding(context, 8),
              ),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_filterType != 'Todos')
                    Chip(
                      label: Text(_filterType),
                      onDeleted: () => setState(() => _filterType = 'Todos'),
                    ),
                  if (_filterDateFrom != null)
                    Chip(
                      label: Text('Desde: ${df.format(_filterDateFrom!)}'),
                      onDeleted: () => setState(() => _filterDateFrom = null),
                    ),
                  if (_filterDateTo != null)
                    Chip(
                      label: Text('Hasta: ${df.format(_filterDateTo!)}'),
                      onDeleted: () => setState(() => _filterDateTo = null),
                    ),
                  Chip(
                    label: Text('${filtered.length} registros'),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                  ),
                ],
              ),
            ),

          // Main list
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: provider.fetchLogs,
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: Responsive.iconSize(context, 64),
                                  color: colors.textSecondary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  context.l10n.adminNoRecentActivity,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: Responsive.fontSize(context, 16),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.all(
                              Responsive.padding(context, 16),
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (context, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final log = filtered[index];
                              final actionColor = _colorForAction(
                                log.accion,
                                colors,
                              );

                              return AppCard(
                                margin: EdgeInsets.zero,
                                padding: EdgeInsets.all(
                                  Responsive.padding(context, 16),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                        Responsive.padding(context, 10),
                                      ),
                                      decoration: BoxDecoration(
                                        color: actionColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _iconForAction(log.accion),
                                        color: actionColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  log.accion.replaceAll(
                                                    '_',
                                                    ' ',
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize:
                                                        Responsive.fontSize(
                                                          context,
                                                          14,
                                                        ),
                                                    color: actionColor,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                DateFormat(
                                                  'dd/MM/yy HH:mm',
                                                ).format(log.fecha),
                                                style: AppTextStyles.labelSmall
                                                    .copyWith(
                                                      fontSize:
                                                          Responsive.fontSize(
                                                            context,
                                                            11,
                                                          ),
                                                      color:
                                                          colors.textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            log.detalle,
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  fontSize: Responsive.fontSize(
                                                    context,
                                                    13,
                                                  ),
                                                  color: colors.textPrimary,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              _buildTag(
                                                Icons.category,
                                                log.modulo,
                                              ),
                                              const SizedBox(width: 8),
                                              _buildTag(
                                                Icons.fingerprint,
                                                log.referenciaId.length > 12
                                                    ? '${log.referenciaId.substring(0, 12)}...'
                                                    : log.referenciaId,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.all(Responsive.padding(context, 24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtros',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Tipo de acción',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                          'Todos',
                          'SUSPENDER',
                          'APROBAR',
                          'CAMBIAR',
                          'ELIMINAR',
                        ].map((type) {
                          return ChoiceChip(
                            label: Text(type),
                            selected: _filterType == type,
                            onSelected: (_) {
                              setSheetState(() => _filterType = type);
                              setState(() => _filterType = type);
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Rango de fechas',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: _filterDateFrom != null
                              ? DateFormat('dd/MM/yy').format(_filterDateFrom!)
                              : 'Desde',
                          type: AppButtonType.outlined,
                          size: AppButtonSize.small,
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            await _pickDateFrom();
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: _filterDateTo != null
                              ? DateFormat('dd/MM/yy').format(_filterDateTo!)
                              : 'Hasta',
                          type: AppButtonType.outlined,
                          size: AppButtonSize.small,
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            await _pickDateTo();
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'Limpiar',
                          type: AppButtonType.outlined,
                          size: AppButtonSize.small,
                          onPressed: () {
                            setState(() {
                              _filterType = 'Todos';
                              _filterDateFrom = null;
                              _filterDateTo = null;
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: 'Aplicar',
                          size: AppButtonSize.small,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 8),
        vertical: Responsive.padding(context, 3),
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: Responsive.iconSize(context, 12),
            color: context.appColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: Responsive.fontSize(context, 11),
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
