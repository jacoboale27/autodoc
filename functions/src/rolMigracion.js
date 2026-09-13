'use strict';

/**
 * ROLE-01 — vocabulario canonico unico de `usuarios/{uid}.rol`.
 *
 * Es EXACTAMENTE el conjunto que exige `firestore.rules` (isAdmin(),
 * isMecanico()) y `lib/core/utils/role_utils.dart` (appRoleOf) tras la
 * correccion de ROLE-01: ambos comparan literales exactos, sin tolerar caja,
 * acentos ni sinonimos. La tolerancia a variantes historicas vive SOLO aqui
 * —el script de migracion, que es lectura/escritura administrada, no un
 * camino de autorizacion— y nunca debe copiarse de vuelta a la app ni a las
 * reglas.
 */
const ROLES_CANONICOS = ['Propietario', 'Mecanico', 'Taller', 'Administrador', 'Superusuario'];

const SIN_ACENTOS = {
  á: 'a', é: 'e', í: 'i', ó: 'o', ú: 'u', ü: 'u',
};

/** Minusculas, sin espacios sobrantes y sin acentos. Solo para clasificar
 * candidatos de migracion — nunca para autorizar (ver docstring de arriba). */
function normalizar(rol) {
  let r = String(rol == null ? '' : rol).trim().toLowerCase();
  for (const [acentuada, plana] of Object.entries(SIN_ACENTOS)) {
    r = r.split(acentuada).join(plana);
  }
  return r;
}

// Sinonimos historicos reconocidos -> su destino canonico. Deliberadamente
// explicito y corto: solo lo que sabemos que significa cada rol por historia
// del producto (incluye 'usuario', el sinonimo viejo de propietario del
// hallazgo §2.15, y 'admin', el alias que firestore.rules SI tolera pero que
// no es uno de los 5 valores del vocabulario canonico). Cualquier valor
// normalizado que no aparezca aqui NO se migra a ciegas: se reporta para
// revision manual.
const SINONIMOS = {
  usuario: 'Propietario',
  propietario: 'Propietario',
  mecanico: 'Mecanico',
  taller: 'Taller',
  admin: 'Administrador',
  administrador: 'Administrador',
  superusuario: 'Superusuario',
};

/**
 * Rol canonico al que deberia migrarse `rolActual`, o `null` si ya es
 * canonico exacto o si no se reconoce ningun sinonimo (revision manual).
 */
function rolCanonicoSugerido(rolActual) {
  if (ROLES_CANONICOS.includes(rolActual)) return null;
  const norm = normalizar(rolActual);
  return SINONIMOS[norm] || null;
}

/**
 * Agrega una coleccion de documentos `{ id, rol }` en tres grupos —ya
 * canonicos, migrables (con su destino) y desconocidos (revision manual)— y
 * un conteo por variante para el reporte legible del dry-run.
 */
function resumenMigracion(docs) {
  const yaCanonicos = [];
  const migrables = [];
  const desconocidos = [];
  const conteoPorVariante = {};

  for (const doc of docs) {
    const rolActual = doc.rol;
    if (ROLES_CANONICOS.includes(rolActual)) {
      yaCanonicos.push(doc);
      continue;
    }
    const destino = rolCanonicoSugerido(rolActual);
    if (destino) {
      migrables.push({ id: doc.id, rolActual, rolCanonico: destino });
      // Se agrupa por la forma NORMALIZADA (no el valor crudo): 'mecanico' y
      // 'MECANICO' son la misma variante para efectos de conteo, aunque
      // difieran en caja.
      const clave = `${normalizar(rolActual)} -> ${destino}`;
      conteoPorVariante[clave] = (conteoPorVariante[clave] || 0) + 1;
      continue;
    }
    desconocidos.push(doc);
  }

  return {
    totalDocumentos: docs.length,
    yaCanonicos,
    migrables,
    desconocidos,
    conteoPorVariante,
  };
}

module.exports = {
  ROLES_CANONICOS,
  normalizar,
  rolCanonicoSugerido,
  resumenMigracion,
};
