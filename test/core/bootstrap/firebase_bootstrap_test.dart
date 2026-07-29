import 'package:autodoc/core/bootstrap/firebase_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseBootstrap', () {
    test('reports ready when Firebase initialization succeeds', () async {
      final result = await FirebaseBootstrap.initialize(() async {});

      expect(result.isReady, isTrue);
      expect(result.error, isNull);
    });

    test(
      'reports an error instead of rethrowing when Firebase initialization fails',
      () async {
        final result = await FirebaseBootstrap.initialize(() async {
          throw StateError('invalid API key');
        });

        expect(result.isReady, isFalse);
        expect(result.error, isA<StateError>());
      },
    );
  });
}
