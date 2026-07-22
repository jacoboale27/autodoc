import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/features/profile/data/services/user_service.dart';

/// Extracted from UserSessionProvider to reduce coupling.
class UserProfileProvider with ChangeNotifier {
  final UserService _userService = UserService();

  UserModel? _userData;
  bool _isLoading = false;
  bool _hasAttemptedFetch = false;
  String? _fetchedUserId;
  String? _error;

  UserModel? get userData => _userData;
  bool get isLoading => _isLoading;
  bool get hasAttemptedFetch => _hasAttemptedFetch;
  String? get fetchedUserId => _fetchedUserId;
  String? get error => _error;

  /// Returns true if profile fetch has been attempted for the given userId
  bool hasAttemptedFetchFor(String userId) {
    return _hasAttemptedFetch && _fetchedUserId == userId;
  }

  /// Fetch user profile data from Firestore
  Future<void> fetchUserData(String userId) async {
    debugPrint('UserProfileProvider: Fetching user data for: $userId');
    _fetchedUserId = userId;
    _hasAttemptedFetch = false;
    _userData = null;
    _setLoading(true);
    try {
      _userData = await _userService.getUserData(userId);
      _hasAttemptedFetch = true;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _hasAttemptedFetch = true;
      _setLoading(false);
    }
  }

  /// Update user profile, optionally with a new profile image
  Future<bool> updateProfile(UserModel updatedUser, {XFile? imageFile, bool isNewUser = false}) async {
    _setLoading(true);
    _setError(null);
    try {
      UserModel userToUpdate = updatedUser;
      if (imageFile != null) {
        final photoUrl = await _userService.uploadProfilePhoto(updatedUser.idUsuario, imageFile);
        userToUpdate = updatedUser.copyWith(fotoPerfilUrl: photoUrl);
      }
      
      if (isNewUser) {
        await _userService.createUserData(userToUpdate);
      } else {
        await _userService.updateUserData(userToUpdate);
      }
      
      _userData = userToUpdate;
      _fetchedUserId = updatedUser.idUsuario;
      _hasAttemptedFetch = true;
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
    _fetchedUserId = null;
    _hasAttemptedFetch = false;
    _isLoading = false;
    _error = null;
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
