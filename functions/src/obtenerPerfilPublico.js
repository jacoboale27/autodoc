'use strict';

const { esMecanico } = require('./publishTallerProfile');

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
 * ¿Existe una conversacion real entre este mecanico y este cliente, en la
 * que el CLIENTE ya haya escrito al menos un mensaje?
 *
 * Ronda 2 (FIX 3): antes, esta funcion solo comprobaba que existiera un
 * documento en `conversaciones` con esos dos uids. Eso era auto-emitible por
 * el propio mecanico: `conversaciones.create` (firestore.rules) le permite
 * crear una conversacion nombrandose a si mismo `id_mecanico` y a
 * CUALQUIER uid como `id_propietario` — no hay relacion previa que probar,
 * la fabrica el mismo. Subir la barra de esa regla (isMecanico(), un taller
 * aprobado en vez de cualquier cuenta) no cierra el hueco: sigue siendo el
 * mecanico quien decide unilateralmente que la relacion "existe".
 *
 * El predicado correcto no es "existe una conversacion" sino "el cliente ha
 * hablado de verdad": se exige al menos un mensaje en esa conversacion cuyo
 * `id_remitente` sea el propio cliente. Esto el mecanico NO lo puede
 * falsificar — `firestore.rules`, match /mensajes, `allow create` exige
 * `request.resource.data.id_remitente == request.auth.uid` (Tarea 11, R1),
 * asi que solo el cliente autenticado puede escribir un mensaje con su
 * propio uid como remitente.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{mecanicoId: string, clienteId: string}} args
 * @returns {Promise<boolean>}
 */
async function compartenConversacion(db, { mecanicoId, clienteId }) {
  const convSnap = await db
    .collection('conversaciones')
    .where('id_mecanico', '==', mecanicoId)
    .where('id_propietario', '==', clienteId)
    .limit(1)
    .get();
  if (convSnap.empty) return false;

  const convId = convSnap.docs[0].id;
  const mensajeSnap = await db
    .collection('conversaciones')
    .doc(convId)
    .collection('mensajes')
    .where('id_remitente', '==', clienteId)
    .limit(1)
    .get();
  return !mensajeSnap.empty;
}

/**
 * ¿El llamante tiene un rol que puede usar este callable en absoluto?
 *
 * Revision de rama completa (hallazgo C2): este callable nunca comprobaba
 * `rol`. Combinado con que `conversaciones` (antes del arreglo de
 * firestore.rules a esta misma revision) dejaba crear una conversacion
 * nombrandose a si mismo `id_mecanico` sin ninguna relacion previa, CUALQUIER
 * cuenta autenticada —incluida una cuenta de CLIENTE— podia fabricar la
 * conversacion que `compartenConversacion` exige y luego leer el subconjunto
 * publico de cualquier cliente por uid, iterando una lista para enumeracion
 * masiva. El arreglo de `firestore.rules` ya cierra la fabricacion de la
 * conversacion; este chequeo de rol es una segunda barrera independiente:
 * aunque alguna otra via llegara a crear una conversacion valida, una cuenta
 * de cliente sigue sin poder invocar este callable en absoluto.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} uid
 * @returns {Promise<boolean>}
 */
async function llamanteEsMecanico(db, uid) {
  const doc = await db.collection('usuarios').doc(uid).get();
  if (!doc.exists) return false;
  return esMecanico(doc.data().rol);
}

module.exports = { subconjuntoPublicoCliente, compartenConversacion, llamanteEsMecanico };
