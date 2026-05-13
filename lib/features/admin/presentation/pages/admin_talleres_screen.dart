import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/taller_admin_card.dart';

class AdminTalleresScreen extends StatefulWidget {
  const AdminTalleresScreen({super.key});

  @override
  State<AdminTalleresScreen> createState() => _AdminTalleresScreenState();
}

class _AdminTalleresScreenState extends State<AdminTalleresScreen> {
  String _filterStatus = 'todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchAllData();
    });
  }

  void _mostrarConfirmacion(BuildContext context, String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final currentUser = context.read<AuthProvider>().user;

    final talleresFiltrados = provider.talleres.where((t) {
      if (_filterStatus == 'todos') return true;
      return t.estado == _filterStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Talleres'),
        centerTitle: true,
      ),
      drawer: const AdminSidebar(),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('todos', 'Todos'),
                const SizedBox(width: 8),
                _buildFilterChip('pendiente', 'Pendientes'),
                const SizedBox(width: 8),
                _buildFilterChip('aprobado', 'Aprobados'),
                const SizedBox(width: 8),
                _buildFilterChip('suspendido', 'Suspendidos'),
              ],
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: provider.fetchAllData,
                    child: talleresFiltrados.isEmpty
                        ? const Center(child: Text('No hay talleres con este filtro'))
                        : ListView.builder(
                            itemCount: talleresFiltrados.length,
                            itemBuilder: (context, index) {
                              final taller = talleresFiltrados[index];
                              return TallerAdminCard(
                                taller: taller,
                                onAprobar: () {
                                  _mostrarConfirmacion(
                                    context,
                                    'Aprobar Taller',
                                    '¿Estás seguro de que quieres aprobar este taller?',
                                    () => provider.aprobarTaller(currentUser?.uid ?? 'admin', taller.idTaller),
                                  );
                                },
                                onRechazar: () {
                                  _mostrarConfirmacion(
                                    context,
                                    'Rechazar Taller',
                                    '¿Estás seguro de que quieres rechazar este taller?',
                                    () => provider.rechazarTaller(currentUser?.uid ?? 'admin', taller.idTaller),
                                  );
                                },
                                onSuspender: () {
                                  _mostrarConfirmacion(
                                    context,
                                    'Suspender Taller',
                                    '¿Estás seguro de que quieres suspender este taller?',
                                    () => provider.suspenderTaller(currentUser?.uid ?? 'admin', taller.idTaller, 'Suspensión administrativa'),
                                  );
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filterStatus = value);
      },
    );
  }
}
