import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/auth/presentation/screens/login_screen.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import '../../helpers/test_helpers.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockAdminAuthService mockAdminAuthService;
  late AuthProvider authProvider;

  setUp(() {
    mockAuthService = MockAuthService();
    mockAdminAuthService = MockAdminAuthService();
    authProvider = AuthProvider(
      authService: mockAuthService,
      adminAuthService: mockAdminAuthService,
    );
  });

  Widget buildTestableWidget(Widget widget) {
    return MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: widget,
      ),
    );
  }

  testWidgets(
    'LoginScreen uses SingleChildScrollView and ConstrainedBox for landscape layout',
    (WidgetTester tester) async {
      // Set landscape physical size
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      // Verify SingleChildScrollView is used
      expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));

      // Verify ConstrainedBox is used to limit width on landscape/wide displays
      expect(find.byType(ConstrainedBox), findsAtLeastNWidgets(1));

      // Verify layout renders without any visual overflow errors
      expect(tester.takeException(), isNull);
    },
  );
}
