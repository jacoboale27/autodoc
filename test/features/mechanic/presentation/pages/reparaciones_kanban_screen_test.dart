import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import '../../../../helpers/test_helpers.mocks.dart';

// UserProfileProvider real construye un UserService que toca
// FirebaseFirestore.instance en su inicializacion, lo que no existe en un
// widget test sin Firebase.initializeApp(). MechanicSidebar (renderizado por
// ReparacionesKanbanScreen) solo necesita leer userData?.idTallerPropietario
// durante build(), asi que un fake evita esa dependencia sin necesitar mocks
// de Firebase Core (mismo patron que reserva_detail_screen_test.dart).
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
  testWidgets('ReparacionesKanbanScreen renderiza las 4 columnas de estado', (
    tester,
  ) async {
    // MechanicSidebar necesita más alto que el viewport de test por defecto
    // (800x600) para no desbordar con sus items de navegación.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = ReparacionRepository(
      firestore: FakeFirebaseFirestore(),
      functions: MockFirebaseFunctions(),
    );
    final router = GoRouter(
      initialLocation: '/mechanic_reparaciones',
      routes: [
        GoRoute(
          path: '/mechanic_reparaciones',
          builder: (context, state) =>
              const ReparacionesKanbanScreen(idTaller: 't1'),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ReparacionProvider(repository: repo),
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

    expect(find.text('Recibido'), findsOneWidget);
    expect(find.text('En Revisión'), findsOneWidget);
    expect(find.text('Esperando Repuestos'), findsOneWidget);
    expect(find.text('Listo para Entregar'), findsOneWidget);
  });
}
