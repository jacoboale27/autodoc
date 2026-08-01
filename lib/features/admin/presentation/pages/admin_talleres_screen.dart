import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/admin_provider.dart';
import '../widgets/taller_admin_card.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/mecanico_admin_card.dart';
import 'package:autodoc/core/models/workshop_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/utils/csv_export_util.dart';

class AdminTalleresScreen extends StatefulWidget {
  const AdminTalleresScreen({super.key});

  @override
  State<AdminTalleresScreen> createState() => _AdminTalleresScreenState();
}

/// Filtra la lista de talleres combinando (AND) estado, texto de búsqueda,
/// municipio, departamento y especialidad. Función pura y top-level para
/// que sea testeable de forma aislada; es el único punto de filtrado que
/// consumen tanto la lista visible como la exportación CSV.
List<WorkshopModel> filtrarTalleres(
  List<WorkshopModel> talleres, {
  String? estado,
  String? busqueda,
  String? municipio,
  String? departamento,
  String? especialidad,
}) {
  return talleres.where((t) {
    if (estado != null && estado != 'todos' && t.estado != estado) {
      return false;
    }
    if (busqueda != null &&
        busqueda.isNotEmpty &&
        !t.nombre.toLowerCase().contains(busqueda.toLowerCase())) {
      return false;
    }
    if (municipio != null &&
        municipio.isNotEmpty &&
        t.ubicacionMunicipio != municipio) {
      return false;
    }
    if (departamento != null &&
        departamento.isNotEmpty &&
        t.departamento != departamento) {
      return false;
    }
    if (especialidad != null &&
        especialidad.isNotEmpty &&
        t.especialidad != especialidad) {
      return false;
    }
    return true;
  }).toList();
}

class _AdminTalleresScreenState extends State<AdminTalleresScreen> {
  String _filterStatus = 'todos';
  String _searchQuery = '';
  String? _filterMunicipio;
  String? _filterDepartamento;
  String? _filterEspecialidad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchAllData();
    });
  }

  void _mostrarConfirmacion(
    BuildContext context,
    String title,
    String content,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.adminCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(context.l10n.adminConfirm),
          ),
        ],
      ),
    );
  }

  List<WorkshopModel> _aplicarFiltros(List<WorkshopModel> talleres) {
    return filtrarTalleres(
      talleres,
      estado: _filterStatus,
      busqueda: _searchQuery,
      municipio: _filterMunicipio,
      departamento: _filterDepartamento,
      especialidad: _filterEspecialidad,
    );
  }

  Future<void> _exportarTalleresCsv(List<WorkshopModel> talleres) async {
    final filtrados = _aplicarFiltros(talleres);
    if (filtrados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay talleres para exportar con los filtros actuales',
          ),
        ),
      );
      return;
    }
    final csv = buildCsv(
      [
        'Nombre',
        'Municipio',
        'Departamento',
        'Especialidad',
        'Estado',
        'Calificación promedio',
      ],
      [
        for (final t in filtrados)
          [
            t.nombre,
            t.ubicacionMunicipio ?? '',
            t.departamento ?? '',
            t.especialidad ?? '',
            t.estado,
            t.calificacionPromedio.toStringAsFixed(1),
          ],
      ],
    );
    await downloadCsv(
      'talleres_${DateTime.now().millisecondsSinceEpoch}.csv',
      csv,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${filtrados.length} talleres exportados a CSV.'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final currentUid = context.read<AuthSessionProvider>().currentUid;
    final colors = context.appColors;
    final mecanicos = provider.mecanicos.where((m) {
      return m.nombreCompleto.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          m.correo.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final talleresFiltrados = _aplicarFiltros(provider.talleres);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminManageWorkshops),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Exportar CSV',
            onPressed: () => _exportarTalleresCsv(provider.talleres),
          ),
        ],
      ),
      drawer: const AdminSidebar(),
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : RefreshIndicator(
              color: colors.primary,
              onRefresh: provider.fetchAllData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Buscar taller / mecánico...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildFiltrosAvanzados(provider.talleres),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mecánicos registrados',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 18),
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${mecanicos.length} usuario${mecanicos.length == 1 ? '' : 's'} con rol Taller o Mecánico',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 13),
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (mecanicos.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.padding(context, 16),
                          vertical: Responsive.padding(context, 24),
                        ),
                        child: Center(
                          child: Text(
                            'No hay mecánicos registrados en la plataforma',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final mecanico = mecanicos[index];
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection(FirestoreCollections.talleres)
                              .doc(mecanico.idUsuario)
                              .snapshots(),
                          builder: (context, snap) {
                            final data =
                                snap.data?.data() as Map<String, dynamic>?;
                            return MecanicoAdminCard(
                              usuario: mecanico,
                              calificacionPromedio:
                                  data?['calificacion_promedio']?.toDouble(),
                              totalResenias: data?['total_resenias'] ?? 0,
                            );
                          },
                        );
                      }, childCount: mecanicos.length),
                    ),
                  if (provider.talleres.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Solicitudes formales (colección Talleres)',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 16),
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
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
                          ],
                        ),
                      ),
                    ),
                    if (talleresFiltrados.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(
                            Responsive.padding(context, 24),
                          ),
                          child: Center(
                            child: Text(
                              'No hay talleres con este filtro',
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final taller = talleresFiltrados[index];
                          return TallerAdminCard(
                            taller: taller,
                            onAprobar: () {
                              _mostrarConfirmacion(
                                context,
                                'Aprobar Taller',
                                '¿Estás seguro de que quieres aprobar este taller?',
                                () => provider.aprobarTaller(
                                  currentUid,
                                  taller.idTaller,
                                ),
                              );
                            },
                            onRechazar: () {
                              _mostrarConfirmacion(
                                context,
                                'Rechazar Taller',
                                '¿Estás seguro de que quieres rechazar este taller?',
                                () => provider.rechazarTaller(
                                  currentUid,
                                  taller.idTaller,
                                ),
                              );
                            },
                            onSuspender: () {
                              _mostrarConfirmacion(
                                context,
                                'Suspender Taller',
                                '¿Estás seguro de que quieres suspender este taller?',
                                () => provider.suspenderTaller(
                                  currentUid,
                                  taller.idTaller,
                                  'Suspensión administrativa',
                                ),
                              );
                            },
                          );
                        }, childCount: talleresFiltrados.length),
                      ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }

  Widget _buildFiltrosAvanzados(List<WorkshopModel> talleres) {
    // Municipios: derivados dinámicamente y, si hay un departamento
    // seleccionado, acotados a los talleres de ese departamento.
    final talleresParaMunicipio = _filterDepartamento == null
        ? talleres
        : talleres.where((t) => t.departamento == _filterDepartamento);
    final municipios =
        talleresParaMunicipio
            .map((t) => t.ubicacionMunicipio)
            .whereType<String>()
            .where((m) => m.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final departamentos =
        talleres
            .map((t) => t.departamento)
            .whereType<String>()
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final especialidades =
        talleres
            .map((t) => t.especialidad)
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    // Si el municipio seleccionado ya no aplica al departamento activo,
    // se limpia para evitar un filtro imposible de satisfacer.
    if (_filterMunicipio != null && !municipios.contains(_filterMunicipio)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _filterMunicipio = null);
      });
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: _filterDepartamento,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            hint: const Text('Departamento'),
            items: [null, ...departamentos]
                .map(
                  (d) => DropdownMenuItem(value: d, child: Text(d ?? 'Todos')),
                )
                .toList(),
            onChanged: (value) => setState(() => _filterDepartamento = value),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: municipios.contains(_filterMunicipio)
                ? _filterMunicipio
                : null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            hint: const Text('Municipio'),
            items: [null, ...municipios]
                .map(
                  (m) => DropdownMenuItem(value: m, child: Text(m ?? 'Todos')),
                )
                .toList(),
            onChanged: (value) => setState(() => _filterMunicipio = value),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: _filterEspecialidad,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            hint: const Text('Especialidad'),
            items: [null, ...especialidades]
                .map(
                  (e) => DropdownMenuItem(value: e, child: Text(e ?? 'Todos')),
                )
                .toList(),
            onChanged: (value) => setState(() => _filterEspecialidad = value),
          ),
        ),
      ],
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
