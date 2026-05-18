/// Utilidades para roles de usuario en AutoDoc.
bool isMechanicRole(String? rol) {
  if (rol == null) return false;
  final normalized = rol.trim().toLowerCase();
  return normalized == 'mecanico';
}

/// Roles de taller usados en consultas Firestore `whereIn`.
const List<String> mechanicFirestoreRoles = ['Mecanico'];
