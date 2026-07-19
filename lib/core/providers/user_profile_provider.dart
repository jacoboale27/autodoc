import 'package:flutter/material.dart';
import 'dart:io';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/features/profile/data/services/user_service.dart';

/// Extracted from UserSessionProvider to reduce coupling.
class UserProfileProvider with ChangeNotifier {
  final UserService _userService = UserService();

  UserModel? _userData;
  bool _isLoading = false;
  String? _error;

  UserModel? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch user profile data from Firestore
  Future<void> fetchUserData(String userId) async {
    debugPrint('UserProfileProvider: Fetching user data for: $userId');
    _setLoading(true);
    try {
      _userData = await _userService.getUserData(userId);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  /// Update user profile, optionally with a new profile image
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

  /// Clear user data (on logout)
  void clearUserData() {
    _userData = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
}
