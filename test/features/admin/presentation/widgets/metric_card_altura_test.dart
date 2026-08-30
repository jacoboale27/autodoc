import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/admin/presentation/widgets/metric_card.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  group('MetricCard - altura', () {
    testWidgets('no debe tener 270px de altura con espaciado vacio', (
      tester,
    ) async {
      // Mount at 1440px width => AppGrid decides 3 columns (expanded mode)
      // Each column: ~430px wide. With childAspectRatio: 1.6, grid cell height = 430/1.6 ≈ 269px
      await pumpAtWidth(
        tester,
        const AppGrid(
          compactColumns: 1,
          mediumColumns: 2,
          expandedColumns: 3,
          largeColumns: 4,
          spacing: 20,
          childAspectRatio: 2.1,
          children: [
            MetricCard(
              title: 'Test Title',
              value: '42',
              icon: Icons.people,
              color: Colors.blue,
            ),
          ],
        ),
        width: 1440,
      );
      await tester.pumpAndSettle();

      // The grid constrains the card to ~269px height.
      // Before fix: mainAxisAlignment.spaceBetween stretches the content,
      // leaving the value at the bottom with ~200px empty space above it.
      // So the card height should be constrained to grid cell height (~269px).
      final cardSize = tester.getSize(find.byType(MetricCard));

      // After fix, the card should wrap to its natural content height (much less than 269px).
      // Red run: we expect this to fail because the grid constrains to ~269px.
      expect(
        cardSize.height,
        lessThan(170),
        reason:
            'card should wrap to content height, not be stretched by grid and spaceBetween',
      );
    });
  });
}
