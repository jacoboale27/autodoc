import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/widgets/main_scaffold.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/l10n/app_localizations.dart';

class _FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  _FakeUserProfileProvider(this._rol);
  final String _rol;
  @override
  UserModel? get userData => UserModel(
    idUsuario: 'u1',
    nombreCompleto: 'Test',
    correo: 't@t.com',
    rol: _rol,
    estado: 'aprobado',
    fechaRegistro: DateTime.now(),
  );
  @override
  bool get isLoading => false;
  @override
  bool get hasAttemptedFetch => true;
  @override
  String? get fetchedUserId => 'u1';
  @override
  String? get error => null;
  @override
  bool hasAttemptedFetchFor(String userId) => true;
  @override
  Future<void> fetchUserData(String userId) async {}
  @override
  Future<bool> updateProfile(
    UserModel u, {
    dynamic imageFile,
    bool isNewUser = false,
  }) async => true;
  @override
  void clearUserData() {}
}

void main() {
  testWidgets('Propietario role sees a scaffold, not the mechanic sidebar', (
    tester,
  ) async {
    // Set mobile viewport to avoid desktop nav bar
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final userProvider = _FakeUserProfileProvider('Propietario');

    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(
          path: '/test',
          builder: (_, __) => ChangeNotifierProvider<UserProfileProvider>.value(
            value: userProvider,
            child: const MainScaffold(child: Text('BODY')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<UserProfileProvider>.value(
        value: userProvider,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BODY'), findsOneWidget);
    expect(find.text('Catálogo'), findsNothing); // mechanic-only sidebar item
  });
}
