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

/// Rol funcional de un valor crudo de `usuarios/{uid}.rol`.
///
/// ROLE-01: esta función es la puerta de autorización de la UI (router,
/// `MainScaffold`, filtros de mecánico), así que compara **exactamente** los
/// mismos literales que `firestore.rules`, carácter por carácter — ni
/// mayúsculas/minúsculas, ni acentos, ni espacios:
///
/// - `AppRole.admin`: `'admin'`, `'Administrador'`, `'Superusuario'` — el
///   mismo conjunto de `isAdmin()`.
/// - `AppRole.mechanic`: `'Mecanico'`, `'Taller'` — el componente de rol de
///   `isMecanico()` (el `estado in ['aprobado','activo']` que exige esa
///   función se valida aparte, en `app_router.dart` vía
///   `estadosMecanicoAprobado`, no aquí).
///
/// Antes esta función normalizaba a minúsculas y sin acentos antes de
/// comparar, así que aceptaba variantes como `'mecanico'` o `'Mecánico'`.
/// Eso hacía que la UI mostrara capacidades de mecánico/admin a una cuenta
/// cuyo `rol` persistido NO es uno de los literales que
/// `firestore.rules` acepta — la UI concedía algo que el backend niega en
/// cada lectura/escritura real. Es una divergencia de contrato, no una
/// escalada de privilegios (el backend sigue negando), pero rompe la
/// experiencia: la cuenta ve un dashboard que no puede usar.
///
/// La tolerancia a variantes históricas (acentos, mayúsculas, sinónimos como
/// `'Usuario'`) existe SOLO para migración de datos —
/// `functions/migrate_rol_usuario.js` — nunca aquí. Cualquier valor que no
/// sea un literal canónico exacto (incluidos vacío o nulo) cae a
/// [AppRole.owner]: es el rol sin privilegios, y por tanto el default
/// seguro que además "falla cerrado" igual que lo haría el backend.
AppRole appRoleOf(String? rol) {
  switch (rol) {
    case 'admin':
    case 'Administrador':
    case 'Superusuario':
      return AppRole.admin;
    case 'Mecanico':
    case 'Taller':
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
