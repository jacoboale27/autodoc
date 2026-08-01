import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/review_model.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';

ReviewModel _r(String id, int estrellas, DateTime fecha) => ReviewModel(
  idResenia: id,
  idUsuario: 'u',
  idTaller: 't',
  idServicio: id,
  estrellas: estrellas,
  fechaResenia: fecha,
);

void main() {
  final resenias = [
    _r('a', 3, DateTime(2026, 1, 1)),
    _r('b', 5, DateTime(2026, 6, 1)),
    _r('c', 1, DateTime(2026, 3, 1)),
  ];

  test('recientes ordena por fecha descendente', () {
    final result = ordenarResenias(resenias, ReviewSortOrder.recientes);
    expect(result.map((r) => r.idResenia), ['b', 'c', 'a']);
  });

  test('masAltas ordena por estrellas descendente', () {
    final result = ordenarResenias(resenias, ReviewSortOrder.masAltas);
    expect(result.map((r) => r.idResenia), ['b', 'a', 'c']);
  });

  test('masBajas ordena por estrellas ascendente', () {
    final result = ordenarResenias(resenias, ReviewSortOrder.masBajas);
    expect(result.map((r) => r.idResenia), ['c', 'a', 'b']);
  });
}
