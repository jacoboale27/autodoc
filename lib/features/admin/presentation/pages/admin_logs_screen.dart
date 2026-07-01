import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_sidebar.dart';
import 'package:autodoc/core/utils/responsive.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Actividad'),
        centerTitle: true,
      ),
      drawer: const AdminSidebar(),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.fetchLogs,
              child: provider.logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: Responsive.iconSize(context, 64), color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No hay registros de actividad',
                            style: TextStyle(color: Colors.grey[500], fontSize: Responsive.fontSize(context, 16)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.all(Responsive.padding(context, 16)),
                      itemCount: provider.logs.length,
                      separatorBuilder: (context, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final log = provider.logs[index];
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
