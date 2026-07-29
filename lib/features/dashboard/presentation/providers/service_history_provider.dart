import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/service_record_model.dart';
import '../../../../core/constants/firestore_collections.dart';

class ServiceHistoryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore;

  ServiceHistoryProvider({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;
  final List<ServiceRecordModel> _services = [];

  List<ServiceRecordModel> get services => _services;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;

  Future<void> fetchServices(String vehicleId, {bool loadMore = false}) async {
    if (_isLoading) return;

    if (!loadMore) {
      _lastDocument = null;
      _hasMore = true;
      _services.clear();
      _isLoading = true;
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
    }

    if (!_hasMore) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      var query = _firestore
          .collection(FirestoreCollections.servicios)
          .where('id_vehiculo', isEqualTo: vehicleId)
          .orderBy('fecha', descending: true)
          .limit(10);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newServices = snapshot.docs
            .map((doc) => ServiceRecordModel.fromMap(doc.data(), doc.id))
            .toList();
        final existingIds = _services.map((s) => s.idServicio).toSet();
        _services.addAll(
          newServices.where((s) => !existingIds.contains(s.idServicio)),
        );
      }

      if (snapshot.docs.length < 10) {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint("Error fetching services: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
