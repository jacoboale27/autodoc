import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/admin_provider.dart';
import 'package:autodoc/core/providers/user_session_provider.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/taller_admin_card.dart';
import '../widgets/mecanico_admin_card.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/responsive.dart';

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
    final currentUid = context.read<UserSessionProvider>().currentUid;
    final colors = context.appColors;
    final mecanicos = provider.mecanicos;

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
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : RefreshIndicator(
              color: colors.primary,
              onRefresh: provider.fetchAllData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                        padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context, 16), vertical: Responsive.padding(context, 24)),
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
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final mecanico = mecanicos[index];
                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection(FirestoreCollections.usuarios)
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
                        },
                        childCount: mecanicos.length,
                      ),
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
                          padding: EdgeInsets.all(Responsive.padding(context, 24)),
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
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final taller = talleresFiltrados[index];
                            return TallerAdminCard(
                              taller: taller,
                              onAprobar: () {
                                _mostrarConfirmacion(
                                  context,
                                  'Aprobar Taller',
                                  '¿Estás seguro de que quieres aprobar este taller?',
                                  () => provider.aprobarTaller(currentUid, taller.idTaller),
                                );
                              },
                              onRechazar: () {
                                _mostrarConfirmacion(
                                  context,
                                  'Rechazar Taller',
                                  '¿Estás seguro de que quieres rechazar este taller?',
                                  () => provider.rechazarTaller(currentUid, taller.idTaller),
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
                          },
                          childCount: talleresFiltrados.length,
                        ),
                      ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
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
