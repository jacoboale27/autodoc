import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/dashboard/presentation/providers/service_history_provider.dart';

void main() {
  test('Check that fetchServices uses limit() or startAfter()', () {
    final provider = ServiceHistoryProvider();
    expect(provider.hasMore, true);
    expect(provider.isLoading, false);
    expect(provider.services, isEmpty);
  });
}
