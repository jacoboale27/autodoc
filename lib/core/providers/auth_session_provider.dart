import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Extracted from UserProfileProvider to reduce coupling.
class AuthSessionProvider with ChangeNotifier {
  User? _user;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  String get currentUid => _user?.uid ?? '';
  String? get error => _error;

  AuthSessionProvider() {
    FirebaseAuth.instance.idTokenChanges().listen(
      (User? user) {
        _user = user;
        _error = null;
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
      await FirebaseAuth.instance.currentUser?.reload();
      _user = FirebaseAuth.instance.currentUser;
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
