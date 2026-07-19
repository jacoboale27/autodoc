import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/features/profile/data/services/user_service.dart';
import 'package:autodoc/features/auth/data/services/auth_preferences_service.dart';
import 'package:autodoc/core/services/notification_service.dart';

/// UserSessionProvider — slim facade.
///
/// This provider consolidates auth state and user profile for screens
/// that need both. The heavy logic is delegated to:
///   - AuthSessionProvider  → FirebaseAuth, uid, isLoggedIn
///   - UserProfileProvider  → UserModel, fetch/update profile
///
/// This facade remains for backward compatibility with existing screens
/// (~20 files reference it). New code should prefer the focused providers.
class UserSessionProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final AuthPreferencesService _authPreferences = AuthPreferencesService();

  User? _user;
  UserModel? _userData;
  bool _isLoading = false;
  String? _error;
  bool _isAdminSession = false;

  User? get user => _user;
  UserModel? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdminSession => _isAdminSession;

  String get currentUid => _user?.uid ?? _userData?.idUsuario ?? '';

  UserSessionProvider() {
    FirebaseAuth.instance.idTokenChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        await fetchUserData(user.uid);
      } else {
        _userData = null;
        _isAdminSession = false;
        notifyListeners();
      }
    });
  }

  Future<void> fetchUserData(String userId) async {
    debugPrint('Fetching user data for: $userId');
    _setLoading(true);
    try {
      _userData = await _userService.getUserData(userId);

      if (_userData != null) {
        final rol = _userData!.rol.trim().toLowerCase();
        _isAdminSession = (rol == 'administrador' || rol == 'admin');
        
        try {
          await NotificationService().saveUserToken();
        } catch (e) {
          debugPrint("Failed to save FCM token: $e");
        }
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

  Future<void> persistRememberMe({
    required bool remember,
    required String email,
  }) async {
    await _authPreferences.setRememberMe(remember);
    if (remember && email.contains('@')) {
      await _authPreferences.saveEmail(email);
    } else if (!remember) {
      await _authPreferences.clearSavedCredentials();
    }
  }

  Future<bool> loadRememberMe() => _authPreferences.getRememberMe();

  Future<String?> loadSavedEmail() => _authPreferences.getSavedEmail();

  /// Refreshes user data from Firestore (used to poll approval status).
  Future<void> refreshUserData() async {
    final uid = _user?.uid ?? _userData?.idUsuario;
    if (uid != null && uid.isNotEmpty) {
      await fetchUserData(uid);
    }
  }
}
