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

  void _mostrarDialogoCambiarRol(BuildContext context, String targetUid, String rolActual, String adminUid) {
    final roles = ['Propietario', 'Mecanico', 'Administrador'];
    String? selectedRol;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Cambiar Rol de Usuario'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rol actual: $rolActual',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text('Selecciona el nuevo rol:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...roles.where((r) => r != rolActual).map((rol) => ListTile(
                  title: Text(rol),
                  subtitle: Text(_descRol(rol), style: const TextStyle(fontSize: 12)),
                  trailing: selectedRol == rol
                      ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                      : const Icon(Icons.circle_outlined, color: Colors.grey),
                  onTap: () => setDialogState(() => selectedRol = rol),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: selectedRol == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        context.read<AdminProvider>().cambiarRolUsuario(
                              adminUid,
                              targetUid,
                              selectedRol!,
                            );
                      },
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _descRol(String rol) {
    switch (rol) {
      case 'Propietario':
        return 'Puede registrar vehículos y ver historial';
      case 'Mecanico':
        return 'Puede iniciar servicios y buscar vehículos';
      case 'Administrador':
        return 'Acceso total al panel de administración';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final authProvider = context.watch<AuthProvider>();
    final adminUid = authProvider.adminUid;

    // Show success/error snackbar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        provider.clearMessages();
      }
      if (provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error!),
            backgroundColor: Colors.red,
          ),
        );
        provider.clearMessages();
      }
    });

    final usuariosFiltrados = provider.usuarios.where((u) {
      return u.nombreCompleto.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             u.correo.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(Icons.people, size: 16),
              label: Text('${provider.usuarios.length}'),
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
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
                    child: usuariosFiltrados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty ? 'No hay usuarios registrados' : 'Sin resultados para "$_searchQuery"',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: usuariosFiltrados.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final usuario = usuariosFiltrados[index];
                              return AccountRow(
                                usuario: usuario,
                                isCurrentAdmin: usuario.idUsuario == adminUid,
                                onSuspender: () {
                                  _mostrarDialogoMotivo(context, 'Suspender Usuario', (motivo) {
                                    provider.suspenderUsuario(adminUid, usuario.idUsuario, motivo);
                                  });
                                },
                                onReactivar: () {
                                  provider.reactivarUsuario(adminUid, usuario.idUsuario);
                                },
                                onCambiarRol: () {
                                  _mostrarDialogoCambiarRol(
                                    context,
                                    usuario.idUsuario,
                                    usuario.rol,
                                    adminUid,
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
