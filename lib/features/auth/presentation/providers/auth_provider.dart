import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../data/services/auth_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../profile/data/services/user_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
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
      _userData = await _userService.getUserData(userId);
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

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signInWithEmail(email, password);
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
      _setLoading(false);
      return credential != null;
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
