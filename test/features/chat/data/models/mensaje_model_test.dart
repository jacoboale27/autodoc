import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';

void main() {
  test('fromMap/toMap conservan duracionSegundos para mensajes de audio', () {
    final model = MensajeModel(
      id: 'm1',
      idRemitente: 'u1',
      contenido: '🎤 Nota de voz',
      tipo: 'audio',
      timestamp: DateTime(2026, 7, 31),
      urlArchivo: 'https://example.com/audio.m4a',
      duracionSegundos: 12,
    );

    expect(model.toMap()['duracion_segundos'], 12);

    final restored = MensajeModel.fromMap(model.toMap(), 'm1');
    expect(restored.duracionSegundos, 12);
  });

  test(
    'duracionSegundos es null para mensajes de texto existentes (retrocompatibilidad)',
    () {
      final restored = MensajeModel.fromMap({
        'id_remitente': 'u1',
        'contenido': 'hola',
        'tipo': 'texto',
      }, 'm2');

      expect(restored.duracionSegundos, isNull);
    },
  );
}
