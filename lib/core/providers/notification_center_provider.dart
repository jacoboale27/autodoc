import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/models/app_notification_model.dart';

/// Provider for the in-app notification center.
/// Streams notifications from `notificaciones/{userId}/items`
/// and provides badge count + mark-as-read functionality.
class NotificationCenterProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;

  NotificationCenterProvider({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  List<AppNotification> _notifications = [];
  StreamSubscription? _subscription;
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.leida).length;
  bool get hasUnread => unreadCount > 0;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Start streaming notifications for a given user
  void initialize(String userId) {
    _subscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _firestore
        .collection('notificaciones')
        .doc(userId)
        .collection('items')
        .orderBy('timestamp', descending: true)
        .limit(50) // Last 50 notifications
        .snapshots()
        .listen(
          (snapshot) {
            _notifications = snapshot.docs
                .map((doc) => AppNotification.fromFirestore(doc))
                .toList();
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('notificaciones')
          .doc(userId)
          .collection('items')
          .doc(notificationId)
          .update({'leida': true});
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final unread = _notifications.where((n) => !n.leida);
      for (final notif in unread) {
        final ref = _firestore
            .collection('notificaciones')
            .doc(userId)
            .collection('items')
            .doc(notif.id);
        batch.update(ref, {'leida': true});
      }
      await batch.commit();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete a single notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('notificaciones')
          .doc(userId)
          .collection('items')
          .doc(notificationId)
          .delete();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
