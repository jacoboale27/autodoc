// test/features/mechanic/presentation/pages/workshop_verification_nit_pdf_test.dart
//
// VER-01: el NIT debe poder subirse como PDF real.
//
// El test anterior de esta pantalla ("un PDF elegido para el NIT...") inyecta
// directamente un `XFile` a traves del seam `selectorDeArchivo`, que en
// produccion envuelve `ImagePicker().pickImage(source: gallery)`. Ese picker
// JAMAS puede devolver un PDF: la suite pasaba en verde sobre una ruta
// inalcanzable.
//
// Este archivo NO repite ese truco. La pantalla, para el slot `nit`, llama
// a `FilePicker.pickFiles(...)` (API estatica de `file_picker`), que a su vez
// delega en `FilePickerPlatform.instance.pickFiles(...)`. El doble de este
// test sustituye exactamente esa pieza -`FilePickerPlatform.instance`- y dejaó
// todo lo demas (el `type`/`allowedExtensions` que la pantalla pasa, la
// resolucion de `FilePicker.pickFiles`, la lectura de bytes con
// `PlatformFile.readAsBytes()`) corriendo con codigo real de produccion. Es
// la misma tecnica que usa la app para sustituir `ImagePickerPlatform.instance`
// en cualquier plugin con arquitectura "platform interface": se reemplaza la
// implementacion del canal de plataforma, nunca el resultado de mas arriba.
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';
import 'package:autodoc/features/mechanic/presentation/pages/workshop_verification_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/verificacion_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../../../support/mechanic_harness.dart'
    show FakeUserProfileProvider, fakeTaller;

/// Doble de `AuthSessionProvider`: el real escucha
/// `FirebaseAuth.instance.idTokenChanges()` en su constructor, que revienta
/// en un widget test sin `Firebase.initializeApp()`. Mismo doble que en
/// `workshop_verification_screen_test.dart`.
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

/// Sustituye el canal de plataforma de `file_picker`. Registra con QUE
/// `type`/`allowedExtensions` la pantalla llamo, y devuelve el resultado que
/// se le indique en `respuesta` — sin que la app conozca ni toque esta clase:
/// llega a ella solo a traves de `FilePicker.pickFiles`, la misma API estatica
/// que usa el codigo de produccion.
class _FakeFilePickerPlatform extends FilePickerPlatform {
  _FakeFilePickerPlatform(this.respuesta);

  final FilePickerResult? respuesta;
  FileType? tipoRecibido;
  List<String>? extensionesRecibidas;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
    dynamic androidSafOptions,
  }) async {
    tipoRecibido = type;
    extensionesRecibidas = allowedExtensions;
    return respuesta;
  }
}

Future<void> _pumpPantalla(
  WidgetTester tester,
  VerificacionProvider provider,
) async {
  final router = GoRouter(
    initialLocation: '/workshop_verification',
    routes: [
      GoRoute(
        path: '/workshop_verification',
        builder: (context, state) => const WorkshopVerificationScreen(),
      ),
      GoRoute(
        path: '/mechanic_pending',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

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

  for (var i = 0; i < 10 && provider.cargando; i++) {
    await tester.pump();
  }
  await tester.pump();
}

void main() {
  late FakeFirebaseFirestore firestore;
  late List<String> rutasSubidas;
  late FilePickerPlatform plataformaOriginal;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    rutasSubidas = [];
    plataformaOriginal = FilePickerPlatform.instance;
  });

  tearDown(() {
    // El canal de `file_picker` es un singleton estatico global: sin
    // restaurarlo, el doble de un test se cuela en el resto de la suite.
    FilePickerPlatform.instance = plataformaOriginal;
  });

  VerificacionProvider crearProvider() => VerificacionProvider(
    service: VerificacionService(
      firestore: firestore,
      subidor:
          ({
            required String ruta,
            required Uint8List bytes,
            required String contentType,
          }) async => rutasSubidas.add(ruta),
      ahora: () => DateTime.utc(2026, 3, 10),
    ),
  );

  testWidgets(
    'tocar "Subir" en el slot NIT llama a FilePicker.pickFiles con PDF entre '
    'las extensiones permitidas',
    (tester) async {
      final fake = _FakeFilePickerPlatform(null);
      FilePickerPlatform.instance = fake;

      final provider = crearProvider();
      await provider.cargar('taller-1');
      await _pumpPantalla(tester, provider);

      // Los tres slots (fachada, rótulo, NIT) se pintan en ese orden: el NIT
      // es el tercer botón "Subir".
      await tester.tap(find.text('Subir').at(2));
      await tester.pump();
      await tester.pump();

      expect(
        fake.tipoRecibido,
        FileType.custom,
        reason:
            'la pantalla debe pedir tipo custom, no la galeria de imagenes '
            'de image_picker',
      );
      expect(
        fake.extensionesRecibidas,
        containsAll(<String>['pdf', 'jpg', 'jpeg', 'png']),
        reason: 'el selector del NIT debe admitir PDF ademas de imagenes',
      );
    },
  );

  testWidgets(
    'un PDF real devuelto por FilePickerPlatform.instance se previsualiza '
    'con nombre, tamaño e icono, sin subirlo todavía',
    (tester) async {
      final bytes = Uint8List(2 * 1024 * 1024); // 2 MB
      FilePickerPlatform.instance = _FakeFilePickerPlatform(
        FilePickerResult([
          PlatformFile(
            name: 'nit.pdf',
            size: bytes.lengthInBytes,
            bytes: bytes,
          ),
        ]),
      );

      final provider = crearProvider();
      await provider.cargar('taller-1');
      await _pumpPantalla(tester, provider);

      await tester.tap(find.text('Subir').at(2));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(find.textContaining('nit.pdf'), findsOneWidget);
      expect(find.textContaining('2.0 MB'), findsOneWidget);
      expect(
        rutasSubidas,
        isEmpty,
        reason: 'elegir el PDF no debe subirlo por si solo',
      );

      await tester.tap(find.text('Confirmar y subir'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(rutasSubidas, ['verificaciones/taller-1/nit.pdf']);
      expect(provider.expediente?.documentos['nit']?.nombreArchivo, 'nit.pdf');
    },
  );

  testWidgets(
    'un archivo con extension no permitida para el NIT se rechaza antes de '
    'previsualizarse y sin llamar a subirEvidencia',
    (tester) async {
      final bytes = Uint8List(1024);
      FilePickerPlatform.instance = _FakeFilePickerPlatform(
        FilePickerResult([
          PlatformFile(name: 'documento.exe', size: bytes.length, bytes: bytes),
        ]),
      );

      final provider = crearProvider();
      await provider.cargar('taller-1');
      await _pumpPantalla(tester, provider);

      await tester.tap(find.text('Subir').at(2));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Confirmar y subir'),
        findsNothing,
        reason:
            'un formato no permitido no debe llegar a previsualizarse ni a '
            'ofrecer confirmar',
      );
      expect(rutasSubidas, isEmpty);
      expect(
        find.textContaining('Formatos aceptados'),
        findsOneWidget,
        reason: 'el rechazo debe explicar que formatos si valen',
      );
    },
  );
}
