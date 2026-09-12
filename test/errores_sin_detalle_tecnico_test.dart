import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Centinela de UX-04: ningun error tecnico vuelve a la pantalla.
///
/// Existe por la misma razon que `firestore_indices_test.dart`: **no hay
/// ninguna otra suite que pueda ver este defecto**. Un `Text('Error: $e')`
/// compila, analiza limpio y pasa cualquier test de widget — el fallo solo
/// aparece cuando a alguien, en produccion, le revienta una consulta. Y volver
/// a meterlo cuesta una linea de nada en cualquier `catch` nuevo.
///
/// Lo que se prohibe es concreto: interpolar la excepcion, o su `toString()`,
/// en un texto destinado a una persona. Lo que se permite, y por eso se mira
/// solo la capa de presentacion y los providers, es seguir registrandola —
/// `developer.log` y `debugPrint` reciben el objeto entero, que es donde tiene
/// que estar.
///
/// Para arreglar un rojo de aqui: `mensajeSeguroDeError(e, accion: '...')` de
/// `lib/core/utils/mensaje_de_error.dart`, o `mensajeDeError(context.l10n, e)`
/// si la pantalla puede traducir.

/// Ficheros donde el patron esta justificado, con el motivo al lado. Nada entra
/// aqui sin una razon escrita; si la lista crece sola, el centinela deja de
/// servir para nada.
const Map<String, String> excepcionesJustificadas = {
  'lib/features/mechanic/presentation/providers/galeria_provider.dart':
      'El codigo de Firebase va en el mensaje A PROPOSITO, y esta razonado en '
      'el propio fichero: sin el, un fallo de configuracion (bucket mal '
      'puesto, CORS del bucket sin metodos de escritura) es indistinguible '
      'de un corte de red y no hay forma de reportarlo. Es solo el CODIGO, '
      'no el mensaje interno ni la consulta.',
  'lib/features/mechanic/presentation/providers/verificacion_provider.dart':
      'Mismo caso y misma razon que galeria_provider: solo el codigo, y solo '
      'en la rama por defecto, despues de traducir los conocidos.',
};

/// Interpolaciones de la excepcion en una cadena.
///
/// `\$e` seguido de algo que no sea identificador (para no cazar `$estado`),
/// `\${e...}`, y `.toString()` sobre la variable del `catch`.
final RegExp interpolaCruda = RegExp(
  r'\$e[^a-zA-Z0-9_]|\$\{e[.}]|\be\.toString\(\)|\$\{snapshot\.error\}',
);

/// Lineas que registran, no muestran: ahi el detalle completo es lo que se
/// quiere.
final RegExp esRegistro = RegExp(
  r'debugPrint|developer\.log|print\(|// |///|/\*|\* ',
);

/// Capas que ve una persona: pantallas, widgets compartidos y providers.
///
/// `data/` queda fuera adrede. Un servicio que hace
/// `throw 'Error al obtener vehiculo: \$e'` esta bien: eso no se pinta, se
/// propaga, y el provider que lo recoge ya lo pasa por `mensajeSeguroDeError`.
/// Incluirlo aqui solo llenaria la lista de excepciones justificadas hasta
/// vaciar el centinela de sentido.
bool esCapaDeInterfaz(String ruta) {
  if (ruta.startsWith('lib/core/widgets/')) return true;
  if (ruta.startsWith('lib/core/providers/')) return true;
  return ruta.startsWith('lib/features/') && ruta.contains('/presentation/');
}

void main() {
  test('ninguna pantalla interpola la excepcion en un texto', () {
    final ofensas = <String>[];

    for (final entrada in Directory('lib').listSync(recursive: true)) {
      if (entrada is! File || !entrada.path.endsWith('.dart')) continue;
      final ruta = entrada.path.replaceAll(r'\', '/');
      if (!esCapaDeInterfaz(ruta)) continue;
      if (excepcionesJustificadas.containsKey(ruta)) continue;

      final lineas = entrada.readAsLinesSync();
      for (var i = 0; i < lineas.length; i += 1) {
        final linea = lineas[i];
        if (esRegistro.hasMatch(linea)) continue;
        if (!interpolaCruda.hasMatch(linea)) continue;
        // `.map((e) => e.toString())` sobre una lista no tiene nada que ver
        // con errores; la variable `e` ahi es un elemento.
        if (linea.contains('(e) =>') || linea.contains('(e)=>')) continue;
        ofensas.add('$ruta:${i + 1}: ${linea.trim()}');
      }
    }

    expect(
      ofensas,
      isEmpty,
      reason:
          'UX-04: el detalle tecnico de una excepcion no puede llegar a la '
          'pantalla. Usa mensajeSeguroDeError(e, accion: ...) o '
          'mensajeDeError(context.l10n, e). Si de verdad hace falta mostrarlo, '
          'anade el fichero a `excepcionesJustificadas` CON el motivo.\n'
          '${ofensas.join('\n')}',
    );
  });

  test('el centinela sabe distinguir lo que persigue', () {
    // Si estos dos dejaran de comportarse asi, el test de arriba estaria
    // pasando por no mirar nada.
    expect(interpolaCruda.hasMatch("Text('Error: \$e')"), isTrue);
    expect(interpolaCruda.hasMatch("Text('Error: \${e.code}')"), isTrue);
    expect(interpolaCruda.hasMatch("Text('Estado: \$estado')"), isFalse);
    expect(esRegistro.hasMatch("debugPrint('fallo: \$e');"), isTrue);
  });
}
