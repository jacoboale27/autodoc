import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/catalogo_item_model.dart';

class CatalogoRepository {
  final FirebaseFirestore _firestore;

  CatalogoRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _catalogoRef(String idTaller) =>
      _firestore
          .collection(FirestoreCollections.talleres)
          .doc(idTaller)
          .collection('catalogo_servicios');

  Future<String> agregarItem({
    required String idTaller,
    required String nombre,
    required double precio,
  }) async {
    final docRef = await _catalogoRef(idTaller).add(
      CatalogoItemModel(
        idItem: '',
        idTaller: idTaller,
        nombre: nombre,
        precio: precio,
      ).toMap(),
    );
    return docRef.id;
  }

  Stream<List<CatalogoItemModel>> watchCatalogo(String idTaller) {
    return _catalogoRef(idTaller)
        .orderBy('nombre')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CatalogoItemModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Future<void> eliminarItem(String idTaller, String idItem) async {
    await _catalogoRef(idTaller).doc(idItem).delete();
  }
}
