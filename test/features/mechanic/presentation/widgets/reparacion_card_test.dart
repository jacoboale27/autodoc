import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/reparacion_card.dart';

void main() {
  final reparacion = ReparacionModel(
    idReparacion: 'rep1',
    idVehiculo: 'v1',
    idTaller: 't1',
    idPropietario: 'p1',
    placa: 'ABC123',
    estado: 'recibido',
    fechaCreacion: DateTime(2026, 1, 1),
    fechaActualizacion: DateTime(2026, 1, 1),
  );

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onCancelar,
    VoidCallback? onAvanzar,
    bool esUltimoEstado = false,
    String? siguienteEstadoLabel,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ReparacionCard(
            reparacion: reparacion,
            onAvanzar: onAvanzar,
            esUltimoEstado: esUltimoEstado,
            siguienteEstadoLabel: siguienteEstadoLabel,
            onCancelar: onCancelar,
          ),
        ),
      ),
    );
  }

  testWidgets('sin onCancelar no se muestra el boton Cancelar', (tester) async {
    await pump(tester);
    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets(
    'con onCancelar se muestra el boton Cancelar aunque sea el ultimo estado',
    (tester) async {
      await pump(tester, onCancelar: () {}, esUltimoEstado: true);
      expect(find.text('Cancelar'), findsOneWidget);
    },
  );

  testWidgets(
    'tocar Cancelar abre una confirmacion antes de llamar a onCancelar',
    (tester) async {
      var llamado = false;
      await pump(tester, onCancelar: () => llamado = true);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // El dialogo de confirmacion aparece y onCancelar todavia no se llamo.
      expect(find.text('Cancelar ticket'), findsWidgets);
      expect(llamado, isFalse);
    },
  );

  testWidgets('confirmar en el dialogo llama a onCancelar', (tester) async {
    var llamado = false;
    await pump(tester, onCancelar: () => llamado = true);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar ticket').last);
    await tester.pumpAndSettle();

    expect(llamado, isTrue);
  });

  testWidgets('volver en el dialogo NO llama a onCancelar', (tester) async {
    var llamado = false;
    await pump(tester, onCancelar: () => llamado = true);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(llamado, isFalse);
    expect(find.text('Cancelar ticket'), findsNothing);
  });
}
