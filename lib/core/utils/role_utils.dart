/// Utilidades para roles de usuario en AutoDoc.
///
/// **Fuente única de verdad sobre `usuarios/{uid}.rol`.**
///
/// Antes había tres criterios distintos conviviendo y no coincidían entre sí:
///
/// - `_normalizeRole` (app_router.dart) mapeaba `'mecanico'` **y** `'taller'`
///   a taller.
/// - `isMechanicRole` (aquí) aceptaba solo `'mecanico'`.
/// - `MainScaffold` comparaba `rol == 'Mecanico'` exacto.
///
/// Con una cuenta guardada como `'Taller'` —que es como quedan las sub-cuentas
/// de empleado y parte de los talleres migrados— el router la trataba como
/// taller (la mandaba a `/mechanic_dashboard` y le bloqueaba las rutas de
/// propietario) mientras `MainScaffold` le montaba el shell de PROPIETARIO.
/// Resultado: un taller aprobado navegando con la barra de propietario. Ese era
/// el síntoma de "el mecánico acaba en páginas de propietario".
library;

/// Los tres roles funcionales de la app. `'Taller'` y `'Mecanico'` son el mismo
/// rol funcional; `'Administrador'` y `'Superusuario'` comparten [admin] (la
/// distinción de superusuario vive en `UserModel.isSuperUser`, no aquí).
enum AppRole { owner, mechanic, admin }

const Map<String, String> _sinAcentos = {
  'á': 'a',
  'é': 'e',
  'í': 'i',
  'ó': 'o',
  'ú': 'u',
  'ü': 'u',
};

/// Minúsculas, sin espacios sobrantes y sin acentos.
///
/// Lo de los acentos no es cosmético: `'Mecánico'` escrito con tilde (que es
/// como lo teclea cualquiera, y como puede haber quedado en cuentas creadas
/// desde el panel de administración) no casaba con `'mecanico'` y la cuenta
/// caía al rol por defecto, que es propietario.
String _normalizar(String? rol) {
  var r = (rol ?? '').trim().toLowerCase();
  _sinAcentos.forEach((acentuada, plana) => r = r.replaceAll(acentuada, plana));
  return r;
}

/// Rol funcional de un valor crudo de `usuarios/{uid}.rol`.
///
/// Cualquier valor desconocido (incluido vacío o nulo) es [AppRole.owner]: es
/// el rol sin privilegios, y por tanto el default seguro.
AppRole appRoleOf(String? rol) {
  switch (_normalizar(rol)) {
    case 'admin':
    case 'administrador':
    case 'superusuario':
      return AppRole.admin;
    case 'mecanico':
    case 'taller':
      return AppRole.mechanic;
    default:
      return AppRole.owner;
  }
}

/// ¿Es una cuenta de taller/mecánico? Incluye `'Taller'`.
bool isMechanicRole(String? rol) => appRoleOf(rol) == AppRole.mechanic;

/// ¿Es una cuenta de administración (Administrador o Superusuario)?
bool isAdminRole(String? rol) => appRoleOf(rol) == AppRole.admin;

/// Roles de taller usados en consultas Firestore `whereIn`.
///
/// Debe cubrir los mismos valores que [isMechanicRole] y que `isMecanico()` en
/// `firestore.rules` (`rol in ['Mecanico', 'Taller']`); si solo lleva
/// `'Mecanico'`, las consultas dejan fuera silenciosamente a los talleres
/// guardados como `'Taller'`.
const List<String> mechanicFirestoreRoles = ['Mecanico', 'Taller'];
