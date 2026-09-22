import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Centinela: `firestore.rules` no puede declarar un `match` con comodin
/// recursivo (`{document=**}`).
///
/// **Por que existe.** Las reglas de Firestore v2 no cascadean: un `match`
/// sobre una coleccion no alcanza a sus subcolecciones. TODO el modelo de
/// seguridad de este repositorio se apoya en eso — cada una de las 28
/// colecciones se autoriza por separado, y varias estan cerradas a todo
/// cliente por los dos lados (`tokens_historial`, `solicitudes_landing_control`,
/// `consultas_ia_control`, `explicaciones_ia`, `configuracion`).
///
/// Un solo `match /{document=**}` en cualquier parte del archivo derriba eso
/// de golpe, y lo derriba EN SILENCIO: no hay error de sintaxis, el despliegue
/// pasa, y los tests de `test_rules/` que afirman `assertFails` empezarian a
/// fallar uno a uno sin que nadie relacionara la causa. Peor todavia si el
/// comodin concede en vez de denegar, porque entonces los tests que PASAN son
/// los que mienten.
///
/// Es la clase de defecto que solo se ve leyendo la configuracion, como
/// `test/firestore_indices_test.dart` y `test/despliegue_web_protegido_test.dart`.
/// Lo propuso el gate de revision de reglas al verificar que las colecciones
/// del asistente de agenda no eran alcanzables por otra via: comprobarlo una
/// vez no sirve de nada si manana puede dejar de ser cierto.
///
/// Si algun dia hace falta un comodin de verdad, este test tiene que caer en
/// el mismo commit, con su razon escrita al lado — no silenciado.
void main() {
  final raiz = Directory.current.path;

  String leerReglas() {
    final archivo = File('$raiz/firestore.rules');
    expect(
      archivo.existsSync(),
      isTrue,
      reason: 'No hay firestore.rules en la raiz del repositorio.',
    );
    return archivo.readAsStringSync();
  }

  test('no hay ningun match con comodin recursivo', () {
    final reglas = leerReglas();
    final lineas = reglas.split('\n');
    final culpables = <String>[];

    for (var i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      // Solo el comodin RECURSIVO (`=**`). Un `{document}` de un segmento es
      // el patron normal y correcto de todo el archivo.
      if (RegExp(r'match\s+[^\s]*\{\w+\s*=\s*\*\*\s*\}').hasMatch(linea)) {
        culpables.add('${i + 1}: ${linea.trim()}');
      }
    }

    expect(
      culpables,
      isEmpty,
      reason:
          'firestore.rules declara un match con comodin recursivo. Eso hace '
          'que las reglas cascadeen a TODAS las subcolecciones que cuelguen '
          'de esa ruta, y este repositorio cierra varias colecciones a todo '
          'cliente contando con que no cascadean. Si el comodin es '
          'deliberado, retira este centinela en el mismo commit y explica por '
          'que; no lo dejes pasar en silencio.\n'
          'Encontrado en:\n${culpables.join('\n')}',
    );
  });

  test('el centinela mira el archivo correcto y sabe reconocer un match', () {
    // Sin esto, el test de arriba pasaria igual de bien sobre un archivo
    // vacio, sobre una ruta equivocada o con una expresion regular rota — que
    // es como un centinela se convierte en decoracion. Es la leccion del
    // `rojo-antes` que no revirtio nada.
    final reglas = leerReglas();

    expect(
      RegExp(r'match\s+/databases/\{database\}/documents').hasMatch(reglas),
      isTrue,
      reason: 'No se reconoce la raiz de firestore.rules: la ruta esta mal.',
    );

    // `multiLine: true` no es decorativo: sin el, `^` solo casa el principio
    // de TODA la cadena y el contador daba 0 — o sea que este propio
    // centinela se atrapo a si mismo la primera vez que se ejecuto.
    final cuantosMatch = RegExp(
      r'^\s*match\s+/',
      multiLine: true,
    ).allMatches(reglas).length;
    expect(
      cuantosMatch,
      greaterThan(20),
      reason:
          'Solo se ven $cuantosMatch bloques `match`, y este repositorio tiene '
          'del orden de 30. El centinela no esta leyendo lo que cree.',
    );

    // Y que la expresion del test de arriba SI atrapa un comodin cuando lo
    // hay: se comprueba sobre una cadena de mentira, no sobre el archivo.
    expect(
      RegExp(
        r'match\s+[^\s]*\{\w+\s*=\s*\*\*\s*\}',
      ).hasMatch(r'      match /{document=**} {'),
      isTrue,
      reason: 'La expresion regular del centinela no reconoce un comodin.',
    );
  });
}
