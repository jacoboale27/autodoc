import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/pages/reserva_detail_screen.dart';
import 'support/chat_harness.dart';

class _Reservas extends FakeReservaProvider {
  final pending = Completer<bool>();
  int calls = 0;
  @override
  Future<bool> reprogramarReserva(
    String id,
    DateTime fecha, {
    required String idProponente,
  }) {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets('grupo 4: reprogramar una vez mientras sigue pendiente', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final reservas = _Reservas();
    await firestore.collection('reservas').doc('r1').set({
      'id_conversacion': 'c1',
      'id_propietario': 'u1',
      'id_mecanico': 'm1',
      'id_vehiculo': 'v1',
      'id_taller': 'm1',
      'id_proponente': 'm1',
      'fecha_hora_propuesta': DateTime.now().add(const Duration(days: 7)),
      'tipo_servicio': 'Frenos',
      'estado': 'pendiente',
      'fecha_creacion': DateTime.now(),
    });
    await pumpChatWidget(
      tester,
      ReservaDetailScreen(reservaId: 'r1', firestore: firestore),
      width: 1000,
      user: fakeChatUser(),
      reservaProvider: reservas,
    );
    await tester.pumpAndSettle();
    // Los dos pickers se confirman por posicion y no por rotulo: el texto del
    // boton de aceptar lo pone GlobalMaterialLocalizations y cambia con el
    // idioma, asi que buscarlo por texto ataba el test a un locale.
    Future<void> confirmar(Type dialogo) async {
      await tester.pumpAndSettle();
      final abierto = find.byType(dialogo);
      if (abierto.evaluate().isEmpty) return;
      await tester.tap(
        find.descendant(of: abierto, matching: find.byType(TextButton)).last,
      );
      await tester.pumpAndSettle();
    }

    Future<void> confirmarPickers() async {
      await confirmar(DatePickerDialog);
      await confirmar(TimePickerDialog);
      await tester.pump();
    }

    await tester.tap(find.text('Reprogramar'));
    await confirmarPickers();
    await tester.tap(find.text('Reprogramar'));
    await confirmarPickers();
    expect(reservas.calls, 1);
    reservas.pending.complete(true);
    await tester.pumpAndSettle();
  });
}
