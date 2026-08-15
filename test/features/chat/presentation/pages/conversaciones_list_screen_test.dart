import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/presentation/pages/conversaciones_list_screen.dart';
import '../../../../support/chat_harness.dart';
import '../../../../support/responsive_harness.dart';

ConversacionModel _conv({int noLeidos = 0, String nombre = 'Taller Escobar'}) =>
    ConversacionModel(
      id: 'c1',
      idPropietario: 'u1',
      idMecanico: 'm1',
      nombrePropietario: 'Ana Pérez',
      nombreMecanico: nombre,
      ultimoMensaje: 'Le confirmo la cita para el jueves a las 10.',
      ultimoMensajeTs: DateTime(2026, 8, 11),
      noLeidosPropietario: noLeidos,
      noLeidosMecanico: 0,
    );

void main() {
  testWidgets('no usa responsive_framework en ningún ancho', (tester) async {
    // Verificación estructural: `ResponsiveBreakpoints.of(context)` lanza si
    // no hay un `ResponsiveBreakpoints.builder` por encima. `pumpChatWidget`
    // no lo monta, así que si la pantalla sigue llamándolo, este test explota.
    for (final width in kAuditWidths) {
      await pumpChatWidget(
        tester,
        const ConversacionesListScreen(),
        width: width,
        chatProvider: FakeChatProvider(conversaciones: [_conv()]),
        user: fakeChatUser(),
      );
      expectNoOverflow(tester);
    }
  });

  testWidgets('usa AppEmptyState cuando no hay conversaciones', (tester) async {
    await pumpChatWidget(
      tester,
      const ConversacionesListScreen(),
      width: 375,
      chatProvider: FakeChatProvider(conversaciones: const []),
      user: fakeChatUser(),
    );
    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('el contador de no leídos se anuncia al lector de pantalla', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      const ConversacionesListScreen(),
      width: 375,
      chatProvider: FakeChatProvider(conversaciones: [_conv(noLeidos: 3)]),
      user: fakeChatUser(),
    );
    // Hoy el badge es un Container con un Text '3' y ninguna semántica: un
    // lector de pantalla lee "3" suelto, sin decir de qué.
    expect(find.bySemanticsLabel('3 mensajes sin leer'), findsOneWidget);
  });

  testWidgets('acota el ancho de la lista en pantallas grandes', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      const ConversacionesListScreen(),
      width: 1440,
      chatProvider: FakeChatProvider(conversaciones: [_conv()]),
      user: fakeChatUser(),
    );
    final ancho = tester.getSize(find.byType(ListView)).width;
    expect(
      ancho,
      lessThanOrEqualTo(720),
      reason:
          'Una fila de conversación de 1440 px deja el nombre a la '
          'izquierda y la hora a 1400 px de distancia.',
    );
  });

  testWidgets('cada fila tiene al menos 48 dp de alto táctil', (tester) async {
    await pumpChatWidget(
      tester,
      const ConversacionesListScreen(),
      width: 375,
      chatProvider: FakeChatProvider(conversaciones: [_conv()]),
      user: fakeChatUser(),
    );
    final alto = tester.getSize(find.byType(ListTile).first).height;
    expect(alto, greaterThanOrEqualTo(48));
  });
}
