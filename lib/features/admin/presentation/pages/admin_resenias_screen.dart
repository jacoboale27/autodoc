import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';
import 'package:autodoc/core/providers/user_session_provider.dart';
import '../widgets/admin_sidebar.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/widgets/translated_text.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

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
    final userSession = context.read<UserSessionProvider>();
    final adminProvider = context.read<AdminProvider>();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          title: Text(ctx.l10n.adminDeleteReview),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.adminCancel)),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                adminProvider.eliminarResenia(
                  userSession.currentUid,
                  idResenia,
                  controller.text.isEmpty ? 'Incumplimiento de normas' : controller.text,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: Colors.white,
              ),
              child: Text(ctx.l10n.adminDelete),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminModerateReviews),
        centerTitle: true,
      ),
      drawer: const AdminSidebar(),
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : RefreshIndicator(
              color: colors.primary,
              onRefresh: provider.fetchAllData,
              child: provider.resenias.isEmpty
                  ? Center(
                      child: Text(
                        'No hay reseñas registradas',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.all(Responsive.padding(context, 16)),
                      itemCount: provider.resenias.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final resenia = provider.resenias[index];
                        return AppCard(
                          padding: EdgeInsets.all(Responsive.padding(context, 16)),
                          margin: EdgeInsets.zero,
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
                                        size: Responsive.iconSize(context, 18),
                                        color: i < resenia.estrellas
                                            ? colors.warning
                                            : colors.textSecondary.withValues(alpha: 0.2),
                                      );
                                    }),
                                  ),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(resenia.fechaResenia),
                                    style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: colors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TranslatedText(
                                resenia.comentario ?? 'Sin comentario',
                                style: TextStyle(fontSize: Responsive.fontSize(context, 15)),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Taller: ${provider.nombreTaller(resenia.idTaller)}',
                                        style: TextStyle(fontSize: Responsive.fontSize(context, 12), fontWeight: FontWeight.bold, color: colors.textPrimary),
                                      ),
                                      Text(
                                        'Cliente: ${provider.nombreUsuario(resenia.idUsuario)}',
                                        style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: colors.textSecondary),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    onPressed: () => _mostrarConfirmarEliminar(context, resenia.idResenia),
                                    icon: Icon(Icons.delete_outline, color: colors.error),
                                    tooltip: 'Eliminar reseña',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
