import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'unmatched paths render the in-app 404 page, not a blank/broken screen',
    (tester) async {
      final router = GoRouter(
        errorBuilder: (context, state) => const Scaffold(
          body: Center(child: Text('Página no encontrada (404)')),
        ),
        routes: [
          GoRoute(
            path: '/workshop_directory',
            builder: (_, __) => const Scaffold(body: Text('DIRECTORY_OK')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/directorio'); // the wrong path TestSprite used
      await tester.pumpAndSettle();
      expect(find.text('Página no encontrada (404)'), findsOneWidget);

      router.go('/workshop_directory'); // the real registered path
      await tester.pumpAndSettle();
      expect(find.text('DIRECTORY_OK'), findsOneWidget);
    },
  );
}
