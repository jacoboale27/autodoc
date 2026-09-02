// test/features/admin/presentation/pages/admin_verificaciones_evidencia_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/app_image_viewer.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_verificaciones_screen.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_verificacion_provider.dart';
import 'package:autodoc/features/dashboard/data/services/workshop_service.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// Mismo doble que en `admin_verificaciones_identidad_test.dart` (tarea A2,
/// ese archivo no se toca aquí): el `AuthSessionProvider` real escucha
/// `idTokenChanges()` de `FirebaseAuth.instance` en su constructor y lanza en
/// un widget test sin `Firebase.initializeApp()`.
class _FakeAuthSessionProvider extends ChangeNotifier
    implements AuthSessionProvider {
  @override
  String get currentUid => 'admin-9';
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

/// Monta la bandeja y espera, con un tope de pumps, a que el expediente
/// llegue y a que el `FutureBuilder` de `urlDeEvidencia` de cada miniatura
/// resuelva. No usa `pumpAndSettle()` mientras `provider.cargando` es
/// verdadero por el mismo motivo documentado en
/// `admin_verificaciones_identidad_test.dart`: el `CircularProgressIndicator`
/// indeterminado nunca se asienta solo.
Future<void> _pumpBandeja(
  WidgetTester tester,
  AdminVerificacionProvider provider,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminVerificacionProvider>.value(
          value: provider,
        ),
        ChangeNotifierProvider<AuthSessionProvider>(
          create: (_) => _FakeAuthSessionProvider(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminVerificacionesScreen(),
      ),
    ),
  );

  for (var i = 0; i < 20 && provider.cargando; i++) {
    await tester.pump();
  }
  // El expediente ya está en `bandeja`, pero el `FutureBuilder` de cada
  // `_Evidencia` todavía necesita algunos ciclos más para que
  // `urlDeEvidencia` resuelva (o falle).
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late WorkshopService workshopService;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    workshopService = WorkshopService(firestore: firestore);
  });

  Future<void> sembrarExpediente(String uid) =>
      firestore.collection('verificaciones').doc(uid).set({
        'estado_verificacion': 'en_revision',
        'fecha_envio': Timestamp.fromDate(DateTime.utc(2026, 3, 2)),
        'documentos': {
          'fachada': {
            'nombre_archivo': 'fachada.jpg',
            'fecha': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
          },
        },
      });

  testWidgets(
    'un tap sobre la miniatura de una imagen abre el visor a pantalla '
    'completa',
    (tester) async {
      const uid = 'taller-evidencia-imagen';
      await sembrarExpediente(uid);
      final service = VerificacionService(
        firestore: firestore,
        resolutorDeUrl: (ruta) async => 'https://storage.test/$ruta',
        ahora: () => DateTime.utc(2026, 3, 10),
      );
      final provider = AdminVerificacionProvider(
        service: service,
        workshopService: workshopService,
      );

      await _pumpBandeja(tester, provider);

      expect(find.byType(AppImageViewer), findsNothing);
      expect(
        find.byType(Image),
        findsOneWidget,
        reason: 'la miniatura de la fachada debe haber resuelto su URL',
      );

      await tester.tap(find.byType(Image));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppImageViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    },
  );

  testWidgets(
    'un tap sobre una miniatura cuya URL no resolvió no abre el visor',
    (tester) async {
      const uid = 'taller-evidencia-sin-archivo';
      await sembrarExpediente(uid);
      final service = VerificacionService(
        firestore: firestore,
        // Simula el archivo anotado en el expediente pero ausente en
        // Storage: `AdminVerificacionProvider.urlDeEvidencia` atrapa esta
        // excepción y devuelve `null`.
        resolutorDeUrl: (ruta) async => throw Exception('objeto no existe'),
        ahora: () => DateTime.utc(2026, 3, 10),
      );
      final provider = AdminVerificacionProvider(
        service: service,
        workshopService: workshopService,
      );

      await _pumpBandeja(tester, provider);

      expect(
        find.byIcon(Icons.broken_image_outlined),
        findsOneWidget,
        reason: 'la miniatura sin URL cae al icono de imagen rota',
      );

      await tester.tap(find.byIcon(Icons.broken_image_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppImageViewer), findsNothing);
      expect(find.byType(InteractiveViewer), findsNothing);
    },
  );
}
