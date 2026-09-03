// test/features/admin/presentation/pages/admin_verificaciones_evidencia_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/models/verificacion_taller_model.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/app_image_viewer.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_verificaciones_screen.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_verificacion_provider.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';
import 'package:autodoc/features/profile/data/services/user_service.dart';
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

/// Cuenta cuantas veces se pide la URL de una miniatura ya resuelta, para
/// distinguir una memoizacion real de una que se descarta en cada
/// `notifyListeners()`. Mismo patron que `_UserServiceContador` en
/// `admin_verificacion_identidad_provider_test.dart`.
class _VerificacionServiceUrlContador extends VerificacionService {
  int llamadas = 0;

  _VerificacionServiceUrlContador({required FakeFirebaseFirestore firestore})
    : super(
        firestore: firestore,
        resolutorDeUrl: (ruta) async => 'https://storage.test/$ruta',
        ahora: () => DateTime.utc(2026, 3, 10),
      );

  @override
  Future<String> urlDeEvidencia(String tallerId, DocumentoEvidencia documento) {
    llamadas++;
    return super.urlDeEvidencia(tallerId, documento);
  }
}

/// Retrasa `getUserData` para que la hidratacion de identidades complete
/// DESPUES de que la primera pintada (y su `FutureBuilder` de evidencia) ya
/// se haya asentado, en vez de en el mismo turno de microtareas. Sin este
/// retraso, en `FakeFirebaseFirestore` las dos resoluciones (bandeja e
/// identidad) terminan tan rapido que caen en el mismo frame y el bug no se
/// distingue de la memoizacion correcta.
class _UserServiceConRetraso extends UserService {
  final Duration retraso;

  _UserServiceConRetraso({
    required FakeFirebaseFirestore firestore,
    required this.retraso,
  }) : super(firestore: firestore);

  @override
  Future<UserModel?> getUserData(String userId) async {
    await Future<void>.delayed(retraso);
    return super.getUserData(userId);
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late UserService userService;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    userService = UserService(firestore: firestore);
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
        userService: userService,
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
        userService: userService,
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

  testWidgets(
    'una reconstruccion provocada por notifyListeners() no vuelve a pedir '
    'la URL de una miniatura ya resuelta',
    (tester) async {
      const uid = 'taller-evidencia-memo';
      await sembrarExpediente(uid);
      // Un perfil publico hace que `_hidratarIdentidades` complete y llame a
      // `notifyListeners()` poco despues del primer pintado: es el disparador
      // real que describe el hallazgo #1, no un rebuild fabricado a mano.
      await firestore.collection('usuarios').doc(uid).set({
        'nombre_completo': 'Taller Memo',
        'correo': 'memo@example.com',
        'rol': 'Taller',
        'fecha_registro': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      final urlService = _VerificacionServiceUrlContador(firestore: firestore);
      final userServiceConRetraso = _UserServiceConRetraso(
        firestore: firestore,
        retraso: const Duration(milliseconds: 50),
      );
      final provider = AdminVerificacionProvider(
        service: urlService,
        userService: userServiceConRetraso,
      );

      await _pumpBandeja(tester, provider);
      expect(
        provider.identidadDe(uid),
        isNull,
        reason:
            'con este retraso, la identidad todavia no debe haber llegado '
            'cuando la miniatura ya pinto su primera URL',
      );

      // Deja que la hidratacion (retrasada) termine DESPUES de que la
      // primera pintada ya se asento, y que dispare su propio
      // `notifyListeners()`.
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump();
      await tester.pump();

      expect(provider.identidadDe(uid), isNotNull);
      expect(
        urlService.llamadas,
        1,
        reason:
            'la hidratacion de identidades reconstruye la tarjeta pero no '
            'debe volver a pedir la URL de una miniatura ya resuelta',
      );
    },
  );
}
