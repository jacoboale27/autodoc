'use strict';

/**
 * Proyeccion y consulta para el callable `obtenerEmpleadosPublicos` (Tarea
 * 13, D1 — "perfil publico del taller").
 *
 * Contexto: la pantalla de perfil publico del taller (`PublicProfileScreen`,
 * seccion Empleados) quiere mostrar quien trabaja ahi. La subcoleccion real
 * `talleres/{uid}/empleados` (`EmpleadoRepository`, `crearEmpleadoTaller`)
 * guarda `correo` y `telefono` — datos que el EMPLEADO entrego a su patron
 * para trabajar, no datos que consintio publicar en el directorio abierto
 * (`talleres/{uid}` si es de lectura anonima, pero eso lo consintio el
 * DUEÑO al operar un negocio publico; el empleado no).
 *
 * `firestore.rules` no puede proyectar campos — un `get()`/`list()`
 * permitido siempre trae el documento completo (mismo principio que
 * `obtenerPerfilPublico.js`) — asi que abrir la lectura de la subcoleccion
 * en las reglas expondria correo/telefono de cada empleado a cualquiera.
 * Por eso este callable, con Admin SDK, hace la proyeccion del lado
 * servidor: ALLOWLIST desde cero, nunca un blacklist sobre el documento
 * fuente.
 *
 * `db` se inyecta por el mismo motivo que en `obtenerPerfilPublico.js`:
 * leer `admin.firestore()` dispara `ensureApp()`, hostil para testear sin
 * emulador.
 */

/**
 * Subconjunto PUBLICO de un documento `talleres/{uid}/empleados/{id}`.
 *
 * Es un ALLOWLIST, no un blocklist: un campo nuevo que se agregue mañana al
 * documento fuente (correo, telefono, id_taller_propietario...) queda fuera
 * por construccion, no por acordarse de excluirlo aqui.
 *
 * @param {object} data documento de `talleres/{uid}/empleados/{id}`
 * @returns {{nombre_completo: string, rol: string, activo: boolean}}
 */
function subconjuntoPublicoEmpleado(data) {
  const d = data || {};
  return {
    nombre_completo: d.nombre_completo || 'Empleado',
    rol: d.rol || 'Mecanico',
    activo: d.activo !== false,
  };
}

/**
 * Lista el subconjunto publico de los empleados ACTIVOS de un taller.
 *
 * Solo activos: un empleado dado de baja no deberia figurar en un perfil
 * publico que un cliente consulta para decidir si confiar en ese taller.
 *
 * El filtro se hace EN MEMORIA sobre `subconjuntoPublicoEmpleado(...).activo`
 * (que ya cae a `true` si el campo falta), a proposito y no como
 * `.where('activo', '==', true)`. Una query de Firestore con esa condicion
 * de igualdad DESCARTA en silencio cualquier documento donde el campo no
 * exista del todo: un empleado creado antes de que `activo` se agregara al
 * esquema desaparecería de todos los perfiles publicos sin ningun error en
 * ninguna parte. Traer la subcoleccion completa y filtrar aqui, donde
 * `subconjuntoPublicoEmpleado` ya decide "ausente == activo", es lo que
 * mantiene esa tolerancia real en vez de solo documentada.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} idTaller
 * @returns {Promise<Array<{nombre_completo: string, rol: string, activo: boolean}>>}
 */
async function listarEmpleadosPublicos(db, idTaller) {
  const snap = await db
    .collection('talleres')
    .doc(idTaller)
    .collection('empleados')
    .get();

  return snap.docs
    .map((doc) => subconjuntoPublicoEmpleado(doc.data()))
    .filter((empleado) => empleado.activo);
}

module.exports = { subconjuntoPublicoEmpleado, listarEmpleadosPublicos };
