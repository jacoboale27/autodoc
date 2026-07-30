import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/features/chat/presentation/pages/reserva_detail_screen.dart';

// Cubre C-03 / Importante 1 de la revision de la Tarea 12: antes, esta
// pantalla casteaba `state.extra` a un `ReservaModel` no nulable, asi que
// una recarga o un enlace directo sin `extra` producia una pantalla en
// blanco. Ahora recibe solo el id y carga el documento; estos tests
// verifican que, aun cuando el documento no existe en Firestore, nunca se
// renderiza una pantalla vacia -- se muestra MissingArgumentScreen.
void main() {
  testWidgets('muestra MissingArgumentScreen (no una pantalla en blanco) si la '
      'reserva no existe en Firestore', (tester) async {
    final firestore = FakeFirebaseFirestore();
    // Deliberadamente no se crea ningun documento 'no-existe'.

    await tester.pumpWidget(
      MaterialApp(
        home: ReservaDetailScreen(reservaId: 'no-existe', firestore: firestore),
      ),
    );

    // Deja que se resuelva la carga asincrona (doc.get() del fake).
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar esta reserva.'), findsOneWidget);
    expect(find.byType(Text), findsWidgets);
  });
}
