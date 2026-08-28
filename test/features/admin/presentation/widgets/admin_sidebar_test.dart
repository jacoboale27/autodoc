// test/features/admin/presentation/widgets/admin_sidebar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/admin/presentation/widgets/admin_sidebar.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';

import '../../../../support/mechanic_harness.dart' show FakeUserProfileProvider;
import '../../../../support/responsive_harness.dart' show expectNoOverflow;

UserModel _admin() => UserModel(
  idUsuario: 'admin-1',
  nombreCompleto: 'Ada Administradora',
  correo: 'admin@example.com',
  rol: 'Administrador',
  fechaRegistro: DateTime(2026, 1, 1),
  estado: 'activo',
);

/// Monta el drawer abierto a un viewport de [width] × [height].
Future<void> pumpSidebar(
  WidgetTester tester, {
  double width = 1280,
  required double height,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const SizedBox.shrink());

  final router = GoRouter(
    initialLocation: '/admin/dashboard',
    routes: [
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) =>
            const Scaffold(drawer: AdminSidebar(), body: SizedBox.shrink()),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProfileProvider>(
          create: (_) => FakeUserProfileProvider(user: _admin()),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no desborda en una ventana baja', (tester) async {
    // 700 dp de alto: cabecera (~200) + seis destinos (~384) + pie (~90) no
    // caben, que es justo el caso en el que el `Spacer()` anterior pedía
    // espacio libre inexistente y el Drawer entero desbordaba.
    await pumpSidebar(tester, height: 700);

    expectNoOverflow(tester);
    expect(find.text('Verificación'), findsOneWidget);
  });

  testWidgets('a 500 dp de alto los destinos siguen siendo alcanzables', (
    tester,
  ) async {
    await pumpSidebar(tester, height: 500);
    expectNoOverflow(tester);

    // El pie no scrollea: cerrar sesión tiene que seguir visible sin
    // desplazar nada.
    expect(find.text('Cerrar Sesión'), findsOneWidget);

    // Y los destinos que no caben se alcanzan scrollando, en vez de quedar
    // recortados sin salida.
    await tester.scrollUntilVisible(find.text('Registro de Actividad'), 100);
    expect(find.text('Registro de Actividad'), findsOneWidget);
    expectNoOverflow(tester);
  });

  testWidgets('en una ventana alta se ve todo sin scroll', (tester) async {
    await pumpSidebar(tester, height: 1200);

    expectNoOverflow(tester);
    for (final destino in [
      'Dashboard',
      'Usuarios',
      'Talleres',
      'Verificación',
      'Reseñas',
      'Registro de Actividad',
      'Cerrar Sesión',
    ]) {
      expect(find.text(destino), findsOneWidget, reason: 'falta $destino');
    }
  });
}
