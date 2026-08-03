import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';

void main() {
  group('CotizacionItem.toMap', () {
    test('never includes beneficio (el cliente no debe verlo)', () {
      final item = CotizacionItem(
        material: 'Filtro de aceite',
        cantidad: 1,
        costo: 15,
        beneficio: 5,
      );

      final map = item.toMap();

      expect(map.containsKey('beneficio'), isFalse);
      expect(map, {
        'material': 'Filtro de aceite',
        'cantidad': 1.0,
        'costo': 15.0,
      });
    });
  });

  group('CotizacionModel.toPrivateMap', () {
    test('lista los beneficios en el mismo orden que items', () {
      final cotizacion = CotizacionModel(
        id: 'c1',
        idPropietario: 'owner1',
        idMecanico: 'taller1',
        items: [
          CotizacionItem(material: 'A', cantidad: 1, costo: 10, beneficio: 3),
          CotizacionItem(material: 'B', cantidad: 2, costo: 5, beneficio: 1.5),
        ],
        fecha: DateTime(2026, 1, 1),
      );

      expect(cotizacion.toPrivateMap(), {
        'beneficios': [3.0, 1.5],
      });
    });
  });

  group('CotizacionModel.copyWithBeneficios', () {
    test('rellena el beneficio de cada item por posicion', () {
      final cotizacion = CotizacionModel(
        id: 'c1',
        idPropietario: 'owner1',
        idMecanico: 'taller1',
        items: [
          CotizacionItem(material: 'A', cantidad: 1, costo: 10),
          CotizacionItem(material: 'B', cantidad: 2, costo: 5),
        ],
        fecha: DateTime(2026, 1, 1),
      );

      final conBeneficios = cotizacion.copyWithBeneficios([3.0, 1.5]);

      expect(conBeneficios.items[0].beneficio, 3.0);
      expect(conBeneficios.items[1].beneficio, 1.5);
    });

    test('rellena con 0 si la lista de beneficios es mas corta que items', () {
      final cotizacion = CotizacionModel(
        id: 'c1',
        idPropietario: 'owner1',
        idMecanico: 'taller1',
        items: [
          CotizacionItem(material: 'A', cantidad: 1, costo: 10),
          CotizacionItem(material: 'B', cantidad: 2, costo: 5),
        ],
        fecha: DateTime(2026, 1, 1),
      );

      final conBeneficios = cotizacion.copyWithBeneficios([3.0]);

      expect(conBeneficios.items[0].beneficio, 3.0);
      expect(conBeneficios.items[1].beneficio, 0.0);
    });
  });
}
