import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Centinela: el despliegue de `functions` no puede publicar un `.env` que
/// simule un emulador.
///
/// **Por que existe.** `functions/src/clienteDelModelo.js` elige entre Gemini
/// y el doble de emulador (`modeloFalso.js`) mirando
/// `FUNCTIONS_EMULATOR === 'true'`. Esa variable la pone el propio emulador de
/// Firebase y no existe en una funcion desplegada, asi que como compuerta es
/// solida frente a un descuido de codigo.
///
/// Lo que no cubre es la CONFIGURACION. Este proyecto manda variables al
/// runtime por `functions/.env.<projectId>` —el mecanismo con el que viaja
/// `APP_CHECK_ENFORCEMENT`— y **`FUNCTIONS_EMULATOR` no esta en las claves
/// reservadas de firebase-tools**, comprobado en la 15.28.2
/// (`lib/functions/env.js`). Una linea ahi llegaria al proceso desplegado y
/// abriria la compuerta.
///
/// El fallo resultante seria el peor de esa pieza porque es **silencioso**: el
/// asistente serviria respuestas enlatadas con toda la pinta de ser buenas.
/// Nada falla, nadie ve un error, y los numeros que lee la persona salen de
/// una plantilla en vez de sus datos.
///
/// **Y ninguna suite puede verlo**, porque esos `.env` estan en
/// `functions/.gitignore`: no se versionan y se editan a mano por proyecto. Es
/// la misma forma del incidente del 2026-09-13 —el fuente estaba bien y lo
/// contaminado era lo que se desplegaba— y por eso la respuesta es la misma:
/// una guarda en `predeploy`, que es el unico punto por el que pasa todo
/// `firebase deploy --only functions`. Este test existe para que nadie la
/// quite.
///
/// Hermano de `test/despliegue_web_protegido_test.dart`, que hace lo propio
/// con el bundle de hosting.
void main() {
  final raiz = Directory.current.path;

  Map<String, dynamic> leerFirebaseJson() {
    final archivo = File('$raiz/firebase.json');
    expect(
      archivo.existsSync(),
      isTrue,
      reason: 'No hay firebase.json en la raiz del repositorio.',
    );
    return jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
  }

  test('el bloque functions declara su guarda predeploy', () {
    final config = leerFirebaseJson();
    final functions = config['functions'];

    expect(
      functions,
      isA<Map<String, dynamic>>(),
      reason:
          'firebase.json no declara el bloque `functions`, o lo declara como '
          'lista. Si cambia de forma, esta guarda hay que reubicarla.',
    );

    final predeploy = (functions as Map<String, dynamic>)['predeploy'];
    expect(
      predeploy,
      isNotNull,
      reason:
          'El bloque `functions` perdio su `predeploy`. Sin el, un '
          'functions/.env con FUNCTIONS_EMULATOR=true se despliega sin que '
          'nada avise, y el asistente sirve respuestas enlatadas en '
          'produccion.',
    );

    final comandos = (predeploy as List<dynamic>).map((e) => '$e').toList();
    expect(
      comandos.any((c) => c.contains('verificar_env_functions.js')),
      isTrue,
      reason:
          'El `predeploy` de functions ya no invoca '
          'scripts/verificar_env_functions.js. Comandos declarados: $comandos',
    );
  });

  test('el script de la guarda existe y comprueba las claves que dice', () {
    // Sin esto, el test de arriba pasaria con el `predeploy` apuntando a un
    // script borrado o vaciado — que es como un centinela se vuelve
    // decoracion. Es la leccion del `rojo-antes` que no revirtio nada.
    final script = File('$raiz/scripts/verificar_env_functions.js');
    expect(
      script.existsSync(),
      isTrue,
      reason:
          'firebase.json invoca scripts/verificar_env_functions.js y ese '
          'archivo no existe: el despliegue fallaria, pero por el motivo '
          'equivocado.',
    );

    final fuente = script.readAsStringSync();
    expect(
      fuente.contains('FUNCTIONS_EMULATOR'),
      isTrue,
      reason:
          'La guarda ya no comprueba FUNCTIONS_EMULATOR, que es la clave que '
          'abre la compuerta del doble de emulador.',
    );
    expect(
      fuente.contains('FIRESTORE_EMULATOR_HOST'),
      isTrue,
      reason:
          'La guarda ya no comprueba FIRESTORE_EMULATOR_HOST. Esa clave '
          'redirige el Admin SDK de la funcion desplegada a otra maquina: '
          'dejaria de leer y escribir los datos reales.',
    );
  });
}
