import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_sidebar.dart';
import 'package:autodoc/core/models/admin_log_model.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

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

  Color _colorForAction(String accion) {
    if (accion.contains('SUSPENDER') || accion.contains('RECHAZAR') || accion.contains('ELIMINAR')) {
      return Colors.red;
    }
    if (accion.contains('REACTIVAR') || accion.contains('APROBAR')) {
      return Colors.green;
    }
    if (accion.contains('CAMBIAR')) {
      return Colors.orange;
    }
    return Colors.blue;
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
      if (_filterDateTo != null && log.fecha.isAfter(_filterDateTo!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Generates a CSV string from the logs and copies it to clipboard
  Future<void> _exportToCsv(List<AdminLogModel> logs) async {
    final filtered = _filteredLogs(logs);
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }

    final buffer = StringBuffer();
    // Header
    buffer.writeln('Fecha,Acción,Módulo,Referencia ID,Detalle');

    // Rows
    for (final log in filtered) {
      final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(log.fecha);
      // Escape commas/quotes in fields
      String escapeText(String s) => '"${s.replaceAll('"', '""')}"';
      buffer.writeln(
        '${escapeText(fecha)},${escapeText(log.accion)},${escapeText(log.modulo)},${escapeText(log.referenciaId)},${escapeText(log.detalle)}',
      );
    }

    final csv = buffer.toString();
    await Clipboard.setData(ClipboardData(text: csv));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${filtered.length} registros copiados como CSV al portapapeles.'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  Future<void> _pickDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDateFrom ?? DateTime.now().subtract(const Duration(days: 30)),
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
          if (_filterType != 'Todos' || _filterDateFrom != null || _filterDateTo != null)
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
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                                Icon(Icons.history, size: Responsive.iconSize(context, 64), color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  context.l10n.adminNoRecentActivity,
                                  style: TextStyle(color: Colors.grey[500], fontSize: Responsive.fontSize(context, 16)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.all(Responsive.padding(context, 16)),
                            itemCount: filtered.length,
                            separatorBuilder: (context, i) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final log = filtered[index];
                              final actionColor = _colorForAction(log.accion);

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(Responsive.padding(context, 16)),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(Responsive.padding(context, 10)),
                                        decoration: BoxDecoration(
                                          color: actionColor.withValues(alpha: 0.1),
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
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    log.accion.replaceAll('_', ' '),
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: Responsive.fontSize(context, 14),
                                                      color: actionColor,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat('dd/MM/yy HH:mm').format(log.fecha),
                                                  style: TextStyle(fontSize: Responsive.fontSize(context, 11), color: Colors.grey[500]),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              log.detalle,
                                              style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: Colors.grey[700]),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                _buildTag(Icons.category, log.modulo),
                                                const SizedBox(width: 8),
                                                _buildTag(Icons.fingerprint, log.referenciaId.length > 12
                                                    ? '${log.referenciaId.substring(0, 12)}...'
                                                    : log.referenciaId),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.all(Responsive.padding(context, 24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filtros', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                Text('Tipo de acción', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Todos', 'SUSPENDER', 'APROBAR', 'CAMBIAR', 'ELIMINAR'].map((type) {
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

                Text('Rango de fechas', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_filterDateFrom != null ? DateFormat('dd/MM/yy').format(_filterDateFrom!) : 'Desde'),
                        onPressed: () async {
                          await _pickDateFrom();
                          setSheetState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_filterDateTo != null ? DateFormat('dd/MM/yy').format(_filterDateTo!) : 'Hasta'),
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
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _filterType = 'Todos';
                            _filterDateFrom = null;
                            _filterDateTo = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Limpiar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context, 8), vertical: Responsive.padding(context, 3)),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Responsive.iconSize(context, 12), color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: Responsive.fontSize(context, 11), color: Colors.grey[700])),
        ],
      ),
    );
  }
}
