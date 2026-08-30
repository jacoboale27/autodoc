// test/features/admin/presentation/pages/admin_verificaciones_identidad_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_verificaciones_screen.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_verificacion_provider.dart';
import 'package:autodoc/features/dashboard/data/services/workshop_service.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// Doble de `AuthSessionProvider`: el real escucha `idTokenChanges()` de
/// `FirebaseAuth.instance` en su constructor y lanza en un widget test sin
/// `Firebase.initializeApp()`. Mismo patrón que en
/// `workshop_gallery_responsive_test.dart`.
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

/// Monta la pantalla y espera, con un tope de pumps, a que la bandeja y la
/// identidad del taller terminen de resolverse.
///
/// No usa `pumpAndSettle()`: mientras `provider.cargando` es verdadero la
/// pantalla pinta un `CircularProgressIndicator` indeterminado, cuya
/// animación nunca se asienta sola y dejaría a `pumpAndSettle` reintentando
/// hasta su timeout de 10 minutos. Sondear `provider` directamente evita esa
/// espera indefinida.
Future<void> pumpVerificaciones(
  WidgetTester tester,
  AdminVerificacionProvider provider, {
  required String uid,
}) async {
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

  for (
    var i = 0;
    i < 20 && (provider.cargando || provider.identidadDe(uid) == null);
    i++
  ) {
    await tester.pump();
  }
  await tester.pump();
}

void main() {
  late FakeFirebaseFirestore firestore;
  late VerificacionService service;
  late WorkshopService workshopService;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = VerificacionService(
      firestore: firestore,
      resolutorDeUrl: (ruta) async => 'https://storage.test/$ruta',
      ahora: () => DateTime.utc(2026, 3, 10),
    );
    workshopService = WorkshopService(firestore: firestore);
  });

  Future<void> sembrarExpediente(String uid, String estado) =>
      firestore.collection('verificaciones').doc(uid).set({
        'estado_verificacion': estado,
        'fecha_envio': Timestamp.fromDate(DateTime.utc(2026, 3, 2)),
        'documentos': {
          'fachada': {
            'nombre_archivo': 'fachada.jpg',
            'fecha': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
          },
        },
      });

  Future<void> sembrarPerfilPublico(
    String uid,
    String nombre, {
    String? especialidad,
  }) => firestore.collection('talleres').doc(uid).set({
    'nombre_completo': nombre,
    'especialidad': ?especialidad,
    // Estado de cuenta valido (`AppEstadoCuenta.aprobados`), no un estado de
    // verificacion: `talleres/{uid}` es la proyeccion publica del perfil, no
    // el expediente, y `getWorkshopById` no filtra por esto, pero sembrar un
    // valor que no es un estado de cuenta real es enganoso igualmente.
    'estado': 'aprobado',
  });

  testWidgets('la tarjeta muestra el nombre del taller, no solo su uid', (
    tester,
  ) async {
    const uid = 'HT8Hkxr0000000000000000';
    await sembrarExpediente(uid, 'listo_para_revision');
    await sembrarPerfilPublico(uid, 'Taller Los Pinos', especialidad: 'Frenos');

    final provider = AdminVerificacionProvider(
      service: service,
      workshopService: workshopService,
    );
    await pumpVerificaciones(tester, provider, uid: uid);

    expect(find.text('Taller Los Pinos'), findsOneWidget);
    expect(
      find.text(uid),
      findsNothing,
      reason: 'el uid crudo no le dice al admin a quien esta aprobando',
    );

    // El uid sigue siendo trazable, pero como dato subordinado: "ID: $uid"
    // en vez del uid aislado (por eso el `find.text(uid)` de arriba no lo
    // encuentra), en un estilo secundario y monoespaciado, no como el titulo.
    // Esto guarda la deviacion B: si esta linea se borrara, el test de arriba
    // seguiria en verde sin esta asercion.
    final colors = AppTheme.light.extension<AppColors>()!;
    final lineaId = tester.widget<Text>(find.text('ID: $uid'));
    expect(
      lineaId.style?.fontFamily,
      'monospace',
      reason: 'el uid debe verse monoespaciado, segun el encargo',
    );
    expect(
      lineaId.style?.color,
      colors.textSecondary,
      reason:
          'el uid es informacion secundaria: no puede llevar el mismo '
          'color que el nombre del taller',
    );
  });

  testWidgets(
    'aprobar es la accion principal; rechazar no es la mas prominente',
    (tester) async {
      const uid = 'taller-en-revision';
      await sembrarExpediente(uid, 'en_revision');
      await sembrarPerfilPublico(uid, 'Taller El Motor');

      final provider = AdminVerificacionProvider(
        service: service,
        workshopService: workshopService,
      );
      await pumpVerificaciones(tester, provider, uid: uid);

      final botones = tester
          .widgetList<AppButton>(find.byType(AppButton))
          .toList();
      final indiceAprobar = botones.indexWhere((b) => b.text == 'Aprobar');
      final indiceRechazar = botones.indexWhere((b) => b.text == 'Rechazar');

      expect(indiceAprobar, greaterThanOrEqualTo(0));
      expect(indiceRechazar, greaterThanOrEqualTo(0));
      expect(
        indiceAprobar,
        lessThan(indiceRechazar),
        reason: 'aprobar debe aparecer primero, como la accion principal',
      );
      expect(
        botones[indiceRechazar].type,
        AppButtonType.text,
        reason:
            'la destructiva no puede tener el mismo peso visual que aprobar',
      );

      // AppButtonType.text por si solo pinta en colors.primary (ver
      // AppButton._palette): sin el Theme(...) que sobreescribe la
      // extension AppColors para ese subarbol, "Rechazar" se veria del
      // mismo color que cualquier accion de texto neutra, no como una
      // destructiva. Esto es justo lo que la revision de QA senalo: nada
      // fallaba si alguien quitaba ese wrapper.
      final colors = AppTheme.light.extension<AppColors>()!;
      final textoRechazar = tester.widget<Text>(
        find.descendant(
          of: find.widgetWithText(AppButton, 'Rechazar'),
          matching: find.text('Rechazar'),
        ),
      );
      expect(
        textoRechazar.style?.color,
        colors.error,
        reason: 'rechazar debe leerse como destructivo, aunque sea de texto',
      );
    },
  );
}
