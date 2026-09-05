import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';

import '../../../../support/chat_harness.dart';

/// Tarea 11b (C4): editar el texto del propio mensaje desde el menú
/// contextual, con marca "(editado)" junto a la hora/acuse. Las reglas que
/// definen el limite de seguridad estan en `test_rules/mensajes.test.js`;
/// aqui solo se cubre la UI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  Future<FakeChatProvider> montar(
    WidgetTester tester, {
    required String tipo,
    bool esMio = true,
    bool editado = false,
  }) async {
    await Firebase.initializeApp();
    final chatProvider = FakeChatProvider(
      conversaciones: [fakeConversacion()],
      mensajes: [
        fakeMensaje(
          id: 'm1',
          idRemitente: esMio ? 'u1' : 'm1',
          contenido: 'hola',
          tipo: tipo,
          editado: editado,
        ),
      ],
    );
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      user: fakeChatUser(),
      chatProvider: chatProvider,
    );
    return chatProvider;
  }

  testWidgets('el menu de un mensaje de texto propio ofrece Editar', (
    tester,
  ) async {
    await montar(tester, tipo: 'texto');
    await tester.longPress(find.text('hola'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu_mensaje_editar')), findsOneWidget);
  });

  testWidgets('un mensaje ajeno no ofrece Editar aunque sea de texto', (
    tester,
  ) async {
    await montar(tester, tipo: 'texto', esMio: false);
    await tester.longPress(find.text('hola'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu_mensaje_editar')), findsNothing);
  });

  testWidgets(
    'una tarjeta de reserva propia no ofrece Editar (no es texto libre)',
    (tester) async {
      await montar(tester, tipo: 'reserva_card');
      await tester.longPress(find.text('Reserva de Cita'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu_mensaje_editar')), findsNothing);
    },
  );

  testWidgets(
    'editar guarda el nuevo texto llamando a editarMensaje con el contenido corregido',
    (tester) async {
      final chatProvider = await montar(tester, tipo: 'texto');
      await tester.longPress(find.text('hola'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('menu_mensaje_editar')));
      await tester.pumpAndSettle();

      // El campo de edicion viene precargado con el texto actual (aparece
      // dos veces: la burbuja de fondo y el TextField del dialogo).
      expect(find.text('hola'), findsNWidgets(2));

      await tester.enterText(
        find.byKey(const Key('campo_editar_mensaje')),
        'hola corregido',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(
        chatProvider.llamadas,
        contains('editarMensaje:c1:m1:hola corregido'),
      );
    },
  );

  testWidgets('un mensaje editado muestra la marca "(editado)"', (
    tester,
  ) async {
    await montar(tester, tipo: 'texto', editado: true);
    expect(find.text('(editado)'), findsOneWidget);
  });

  testWidgets(
    'un mensaje sin el campo editado (produccion anterior) no muestra la marca',
    (tester) async {
      // A diferencia de `montar()` (que construye el MensajeModel directo
      // con `editado: false`, sin pasar por Firestore), este test construye
      // el mapa CRUDO tal como vendria de un documento real anterior a la
      // Tarea 11b: sin la clave 'editado' en absoluto. Ejercita
      // `MensajeModel.fromMap` de verdad, para probar la lectura tolerante
      // (`map['editado'] ?? false`) — no simplemente que el widget respete
      // un valor que ya le dimos como `false`.
      await Firebase.initializeApp();
      final mensajeProduccionAnterior = MensajeModel.fromMap({
        'id_remitente': 'u1',
        'contenido': 'hola',
        'tipo': 'texto',
        'estado': 'enviado',
        'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1, 10)),
        // Sin 'editado': asi son los documentos ya existentes en produccion.
      }, 'm1');
      final chatProvider = FakeChatProvider(
        conversaciones: [fakeConversacion()],
        mensajes: [mensajeProduccionAnterior],
      );
      await pumpChatWidget(
        tester,
        const ChatScreen(conversacionId: 'c1'),
        width: 375,
        user: fakeChatUser(),
        chatProvider: chatProvider,
      );

      // Afirmar la ausencia de la marca no basta: tambien pasaria si la
      // burbuja hubiera dejado de renderizar. Anclamos el texto visible.
      expect(find.text('hola'), findsOneWidget);
      expect(find.text('(editado)'), findsNothing);
    },
  );
}
