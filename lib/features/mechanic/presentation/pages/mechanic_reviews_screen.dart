import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/review_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/widgets/translated_text.dart';

class MechanicReviewsScreen extends StatefulWidget {
  const MechanicReviewsScreen({super.key});

  @override
  State<MechanicReviewsScreen> createState() => _MechanicReviewsScreenState();
}

class _MechanicReviewsScreenState extends State<MechanicReviewsScreen> {
  ReviewSortOrder _orden = ReviewSortOrder.recientes;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final userSession = context.watch<UserProfileProvider>();
    final userData = userSession.userData;

    if (userData == null || userData.idUsuario.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tallerId = userData.idUsuario;
    final reviewService = ReviewService();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isMobile
          ? AppBar(
              title: Text(
                'Mis Reseñas',
                style: GoogleFonts.inter(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: IconThemeData(color: colors.primary),
            )
          : null,
      drawer: isMobile ? const Drawer(child: MechanicSidebar()) : null,
      body: Row(
        children: [
          if (!isMobile) const MechanicSidebar(),
          Expanded(
            child: Column(
              children: [
                if (!isMobile)
                  Container(
                    height: 64,
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 32),
                    ),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: colors.textSecondary.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Text(
                      'MIS RESEÑAS',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: Responsive.fontSize(context, 20),
                        color: colors.primary,
                      ),
                    ),
                  ),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(FirestoreCollections.usuarios)
                        .doc(tallerId)
                        .snapshots(),
                    builder: (context, userSnap) {
                      final userData =
                          userSnap.data?.data() as Map<String, dynamic>?;
                      final promedio =
                          userData?['calificacion_promedio']?.toDouble() ?? 0.0;
                      final total = userData?['total_resenias'] ?? 0;

                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(
                              Responsive.padding(context, 24),
                            ),
                            child: AppCard(
                              margin: EdgeInsets.zero,
                              padding: EdgeInsets.all(
                                Responsive.padding(context, 24),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      Responsive.padding(context, 16),
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.warning.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.star_rounded,
                                      color: colors.warning,
                                      size: Responsive.iconSize(context, 40),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          promedio > 0
                                              ? promedio.toStringAsFixed(1)
                                              : '—',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.fontSize(
                                              context,
                                              32,
                                            ),
                                            fontWeight: FontWeight.bold,
                                            color: colors.primary,
                                          ),
                                        ),
                                        Text(
                                          '$total reseña${total == 1 ? '' : 's'} de clientes',
                                          style: GoogleFonts.inter(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: StreamBuilder<List<ReviewModel>>(
                              stream: reviewService.watchReviewsForTaller(
                                tallerId,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                    child: CircularProgressIndicator(
                                      color: colors.primary,
                                    ),
                                  );
                                }

                                final reviewsSinOrdenar = snapshot.data ?? [];
                                final reviews = ordenarResenias(
                                  reviewsSinOrdenar,
                                  _orden,
                                );
                                if (reviews.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                        Responsive.padding(context, 32),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.rate_review_outlined,
                                            size: Responsive.iconSize(
                                              context,
                                              56,
                                            ),
                                            color: colors.textSecondary
                                                .withValues(alpha: 0.4),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Aún no tienes reseñas',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              color: colors.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Los propietarios pueden calificarte desde el directorio de talleres o su historial de servicios.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  children: [
                                    _buildDistribution(
                                      reviews,
                                      colors,
                                      context,
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.padding(
                                          context,
                                          24,
                                        ),
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: DropdownButton<ReviewSortOrder>(
                                          value: _orden,
                                          onChanged: (value) {
                                            if (value == null) return;
                                            setState(() => _orden = value);
                                          },
                                          items: const [
                                            DropdownMenuItem(
                                              value: ReviewSortOrder.recientes,
                                              child: Text('Más Recientes'),
                                            ),
                                            DropdownMenuItem(
                                              value: ReviewSortOrder.masAltas,
                                              child: Text('Más Altas'),
                                            ),
                                            DropdownMenuItem(
                                              value: ReviewSortOrder.masBajas,
                                              child: Text('Más Bajas'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          0,
                                          24,
                                          24,
                                        ),
                                        itemCount: reviews.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(height: 12),
                                        itemBuilder: (context, index) {
                                          final r = reviews[index];
                                          return AppCard(
                                            margin: EdgeInsets.zero,
                                            padding: EdgeInsets.all(
                                              Responsive.padding(context, 16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: List.generate(5, (
                                                        i,
                                                      ) {
                                                        return Icon(
                                                          Icons.star,
                                                          size:
                                                              Responsive.iconSize(
                                                                context,
                                                                16,
                                                              ),
                                                          color: i < r.estrellas
                                                              ? colors.warning
                                                              : colors
                                                                    .textSecondary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    ),
                                                        );
                                                      }),
                                                    ),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          DateFormat(
                                                            'dd MMM yyyy',
                                                          ).format(
                                                            r.fechaResenia,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize:
                                                                Responsive.fontSize(
                                                                  context,
                                                                  12,
                                                                ),
                                                            color: colors
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                        if (r.comentario !=
                                                                null &&
                                                            r
                                                                .comentario!
                                                                .isNotEmpty &&
                                                            !r.isReported)
                                                          IconButton(
                                                            icon: Icon(
                                                              Icons
                                                                  .flag_outlined,
                                                              size: 16,
                                                              color: colors
                                                                  .textSecondary,
                                                            ),
                                                            onPressed: () async {
                                                              final confirm = await showDialog<bool>(
                                                                context:
                                                                    context,
                                                                builder: (ctx) => AlertDialog(
                                                                  title: const Text(
                                                                    'Reportar Reseña',
                                                                  ),
                                                                  content:
                                                                      const Text(
                                                                        '¿Estás seguro de que deseas reportar esta reseña por lenguaje inapropiado o falso? Será revisada por el equipo de moderación.',
                                                                      ),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                            ctx,
                                                                            false,
                                                                          ),
                                                                      child: const Text(
                                                                        'Cancelar',
                                                                      ),
                                                                    ),
                                                                    TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                            ctx,
                                                                            true,
                                                                          ),
                                                                      child: const Text(
                                                                        'Reportar',
                                                                        style: TextStyle(
                                                                          color:
                                                                              Colors.red,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                              if (confirm ==
                                                                  true) {
                                                                await reviewService
                                                                    .reportReview(
                                                                      r.idResenia,
                                                                    );
                                                                if (context
                                                                    .mounted) {
                                                                  ScaffoldMessenger.of(
                                                                    context,
                                                                  ).showSnackBar(
                                                                    const SnackBar(
                                                                      content: Text(
                                                                        'Reseña reportada para moderación.',
                                                                      ),
                                                                    ),
                                                                  );
                                                                }
                                                              }
                                                            },
                                                          ),
                                                        if (r.isReported)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  left: 8.0,
                                                                ),
                                                            child: Icon(
                                                              Icons.flag,
                                                              size: 16,
                                                              color:
                                                                  colors.error,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                if (r.comentario != null &&
                                                    r
                                                        .comentario!
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 12),
                                                  TranslatedText(
                                                    r.comentario!,
                                                    style: GoogleFonts.inter(
                                                      color: colors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                                if (r.respuestaTaller != null)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                          left: 16,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: colors.primary
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Respuesta del taller',
                                                          style:
                                                              GoogleFonts.inter(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: colors
                                                                    .primary,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          r.respuestaTaller!['texto']
                                                              as String,
                                                          style:
                                                              GoogleFonts.inter(
                                                                color: colors
                                                                    .textPrimary,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                else
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: TextButton.icon(
                                                      icon: const Icon(
                                                        Icons.reply,
                                                      ),
                                                      label: const Text(
                                                        'Responder',
                                                      ),
                                                      onPressed: () =>
                                                          _mostrarDialogoResponder(
                                                            context,
                                                            reviewService,
                                                            r,
                                                          ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoResponder(
    BuildContext context,
    ReviewService reviewService,
    ReviewModel review,
  ) async {
    final controller = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Responder a la reseña'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 300,
          decoration: const InputDecoration(
            hintText: 'Ej. Gracias por tu confianza...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );

    if (texto == null || texto.trim().isEmpty) return;

    try {
      await reviewService.responderResenia(
        reviewId: review.idResenia,
        tallerId: review.idTaller,
        texto: texto,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Respuesta publicada')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _buildDistribution(
    List<ReviewModel> reviews,
    AppColors colors,
    BuildContext context,
  ) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (var r in reviews) {
      counts[r.estrellas] = (counts[r.estrellas] ?? 0) + 1;
    }
    final total = reviews.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.all(Responsive.padding(context, 20)),
        child: Column(
          children: [
            for (int i = 5; i >= 1; i--)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '$i',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Icon(Icons.star, size: 16, color: colors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total > 0 ? (counts[i]! / total) : 0,
                          backgroundColor: colors.textSecondary.withValues(
                            alpha: 0.1,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colors.warning,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${counts[i]}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
