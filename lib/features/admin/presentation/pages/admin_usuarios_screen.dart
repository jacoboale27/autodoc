import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/account_row.dart';

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchUsuarios();
    });
  }

  void _mostrarDialogoMotivo(BuildContext context, String title, Function(String) onConfirm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Motivo / Detalle'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm(controller.text.isEmpty ? 'Sin motivo' : controller.text);
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
    final currentUser = context.watch<AuthProvider>().user;

    final usuariosFiltrados = provider.usuarios.where((u) {
      return u.nombreCompleto.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             u.correo.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        centerTitle: true,
      ),
      drawer: const AdminSidebar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar usuario...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: provider.fetchUsuarios,
                    child: ListView.separated(
                      itemCount: usuariosFiltrados.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final usuario = usuariosFiltrados[index];
                        return AccountRow(
                          usuario: usuario,
                          isCurrentAdmin: usuario.idUsuario == currentUser?.uid,
                          onSuspender: () {
                            _mostrarDialogoMotivo(context, 'Suspender Usuario', (motivo) {
                              provider.suspenderUsuario(currentUser?.uid ?? 'admin', usuario.idUsuario, motivo);
                            });
                          },
                          onReactivar: () {
                            provider.reactivarUsuario(currentUser?.uid ?? 'admin', usuario.idUsuario);
                          },
                          onCambiarRol: () {
                            // En un entorno real se mostraría un selector de roles
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Función de cambiar rol en desarrollo')),
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
}
