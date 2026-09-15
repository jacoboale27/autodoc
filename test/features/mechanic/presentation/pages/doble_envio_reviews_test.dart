import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/mechanic/presentation/pages/mechanic_reviews_screen.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';

import '../../../../support/mechanic_harness.dart';

/// `ReviewService` cuyas dos escrituras se quedan pendientes a voluntad. Con
/// `FakeFirebaseFirestore` a secas no hay ventana "en vuelo": la escritura
/// resuelve en el mismo microtask y el doble envio no se puede reproducir.
class _ServicioPendiente extends ReviewService {
  _ServicioPendiente(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  final reporte = Completer<void>();
  final respuesta = Completer<void>();
  var reportes = 0;
  var respuestas = 0;

  @override
  Future<void> reportReview(String reviewId) {
    reportes++;
    return reporte.future;
  }

  @override
  Future<void> responderResenia({
    required String reviewId,
    required String tallerId,
    required String texto,
  }) {
    respuestas++;
    return respuesta.future;
  }
}

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

Future<_ServicioPendiente> _montar(WidgetTester tester) async {
  final firestore = await _sembrar();
  final servicio = _ServicioPendiente(firestore);
  await pumpMechanicScreen(
    tester,
    MechanicReviewsScreen(firestore: firestore, reviewService: servicio),
    width: 1200,
    height: 1000,
    location: '/mechanic_reviews',
    disableAnimations: true,
  );
  await tester.pumpAndSettle();
  return servicio;
}

void main() {
  testWidgets('grupo 15: dos confirmaciones reportan la resenia una vez', (
    tester,
  ) async {
    final servicio = await _montar(tester);

    final reportar = find.widgetWithIcon(IconButton, Icons.flag_outlined);
    await tester.tap(reportar);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reportar'));
    await tester.pump();

    // El dialogo se cierra al confirmar, asi que el segundo envio solo puede
    // venir de reabrirlo. Se afirma sobre el control y no volviendo a tocarlo:
    // con `onPressed: null` el dialogo ya no puede abrirse.
    expect(tester.widget<IconButton>(reportar).onPressed, isNull);
    expect(servicio.reportes, 1);

    servicio.reporte.complete();
    await tester.pumpAndSettle();
  });

  // NO hay test del boton "Publicar" de la respuesta, y no es un olvido: el
  // dialogo de respuesta DESBORDA ~99000 px al abrirse en un test de widget y
  // las excepciones se encadenan por todo su subarbol (incluido el
  // RawGestureDetector), asi que no se puede tocar su boton. La causa no es
  // este arreglo: `AlertDialog` envuelve el contenido en `IntrinsicWidth` y el
  // `SizedBox(width: double.maxFinite)` de `AppDialogContent` vuelve absurdo el
  // ancho intrinseco. Es el unico de los dieciseis controles de esta tanda que
  // se queda sin test; el guard esta puesto y es el mismo `_enCurso` que el de
  // reportar, que si esta verificado arriba. Queda anotado como gap propio.
}
