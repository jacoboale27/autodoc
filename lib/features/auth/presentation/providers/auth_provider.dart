import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:autodoc/features/auth/data/services/auth_service.dart';
import 'package:autodoc/features/admin/data/services/admin_auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final AdminAuthService _adminAuthService;

  AuthProvider({AuthService? authService, AdminAuthService? adminAuthService})
    : _authService = authService ?? AuthService(),
      _adminAuthService = adminAuthService ?? AdminAuthService();

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get needsEmailVerification {
    if (!_authService.isCurrentUserSignedIn) return false;
    return _authService.isEmailPasswordUser &&
        !_authService.isCurrentUserEmailVerified;
  }

  bool get isEmailPasswordUser => _authService.isEmailPasswordUser;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<bool> signIn(String emailOrUsername, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      String email = emailOrUsername.trim();

      // If not an email, attempt to resolve as admin username
      if (!email.contains('@')) {
        final adminUser = await _adminAuthService.loginAsAdmin(email, password);
        if (adminUser != null) {
          _setLoading(false);
          return true;
        }
        // If not an admin username, fail
        _setError('No se encontró un usuario con ese nombre.');
        _setLoading(false);
        return false;
      }

      // Standard email sign in via Firebase Auth
      final credential = await _authService.signInWithEmail(email, password);
      _setLoading(false);
      return credential?.user != null;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);
    try {
      final credential = await _authService.signInWithGoogle();
      _setLoading(false);
      return credential?.user != null;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final credential = await _authService.registerWithEmail(email, password);
      if (credential?.user != null) {
        await _authService.sendEmailVerification();
        _setLoading(false);
        return true;
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.sendPasswordReset(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendEmailVerification() async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.sendEmailVerification();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> refreshEmailVerificationStatus() async {
    try {
      await _authService.reloadCurrentUser();
      notifyListeners();
      return _authService.isCurrentUserEmailVerified;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.deleteAccount();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      if (e == 'requires-recent-login') {
        _error = 'requires-recent-login';
      } else {
        _error = e.toString();
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<bool> verifyPassword(String password) async {
    _setLoading(true);
    final isValid = await _authService.verifyPassword(password);
    _setLoading(false);
    return isValid;
  }

  Future<void> clearError() async {
    _setError(null);
  }

  Future<void> reloadUser() async {
    await FirebaseAuth.instance.currentUser?.reload();
    notifyListeners();
  }
}
