import 'dart:async';

import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/chat/data/models/reserva_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../support/chat_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

/// `FakeReservaProvider` resuelve todo por `noSuchMethod`, que devuelve null:
/// `solicitarReserva` declara `Future<String>`, asi que hay que darle un valor
/// real o el flujo muere antes de llegar al defecto.
class _ReservasPendientes extends FakeReservaProvider {
  final pendiente = Completer<String>();
  var solicitudes = 0;

  @override
  Future<String> solicitarReserva(ReservaModel reserva) {
    solicitudes++;
    return pendiente.future;
  }
}

void main() {
  testWidgets(
    'grupo 2: recorrer dos veces el flujo de cita nueva crea una sola reserva',
    (tester) async {
      final reservas = _ReservasPendientes();

      await pumpChatWidget(
        tester,
        const ChatScreen(conversacionId: 'c1'),
        width: 500,
        height: 1000,
        user: fakeChatUser(),
        reservaProvider: reservas,
        extraProviders: [
          ChangeNotifierProvider<VehicleProvider>.value(
            value: FakeVehicleProvider([fakeVehicle(0)]),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // Confirma un picker por posicion: el rotulo de aceptar lo pone
      // GlobalMaterialLocalizations y cambia con el idioma.
      Future<void> confirmar(Type dialogo) async {
        await tester.pumpAndSettle();
        final abierto = find.byType(dialogo);
        if (abierto.evaluate().isEmpty) return;
        await tester.tap(
          find.descendant(of: abierto, matching: find.byType(TextButton)).last,
        );
        await tester.pumpAndSettle();
      }

      /// Recorre hoja -> selector de vehiculo -> fecha -> hora. Devuelve false
      /// si la entrada de cita nueva esta deshabilitada, que es la senal de que
      /// la proteccion actuo: el rotulo sigue RENDERIZADO, con `onTap: null`, asi
      /// que comprobar que el texto existe no distingue un caso del otro.
      Future<bool> recorrerFlujo() async {
        await tester.tap(find.byTooltip('Adjuntar'));
        await tester.pumpAndSettle();
        final nueva = find.widgetWithText(ListTile, 'Nueva Reserva');
        expect(nueva, findsOneWidget);
        if (tester.widget<ListTile>(nueva).onTap == null) {
          await tester.tapAt(const Offset(10, 10)); // cierra la hoja
          await tester.pumpAndSettle();
          return false;
        }
        await tester.tap(nueva);
        await tester.pumpAndSettle();
        await tester.tap(find.text(fakeVehicle(0).placa));
        await tester.pumpAndSettle();
        await confirmar(DatePickerDialog);
        await confirmar(TimePickerDialog);
        return true;
      }

      expect(
        await recorrerFlujo(),
        isTrue,
        reason: 'el primer recorrido tiene que llegar a la escritura',
      );
      expect(reservas.solicitudes, 1);

      // Con la primera escritura en vuelo, la entrada de cita nueva tiene que
      // estar deshabilitada: sin eso se creaban DOS reservas y dos tarjetas.
      expect(await recorrerFlujo(), isFalse);
      expect(reservas.solicitudes, 1);

      reservas.pendiente.complete('r1');
      await tester.pumpAndSettle();
    },
  );
}
