import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/models/review_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';

/// Shows a read-only bottom sheet with the reviews already posted for a
/// workshop. Unlike the "write a review" flow, this is reachable by any
/// user regardless of whether they have a completed service with the
/// workshop — it is purely for browsing before choosing a workshop.
Future<void> showWorkshopReviewsSheet(
  BuildContext context, {
  required String tallerId,
  required String tallerNombre,
  ReviewService? reviewService,
}) {
  final service = reviewService ?? ReviewService();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _WorkshopReviewsSheetContent(
      tallerId: tallerId,
      tallerNombre: tallerNombre,
      reviewService: service,
    ),
  );
}

class _WorkshopReviewsSheetContent extends StatelessWidget {
  const _WorkshopReviewsSheetContent({
    required this.tallerId,
    required this.tallerNombre,
    required this.reviewService,
  });

  final String tallerId;
  final String tallerNombre;
  final ReviewService reviewService;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reseñas de $tallerNombre',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: StreamBuilder<List<ReviewModel>>(
                  stream: reviewService.watchReviewsForTaller(tallerId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final reviews = snapshot.data!;
                    if (reviews.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('Aún no hay reseñas para este taller.'),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: reviews.length,
                      separatorBuilder: (_, _) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final review = reviews[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ...List.generate(
                                  5,
                                  (i) => Icon(
                                    i < review.estrellas
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(review.fechaResenia),
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (review.comentario != null &&
                                review.comentario!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(review.comentario!),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
