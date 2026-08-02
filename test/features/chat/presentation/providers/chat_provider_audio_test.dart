import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';

/// Mock mínimo, calcado del usado en chat_provider_test.dart, para poder
/// construir un ChatProvider sin depender de Firebase.initializeApp().
class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  test(
    'subirAudioChat retorna null y limpia isLoading si la subida falla',
    () async {
      // No hay mock de Storage inyectado en ChatProvider (igual que
      // subirImagenChat, que tampoco se testea contra Storage real).
      // Un archivo inexistente hace que File.readAsBytes() lance antes
      // de tocar FirebaseStorage, ejercitando la rama catch sin red.
      // Se inyecta un ChatRepository mock para evitar necesitar
      // Firebase.initializeApp() en el constructor de ChatProvider.
      final provider = ChatProvider(repository: MockChatRepository());

      final result = await provider.subirAudioChat(
        'conv1',
        File('/ruta/inexistente.m4a'),
      );

      expect(result, isNull);
      expect(provider.isLoading, isFalse);
    },
  );
}
