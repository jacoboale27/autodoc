// Observaciones del 2026-09-19: «quiero que solo aparezca una opción de
// reseñar en lugar de que todas tengan», y que una vez reseñado no deje
// volver a reseñar hasta el siguiente servicio.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/chat/presentation/widgets/aviso_resenia_chat.dart';

import '../../../../support/chat_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('sin nada que reseñar no aparece', (tester) async {
    await pumpChatWidget(
      tester,
      AvisoReseniaChat(
        userId: 'p1',
        tallerId: 't1',
        tallerNombre: 'Taller Escobar',
        buscarResenable: (_, _) async => null,
      ),
      width: 375,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aviso_resenia_chat')), findsNothing);
  });

  testWidgets('reseñar lo retira hasta el siguiente servicio', (tester) async {
    String? resenable = 's1';
    var consultas = 0;
    final abiertas = <String>[];
    await pumpChatWidget(
      tester,
      AvisoReseniaChat(
        userId: 'p1',
        tallerId: 't1',
        tallerNombre: 'Taller Escobar',
        buscarResenable: (_, _) async {
          consultas++;
          return resenable;
        },
        abrirResenia:
            (
              _, {
              required tallerId,
              required tallerNombre,
              required idServicio,
            }) async {
              abiertas.add(idServicio);
              resenable = null; // la reseña quedó escrita
              return true;
            },
      ),
      width: 375,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Tu servicio con Taller Escobar terminó. ¿Cómo te fue?'),
      findsOneWidget,
    );

    final boton = find.byKey(const Key('aviso_resenia_calificar'));
    await tester.tap(boton);
    await tester.tap(boton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(abiertas, ['s1'], reason: 'dos toques abren la hoja una sola vez');
    expect(consultas, 2, reason: 'enviada la reseña se vuelve a preguntar');
    expect(find.byKey(const Key('aviso_resenia_chat')), findsNothing);
  });

  testWidgets('cerrar la hoja sin enviar lo deja donde estaba', (tester) async {
    await pumpChatWidget(
      tester,
      AvisoReseniaChat(
        userId: 'p1',
        tallerId: 't1',
        tallerNombre: 'Taller Escobar',
        buscarResenable: (_, _) async => 's1',
        abrirResenia:
            (
              _, {
              required tallerId,
              required tallerNombre,
              required idServicio,
            }) async => null,
      ),
      width: 375,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aviso_resenia_calificar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aviso_resenia_chat')), findsOneWidget);
  });

  testWidgets('un error al consultar no pinta nada ni revienta', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      AvisoReseniaChat(
        userId: 'p1',
        tallerId: 't1',
        tallerNombre: 'Taller Escobar',
        buscarResenable: (_, _) async => throw Exception('sin red'),
      ),
      width: 375,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('aviso_resenia_chat')), findsNothing);
  });

  testWidgets('no desborda en ningún ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      await pumpChatWidget(
        tester,
        AvisoReseniaChat(
          userId: 'p1',
          tallerId: 't1',
          tallerNombre: 'Taller Mecánico Hermanos Escobar y Asociados',
          buscarResenable: (_, _) async => 's1',
        ),
        width: width,
      );
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    }
  });
}
