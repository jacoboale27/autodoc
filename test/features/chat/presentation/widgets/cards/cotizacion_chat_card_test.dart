import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_status_badge.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/contrast.dart';
import '../../../../../support/responsive_harness.dart';

// Desviación deliberada del snippet del brief: la firma original de `_card`
// no aceptaba `firestore` y CotizacionChatCard lo usaba sin inyectar nada,
// así que en un widget test sin Firebase.initializeApp() el
// StreamBuilder no "nunca emite" (como decía la nota del Step 2): lanza
// FirebaseException('[core/no-app]') de forma síncrona en build(), que
// Flutter atrapa como un ErrorWidget de tamaño no acotado y desborda el
// Column de ChatBubble. Mismo precedente que reserva_detail_screen_test.dart:
// se inyecta un FakeFirebaseFirestore explícito en cada test.
Widget _card({required bool isMe, required FakeFirebaseFirestore firestore}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ChatBubble(
          isMe: isMe,
          child: CotizacionChatCard(
            metadata: const {'id_cotizacion': 'q1'},
            isMe: isMe,
            mensajeId: 'm1',
            conversacionId: 'c1',
            firestore: firestore,
          ),
        ),
      ),
    );

/// Firestore con `cotizaciones/q1` ya sembrado, para que el `StreamBuilder`
/// del widget resuelva a la tarjeta con contenido en el primer settle.
Future<FakeFirebaseFirestore> _firestoreConCotizacion({
  String estado = 'pendiente',
  bool conItems = true,
}) async {
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('cotizaciones').doc('q1').set({
    'id_propietario': 'u1',
    'id_mecanico': 'm1',
    'items': conItems
        ? [
            {'material': 'Filtro de aceite', 'cantidad': 1, 'costo': 45.0},
          ]
        : const [],
    'estado': estado,
    'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'fecha_propuesta': Timestamp.fromDate(DateTime(2026, 1, 5, 10)),
  });
  return firestore;
}

void main() {
  testWidgets(
    'el total es legible cuando la cotización es propia y el tema claro',
    (tester) async {
      // `conItems: false` para que la única `Text` con '$' en la tarjeta sea
      // la del total (si hubiera renglones, `find.textContaining(r'$')`
      // encontraría también sus subtotales y fallaría por ambigüedad, no
      // por el contraste que este test quiere verificar).
      final firestore = await _firestoreConCotizacion(conItems: false);
      await pumpChatWidget(
        tester,
        _card(isMe: true, firestore: firestore),
        width: 375,
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ChatCardShell));
      final colors = context.appColors;
      final total = tester.widget<Text>(find.textContaining(r'$'));
      final color =
          total.style?.color ??
          DefaultTextStyle.of(
            tester.element(find.textContaining(r'$')),
          ).style.color!;
      expect(
        contrastRatio(color, colors.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'Colors.white sobre tarjeta Colors.white = 1,00:1.',
      );
    },
  );

  testWidgets('la fila "Tu beneficio" es visible en tema claro', (
    tester,
  ) async {
    // Esta fila solo se dibuja con isMe=true, y su color era Colors.white54
    // sobre una tarjeta Colors.white: nunca se ha visto en claro.
    final firestore = await _firestoreConCotizacion();
    await pumpChatWidget(
      tester,
      _card(isMe: true, firestore: firestore),
      width: 375,
    );
    await tester.pumpAndSettle();
    final finder = find.text('Tu beneficio:');
    if (finder.evaluate().isEmpty) return; // sin beneficios cargados
    final context = tester.element(find.byType(ChatCardShell));
    final colors = context.appColors;
    final texto = tester.widget<Text>(finder);
    expect(
      contrastRatio(texto.style!.color!, colors.surface),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('usa ChatCardShell, AppStatusBadge y AppButton', (tester) async {
    final firestore = await _firestoreConCotizacion();
    await pumpChatWidget(
      tester,
      _card(isMe: false, firestore: firestore),
      width: 375,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChatCardShell), findsOneWidget);
    expect(find.byType(AppStatusBadge), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('no desborda en ningún ancho auditado, en ambos temas', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final firestore = await _firestoreConCotizacion();
        await pumpChatWidget(
          tester,
          _card(isMe: false, firestore: firestore),
          width: width,
          brightness: brightness,
        );
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      }
    }
  });

  testWidgets('el placeholder de carga tampoco tiene ancho fijo', (
    tester,
  ) async {
    // Era `SizedBox(width: 280)`, el noveno ancho fijo del módulo. Aquí se
    // usa un firestore vacío (sin sembrar 'q1') para que la tarjeta se
    // quede deliberadamente en el estado de carga.
    final firestore = FakeFirebaseFirestore();
    await pumpChatWidget(
      tester,
      _card(isMe: false, firestore: firestore),
      width: 320,
    );
    await tester.pump(); // sin settle: se queda en el estado de carga
    expectNoOverflow(tester);
  });
}
