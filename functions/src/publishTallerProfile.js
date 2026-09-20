const functions = require('firebase-functions');
const admin = require('firebase-admin');

const { reabrirSiCambioLaIdentidad } = require('./reabrirVerificacion');

/**
 * Campos de `usuarios/{uid}` que se copian al perfil publico
 * `talleres/{uid}`. Todo lo que NO este aqui (correo, fcm_token,
 * fecha_nacimiento, id_taller_propietario...) queda fuera del directorio,
 * que es de lectura publica (`allow read: if true` en firestore.rules).
 *
 * `foto_perfil_url` es la clave real que escribe la app
 * (`UserModel.toMap()`, lib/core/models/user_model.dart:131). Durante un
 * tiempo aqui solo figuraba `foto_url` —el nombre que usa vehicle_model, no
 * user_model—, asi que el `if (data[campo] !== undefined)` de abajo nunca
 * casaba y la foto del taller no llegaba jamas al directorio. Se mantienen
 * las DOS claves: `foto_url` por si algun doc heredado la trae, y porque
 * `UserModel.fromMap` ya lee `foto_perfil_url ?? foto_url` indistintamente.
 */
// Campos que se copian tal cual de `usuarios/{uid}` al documento PUBLICO
// `talleres/{uid}`, que es de lectura anonima.
//
// Los dos campos de imagen que el cliente escribe libremente —'foto_perfil_url'
// y su alias heredado 'foto_url'— siguen aqui porque la ficha del directorio
// los necesita, pero ya NO son URLs arbitrarias: firestore.rules valida en el
// update de 'usuarios' que apunten al objeto del propio usuario en Storage
// (ver fotoDePerfilValida). Sin esa validacion, este proyector convertia un
// campo de texto libre en una peticion que hacia la app de cada visitante del
// directorio contra el servidor que eligiera el taller.
//
// 'galeria' no guarda URLs sino nombres de archivo de un whitelist; la ruta se
// reconstruye en el cliente a partir del uid y del nombre (ver GaleriaTaller),
// asi que no hay nada que un taller pueda apuntar a otro sitio.
// Observaciones del 2026-09-19: 'telefono' y 'municipio'. La pantalla de
// ajustes del taller los presenta dentro de «Informacion Publica — estos datos
// seran visibles en el directorio de talleres», pero nunca se publicaban, asi
// que el perfil del taller no tenia ni como llamarle. Solo se proyectan las
// cuentas de TALLER (las de empleado se retiran abajo), nunca las de un
// propietario.
const CAMPOS_PUBLICOS = [
  'nombre', 'especialidad', 'ubicacion', 'direccion',
  'foto_perfil_url', 'foto_url', 'galeria',
  'calificacion_promedio', 'total_resenias', 'estado', 'departamento',
  'telefono', 'municipio', 'banner_encuadre', 'tipos_atendidos',
];

// Campos de CONTACTO: solo se publican con el taller aprobado. `talleres` es
// de lectura anonima para la coleccion entera (la landing la descarga por
// REST y filtra por estado en el navegador), asi que publicarlos antes de la
// aprobacion ponia al alcance de cualquiera el telefono y la direccion de
// cada solicitante, de los rechazados y de los suspendidos (revision de gate
// del 2026-09-19). Al aprobar, el cambio de `estado` vuelve a disparar el
// trigger y se publican; al suspender, el `set` sin merge los retira.
const CAMPOS_DE_CONTACTO = ['telefono', 'direccion'];
const ESTADOS_PUBLICABLES = ['aprobado', 'activo'];

function esMecanico(rol) {
  const r = String(rol || '').trim().toLowerCase();
  return r === 'mecanico' || r === 'taller';
}

/**
 * Construye el documento publico `talleres/{uid}` a partir del documento
 * privado `usuarios/{uid}`.
 *
 * Funcion pura y exportada aparte del trigger para poder testear la
 * proyeccion sin montar el SDK de Admin. `GeoPoint` se inyecta por la misma
 * razon: leer `admin.firestore` dispara `ensureApp()` (ver la nota de
 * functions/test/empleados.test.js).
 *
 * @param {string} uid
 * @param {object} data documento de `usuarios/{uid}`
 * @param {{GeoPoint: Function}} [opciones]
 * @returns {object} documento a escribir en `talleres/{uid}`
 */
function construirPerfilPublico(uid, data, opciones) {
  const GeoPoint = (opciones && opciones.GeoPoint) || admin.firestore.GeoPoint;

  const aprobado = ESTADOS_PUBLICABLES.includes(data.estado);
  const perfil = { id_taller: uid };
  for (const campo of CAMPOS_PUBLICOS) {
    if (!aprobado && CAMPOS_DE_CONTACTO.includes(campo)) continue;
    if (data[campo] !== undefined) perfil[campo] = data[campo];
  }
  perfil.nombre = perfil.nombre || data.nombre_completo || 'Taller sin nombre';
  perfil.especialidad = perfil.especialidad || 'General';
  perfil.calificacion_promedio = perfil.calificacion_promedio || 0;
  perfil.total_resenias = perfil.total_resenias || 0;
  perfil.estado = perfil.estado || 'pendiente';

  if (
    aprobado &&
    typeof data.latitud === 'number' &&
    typeof data.longitud === 'number'
  ) {
    perfil.ubicacion = new GeoPoint(data.latitud, data.longitud);
  }

  return perfil;
}

/**
 * Proyecta a `talleres/{uid}` unicamente los campos publicos del documento
 * `usuarios/{uid}` cuando ese usuario es mecanico. Es la unica escritura
 * permitida en `talleres`, lo que hace posible cerrar la lectura de `usuarios`.
 *
 * Aprovecha el mismo onWrite para reabrir la verificacion cuando un taller ya
 * aprobado cambia datos que un humano habia contrastado (ver
 * ./reabrirVerificacion). Van juntas y no en dos triggers sobre `usuarios`
 * porque cada trigger es una invocacion facturada por escritura, y las dos
 * necesitan exactamente lo mismo: el antes y el despues del documento.
 */
exports.publishTallerProfile = functions.firestore
  .document('usuarios/{uid}')
  .onWrite(async (change, context) => {
    const uid = context.params.uid;
    const tallerRef = admin.firestore().collection('talleres').doc(uid);

    // Usuario borrado, o ya no es mecanico -> retirar del directorio.
    if (!change.after.exists) {
      await tallerRef.delete().catch(() => {});
      return null;
    }
    const data = change.after.data() || {};
    // Una sub-cuenta de empleado (crearEmpleadoTaller) hereda rol == 'Taller'
    // igual que el dueño real (mismos permisos operativos), distinguida solo
    // por `id_taller_propietario`. Sin este check, cada empleado creado
    // disparaba este trigger (onWrite en usuarios/{uid}) y publicaba una
    // ficha de taller propia y fantasma en el directorio publico bajo su
    // propio uid -- el taller real ya tiene la suya bajo el uid del dueño.
    if (!esMecanico(data.rol) || data.id_taller_propietario) {
      await tallerRef.delete().catch(() => {});
      return null;
    }

    await tallerRef.set(construirPerfilPublico(uid, data), { merge: false });

    // Solo en una edicion: un alta no tiene "antes" que comparar, y su
    // expediente no puede estar aprobado todavia. La reapertura escribe en
    // `verificaciones/`, nunca en `usuarios/`, asi que no se realimenta este
    // mismo trigger.
    if (change.before.exists) {
      try {
        await reabrirSiCambioLaIdentidad(
          admin.firestore(),
          uid,
          change.before.data() || {},
          data
        );
      } catch (e) {
        // Que falle la reapertura no debe deshacer la proyeccion, que ya se
        // escribio. Se registra para poder detectarlo: un fallo silencioso
        // aqui significa datos publicados sin volver a revisar.
        console.error(`Error reabriendo la verificacion de ${uid}:`, e);
      }
    }
    return null;
  });

exports.construirPerfilPublico = construirPerfilPublico;
exports.CAMPOS_PUBLICOS = CAMPOS_PUBLICOS;
exports.esMecanico = esMecanico;
