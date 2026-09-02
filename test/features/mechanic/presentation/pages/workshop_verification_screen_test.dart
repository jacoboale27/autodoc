// test/features/mechanic/presentation/pages/workshop_verification_screen_test.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/app_image_viewer.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';
import 'package:autodoc/features/mechanic/presentation/pages/workshop_verification_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/verificacion_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../../../support/mechanic_harness.dart'
    show FakeUserProfileProvider, fakeTaller;

/// Mismo doble que en `admin_verificaciones_evidencia_test.dart`: el
/// `AuthSessionProvider` real escucha `idTokenChanges()` de
/// `FirebaseAuth.instance` en su constructor y lanza en un widget test sin
/// `Firebase.initializeApp()`.
class _FakeAuthSessionProvider extends ChangeNotifier
    implements AuthSessionProvider {
  @override
  String get currentUid => 'taller-1';
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

/// Monta la pantalla con los tres providers que necesita, dentro de un
/// `GoRouter` (el botón «volver» llama `context.go`) y con las
/// localizaciones cargadas (la pantalla ahora lee `context.l10n`).
Future<void> _pumpPantalla(
  WidgetTester tester,
  VerificacionProvider provider, {
  SelectorDeArchivo? selectorDeArchivo,
}) async {
  final router = GoRouter(
    initialLocation: '/workshop_verification',
    routes: [
      GoRoute(
        path: '/workshop_verification',
        builder: (context, state) =>
            WorkshopVerificationScreen(selectorDeArchivo: selectorDeArchivo),
      ),
      GoRoute(
        path: '/mechanic_pending',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  // La pantalla completa (banner + checklist + tres tarjetas de evidencia)
  // no cabe en el viewport 800x600 por defecto: sin esto, `tester.tap()`
  // sobre las tarjetas de más abajo (rótulo, NIT) cae fuera del árbol
  // renderizado y el hit test falla en vez de tocar el botón.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthSessionProvider>(
          create: (_) => _FakeAuthSessionProvider(),
        ),
        ChangeNotifierProvider<UserProfileProvider>(
          create: (_) => FakeUserProfileProvider(user: fakeTaller()),
        ),
        ChangeNotifierProvider<VerificacionProvider>.value(value: provider),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );

  // `initState` dispara `provider.cargar(uid)` en un postFrameCallback.
  for (var i = 0; i < 10 && provider.cargando; i++) {
    await tester.pump();
  }
  await tester.pump();
}

/// XFile en memoria, sin tocar disco ni el canal de plataforma de
/// `image_picker`. En la variante `dart:io` de `cross_file` el parámetro
/// `name` de `XFile.fromData` se ignora — el nombre sale de `path` — así que
/// hay que fijar los dos para que `archivo.name` devuelva lo esperado.
XFile _archivoDePrueba(String nombre, Uint8List bytes) =>
    XFile.fromData(bytes, name: nombre, path: nombre, mimeType: 'image/jpeg');

/// PNG válido de 1x1 transparente. `Image.memory` decodifica bytes de
/// verdad (no solo los guarda), así que un `Uint8List` cualquiera hace que
/// `dart:ui` lance al resolver el codec y tumbe el test con una excepción no
/// capturada. Estos tests no verifican qué pinta la imagen, solo que el
/// widget de previsualización existe, pero igual necesita bytes decodificables.
final Uint8List _pngDePrueba = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  late FakeFirebaseFirestore firestore;
  late List<String> rutasSubidas;
  late VerificacionProvider provider;

  VerificacionProvider crearProvider({ResolutorDeUrl? resolutorDeUrl}) {
    rutasSubidas = [];
    return VerificacionProvider(
      service: VerificacionService(
        firestore: firestore,
        subidor:
            ({
              required String ruta,
              required Uint8List bytes,
              required String contentType,
            }) async => rutasSubidas.add(ruta),
        resolutorDeUrl: resolutorDeUrl,
        ahora: () => DateTime.utc(2026, 3, 10),
      ),
    );
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    provider = crearProvider();
  });

  testWidgets(
    'tras seleccionar un archivo, el slot muestra una miniatura antes de '
    'confirmar',
    (tester) async {
      final bytes = _pngDePrueba;
      await provider.cargar('taller-1');

      await _pumpPantalla(
        tester,
        provider,
        selectorDeArchivo: () async => _archivoDePrueba('fachada.jpg', bytes),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is MemoryImage,
        ),
        findsNothing,
        reason: 'todavía no se ha elegido ningún archivo',
      );

      await tester.tap(find.text('Subir').first);
      await tester.pump();
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is MemoryImage,
        ),
        findsOneWidget,
        reason:
            'el archivo recién elegido se previsualiza desde bytes locales, '
            'sin haberse subido',
      );
    },
  );

  testWidgets('seleccionar y no confirmar no dispara ninguna subida', (
    tester,
  ) async {
    final bytes = _pngDePrueba;
    await provider.cargar('taller-1');

    await _pumpPantalla(
      tester,
      provider,
      selectorDeArchivo: () async => _archivoDePrueba('fachada.jpg', bytes),
    );

    await tester.tap(find.text('Subir').first);
    await tester.pump();
    await tester.pump();

    expect(
      rutasSubidas,
      isEmpty,
      reason: 'seleccionar un archivo no debe subirlo por sí solo',
    );
    expect(provider.expediente?.documentos['fachada'], isNull);
    expect(
      find.text('Confirmar y subir'),
      findsOneWidget,
      reason: 'la previsualización debe ofrecer confirmar explícitamente',
    );
  });

  testWidgets(
    'confirmar y subir sí ejecuta la subida y limpia la previsualización',
    (tester) async {
      final bytes = _pngDePrueba;
      await provider.cargar('taller-1');

      await _pumpPantalla(
        tester,
        provider,
        selectorDeArchivo: () async => _archivoDePrueba('fachada.jpg', bytes),
      );

      await tester.tap(find.text('Subir').first);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Confirmar y subir'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(rutasSubidas, ['verificaciones/taller-1/fachada.jpg']);
      expect(provider.expediente?.documentos['fachada'], isNotNull);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is MemoryImage,
        ),
        findsNothing,
        reason:
            'una vez subido, la previsualización local ya no hace falta: '
            'el documento subido es la fuente de verdad',
      );
    },
  );

  testWidgets(
    'un PDF elegido para el NIT se previsualiza con nombre, tamaño e icono, '
    'sin renderizador embebido',
    (tester) async {
      final bytes = Uint8List(2 * 1024 * 1024); // 2 MB
      await provider.cargar('taller-1');

      await _pumpPantalla(
        tester,
        provider,
        selectorDeArchivo: () async => _archivoDePrueba('nit.pdf', bytes),
      );

      final botonesSubir = find.text('Subir');
      // Los tres slots (fachada, rótulo, NIT) empiezan vacíos: el del NIT es
      // el tercero en el orden en que se pintan.
      await tester.tap(botonesSubir.at(2));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(find.textContaining('nit.pdf'), findsOneWidget);
      expect(find.textContaining('2.0 MB'), findsOneWidget);
    },
  );

  testWidgets(
    'un documento ya subido, al recibir un tap, abre el AppImageViewer de A1',
    (tester) async {
      await firestore.collection('verificaciones').doc('taller-1').set({
        'documentos': {
          'fachada': {
            'nombre_archivo': 'fachada.jpg',
            'fecha': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
          },
        },
      });
      final providerConUrl = crearProvider(
        resolutorDeUrl: (ruta) async => 'https://storage.test/$ruta',
      );
      await providerConUrl.cargar('taller-1');

      await _pumpPantalla(tester, providerConUrl);

      expect(find.byType(AppImageViewer), findsNothing);
      expect(find.byType(InteractiveViewer), findsNothing);

      await tester.tap(find.text('Foto de la fachada'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppImageViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    },
  );
}
