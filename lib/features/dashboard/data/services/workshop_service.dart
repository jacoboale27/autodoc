import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/theme/app_estado_cuenta.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkshopService {
  final FirebaseFirestore _firestore;

  WorkshopService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Valores de `estado` que hacen visible a un taller en el directorio
  /// publico, en el formato que espera `whereIn`.
  ///
  /// Debe ser el conjunto COMPLETO de [AppEstadoCuenta.aprobados], no solo
  /// `'aprobado'`: `AdminService.aprobarUsuario` escribe `'activo'` mientras
  /// que `aprobarTaller`/`reactivarTaller` escriben `'aprobado'` (ver
  /// admin_service.dart:69 y :145). Filtrar solo por `'aprobado'` dejaba
  /// permanentemente fuera del directorio a todo taller habilitado desde la
  /// pantalla de Usuarios, aunque la app le diera acceso completo.
  ///
  /// El indice compuesto `talleres (estado ASC, calificacion_promedio DESC)`
  /// de firestore.indexes.json sirve igual para `whereIn` que para la
  /// igualdad anterior: no hace falta indice nuevo.
  static final List<String> _estadosVisibles = AppEstadoCuenta.aprobados.toList(
    growable: false,
  );

  Stream<List<UserModel>> getWorkshopsStream({int limit = 50}) {
    return _firestore
        .collection(FirestoreCollections.talleres)
        .where('estado', whereIn: _estadosVisibles)
        .orderBy('calificacion_promedio', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<List<UserModel>> getWorkshops({int limit = 50}) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.talleres)
        .where('estado', whereIn: _estadosVisibles)
        .orderBy('calificacion_promedio', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<UserModel?> getWorkshopById(String id) async {
    // I1 (Fase C, revision de correcciones): 'usuarios' quedo cerrada a solo
    // lectura del propio documento (Tarea 8); el perfil publico del taller
    // vive en 'talleres', proyectado por publishTallerProfile.
    final doc = await _firestore
        .collection(FirestoreCollections.talleres)
        .doc(id)
        .get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> updateWorkshopProfile(UserModel workshop) async {
    await _firestore
        .collection(FirestoreCollections.usuarios)
        .doc(workshop.idUsuario)
        .update(workshop.toMap());
  }

  Future<void> saveFilters({
    double? minRating,
    double? maxDistance,
    String? specialty,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (minRating != null) await prefs.setDouble('wd_min_rating', minRating);
    if (maxDistance != null) {
      await prefs.setDouble('wd_max_distance', maxDistance);
    }
    if (specialty != null) {
      if (specialty.isEmpty) {
        await prefs.remove('wd_specialty');
      } else {
        await prefs.setString('wd_specialty', specialty);
      }
    }
  }

  Future<Map<String, dynamic>> loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'minRating': prefs.getDouble('wd_min_rating'),
      'maxDistance': prefs.getDouble('wd_max_distance'),
      'specialty': prefs.getString('wd_specialty'),
    };
  }
}
