import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/empleado_model.dart';

class EmpleadoRepository {
  final FirebaseFirestore _firestore;

  EmpleadoRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _empleadosRef(
    String idTallerPropietario,
  ) => _firestore
      .collection(FirestoreCollections.talleres)
      .doc(idTallerPropietario)
      .collection('empleados');

  Future<void> crearRegistroEmpleado(EmpleadoModel empleado) async {
    await _empleadosRef(
      empleado.idTallerPropietario,
    ).doc(empleado.idEmpleado).set(empleado.toMap());
  }

  Stream<List<EmpleadoModel>> watchEmpleados(String idTallerPropietario) {
    return _empleadosRef(idTallerPropietario).snapshots().map(
      (snap) =>
          snap.docs.map((d) => EmpleadoModel.fromMap(d.data(), d.id)).toList(),
    );
  }

  Future<void> desactivarEmpleado(
    String idTallerPropietario,
    String idEmpleado,
  ) async {
    await _empleadosRef(
      idTallerPropietario,
    ).doc(idEmpleado).update({'activo': false});
  }
}
