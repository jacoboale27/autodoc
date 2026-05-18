import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/models/review_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';

class MechanicReviewsScreen extends StatelessWidget {
  const MechanicReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final tallerId = context.watch<AuthProvider>().userData?.idUsuario ?? '';
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
                    padding: const EdgeInsets.symmetric(horizontal: 32),
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
                        fontSize: 20,
                        color: colors.primary,
                      ),
                    ),
                  ),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Usuarios')
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
                            padding: const EdgeInsets.all(24),
                            child: AppCard(
                              margin: EdgeInsets.zero,
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: colors.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.star_rounded,
                                      color: colors.warning,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          promedio > 0
                                              ? promedio.toStringAsFixed(1)
                                              : '—',
                                          style: GoogleFonts.inter(
                                            fontSize: 32,
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
                              stream: reviewService.watchReviewsForTaller(tallerId),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                    child: CircularProgressIndicator(
                                      color: colors.primary,
                                    ),
                                  );
                                }

                                final reviews = snapshot.data ?? [];
                                if (reviews.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.rate_review_outlined,
                                            size: 56,
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

                                return ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                  itemCount: reviews.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final r = reviews[index];
                                    return AppCard(
                                      margin: EdgeInsets.zero,
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: List.generate(5, (i) {
                                                  return Icon(
                                                    Icons.star,
                                                    size: 16,
                                                    color: i < r.estrellas
                                                        ? colors.warning
                                                        : colors.textSecondary
                                                            .withValues(
                                                                alpha: 0.2),
                                                  );
                                                }),
                                              ),
                                              Text(
                                                DateFormat('dd MMM yyyy')
                                                    .format(r.fechaResenia),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: colors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (r.comentario != null &&
                                              r.comentario!.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Text(
                                              r.comentario!,
                                              style: GoogleFonts.inter(
                                                color: colors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
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
}
