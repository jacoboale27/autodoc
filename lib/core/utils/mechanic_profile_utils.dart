import 'package:autodoc/core/models/user_model.dart';

/// Campos obligatorios para que un mecánico pueda cotizar/finalizar servicios.
/// El teléfono NO es obligatorio a propósito; la ubicación geográfica sí,
/// porque de eso depende la confianza del cliente en el taller.
bool isMechanicProfileComplete(UserModel? user) {
  if (user == null) return false;
  // El municipio puede venir del campo nuevo (`municipio`) o del legado
  // (`ubicacionMunicipio`) según cuándo se haya guardado el perfil.
  final tieneMunicipio =
      (user.municipio?.trim().isNotEmpty ?? false) ||
      (user.ubicacionMunicipio?.trim().isNotEmpty ?? false);
  return user.nombreCompleto.trim().isNotEmpty &&
      (user.especialidad?.trim().isNotEmpty ?? false) &&
      (user.departamento?.trim().isNotEmpty ?? false) &&
      tieneMunicipio &&
      user.latitud != null &&
      user.longitud != null;
}

/// Lista legible de los campos que le faltan al mecánico por completar.
List<String> missingMechanicProfileFields(UserModel? user) {
  final missing = <String>[];
  if (user == null) return ['Perfil'];
  if (user.nombreCompleto.trim().isEmpty) missing.add('Nombre del taller');
  if (!(user.especialidad?.trim().isNotEmpty ?? false)) {
    missing.add('Especialidad');
  }
  if (!(user.departamento?.trim().isNotEmpty ?? false)) {
    missing.add('Departamento');
  }
  final tieneMunicipio =
      (user.municipio?.trim().isNotEmpty ?? false) ||
      (user.ubicacionMunicipio?.trim().isNotEmpty ?? false);
  if (!tieneMunicipio) {
    missing.add('Municipio');
  }
  if (user.latitud == null || user.longitud == null) {
    missing.add('Ubicación geográfica');
  }
  return missing;
}
