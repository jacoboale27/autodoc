import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:autodoc/features/mechanic/presentation/pages/mechanic_reviews_screen.dart';

import '../../../../support/mechanic_harness.dart';

/// Regresion del gap 1 de GAPS-07.
///
/// La anotacion decia que el dialogo de respuesta desbordaba ~99 000 px por
/// culpa del `IntrinsicWidth` de `AlertDialog` y el `SizedBox(width:
/// double.maxFinite)` de `AppDialogContent`. Medido, eso es falso: el dialogo
/// mide bien tanto a 360 como a 1200 px, incluso con el codigo defectuoso.
///
/// El defecto real era de ciclo de vida. `_mostrarDialogoResponder` creaba el
/// `TextEditingController` en el metodo y lo desechaba en la linea siguiente
/// al `await showDialog`, pero `showDialog` devuelve en cuanto se llama a
/// `Navigator.pop` — con la ruta todavia montada, animando su salida. El campo
/// vivo volvia a usar el controlador muerto, y de ahi salia la cascada de
/// excepciones que terminaba en el desbordamiento. Es un defecto de
/// PRODUCCION, no solo de test: la ruta que se anima es la misma en la app.
///
/// Por eso este test no afirma solo sobre el ancho: **escribe y cierra**, que
/// es lo unico que ejercita el ciclo de vida del controlador.
Future<FakeFirebaseFirestore> _sembrar() async {
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('usuarios').doc('t1').set({
    'calificacion_promedio': 4.5,
    'total_resenias': 1,
  });
  await firestore.collection('resenias').doc('r0').set({
    'id_taller': 't1',
    'id_usuario': 'u0',
    'estrellas': 5,
    'comentario': 'Muy buen servicio',
    'fecha_resenia': DateTime(2026, 7, 1),
    'fotos': <String>[],
  });
  return firestore;
}

Future<void> _abrirDialogo(WidgetTester tester, {required double width}) async {
  final firestore = await _sembrar();
  await pumpMechanicScreen(
    tester,
    MechanicReviewsScreen(firestore: firestore),
    width: width,
    height: 1000,
    location: '/mechanic_reviews',
    disableAnimations: true,
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Responder'));
  await tester.pumpAndSettle();
  expect(find.text('Responder a la reseña'), findsOneWidget);
}

void main() {
  for (final ancho in <double>[360, 1200]) {
    testWidgets('el diálogo de respuesta cabe en una pantalla de $ancho px', (
      tester,
    ) async {
      await _abrirDialogo(tester, width: ancho);

      final medido = tester.getSize(find.byType(AlertDialog)).width;
      expect(
        medido,
        lessThanOrEqualTo(ancho),
        reason: 'el diálogo mide $medido px en una pantalla de $ancho',
      );
    });
  }

  testWidgets('escribir y cancelar no usa el controlador tras desecharlo', (
    tester,
  ) async {
    await _abrirDialogo(tester, width: 1200);

    await tester.enterText(find.byType(TextField), 'Gracias por tu confianza');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    // Sin `pumpAndSettle` no se llega a ver: la excepcion aparece en el primer
    // rebuild DESPUES del pop, mientras la ruta se desmonta.
    await tester.pumpAndSettle();

    expect(find.text('Responder a la reseña'), findsNothing);
    expect(
      tester.takeException(),
      isNull,
      reason: 'el controlador se desechó con su campo todavía en el árbol',
    );
  });
}
