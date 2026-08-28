import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/theme/app_estado_cuenta.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/admin_provider.dart';
import '../widgets/taller_admin_card.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/mecanico_admin_card.dart';
import 'package:autodoc/core/models/workshop_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
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
    // Comparacion por estado NORMALIZADO y no por texto crudo: 'activo' y
    // 'aprobado' significan lo mismo (aprobarUsuario escribe uno, aprobarTaller
    // el otro), asi que filtrar por igualdad de string dejaba fuera de
    // "Aprobados" a la mitad de los talleres aprobados.
    if (estado != null &&
        estado != 'todos' &&
        AppEstadoCuenta.parse(t.estado) != AppEstadoCuenta.parse(estado)) {
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
        content: AppDialogContent(child: Text(content)),
        actions: [
          AppButton(
            text: context.l10n.adminCancel,
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            text: context.l10n.adminConfirm,
            size: AppButtonSize.small,
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
          ),
        ],
      ),
    );
  }

  /// Pide el motivo antes de rechazar.
  ///
  /// A diferencia de `_mostrarDialogoMotivo` en admin_usuarios_screen, aqui el
  /// motivo NO puede quedar vacio ni caer en un 'Sin motivo' por defecto: es
  /// lo unico que el taller va a leer para saber que corregir, y un rechazo
  /// mudo solo consigue que reenvie lo mismo. El boton permanece deshabilitado
  /// mientras no haya texto.
  void _mostrarDialogoRechazo(
    BuildContext context,
    String nombreTaller,
    void Function(String motivo) onConfirm,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar taller'),
        content: AppDialogContent(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El taller «$nombreTaller» verá este mensaje y podrá corregir y '
                'volver a enviar su solicitud.',
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => AppTextField(
                  controller: controller,
                  enabled: true,
                  autofocus: true,
                  maxLines: 3,
                  maxLength: 300,
                  hintText: 'Ej.: la foto de la fachada no deja ver el rótulo.',
                  label: 'Motivo del rechazo',
                  errorText: value.text.trim().isEmpty
                      ? 'Explica qué debe corregir'
                      : null,
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppButton(
            text: context.l10n.adminCancel,
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => AppButton(
              text: context.l10n.adminConfirm,
              size: AppButtonSize.small,
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      onConfirm(controller.text.trim());
                    },
            ),
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
                      child: AppTextField(
                        label: 'Buscar taller / mecánico',
                        prefixIcon: const Icon(Icons.search),
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
                            // Un taller PENDIENTE ya no se aprueba desde
                            // aqui: esta tarjeta no enseña la evidencia, y
                            // aprobar sin mirarla es lo que la bandeja de
                            // verificacion existe para impedir.
                            onVerExpediente: () =>
                                context.go('/admin/verificaciones'),
                            onReactivar: () {
                              _mostrarConfirmacion(
                                context,
                                'Reactivar Taller',
                                '¿Estás seguro de que quieres reactivar este taller?',
                                // `reactivarTaller` y no `aprobarTaller`: el
                                // efecto en `estado` es el mismo, pero el log
                                // de auditoria tiene que decir lo que de
                                // verdad paso.
                                () => provider.reactivarTaller(
                                  currentUid,
                                  taller.idTaller,
                                ),
                              );
                            },
                            onRechazar: () {
                              _mostrarDialogoRechazo(
                                context,
                                taller.nombre,
                                (motivo) => provider.rechazarTaller(
                                  currentUid,
                                  taller.idTaller,
                                  motivo,
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
            isExpanded: true,
            items: [null, ...departamentos]
                .map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text(d ?? 'Todos', overflow: TextOverflow.ellipsis),
                  ),
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
            isExpanded: true,
            items: [null, ...municipios]
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(m ?? 'Todos', overflow: TextOverflow.ellipsis),
                  ),
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
            isExpanded: true,
            items: [null, ...especialidades]
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e ?? 'Todos', overflow: TextOverflow.ellipsis),
                  ),
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
