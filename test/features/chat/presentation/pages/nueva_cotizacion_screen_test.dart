// Observaciones del 2026-09-18 (captura 6): la cotización del chat tiene que
// ser la misma que la de Buscar Vehículo —vehículo, materiales, catálogo,
// mano de obra y total, a dos columnas en pantalla ancha— y además llevar
// día y hora del servicio.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/chat/data/models/vehiculo_cotizado.dart';
import 'package:autodoc/features/chat/presentation/pages/nueva_cotizacion_screen.dart';

import '../../../../support/chat_harness.dart';
import '../../../../support/responsive_harness.dart';

const _vehiculo = VehiculoCotizado(
  idVehiculo: 'v1',
  marca: 'NISSAN',
  modelo: 'Rogue Sport',
  placa: 'P123-123',
  kilometraje: 75,
);

Future<void> _llenarRenglon(
  WidgetTester tester, {
  required String nombre,
  required String costo,
  String cantidad = '1',
}) async {
  await tester.enterText(
    find.byKey(const Key('cotizacion_item_nombre_0')),
    nombre,
  );
  await tester.enterText(
    find.byKey(const Key('cotizacion_item_cantidad_0')),
    cantidad,
  );
  await tester.enterText(
    find.byKey(const Key('cotizacion_item_costo_0')),
    costo,
  );
  await tester.pump();
}

Future<void> _tocarEnviar(WidgetTester tester) async {
  final boton = find.text('Generar y Enviar');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pump();
}

void main() {
  testWidgets('muestra el vehículo que se está cotizando', (tester) async {
    await pumpChatWidget(
      tester,
      NuevaCotizacionScreen(vehiculo: _vehiculo, onEnviar: (_) async => true),
      width: 375,
    );
    expect(find.text('NISSAN Rogue Sport'), findsOneWidget);
    expect(find.textContaining('P123-123'), findsOneWidget);
    expect(find.text('75 KM'), findsOneWidget);
  });

  testWidgets('en pantalla ancha va a dos columnas, como Buscar Vehículo', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      NuevaCotizacionScreen(vehiculo: _vehiculo, onEnviar: (_) async => true),
      width: 1440,
    );
    final vehiculo = tester.getCenter(find.text('NISSAN Rogue Sport'));
    final manoDeObra = tester.getCenter(
      find.byKey(const Key('cotizacion_mano_de_obra')),
    );
    expect(
      manoDeObra.dx,
      greaterThan(vehiculo.dx),
      reason: 'los importes van a la derecha del vehículo, no debajo',
    );
  });

  testWidgets('pide el día y la hora, y lo anuncia al lector de pantalla', (
    tester,
  ) async {
    var enviados = 0;
    await pumpChatWidget(
      tester,
      NuevaCotizacionScreen(
        vehiculo: _vehiculo,
        onEnviar: (_) async {
          enviados++;
          return true;
        },
      ),
      width: 375,
    );
    await _llenarRenglon(tester, nombre: 'Chasis', costo: '50');
    await _tocarEnviar(tester);

    expect(enviados, 0);
    expect(
      find.bySemanticsLabel(
        RegExp('Debes proponer el día y hora del servicio'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('la mano de obra rechaza letras y suma al total', (tester) async {
    await pumpChatWidget(
      tester,
      NuevaCotizacionScreen(vehiculo: _vehiculo, onEnviar: (_) async => true),
      width: 375,
    );
    await _llenarRenglon(tester, nombre: 'Filtro', costo: '10', cantidad: '2');

    final manoDeObra = find.descendant(
      of: find.byKey(const Key('cotizacion_mano_de_obra')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(manoDeObra, 'abc');
    await tester.pump();
    expect(tester.widget<EditableText>(manoDeObra).controller.text, isEmpty);

    await tester.enterText(manoDeObra, '30');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('cotizacion_total'))).data,
      '\$50.00',
    );
  });

  testWidgets(
    'envía materiales, beneficio, mano de obra y fecha, y se cierra al enviar',
    (tester) async {
      CotizacionBorrador? recibido;
      await pumpChatWidget(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => abrirNuevaCotizacion(
              context,
              vehiculo: _vehiculo,
              initialFecha: DateTime(2030, 9, 30, 9, 20),
              onEnviar: (b) async {
                recibido = b;
                return true;
              },
            ),
            child: const Text('abrir'),
          ),
        ),
        width: 375,
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await _llenarRenglon(tester, nombre: 'Chasis entero', costo: '5000');
      await tester.enterText(
        find.byKey(const Key('cotizacion_item_beneficio_0')),
        '200',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('cotizacion_mano_de_obra')),
          matching: find.byType(EditableText),
        ),
        '150',
      );
      await tester.pump();
      await _tocarEnviar(tester);
      await tester.pumpAndSettle();

      expect(recibido, isNotNull);
      expect(recibido!.items.single.material, 'Chasis entero');
      expect(recibido!.items.single.beneficio, 200);
      expect(recibido!.manoDeObra, 150);
      expect(recibido!.fechaPropuesta, DateTime(2030, 9, 30, 9, 20));
      expect(recibido!.total, 5150);
      expect(
        find.byType(NuevaCotizacionScreen),
        findsNothing,
        reason: 'enviada la cotización, la pantalla se cierra',
      );

      final cotizacion = recibido!.toCotizacion(
        idPropietario: 'cli1',
        idMecanico: 'mec1',
        idTaller: 't1',
        idVehiculo: 'v1',
      );
      final mapa = cotizacion.toMap();
      expect(mapa['id_vehiculo'], 'v1');
      expect(mapa['mano_de_obra'], 150);
      expect(mapa['total'], 5150);
      expect(
        mapa.containsKey('beneficio'),
        isFalse,
        reason: 'el beneficio nunca va al documento que lee el cliente',
      );
      expect((mapa['materiales'] as List).single['nombre'], 'Chasis entero');
    },
  );

  testWidgets('si el envío falla, la pantalla sigue abierta con lo tecleado', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      NuevaCotizacionScreen(
        vehiculo: _vehiculo,
        initialFecha: DateTime(2030, 1, 1, 10),
        onEnviar: (_) async => false,
      ),
      width: 375,
    );
    await _llenarRenglon(tester, nombre: 'Aceite', costo: '25');
    await _tocarEnviar(tester);
    await tester.pumpAndSettle();

    expect(find.byType(NuevaCotizacionScreen), findsOneWidget);
    expect(find.text('Aceite'), findsOneWidget);
    expect(find.text('Generar y Enviar'), findsOneWidget);
  });

  testWidgets('sin materiales ni mano de obra no deja enviar', (tester) async {
    var enviados = 0;
    await pumpChatWidget(
      tester,
      NuevaCotizacionScreen(
        vehiculo: _vehiculo,
        initialFecha: DateTime(2030, 1, 1, 10),
        onEnviar: (_) async {
          enviados++;
          return true;
        },
      ),
      width: 375,
    );
    // Quita el renglón vacío con el que abre.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('cotizacion_item_row_0')),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();
    await _tocarEnviar(tester);

    expect(enviados, 0);
    expect(
      find.text('Agrega al menos un material o la mano de obra.'),
      findsOneWidget,
    );
  });

  testWidgets('no desborda en ningún ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      await pumpChatWidget(
        tester,
        NuevaCotizacionScreen(vehiculo: _vehiculo, onEnviar: (_) async => true),
        width: width,
      );
      expectNoOverflow(tester);
    }
  });
}
