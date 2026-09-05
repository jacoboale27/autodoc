import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardia de Blocker 6 (revisión de rama completa).
///
/// `firestore.rules` (match /mensajes, rama de borrado lógico) compara el
/// `contenido` que escribe `ChatRepository.deleteMensaje`
/// (`kTombstoneMensajeEliminado`) CARÁCTER A CARÁCTER contra un literal
/// propio. Los dos lados no comparten ninguna referencia en tiempo de
/// compilación — una regla de Firestore no puede importar una constante de
/// Dart — así que la única forma de que no diverjan es un test que lea
/// ambos archivos y los compare, siguiendo el patrón ya usado en
/// `test/features/dashboard/presentation/pages/workshop_directory_test.dart`
/// para invariantes de código fuente.
///
/// Si esto falla: alguien cambió el literal en un lado sin cambiar el otro
/// (típicamente una pasada de localización). Cambia AMBOS lados al mismo
/// valor; no debilites este test.
void main() {
  test(
    'el literal del tombstone es idéntico en ChatRepository y firestore.rules',
    () {
      final repoSource = File(
        'lib/features/chat/data/repositories/chat_repository.dart',
      ).readAsStringSync();
      final rulesSource = File('firestore.rules').readAsStringSync();

      final constanteMatch = RegExp(
        r"const String kTombstoneMensajeEliminado = '([^']*)';",
      ).firstMatch(repoSource);
      expect(
        constanteMatch,
        isNotNull,
        reason:
            'no se encontró `const String kTombstoneMensajeEliminado = \'...\';` '
            'en chat_repository.dart — ¿se renombró o se movió?',
      );
      final valorConstante = constanteMatch!.group(1);

      final reglaMatch = RegExp(
        r"request\.resource\.data\.contenido == '([^']*)'\)",
      ).firstMatch(rulesSource);
      expect(
        reglaMatch,
        isNotNull,
        reason:
            'no se encontró la comparación '
            '`request.resource.data.contenido == \'...\'` en firestore.rules '
            '(rama de borrado lógico de /mensajes) — ¿se reescribió la regla?',
      );
      final valorRegla = reglaMatch!.group(1);

      expect(
        valorRegla,
        equals(valorConstante),
        reason:
            'el literal del tombstone diverge entre '
            'kTombstoneMensajeEliminado ("$valorConstante") y firestore.rules '
            '("$valorRegla"). El borrado lógico fallará en producción para '
            'todos los usuarios hasta que ambos coincidan carácter a '
            'carácter.',
      );

      // Ademas del `equals` de arriba (que ya es la prueba real), se deja
      // explicito el valor esperado para que un cambio accidental de AMBOS
      // lados a la vez (que `equals` no detectaria) tambien se note aqui.
      expect(valorConstante, 'Este mensaje ha sido eliminado');
    },
  );

  test(
    'los dos tests de widget que fijan el tombstone usan la constante compartida, no un literal propio',
    () {
      for (final path in [
        'test/features/chat/presentation/pages/chat_screen_deleted_message_test.dart',
        'test/features/chat/presentation/pages/chat_screen_menu_contextual_test.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('kTombstoneMensajeEliminado'),
          isTrue,
          reason:
              '$path ya no referencia kTombstoneMensajeEliminado: ¿volvió a '
              'quedar un literal propio, desvinculado de la constante?',
        );
        expect(
          source.contains("'Este mensaje ha sido eliminado'"),
          isFalse,
          reason:
              '$path tiene el literal repetido en vez de usar '
              'kTombstoneMensajeEliminado.',
        );
      }
    },
  );
}
