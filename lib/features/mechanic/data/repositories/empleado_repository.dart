import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/empleado_model.dart';
import 'package:autodoc/core/models/invitacion_empleo_model.dart';

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

  CollectionReference<Map<String, dynamic>> _invitacionesRef(
    String idTallerPropietario,
  ) => _firestore
      .collection(FirestoreCollections.talleres)
      .doc(idTallerPropietario)
      .collection('invitaciones');

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

  /// Cota del stream de invitaciones: el servidor no deja pasar de 20 vivas
  /// por taller (`INVITACIONES_VIVAS_MAX` en
  /// `functions/src/empleadosTaller.js`, que además barre las caducadas al
  /// invitar), así que 30 deja holgura para las que quedaran de antes sin
  /// dejar el stream sin tope. Si alguna vez se llenara, lo que se pierde es
  /// el final de la lista, no la capacidad de retirar las que se ven.
  static const int _topeInvitaciones = 30;

  /// Las invitaciones que el taller tiene sin responder (observaciones del
  /// 2026-09-19).
  Stream<List<InvitacionEmpleoModel>> watchInvitaciones(
    String idTallerPropietario,
  ) {
    return _invitacionesRef(idTallerPropietario)
        .limit(_topeInvitaciones)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => InvitacionEmpleoModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  /// El taller retira una invitación que ya no quiere. La persona, si la
  /// intenta aceptar después, recibe «Esta invitación ya no está
  /// disponible».
  Future<void> retirarInvitacion(
    String idTallerPropietario,
    String idInvitado,
  ) async {
    await _invitacionesRef(idTallerPropietario).doc(idInvitado).delete();
  }
}
