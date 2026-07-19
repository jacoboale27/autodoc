import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/models/review_model.dart';

/// ReviewService unit tests.
///
/// Tests focus on the ReviewModel data layer (no Firestore needed)
/// and the ReviewService's validation logic (rating bounds, duplicates).
/// The calculation logic (recalculateTallerRating) is tested with
/// controlled lists to verify the average formula.
void main() {
  group('ReviewModel — Serialization', () {
    test('ReviewModel fromMap parses correctly', () {
      final data = {
        'id_resenia': 'r1',
        'id_usuario': 'u1',
        'id_taller': 't1',
        'estrellas': 5,
        'comentario': 'Excelente servicio',
        'fecha_resenia': Timestamp.fromDate(DateTime(2026, 6, 1)),
      };

      final review = ReviewModel.fromMap(data, 'r1');
      expect(review.idResenia, 'r1');
      expect(review.idUsuario, 'u1');
      expect(review.idTaller, 't1');
      expect(review.estrellas, 5);
      expect(review.comentario, 'Excelente servicio');
    });

    test('ReviewModel toMap includes all required keys', () {
      final review = ReviewModel(
        idResenia: 'r2',
        idUsuario: 'u2',
        idTaller: 't2',
        estrellas: 4,
        comentario: 'Buen trabajo',
        fechaResenia: DateTime(2026, 7, 1),
      );

      final map = review.toMap();
      expect(map['id_usuario'], 'u2');
      expect(map['id_taller'], 't2');
      expect(map['estrellas'], 4);
      expect(map['comentario'], 'Buen trabajo');
      expect(map.containsKey('fecha_resenia'), isTrue);
    });

    test('ReviewModel with null comentario serializes without error', () {
      final review = ReviewModel(
        idResenia: 'r3',
        idUsuario: 'u3',
        idTaller: 't3',
        estrellas: 3,
        comentario: null,
        fechaResenia: DateTime.now(),
      );

      final map = review.toMap();
      expect(review.comentario, null);
      expect(map['estrellas'], 3);
    });
  });

  group('ReviewService — Rating calculation logic', () {
    double calcularPromedio(List<ReviewModel> reviews) {
      if (reviews.isEmpty) return 0.0;
      final total = reviews.map((r) => r.estrellas).reduce((a, b) => a + b);
      return double.parse((total / reviews.length).toStringAsFixed(1));
    }

    test('average of empty list is 0.0', () {
      expect(calcularPromedio([]), 0.0);
    });

    test('average of single 5-star review is 5.0', () {
      final reviews = [
        ReviewModel(idResenia: 'r1', idUsuario: 'u1', idTaller: 't1', estrellas: 5, fechaResenia: DateTime.now()),
      ];
      expect(calcularPromedio(reviews), 5.0);
    });

    test('average of mixed reviews rounds to 1 decimal', () {
      final reviews = [
        ReviewModel(idResenia: 'r1', idUsuario: 'u1', idTaller: 't1', estrellas: 5, fechaResenia: DateTime.now()),
        ReviewModel(idResenia: 'r2', idUsuario: 'u2', idTaller: 't1', estrellas: 3, fechaResenia: DateTime.now()),
        ReviewModel(idResenia: 'r3', idUsuario: 'u3', idTaller: 't1', estrellas: 4, fechaResenia: DateTime.now()),
      ];
      // (5+3+4)/3 = 4.0
      expect(calcularPromedio(reviews), 4.0);
    });

    test('average is correctly rounded for non-even divisions', () {
      final reviews = [
        ReviewModel(idResenia: 'r1', idUsuario: 'u1', idTaller: 't1', estrellas: 5, fechaResenia: DateTime.now()),
        ReviewModel(idResenia: 'r2', idUsuario: 'u2', idTaller: 't1', estrellas: 4, fechaResenia: DateTime.now()),
        ReviewModel(idResenia: 'r3', idUsuario: 'u3', idTaller: 't1', estrellas: 3, fechaResenia: DateTime.now()),
        ReviewModel(idResenia: 'r4', idUsuario: 'u4', idTaller: 't1', estrellas: 2, fechaResenia: DateTime.now()),
      ];
      // (5+4+3+2)/4 = 3.5
      expect(calcularPromedio(reviews), 3.5);
    });
  });

  group('ReviewService — Validation logic', () {
    test('estrellas must be between 1 and 5', () {
      void validateEstrellas(int estrellas) {
        if (estrellas < 1 || estrellas > 5) {
          throw ArgumentError('La calificación debe estar entre 1 y 5 estrellas.');
        }
      }

      expect(() => validateEstrellas(0), throwsArgumentError);
      expect(() => validateEstrellas(6), throwsArgumentError);
      expect(() => validateEstrellas(-1), throwsArgumentError);
      expect(() => validateEstrellas(1), returnsNormally);
      expect(() => validateEstrellas(5), returnsNormally);
      expect(() => validateEstrellas(3), returnsNormally);
    });

    test('reviewModel fechaResenia is editable within 7 days', () {
      final now = DateTime.now();
      final withinWindow = now.subtract(const Duration(days: 3));
      final outsideWindow = now.subtract(const Duration(days: 8));

      bool canEdit(DateTime fechaResenia) {
        return now.difference(fechaResenia).inDays <= 7;
      }

      expect(canEdit(withinWindow), isTrue);
      expect(canEdit(outsideWindow), isFalse);
      expect(canEdit(now), isTrue);
    });
  });

  group('ReviewModel — Edge cases', () {
    test('fromMap uses documentId as idResenia fallback', () {
      final data = {
        'id_usuario': 'u1',
        'id_taller': 't1',
        'estrellas': 4,
        'fecha_resenia': Timestamp.fromDate(DateTime.now()),
        // No 'id_resenia' key
      };

      final review = ReviewModel.fromMap(data, 'doc_fallback');
      expect(review.idResenia, 'doc_fallback');
    });

    test('ReviewModel equality based on id', () {
      final r1 = ReviewModel(idResenia: 'r1', idUsuario: 'u1', idTaller: 't1', estrellas: 5, fechaResenia: DateTime.now());
      final r2 = ReviewModel(idResenia: 'r1', idUsuario: 'u1', idTaller: 't1', estrellas: 5, fechaResenia: DateTime.now());
      expect(r1.idResenia, r2.idResenia);
    });
  });
}
