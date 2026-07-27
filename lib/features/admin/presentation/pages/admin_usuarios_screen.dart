import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/account_row.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  String _searchQuery = '';
  String _filterRol = 'Todos';
  String _filterEstado = 'Todos'; // Todos, activo, suspendido, Pendiente
  DateTime? _filterDateFrom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchUsuarios();
    });
  }

  void _mostrarDialogoMotivo(
    BuildContext context,
    String title,
    Function(String) onConfirm,
  ) {
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.adminCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm(
                controller.text.isEmpty ? 'Sin motivo' : controller.text,
              );
            },
            child: Text(context.l10n.adminConfirm),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCambiarRol(
    BuildContext context,
    String targetUid,
    String rolActual,
    String adminUid,
  ) {
    final roles = ['Propietario', 'Mecanico', 'Administrador'];
    String? selectedRol;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(context.l10n.adminChangeRole),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rol actual: $rolActual',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: Responsive.fontSize(context, 13),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.adminSelectNewRole,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...roles
                    .where((r) => r != rolActual)
                    .map(
                      (rol) => ListTile(
                        title: Text(rol),
                        subtitle: Text(
                          _descRol(rol),
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 12),
                          ),
                        ),
                        trailing: selectedRol == rol
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : const Icon(
                                Icons.circle_outlined,
                                color: Colors.grey,
                              ),
                        onTap: () => setDialogState(() => selectedRol = rol),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.adminCancel),
              ),
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
                child: Text(context.l10n.adminConfirm),
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
    final userSession = context.watch<UserProfileProvider>();
    final currentUid = (userSession.userData?.idUsuario ?? "");
    final colors = context.appColors;

    // Show success/error snackbar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.successMessage!),
            backgroundColor: colors.secondary,
          ),
        );
        provider.clearMessages();
      }
      if (provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error!),
            backgroundColor: colors.error,
          ),
        );
        provider.clearMessages();
      }
    });

    final usuariosFiltrados = provider.usuarios.where((u) {
      final matchSearch =
          u.nombreCompleto.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.correo.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchRol = _filterRol == 'Todos' || u.rol == _filterRol;
      final matchEstado =
          _filterEstado == 'Todos' ||
          u.estado.toLowerCase() == _filterEstado.toLowerCase();
      final matchDate =
          _filterDateFrom == null || u.fechaRegistro.isAfter(_filterDateFrom!);
      return matchSearch && matchRol && matchEstado && matchDate;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminManageUsers),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filtros avanzados',
            onPressed: _showAdvancedFilters,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(
                Icons.people,
                size: Responsive.iconSize(context, 16),
              ),
              label: Text('${usuariosFiltrados.length}'),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
      drawer: const AdminSidebar(),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(Responsive.padding(context, 16.0)),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar usuario...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.padding(context, 16.0),
            ),
            child: Row(
              children: [
                _buildFilterChip('Todos'),
                const SizedBox(width: 8),
                _buildFilterChip('Propietario'),
                const SizedBox(width: 8),
                _buildFilterChip('Mecanico'),
                const SizedBox(width: 8),
                _buildFilterChip('Administrador'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: provider.isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  )
                : RefreshIndicator(
                    color: colors.primary,
                    onRefresh: provider.fetchUsuarios,
                    child: usuariosFiltrados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_search,
                                  size: Responsive.iconSize(context, 64),
                                  color: colors.textSecondary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No hay usuarios registrados'
                                      : 'Sin resultados para "$_searchQuery"',
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.padding(context, 16),
                            ),
                            itemCount: usuariosFiltrados.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final usuario = usuariosFiltrados[index];
                              return AccountRow(
                                usuario: usuario,
                                isCurrentAdmin: usuario.idUsuario == currentUid,
                                onSuspender: () {
                                  _mostrarDialogoMotivo(
                                    context,
                                    'Suspender Usuario',
                                    (motivo) {
                                      provider.suspenderUsuario(
                                        currentUid,
                                        usuario.idUsuario,
                                        motivo,
                                      );
                                    },
                                  );
                                },
                                onReactivar: () {
                                  provider.reactivarUsuario(
                                    currentUid,
                                    usuario.idUsuario,
                                  );
                                },
                                onCambiarRol: () {
                                  _mostrarDialogoCambiarRol(
                                    context,
                                    usuario.idUsuario,
                                    usuario.rol,
                                    currentUid,
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

  Widget _buildFilterChip(String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filterRol == label,
      onSelected: (selected) {
        if (selected) setState(() => _filterRol = label);
      },
    );
  }

  void _showAdvancedFilters() {
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
                    'Filtros Avanzados',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Estado de cuenta',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Todos', 'activo', 'suspendido', 'Pendiente']
                        .map((estado) {
                          return ChoiceChip(
                            label: Text(
                              estado == 'Todos'
                                  ? 'Todos'
                                  : estado[0].toUpperCase() +
                                        estado.substring(1),
                            ),
                            selected: _filterEstado == estado,
                            onSelected: (_) {
                              setSheetState(() => _filterEstado = estado);
                              setState(() => _filterEstado = estado);
                            },
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Registrado desde',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _filterDateFrom != null
                          ? 'Desde ${_filterDateFrom!.day}/${_filterDateFrom!.month}/${_filterDateFrom!.year}'
                          : 'Seleccionar fecha',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _filterDateFrom ??
                            DateTime.now().subtract(const Duration(days: 30)),
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setSheetState(() => _filterDateFrom = picked);
                        setState(() => _filterDateFrom = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _filterEstado = 'Todos';
                              _filterDateFrom = null;
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
          },
        );
      },
    );
  }
}
