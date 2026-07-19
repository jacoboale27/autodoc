import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Extracted from UserSessionProvider to reduce coupling.
class AuthSessionProvider with ChangeNotifier {
  User? _user;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  String get currentUid => _user?.uid ?? '';

  AuthSessionProvider() {
    FirebaseAuth.instance.idTokenChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  /// Force refresh from FirebaseAuth (e.g. after email verification)
  Future<void> refreshUser() async {
    await FirebaseAuth.instance.currentUser?.reload();
    _user = FirebaseAuth.instance.currentUser;
    notifyListeners();
  }
}
