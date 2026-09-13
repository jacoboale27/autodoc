import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/review_model.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/review_sheet.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';

/// Registra con qué argumentos de foto se llamó a `updateReview`, que es
/// exactamente el contrato que FUNC-01 tenía roto: la pantalla dejaba
/// seleccionar fotos que el servicio nunca recibía.
class _FakeReviewService implements ReviewService {
  _FakeReviewService(this._existente);

  final ReviewModel? _existente;

  bool llamadoUpdate = false;
  List<String>? conservadasRecibidas;
  List<XFile> nuevasRecibidas = const [];

  @override
  Future<ReviewModel?> getUserReviewForService(
    String userId,
    String idServicio,
  ) async => _existente;

  @override
  Future<List<String>?> updateReview({
    required String reviewId,
    required String tallerId,
    required int estrellas,
    String? comentario,
    List<String>? fotosConservadas,
    List<XFile> fotosNuevas = const [],
  }) async {
    llamadoUpdate = true;
    conservadasRecibidas = fotosConservadas;
    nuevasRecibidas = fotosNuevas;
    return [...?fotosConservadas];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  @override
  UserModel? get userData => UserModel(
    idUsuario: 'u1',
    nombreCompleto: 'Juan Owner',
    correo: 'owner@test.com',
    rol: 'Propietario',
    fechaRegistro: DateTime(2026, 1, 1),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// PNG 1x1 decodificable: `Image.memory` decodifica de verdad, así que unos
/// bytes cualesquiera tumbarían el test al resolver el codec.
final Uint8List _png1x1 = Uint8List.fromList(const <int>[
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

ReviewModel _resenia(List<String> fotos) => ReviewModel(
  idResenia: 's1_u1',
  idUsuario: 'u1',
  idTaller: 't1',
  idServicio: 's1',
  estrellas: 4,
  comentario: 'original',
  fechaResenia: DateTime.now(),
  fotos: fotos,
);

Future<void> _abrirSheet(
  WidgetTester tester, {
  required _FakeReviewService service,
  SelectorDeFotoResenia? selector,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<UserProfileProvider>.value(
      value: _FakeUserProfileProvider(),
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showReviewBottomSheet(
                context,
                tallerId: 't1',
                tallerNombre: 'Taller Central',
                idServicio: 's1',
                reviewService: service,
                selectorDeFoto: selector,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('en modo edicion se muestran las fotos ya publicadas', (
    tester,
  ) async {
    final service = _FakeReviewService(
      _resenia(const ['https://a/1.jpg', 'https://a/2.jpg']),
    );
    await _abrirSheet(tester, service: service);

    expect(
      find.byKey(const ValueKey('foto-existente-https://a/1.jpg')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('foto-existente-https://a/2.jpg')),
      findsOneWidget,
    );
  });

  testWidgets('editar sin tocar las fotos las conserva todas', (tester) async {
    final service = _FakeReviewService(
      _resenia(const ['https://a/1.jpg', 'https://a/2.jpg']),
    );
    await _abrirSheet(tester, service: service);

    await tester.tap(find.text('Actualizar reseña'));
    await tester.pumpAndSettle();

    expect(service.llamadoUpdate, isTrue);
    expect(service.conservadasRecibidas, [
      'https://a/1.jpg',
      'https://a/2.jpg',
    ]);
    expect(service.nuevasRecibidas, isEmpty);
  });

  testWidgets('quitar una foto publicada la excluye de las conservadas', (
    tester,
  ) async {
    final service = _FakeReviewService(
      _resenia(const ['https://a/1.jpg', 'https://a/2.jpg']),
    );
    await _abrirSheet(tester, service: service);

    await tester.tap(find.byKey(const ValueKey('quitar-https://a/1.jpg')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('foto-existente-https://a/1.jpg')),
      findsNothing,
    );

    await tester.tap(find.text('Actualizar reseña'));
    await tester.pumpAndSettle();

    expect(service.conservadasRecibidas, ['https://a/2.jpg']);
  });

  testWidgets('en modo edicion se puede anadir una foto nueva', (tester) async {
    final service = _FakeReviewService(_resenia(const ['https://a/1.jpg']));
    await _abrirSheet(
      tester,
      service: service,
      selector: () async => XFile.fromData(
        _png1x1,
        name: 'nueva.png',
        path: 'nueva.png',
        mimeType: 'image/png',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('anadir-foto')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Actualizar reseña'));
    await tester.pumpAndSettle();

    expect(service.conservadasRecibidas, ['https://a/1.jpg']);
    expect(service.nuevasRecibidas.length, 1);
    expect(service.nuevasRecibidas.single.name, 'nueva.png');
  });

  testWidgets('el boton de anadir desaparece al llegar al maximo', (
    tester,
  ) async {
    final service = _FakeReviewService(
      _resenia(const ['https://a/1.jpg', 'https://a/2.jpg', 'https://a/3.jpg']),
    );
    await _abrirSheet(tester, service: service);

    expect(find.byKey(const ValueKey('anadir-foto')), findsNothing);
  });
}
