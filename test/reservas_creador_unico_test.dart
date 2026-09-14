import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Centinela de GAPS-05 — la nota de la regla de `/reservas` dice que en `lib/`
/// hay **un unico creador de reservas**, y hasta ahora no lo vigilaba nadie.
///
/// **Ahora esa frase es carga estructural, no documentacion.** El `allow
/// create` de `firestore.rules` ata `id_taller == id_mecanico` y
/// `id_proponente == request.auth.uid` PORQUE se comprobo que eso es lo que
/// escribe el unico creador (`chat_screen.dart`). Si manana nace un segundo
/// creador con otro criterio —por ejemplo escribiendo `idTallerEfectivo` en
/// `id_taller`, que es lo que hacen las COTIZACIONES—, sus escrituras se van a
/// denegar en produccion y el sintoma sera un `permission-denied` opaco en una
/// pantalla que nadie relacionara con esta regla.
///
/// Es el tipo de invariante que FUNC-02 vio caducar: verdadero el dia que se
/// escribe y falso seis semanas despues, sin que nada avise.
///
/// Lo que el centinela NO puede hacer es comprobar los valores: para eso estan
/// `test_rules/reservas_id_taller.test.js` (la regla) y la revision humana del
/// diff. Lo que hace es obligar a que ese diff exista.
void main() {
  final raiz = Directory.current.path;

  /// Ficheros de `lib/` que construyen un `ReservaModel`, sin contar el propio
  /// modelo (su constructor y sus dos factories).
  List<String> creadores() {
    final encontrados = <String>[];
    for (final entrada in Directory('$raiz/lib').listSync(recursive: true)) {
      if (entrada is! File || !entrada.path.endsWith('.dart')) continue;
      final ruta = entrada.path.replaceAll(r'\', '/');
      if (ruta.endsWith('/reserva_model.dart')) continue;
      if (entrada.readAsStringSync().contains('ReservaModel(')) {
        encontrados.add(ruta.substring(ruta.indexOf('/lib/') + 1));
      }
    }
    return encontrados..sort();
  }

  test('sigue habiendo UN solo creador de reservas en lib/', () {
    expect(
      creadores(),
      ['lib/features/chat/presentation/pages/chat_screen.dart'],
      reason:
          'El `allow create` de /reservas ata `id_taller` a `id_mecanico` y '
          '`id_proponente` al llamante porque eso es lo que escribe este '
          'creador. Un creador nuevo con otro criterio se va a encontrar un '
          'permission-denied en produccion, no aqui. Si anades uno, comprueba '
          'que escribe esos dos campos igual y actualiza esta lista.',
    );
  });

  test('ese creador pasa `idProponente` explicitamente', () {
    // `ReservaModel` lo resuelve con `idProponente ?? idPropietario`, asi que
    // omitirlo no es un error de compilacion: es una cita que nace con el
    // proponente al reves cuando la propone el mecanico, y con ella la
    // confirmacion invertida. Ese fue el defecto que GAPS-05 encontro.
    final fuente = File(
      '$raiz/lib/features/chat/presentation/pages/chat_screen.dart',
    ).readAsStringSync();
    final desde = fuente.indexOf('ReservaModel(');
    expect(desde, greaterThan(-1));
    // Hasta el cierre de la llamada, no una ventana de N caracteres: la
    // primera version media 700 y fallaba porque el comentario que explica
    // este mismo campo empuja la linea mas alla. Una ventana fija convierte
    // un centinela en un medidor de longitud de comentarios.
    final cierre = fuente.indexOf('\n    );', desde);
    expect(
      cierre,
      greaterThan(desde),
      reason: 'no se encontro el fin de la llamada',
    );
    final bloque = fuente.substring(desde, cierre);

    expect(
      bloque.contains('idProponente:'),
      isTrue,
      reason:
          'sin `idProponente` explicito, una cita propuesta por el mecanico '
          'nace con el uid del propietario y el propietario no puede '
          'confirmarla — el `allow create` ademas la deniega',
    );
  });
}
