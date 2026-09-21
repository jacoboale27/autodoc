import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Centinela: el proyecto por defecto de `.firebaserc` no puede ser
/// produccion.
///
/// **Por que existe.** `CLAUDE.md` y `AGENTS.md` afirman, como advertencia
/// permanente, que «todo `firebase deploy` sin `--project` va a staging». Esa
/// frase es cierta solo mientras `.firebaserc` lo sea, y `.firebaserc` es un
/// fichero de cuatro lineas que nadie relee: el 2026-09-19 el arbol de trabajo
/// tenia `"default": "autodoc-6ef5a"` sin commitear, o sea que la advertencia
/// de los dos documentos era **falsa** y cualquier despliegue implicito
/// publicaba en produccion.
///
/// Es la misma forma que el incidente del 2026-09-13: la condicion peligrosa
/// no vive en el codigo que las suites miran, sino en la CONFIGURACION del
/// despliegue. Leer la configuracion es la unica forma de verlo — ni
/// `analyze`, ni `flutter test`, ni las reglas, ni Playwright pueden.
///
/// El default es una red de seguridad, no una interfaz: la regla de que todo
/// despliegue lleve `--project production` o `--project staging` explicito
/// sigue en pie. Este centinela solo garantiza que, cuando alguien la olvide,
/// el destino sea el proyecto que nunca se ha usado.
///
/// Si algun dia se decide de verdad que el default apunte a produccion, este
/// test tiene que caer EN EL MISMO COMMIT que la correccion de `CLAUDE.md` y
/// `AGENTS.md`. No lo silencies dejando los documentos mintiendo.
void main() {
  final raiz = Directory.current.path;

  Map<String, dynamic> leerProyectos() {
    final archivo = File('$raiz/.firebaserc');
    expect(
      archivo.existsSync(),
      isTrue,
      reason: 'No hay .firebaserc en la raiz del repositorio.',
    );
    final json = jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
    final proyectos = json['projects'];
    expect(
      proyectos,
      isA<Map<String, dynamic>>(),
      reason: '.firebaserc ya no declara el bloque `projects`.',
    );
    return (proyectos as Map).cast<String, dynamic>();
  }

  test('.firebaserc declara los tres alias que el runbook usa', () {
    final proyectos = leerProyectos();

    for (final alias in ['default', 'staging', 'production']) {
      expect(
        proyectos.containsKey(alias),
        isTrue,
        reason:
            'Falta el alias `$alias` en .firebaserc. El runbook de despliegue '
            'invoca `--project production` y `--project staging` por nombre; '
            'sin el alias, el comando falla o —peor— cae al implicito.',
      );
    }
  });

  test('el proyecto por defecto NO es produccion', () {
    final proyectos = leerProyectos();

    expect(
      proyectos['default'],
      isNot(equals(proyectos['production'])),
      reason:
          'El `default` de .firebaserc apunta al MISMO proyecto que el alias '
          '`production`. Con eso, un `firebase deploy` sin `--project` '
          'publica en produccion, y la advertencia permanente de CLAUDE.md y '
          'AGENTS.md («va a staging») pasa a ser falsa. Si el cambio es '
          'deliberado, corrige los dos documentos y retira este centinela en '
          'el mismo commit.',
    );
  });

  test('el proyecto por defecto es el alias de staging', () {
    final proyectos = leerProyectos();

    expect(
      proyectos['default'],
      equals(proyectos['staging']),
      reason:
          'El `default` de .firebaserc no coincide con el alias `staging`. '
          'Un despliegue implicito iria a un tercer proyecto que nadie ha '
          'documentado, que es peor que cualquiera de las dos opciones '
          'conocidas.',
    );
  });
}
