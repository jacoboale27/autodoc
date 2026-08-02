import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

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

    final repo = ReparacionRepository(firestore: FakeFirebaseFirestore());
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
