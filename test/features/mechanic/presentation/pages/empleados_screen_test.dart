import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/empleados_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';

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
  testWidgets(
    'la lista de empleados muestra el rol de cada empleado seedeado',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('talleres')
          .doc('t1')
          .collection('empleados')
          .doc('e1')
          .set({
            'id_taller_propietario': 't1',
            'nombre_completo': 'Juan Pérez',
            'correo': 'juan@taller.com',
            'telefono': '5551234',
            'rol': 'Recepcionista',
            'activo': true,
          });
      final repo = EmpleadoRepository(firestore: firestore);

      final router = GoRouter(
        initialLocation: '/empleados',
        routes: [
          GoRoute(
            path: '/empleados',
            builder: (context, state) => const EmpleadosScreen(idTaller: 't1'),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => EmpleadoProvider(repository: repo),
            ),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider<UserProfileProvider>(
              create: (_) => _FakeUserProfileProvider(),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('juan@taller.com'), findsOneWidget);
      // Deliberado (Task 6, no una regresión): el rol ya no vive en un Text
      // propio, sino dentro del chip de estado ("Recepcionista · Activo"),
      // que comunica rol + actividad como un solo texto legible.
      expect(find.textContaining('Recepcionista'), findsOneWidget);
    },
  );
}
