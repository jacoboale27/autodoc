import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:autodoc/core/services/push_notification_service.dart';

/// Extracted from UserProfileProvider to reduce coupling.
class AuthSessionProvider with ChangeNotifier {
  User? _user;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  String get currentUid => _user?.uid ?? '';
  String? get error => _error;

  final FirebaseAuth _firebaseAuth;

  AuthSessionProvider({FirebaseAuth? firebaseAuth}) 
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    _firebaseAuth.idTokenChanges().listen(
      (User? user) {
        _user = user;
        _error = null;
        if (user != null) {
          PushNotificationService().updateUserToken(user.uid);
        }
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  /// Force refresh from FirebaseAuth (e.g. after email verification)
  Future<void> refreshUser() async {
    try {
      await _firebaseAuth.currentUser?.reload();
      _user = _firebaseAuth.currentUser;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
