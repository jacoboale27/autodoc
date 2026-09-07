import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/models/review_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/widgets/translated_text.dart';

class MechanicReviewsScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;

  const MechanicReviewsScreen({super.key, this.firestore});

  @override
  State<MechanicReviewsScreen> createState() => _MechanicReviewsScreenState();
}

class _MechanicReviewsScreenState extends State<MechanicReviewsScreen> {
  ReviewSortOrder _orden = ReviewSortOrder.recientes;
  late final ReviewService _reviewService;

  @override
  void initState() {
    super.initState();
    _reviewService = ReviewService(firestore: widget.firestore);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final userSession = context.watch<UserProfileProvider>();
    final userData = userSession.userData;

    if (userData == null || userData.idUsuario.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tallerId = userData.idUsuario;

    return MechanicScaffold(
      title: 'Mis Reseñas',
      // Un unico stream para toda la pantalla, y a proposito.
      //
      // La cabecera leia el contador denormalizado
      // `usuarios/{id}.total_resenias` mientras el histograma contaba la lista
      // real, asi que los dos numeros se contradecian en la misma pantalla —
      // la revision adversarial vio «9 reseñas de clientes» sobre un
      // histograma que sumaba 5. Uno de los dos mentia, y el que manda es la
      // lista: es la que el taller puede abrir, ordenar y responder. El
      // promedio se calcula de la misma lista por el mismo motivo.
      body: StreamBuilder<List<ReviewModel>>(
        stream: _reviewService.watchReviewsForTaller(tallerId),
        builder: (context, snapshot) {
          final reviewsSinOrdenar = snapshot.data ?? [];
          final cargando = snapshot.connectionState == ConnectionState.waiting;
          final total = reviewsSinOrdenar.length;
          final promedio = total == 0
              ? 0.0
              : reviewsSinOrdenar.fold<int>(0, (a, r) => a + r.estrellas) /
                    total;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: AppPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.star_rounded,
                            color: colors.warning,
                            size: Responsive.iconSize(context, 40),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                promedio > 0
                                    ? promedio.toStringAsFixed(1)
                                    : '—',
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                '$total reseña${total == 1 ? '' : 's'} de clientes',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Builder(
                    builder: (context) {
                      if (cargando) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xxl,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colors.primary,
                            ),
                          ),
                        );
                      }

                      final reviews = ordenarResenias(
                        reviewsSinOrdenar,
                        _orden,
                      );
                      if (reviews.isEmpty) {
                        return const AppEmptyState(
                          title: 'Aún no tienes reseñas',
                          description:
                              'Los propietarios pueden calificarte desde el '
                              'directorio de talleres o su historial de '
                              'servicios.',
                          icon: Icons.rate_review_outlined,
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DistribucionResenias(
                            reviews: reviews,
                            colors: colors,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppSectionHeader(
                            title: 'Reseñas',
                            trailing: DropdownButton<ReviewSortOrder>(
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
                          const SizedBox(height: AppSpacing.base),
                          AppGrid(
                            compactColumns: 1,
                            mediumColumns: 1,
                            expandedColumns: 2,
                            largeColumns: 2,
                            childAspectRatio: 1.9,
                            children: [
                              for (final r in reviews)
                                _ReviewCard(
                                  review: r,
                                  onReportar: () => _reportar(context, r),
                                  onResponder: () =>
                                      _mostrarDialogoResponder(context, r),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _reportar(BuildContext context, ReviewModel review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reportar Reseña'),
        content: const Text(
          '¿Estás seguro de que deseas reportar esta reseña por lenguaje '
          'inapropiado o falso? Será revisada por el equipo de moderación.',
        ),
        actions: [
          AppButton(
            text: 'Cancelar',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            text: 'Reportar',
            type: AppButtonType.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _reviewService.reportReview(review.idResenia);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reseña reportada para moderación.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo reportar la reseña: $e')),
        );
      }
    }
  }

  Future<void> _mostrarDialogoResponder(
    BuildContext context,
    ReviewModel review,
  ) async {
    final controller = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Responder a la reseña'),
        content: AppDialogContent(
          child: AppTextField(
            controller: controller,
            maxLines: 3,
            maxLength: 300,
            hintText: 'Ej. Gracias por tu confianza...',
            label: 'Respuesta',
          ),
        ),
        actions: [
          AppButton(
            text: 'Cancelar',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            text: 'Publicar',
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context, controller.text),
          ),
        ],
      ),
    );
    controller.dispose();

    if (texto == null || texto.trim().isEmpty) return;

    try {
      await _reviewService.responderResenia(
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
}

/// Cinco estrellas con una única etiqueta semántica.
///
/// Antes eran cinco `Icon` sueltos: el lector de pantalla anunciaba cinco
/// iconos sin nombre y la calificación no llegaba.
class _Estrellas extends StatelessWidget {
  final int estrellas;

  const _Estrellas({required this.estrellas});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: '$estrellas de 5 estrellas',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Icon(
                i < estrellas ? Icons.star : Icons.star_border,
                size: 16,
                color: i < estrellas
                    ? colors.warning
                    : colors.textSecondary.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de una reseña individual: calificación anunciable, comentario,
/// fotos, acción de reporte y respuesta del taller.
///
/// Antes vivía inline en el `itemBuilder` de un `ListView.separated`
/// (290 líneas, con el diálogo de reportar anidado dentro).
class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final VoidCallback onReportar;
  final VoidCallback onResponder;

  const _ReviewCard({
    required this.review,
    required this.onReportar,
    required this.onResponder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final r = review;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _Estrellas(estrellas: r.estrellas),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(r.fechaResenia),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (r.comentario != null &&
                        r.comentario!.isNotEmpty &&
                        !r.isReported)
                      IconButton(
                        icon: Icon(
                          Icons.flag_outlined,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                        tooltip: 'Reportar esta reseña',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.only(left: 8),
                        onPressed: onReportar,
                      ),
                    if (r.isReported)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.flag, size: 16, color: colors.error),
                      ),
                  ],
                ),
              ],
            ),
            if (r.comentario != null && r.comentario!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              TranslatedText(
                r.comentario!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
            if (r.fotos.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final url in r.fotos)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          width: 64,
                          height: 64,
                          color: colors.textSecondary.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (r.respuestaTaller != null)
              Container(
                margin: const EdgeInsets.only(top: 8, left: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Respuesta del taller',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.respuestaTaller!['texto'] as String,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  text: 'Responder',
                  type: AppButtonType.text,
                  size: AppButtonSize.small,
                  icon: const Icon(Icons.reply),
                  onPressed: onResponder,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Distribución de reseñas por número de estrellas.
class _DistribucionResenias extends StatelessWidget {
  final List<ReviewModel> reviews;
  final AppColors colors;

  const _DistribucionResenias({required this.reviews, required this.colors});

  @override
  Widget build(BuildContext context) {
    final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (var r in reviews) {
      counts[r.estrellas] = (counts[r.estrellas] ?? 0) + 1;
    }
    final total = reviews.length;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          for (int i = 5; i >= 1; i--)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Semantics(
                label: '$i estrellas: ${counts[i]} de $total reseñas',
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Text(
                        '$i',
                        style: AppTextStyles.bodyMedium.copyWith(
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
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 32),
                        child: Text(
                          '${counts[i]}',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
