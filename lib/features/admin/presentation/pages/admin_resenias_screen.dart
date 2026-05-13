import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/admin_sidebar.dart';

class AdminReseniasScreen extends StatefulWidget {
  const AdminReseniasScreen({super.key});

  @override
  State<AdminReseniasScreen> createState() => _AdminReseniasScreenState();
}

class _AdminReseniasScreenState extends State<AdminReseniasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchAllData();
    });
  }

  void _mostrarConfirmarEliminar(BuildContext context, String idResenia) {
    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Reseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Estás seguro de que quieres eliminar esta reseña? Esta acción no se puede deshacer.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Motivo de eliminación',
                hintText: 'Ej: Contenido ofensivo',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              adminProvider.eliminarResenia(
                authProvider.user?.uid ?? 'admin',
                idResenia,
                controller.text.isEmpty ? 'Incumplimiento de normas' : controller.text,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderación de Reseñas'),
        centerTitle: true,
      ),
      drawer: const AdminSidebar(),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.fetchAllData,
              child: provider.resenias.isEmpty
                  ? const Center(child: Text('No hay reseñas registradas'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.resenias.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final resenia = provider.resenias[index];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: List.generate(5, (i) {
                                        return Icon(
                                          Icons.star,
                                          size: 18,
                                          color: i < resenia.estrellas ? Colors.amber : Colors.grey[300],
                                        );
                                      }),
                                    ),
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(resenia.fechaResenia),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  resenia.comentario ?? 'Sin comentario',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('ID Taller: ${resenia.idTaller}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text('ID Usuario: ${resenia.idUsuario}', style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    IconButton(
                                      onPressed: () => _mostrarConfirmarEliminar(context, resenia.idResenia),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Eliminar reseña',
                                    ),
                                  ],
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
}
