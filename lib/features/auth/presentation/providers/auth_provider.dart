import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../data/services/auth_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../profile/data/services/user_service.dart';
import '../../admin/data/services/admin_auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final AdminAuthService _adminAuthService = AdminAuthService();
  User? _user;
  UserModel? _userData;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  UserModel? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _authService.user.listen((User? user) async {
      _user = user;
      if (user != null) {
        await fetchUserData(user.uid);
      } else {
        _userData = null;
      }
      notifyListeners();
    });
  }

  Future<void> fetchUserData(String userId) async {
    debugPrint('Fetching user data for: $userId');
    _setLoading(true);
    try {
      // Intentar obtener de administradores hardcoded primero
      _userData = _adminAuthService.getHardcodedAdminByUid(userId);
      
      if (_userData == null) {
        _userData = await _userService.getUserData(userId);
      }
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<bool> updateProfile(UserModel updatedUser, {File? imageFile}) async {
    _setLoading(true);
    _setError(null);
    try {
      UserModel userToUpdate = updatedUser;
      if (imageFile != null) {
        final photoUrl = await _userService.uploadProfilePhoto(updatedUser.idUsuario, imageFile);
        userToUpdate = updatedUser.copyWith(fotoPerfilUrl: photoUrl);
      }
      await _userService.updateUserData(userToUpdate);
      _userData = userToUpdate;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

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
      // 1. Verificar si es un administrador hardcoded
      final adminUser = await _adminAuthService.loginAsAdmin(emailOrUsername, password);
      if (adminUser != null) {
        _userData = adminUser;
        _user = null; // No hay usuario de Firebase para administradores hardcoded
        _setLoading(false);
        return true;
      }

      // 2. Intento normal con Firebase
      final credential = await _authService.signInWithEmail(emailOrUsername, password);
      _user = credential?.user;
      if (_user != null) {
        _userData = null; // Limpiar datos antiguos
        await fetchUserData(_user!.uid);
      }
      _setLoading(false);
      return true;
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
      if (credential?.user != null) {
        _user = credential!.user;
        _userData = null; // Clear stale data
        await fetchUserData(_user!.uid);
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

  Future<bool> register(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.registerWithEmail(email, password);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _userData = null;
    _user = null;
    notifyListeners();
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
    await _user?.reload();
    _user = FirebaseAuth.instance.currentUser;
    notifyListeners();
  }
}
