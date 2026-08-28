// test/features/mechanic/presentation/pages/workshop_gallery_responsive_test.dart
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/features/mechanic/data/services/galeria_service.dart';
import 'package:autodoc/features/mechanic/presentation/pages/workshop_gallery_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/galeria_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

/// Doble de `AuthSessionProvider`: el real escucha `idTokenChanges()` de
/// `FirebaseAuth.instance` en su constructor y lanza en un widget test sin
/// `Firebase.initializeApp()`. Mismo patrón que `FakeUserProfileProvider`.
class _FakeAuthSessionProvider extends ChangeNotifier
    implements AuthSessionProvider {
  @override
  String get currentUid => 't1';
  @override
  bool get isLoggedIn => true;
  @override
  User? get user => null;
  @override
  String? get error => null;
  @override
  Future<void> refreshUser() async {}
  @override
  void clearError() {}
}

/// `GaleriaService` sin Storage detrás: los huecos vacíos bastan para las
/// aserciones de layout, y así el test no toca `FirebaseStorage.instance`.
GaleriaService galeriaServiceDePrueba() => GaleriaService(
  firestore: FakeFirebaseFirestore(),
  subidor: ({required ruta, required bytes, required contentType}) async {},
  borrador: (ruta) async {},
);

Future<void> pumpGaleria(WidgetTester tester, double width) async {
  await pumpMechanicScreen(
    tester,
    const WorkshopGalleryScreen(),
    width: width,
    height: 1200,
    location: '/workshop_gallery',
    disableAnimations: true,
    extraProviders: [
      ChangeNotifierProvider<AuthSessionProvider>(
        create: (_) => _FakeAuthSessionProvider(),
      ),
      ChangeNotifierProvider(
        create: (_) => GaleriaProvider(service: galeriaServiceDePrueba()),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a 1440 px la galería monta el sidebar fijo del panel', (
    tester,
  ) async {
    await pumpGaleria(tester, 1440);

    expect(
      find.byType(MechanicSidebar),
      findsOneWidget,
      reason:
          'la pantalla montaba su propio Scaffold y se quedaba sin '
          'navegación del panel de taller',
    );
    expect(find.text('FOTOS DEL TALLER'), findsOneWidget);
  });

  testWidgets('a 375 px la galería usa AppBar + drawer, no sidebar fijo', (
    tester,
  ) async {
    await pumpGaleria(tester, 375);

    expect(find.byType(MechanicSidebar), findsNothing);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.drawer, isNotNull);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byType(MechanicSidebar), findsOneWidget);
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pumpGaleria(tester, width);
      expectNoOverflow(tester);
    }
  });

  test('la pantalla no vuelve a construir su propio Scaffold', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/workshop_gallery_screen.dart',
    ).readAsStringSync();

    expect(source.contains('return Scaffold('), isFalse);
    expect(source.contains('MechanicScaffold('), isTrue);
  });
}
