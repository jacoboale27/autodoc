// test/features/chat/presentation/widgets/adjunto_preview_sheet_test.dart
//
// Tarea 12, C6, revisión — F2 y F5: hasta ahora `AdjuntoPreviewSheet` solo se
// ejercitaba indirectamente a través de `ChatScreen`
// (`chat_screen_adjunto_preview_test.dart`), que nunca la monta a un
// viewport bajo ni afirma sobre el nombre/peso que muestra. Este archivo
// cubre el widget en aislamiento.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/chat/presentation/widgets/adjunto_preview_sheet.dart';

import '../../../../support/responsive_harness.dart';

/// PNG válido de 1x1 transparente (mismos bytes que
/// `chat_screen_adjunto_preview_test.dart` y
/// `workshop_verification_screen_test.dart`): `Image.memory` decodifica de
/// verdad, así que un `Uint8List` cualquiera lanza al resolver el codec.
final Uint8List _pngDePrueba = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82, //
]);

void main() {
  testWidgets('F5: muestra el nombre y el peso formateado del archivo', (
    tester,
  ) async {
    // 1.600.000 bytes = 1,52587890625 MiB -> "1.5", un valor que fija
    // exactamente el redondeo de `_tamanoEnMB` (no "1.6" ni "2.0"). Los
    // bytes no decodifican como imagen válida; el `errorBuilder` (F2,
    // opcional) evita que eso tumbe el test, y de todas formas el peso
    // mostrado sale de `bytes.lengthInBytes`, no de la decodificación.
    final bytes = Uint8List(1600000);
    await pumpAtWidth(
      tester,
      AdjuntoPreviewSheet(bytes: bytes, nombre: 'evidencia.png'),
      width: 400,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('evidencia.png'), findsOneWidget);
    expect(find.textContaining('1.5 MB'), findsOneWidget);
    // Por `Key` y no por texto: `pumpAtWidth` no fija locale, asi que la
    // hoja se pinta con el idioma por defecto del entorno de test (ingles).
    // Afirmar 'Cancelar' aqui ataba el test a un idioma; el nombre y el
    // peso, en cambio, no se traducen.
    expect(find.byKey(const Key('adjunto_preview_cancelar')), findsOneWidget);
    expect(find.byKey(const Key('adjunto_preview_cambiar')), findsOneWidget);
    expect(find.byKey(const Key('adjunto_preview_enviar')), findsOneWidget);
  });

  testWidgets(
    'F2: en un viewport bajo (paisaje) no desborda y los botones siguen '
    'alcanzables',
    (tester) async {
      const height = 260.0;
      await pumpAtWidth(
        tester,
        AdjuntoPreviewSheet(bytes: _pngDePrueba, nombre: 'foto_larga.jpg'),
        width: 700,
        height: height,
      );

      // Antes del fix: `RenderFlex overflowed` porque el contenido (imagen
      // fija de 220dp + título + info + fila de botones) no cabía en los
      // 260dp de alto disponibles y no había ningún scroll que lo
      // absorbiera.
      expectNoOverflow(tester);

      // El botón puede empezar fuera del viewport visible; a diferencia de
      // antes (arrastrar la hoja = cancelar), ahora hay un `Scrollable`
      // interno que `ensureVisible` puede usar para alcanzarlo.
      final enviar = find.byKey(const Key('adjunto_preview_enviar'));
      await tester.ensureVisible(enviar);
      await tester.pumpAndSettle();
      expectNoOverflow(tester);

      final rect = tester.getRect(enviar);
      expect(
        rect.bottom,
        lessThanOrEqualTo(height),
        reason:
            'el boton "Enviar" debe quedar dentro del viewport, no '
            'recortado por debajo',
      );
      expect(rect.top, greaterThanOrEqualTo(0));

      expect(find.byKey(const Key('adjunto_preview_cancelar')), findsOneWidget);
      expect(find.byKey(const Key('adjunto_preview_cambiar')), findsOneWidget);
      expect(enviar, findsOneWidget);
    },
  );
}
