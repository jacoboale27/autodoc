'use strict';

/**
 * Compuerta y proyeccion para el callable `obtenerPerfilPublico` (Tarea 10,
 * C3 — "ver el perfil del otro desde el chat").
 *
 * Contexto: el chat header (`chat_screen.dart`) necesita mostrar nombre y
 * foto del OTRO participante de la conversacion. Cuando ese participante es
 * el mecanico, `talleres/{uid}` ya resuelve esto (proyeccion publica de
 * `publishTallerProfile.js`, lectura anonima). Pero no existe un equivalente
 * publico para un CLIENTE — y no deberia haberlo por proyeccion estatica,
 * porque el subconjunto visible es dependiente del ROL DEL QUE MIRA (un
 * mecanico ve nombre/foto/municipio; nadie mas deberia poder leer ni eso).
 * Ese es exactamente el motivo de elegir un callable en vez de una
 * denormalizacion como `talleres`: la decision de "quien puede ver que"
 * depende de la relacion llamante->objetivo (¿comparten conversacion?), algo
 * que un documento publico estatico no puede expresar.
 *
 * `db` se inyecta (no se lee `admin.firestore()` aqui dentro) por el mismo
 * motivo que en `iniciarReparacionPorVehiculo.js`: leer esa propiedad
 * dispara `ensureApp()`, lo que hace hostil stubbearla desde tests sin
 * emulador.
 */

/**
 * Subconjunto PUBLICO del documento `usuarios/{uid}` de un CLIENTE que un
 * mecanico con el que comparte conversacion puede ver.
 *
 * Es un ALLOWLIST, no un blocklist: un campo nuevo que se agregue mañana a
 * `usuarios` (telefono, dui, correo, vehiculos...) queda fuera por
 * construccion, no por acordarse de excluirlo aqui.
 *
 * @param {object} data documento de `usuarios/{uid}`
 * @returns {{nombre: string, foto_perfil_url: string|null, municipio: string|null}}
 */
function subconjuntoPublicoCliente(data) {
  const d = data || {};
  return {
    nombre: d.nombre_completo || 'Cliente',
    // Mismo alias heredado que publishTallerProfile.js: el cliente real
    // (UserModel.toMap()) escribe 'foto_perfil_url', pero un documento viejo
    // puede traer solo 'foto_url'.
    foto_perfil_url: d.foto_perfil_url || d.foto_url || null,
    municipio: d.municipio || null,
  };
}

/**
 * ¿Existe una conversacion real entre este mecanico y este cliente? Es la
 * UNICA relacion que habilita a un mecanico a ver el subconjunto publico de
 * un cliente — sin ella, cualquier mecanico podria consultar a cualquier
 * cliente por uid (el hallazgo que el brief pedia cerrar con "un usuario
 * cualquiera sin conversacion no lee el perfil ajeno").
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{mecanicoId: string, clienteId: string}} args
 * @returns {Promise<boolean>}
 */
async function compartenConversacion(db, { mecanicoId, clienteId }) {
  const snap = await db
    .collection('conversaciones')
    .where('id_mecanico', '==', mecanicoId)
    .where('id_propietario', '==', clienteId)
    .limit(1)
    .get();
  return !snap.empty;
}

module.exports = { subconjuntoPublicoCliente, compartenConversacion };
