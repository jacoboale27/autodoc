import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/admin/presentation/widgets/metric_card.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_dashboard_screen.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  group('MetricCard - altura', () {
    testWidgets('no debe estirarse cuando esta en el grid del dashboard', (
      tester,
    ) async {
      // Measure the card's natural content height when unbounded.
      await pumpAtWidth(
        tester,
        const SizedBox(
          width: 1440,
          child: MetricCard(
            title: 'Test Title',
            value: '42',
            icon: Icons.people,
            color: Colors.blue,
          ),
        ),
        width: 1440,
      );
      await tester.pumpAndSettle();

      final looseHeight = tester.getSize(find.byType(MetricCard)).height;

      // Now mount the same card inside the dashboard's grid configuration,
      // using the actual production constant (adminMetricCardsAspectRatio).
      // If someone reverts that constant to 1.6, this test will fail because
      // the grid cell height will change, and the card will no longer wrap
      // to its natural height.
      await pumpAtWidth(
        tester,
        const AppGrid(
          compactColumns: 1,
          mediumColumns: 2,
          expandedColumns: 3,
          largeColumns: 4,
          spacing: 20,
          childAspectRatio: adminMetricCardsAspectRatio,
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

      final gridHeight = tester.getSize(find.byType(MetricCard)).height;

      // After the fix (mainAxisSize.min + start alignment), the card should
      // wrap to its natural content height, not stretch to fill the grid cell.
      // Allow a small tolerance (3px) for rendering differences.
      expect(
        gridHeight,
        closeTo(looseHeight, 3),
        reason:
            'card should wrap to content height, not stretch to grid cell height',
      );
    });
  });
}
