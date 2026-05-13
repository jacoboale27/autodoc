import '../../../../core/models/user_model.dart';
import '../../../../core/config/admin_secrets.dart';

class AdminAuthService {
  // Use secrets from ignored config file
  static const List<Map<String, String>> _hardcodedAdmins = AdminSecrets.hardcodedAdmins;

  /// Checks if credentials match the hardcoded list.
  /// Returns a mocked UserModel if valid, null otherwise.
  Future<UserModel?> loginAsAdmin(String input, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    for (var admin in _hardcodedAdmins) {
      if ((admin['correo'] == input || admin['usuario'] == input) && admin['password'] == password) {
        return UserModel(
          idUsuario: admin['uid']!,
          nombreCompleto: admin['nombre']!,
          correo: admin['correo']!,
          rol: admin['rol']!,
          estado: 'activo',
          fechaRegistro: DateTime.now(),
        );
      }
    }
    return null;
  }

  /// Helper to check if an email or username belongs to the hardcoded admins
  bool isHardcodedAdmin(String input) {
    return _hardcodedAdmins.any((admin) => admin['correo'] == input || admin['usuario'] == input);
  }

  /// Get admin data by UID for session persistence
  UserModel? getHardcodedAdminByUid(String uid) {
    try {
      final admin = _hardcodedAdmins.firstWhere((admin) => admin['uid'] == uid);
      return UserModel(
        idUsuario: admin['uid']!,
        nombreCompleto: admin['nombre']!,
        correo: admin['correo']!,
        rol: admin['rol']!,
        estado: 'activo',
        fechaRegistro: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
