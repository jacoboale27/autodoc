import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Centinela de coherencia entre `firestore.rules` y `AlertModel`.
///
/// **Por qué existe.** El acotado de campos de `/alertas` pasó de denylist a
/// allowlist (`hasOnly`) en la tanda GAPS-04. Una allowlist es estrictamente
/// más segura, pero tiene un modo de fallo propio: **cualquier escritor que use
/// un nombre fuera del inventario muere con `permission-denied`**. Si
/// `AlertModel` gana un campo mañana y nadie amplía la regla, el campo se
/// deniega **solo en producción** — los emuladores no pueden avisar, porque
/// obedecen la regla igual de bien que Firestore.
///
/// El comentario de la regla prometía que «el test lo obliga». No lo obligaba:
/// la suite de `test_rules/` escribe su propio inventario en JS, así que se
/// queda atrás en silencio exactamente igual. Lo señaló el gate de revisión de
/// reglas, y este archivo es la respuesta.
///
/// Cruza las dos listas **en las dos direcciones**, que es lo que hace útil a un
/// centinela: sobrar un campo en la regla es un permiso que nadie pidió, y
/// faltar es una escritura que morirá en producción.
///
/// Mismo patrón que `test/features/chat/tombstone_literal_test.dart`.
void main() {
  final raiz = Directory.current.path;

  test('camposDeAlerta() de firestore.rules es espejo de AlertModel.toMap()', () {
    final enLaRegla = _listaDeLaRegla(raiz, 'camposDeAlerta');
    final enElModelo = _clavesDeToMap(raiz);

    expect(
      enLaRegla.difference(enElModelo),
      isEmpty,
      reason:
          'La regla permite campos que el modelo no escribe. Un permiso que '
          'nadie pidio: quitalos de camposDeAlerta() en firestore.rules.',
    );
    expect(
      enElModelo.difference(enLaRegla),
      isEmpty,
      reason:
          'AlertModel.toMap() escribe campos que la regla NO permite. Escribir '
          'una alerta morira con permission-denied, y solo en produccion: los '
          'emuladores aplican la misma regla, asi que ninguna suite lo ve. '
          'Anade el campo a camposDeAlerta() en firestore.rules, y decide si '
          'va tambien en camposMutablesDeAlerta().',
    );
  });

  test('los campos mutables son los del modelo menos la identidad', () {
    final mutables = _listaDeLaRegla(raiz, 'camposMutablesDeAlerta');
    final todos = _listaDeLaRegla(raiz, 'camposDeAlerta');

    // `id_vehiculo` e `id_alerta` son identidad y no se reescriben: el primero
    // porque mover una alerta al coche de otra persona no es una operacion
    // legitima, el segundo porque la app lo usa como DESTINO de la escritura al
    // completar la alerta, asi que reescribirlo la deja pintada como completada
    // y `Pendiente` en el servidor para siempre.
    expect(
      todos.difference(mutables),
      {'id_vehiculo', 'id_alerta'},
      reason:
          'Cambio el conjunto de campos INMUTABLES de /alertas. Si es a '
          'proposito, actualiza este centinela explicando por que; si no, es '
          'un campo de identidad que acaba de volverse reescribible.',
    );
  });
}

/// Extrae los literales de una funcion de `firestore.rules` que devuelve una
/// lista de cadenas.
Set<String> _listaDeLaRegla(String raiz, String nombre) {
  final reglas = File('$raiz/firestore.rules').readAsStringSync();
  final inicio = reglas.indexOf('function $nombre()');
  expect(
    inicio,
    isNot(-1),
    reason:
        'No existe `function $nombre()` en firestore.rules. Si se renombro, '
        'actualiza este centinela: sin el, la regla y el modelo pueden '
        'divergir sin que nada avise.',
  );
  final cuerpo = reglas.substring(
    reglas.indexOf('[', inicio),
    reglas.indexOf(']', inicio),
  );
  return RegExp(
    "'([a-z_]+)'",
  ).allMatches(cuerpo).map((m) => m.group(1)!).toSet();
}

/// Extrae las claves que escribe `AlertModel.toMap()`.
Set<String> _clavesDeToMap(String raiz) {
  final modelo = File(
    '$raiz/lib/core/models/alert_model.dart',
  ).readAsStringSync();
  final inicio = modelo.indexOf('Map<String, dynamic> toMap()');
  expect(inicio, isNot(-1), reason: 'AlertModel.toMap() ya no se llama asi.');
  final cuerpo = modelo.substring(
    inicio,
    modelo.indexOf('factory AlertModel.fromMap', inicio),
  );
  return RegExp(
    "'([a-z_]+)':",
  ).allMatches(cuerpo).map((m) => m.group(1)!).toSet();
}
