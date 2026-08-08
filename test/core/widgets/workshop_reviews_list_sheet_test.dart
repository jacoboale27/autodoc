import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/review_model.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/workshop_reviews_list_sheet.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';

class _FakeReviewService implements ReviewService {
  _FakeReviewService(this._reviews);
  final List<ReviewModel> _reviews;

  @override
  Stream<List<ReviewModel>> watchReviewsForTaller(String tallerId) =>
      Stream.value(_reviews);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('shows existing reviews without requiring a completed service', (
    tester,
  ) async {
    final reviews = [
      ReviewModel(
        idResenia: 'r1',
        idUsuario: 'u1',
        idTaller: 't1',
        idServicio: 's1',
        estrellas: 5,
        comentario: 'Excelente atención, muy rápido.',
        fechaResenia: DateTime(2026, 1, 10),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showWorkshopReviewsSheet(
              context,
              tallerId: 't1',
              tallerNombre: 'Taller Central',
              reviewService: _FakeReviewService(reviews),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Excelente atención, muy rápido.'), findsOneWidget);
    // Must NOT show the write-review eligibility gate — this is a
    // read-only view.
    expect(find.textContaining('Debes completar un servicio'), findsNothing);
  });

  testWidgets('shows an empty state when the workshop has no reviews yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showWorkshopReviewsSheet(
              context,
              tallerId: 't2',
              tallerNombre: 'Taller Nuevo',
              reviewService: _FakeReviewService(const []),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay reseñas para este taller.'), findsOneWidget);
  });
}
