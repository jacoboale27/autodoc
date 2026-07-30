import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';

void main() {
  testWidgets('muestra el mensaje y un boton de regreso', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MissingArgumentScreen(mensaje: 'No se encontró el vehículo'),
      ),
    );
    expect(find.text('No se encontró el vehículo'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('nunca renderiza una pantalla vacia', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MissingArgumentScreen(mensaje: 'Falta el dato')),
    );
    expect(find.byType(Text), findsWidgets);
  });
}
