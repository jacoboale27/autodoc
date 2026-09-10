import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/reparacion_model.dart';

/// Escribe un ticket de reparación directamente en Firestore, para tests que
/// necesitan partir de un ticket ya existente.
///
/// FUNC-02 retiró `ReparacionRepository.iniciarReparacion`, que era la única
/// forma que tenía el cliente de crear un ticket. No la usaba ya ninguna
/// pantalla —desde A4b el único creador es el trigger `onCotizacionAceptada`,
/// y `firestore.rules` cierra `allow create` de `/reparaciones` con
/// `if false`—, pero seguía viva en producción **porque los tests la usaban
/// para sembrar**. Esa es exactamente la forma de dejar código muerto dentro
/// del binario: sostenido solo por sus pruebas.
///
/// La siembra se muda aquí, a `test/support/`, donde no puede compilarse
/// dentro de la app. Escribe el mismo documento que escribía el método
/// retirado (vía [ReparacionModel], así que un cambio de esquema sigue
/// rompiendo aquí), y por eso [estado] sigue siendo `recibido` por defecto:
/// los tests que ya existían seguían probando lo mismo que probaban.
///
/// Un ticket nuevo del flujo oficial nace en `pendiente_recepcion`; si lo que
/// se está sembrando es eso, pásalo explícitamente.
Future<String> sembrarReparacion(
  FirebaseFirestore firestore, {
  required String idVehiculo,
  required String idTaller,
  required String idPropietario,
  required String placa,
  String estado = 'recibido',
  DateTime? ahora,
}) async {
  final momento = ahora ?? DateTime.now();
  final docRef = firestore.collection(FirestoreCollections.reparaciones).doc();
  final model = ReparacionModel(
    idReparacion: docRef.id,
    idVehiculo: idVehiculo,
    idTaller: idTaller,
    idPropietario: idPropietario,
    placa: placa,
    estado: estado,
    historialEstados: [
      {'estado': estado, 'timestamp': momento},
    ],
    fechaCreacion: momento,
    fechaActualizacion: momento,
  );
  await docRef.set(model.toMap());
  return docRef.id;
}
