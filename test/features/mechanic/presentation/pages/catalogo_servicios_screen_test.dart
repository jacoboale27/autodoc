import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/features/mechanic/presentation/pages/catalogo_servicios_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

class _FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  @override
  UserModel? get userData => null;
  @override
  bool get isLoading => false;
  @override
  bool get hasAttemptedFetch => true;
  @override
  String? get fetchedUserId => null;
  @override
  String? get error => null;
  @override
  bool hasAttemptedFetchFor(String userId) => true;
  @override
  Future<void> fetchUserData(String userId) async {}
  @override
  Future<bool> updateProfile(
    UserModel updatedUser, {
    XFile? imageFile,
    bool isNewUser = false,
  }) async => true;
  @override
  void clearUserData() {}
}

void main() {
  testWidgets('Price field restricts input to numeric and decimal characters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CatalogoRepository(firestore: FakeFirebaseFirestore());
    final router = GoRouter(
      initialLocation: '/catalogo',
      routes: [
        GoRoute(
          path: '/catalogo',
          builder: (context, state) =>
              const CatalogoServiciosScreen(idTaller: 't1'),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => CatalogoProvider(repository: repo),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider<UserProfileProvider>(
            create: (_) => _FakeUserProfileProvider(),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the FAB to open the dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Find the price TextFormField by its labelText
    final priceFieldFinder = find.widgetWithText(
      TextFormField,
      'Precio unitario',
    );
    expect(priceFieldFinder, findsOneWidget);

    // Get the TextEditingController from the TextFormField
    TextEditingController? priceController;
    for (final element in priceFieldFinder.evaluate()) {
      final widget = element.widget as TextFormField;
      priceController = widget.controller;
      break;
    }
    expect(priceController, isNotNull);

    // Test: Formatter should accept valid numeric input with up to 2 decimals
    await tester.tap(priceFieldFinder);
    await tester.pump();

    // Valid input: '12.5' should pass through
    await tester.enterText(priceFieldFinder, '12.5');
    await tester.pump();
    expect(priceController!.text, '12.5');

    // Valid input: '99.99' should pass through
    await tester.enterText(priceFieldFinder, '99.99');
    await tester.pump();
    expect(priceController!.text, '99.99');

    // Valid input: '100.50' should pass through
    await tester.enterText(priceFieldFinder, '100.50');
    await tester.pump();
    expect(priceController!.text, '100.50');

    // Invalid input: '99.999' (3 decimals) does not match the whole-string
    // pattern, so the edit is rejected and the field keeps its prior value
    // instead of being wiped to ''.
    await tester.enterText(priceFieldFinder, '99.999');
    await tester.pump();
    expect(priceController!.text, '100.50');

    // Invalid input: '12a.5b' (with letters) is also rejected as a whole,
    // so the field keeps the last valid value it had ('100.50') rather than
    // being destructively cleared to ''.
    await tester.enterText(priceFieldFinder, '12a.5b');
    await tester.pump();
    expect(priceController!.text, '100.50');
  });

  testWidgets('Price field does not wipe existing valid text when an invalid '
      'character is typed (regression for destructive-wipe bug)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CatalogoRepository(firestore: FakeFirebaseFirestore());
    final router = GoRouter(
      initialLocation: '/catalogo',
      routes: [
        GoRoute(
          path: '/catalogo',
          builder: (context, state) =>
              const CatalogoServiciosScreen(idTaller: 't1'),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => CatalogoProvider(repository: repo),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider<UserProfileProvider>(
            create: (_) => _FakeUserProfileProvider(),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final priceFieldFinder = find.widgetWithText(
      TextFormField,
      'Precio unitario',
    );

    TextEditingController? priceController;
    for (final element in priceFieldFinder.evaluate()) {
      final widget = element.widget as TextFormField;
      priceController = widget.controller;
      break;
    }
    expect(priceController, isNotNull);

    // Simulate incremental typing of a valid value already accepted by
    // the field: '12.50'.
    await tester.enterText(priceFieldFinder, '12.50');
    await tester.pump();
    expect(priceController!.text, '12.50');

    // Now simulate an invalid whole-string candidate coming from a single
    // additional keystroke while '12.50' is already present (e.g. typing
    // 'a' at the end produces the candidate '12.50a'). This must NOT wipe
    // the field to '' like the old FilteringTextInputFormatter.allow did;
    // it must keep '12.50' unchanged.
    await tester.enterText(priceFieldFinder, '12.50a');
    await tester.pump();
    expect(priceController!.text, '12.50');
  });
}
