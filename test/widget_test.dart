import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_skeleton.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('App theme smoke test', (WidgetTester tester) async {
    // Create a simple router for the test
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('AutoDoc Smoke Test')),
          ),
        ),
      ],
    );

    // Build our app with the theme and router
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: router,
      ),
    );

    // Initial frame
    await tester.pump();

    // Verify that the theme is applied
    final BuildContext context = tester.element(find.text('AutoDoc Smoke Test'));
    final colors = context.appColors;

    // Verify primary color from light theme tokens
    expect(colors.primary, AppPalette.lightPrimary);
    
    // Verify background color
    expect(Theme.of(context).scaffoldBackgroundColor, colors.surface);

    expect(find.text('AutoDoc Smoke Test'), findsOneWidget);
  });

  testWidgets('AppSkeleton renders with theme tokens', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppSkeleton.card(height: 80),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSkeleton), findsOneWidget);
    final context = tester.element(find.byType(AppSkeleton));
    expect(context.appColors.primary, AppPalette.lightPrimary);
  });
}
