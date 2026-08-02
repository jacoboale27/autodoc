import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';

void main() {
  test(
    'watchEmpleados solo devuelve empleados del taller correspondiente',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = EmpleadoRepository(firestore: firestore);

      await firestore
          .collection('talleres')
          .doc('t1')
          .collection('empleados')
          .doc('e1')
          .set({
            'id_taller_propietario': 't1',
            'nombre_completo': 'A',
            'correo': 'a@x.com',
            'activo': true,
          });
      await firestore
          .collection('talleres')
          .doc('t2')
          .collection('empleados')
          .doc('e2')
          .set({
            'id_taller_propietario': 't2',
            'nombre_completo': 'B',
            'correo': 'b@x.com',
            'activo': true,
          });

      final empleados = await repo.watchEmpleados('t1').first;

      expect(empleados.length, 1);
      expect(empleados.first.nombreCompleto, 'A');
    },
  );

  test('desactivarEmpleado marca activo=false', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = EmpleadoRepository(firestore: firestore);
    await firestore
        .collection('talleres')
        .doc('t1')
        .collection('empleados')
        .doc('e1')
        .set({
          'id_taller_propietario': 't1',
          'nombre_completo': 'A',
          'correo': 'a@x.com',
          'activo': true,
        });

    await repo.desactivarEmpleado('t1', 'e1');

    final doc = await firestore
        .collection('talleres')
        .doc('t1')
        .collection('empleados')
        .doc('e1')
        .get();
    expect(doc.data()!['activo'], isFalse);
  });
}
