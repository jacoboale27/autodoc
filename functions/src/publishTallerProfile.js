const functions = require('firebase-functions');
const admin = require('firebase-admin');

const CAMPOS_PUBLICOS = [
  'nombre', 'especialidad', 'ubicacion', 'direccion', 'foto_url',
  'calificacion_promedio', 'total_resenias', 'estado',
];

function esMecanico(rol) {
  const r = String(rol || '').trim().toLowerCase();
  return r === 'mecanico' || r === 'taller';
}

/**
 * Proyecta a `talleres/{uid}` unicamente los campos publicos del documento
 * `usuarios/{uid}` cuando ese usuario es mecanico. Es la unica escritura
 * permitida en `talleres`, lo que hace posible cerrar la lectura de `usuarios`.
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
    if (!esMecanico(data.rol)) {
      await tallerRef.delete().catch(() => {});
      return null;
    }

    const perfil = { id_taller: uid };
    for (const campo of CAMPOS_PUBLICOS) {
      if (data[campo] !== undefined) perfil[campo] = data[campo];
    }
    perfil.nombre = perfil.nombre || data.nombre_completo || 'Taller sin nombre';
    perfil.especialidad = perfil.especialidad || 'General';
    perfil.calificacion_promedio = perfil.calificacion_promedio || 0;
    perfil.total_resenias = perfil.total_resenias || 0;
    perfil.estado = perfil.estado || 'pendiente';
    
    if (typeof data.latitud === 'number' && typeof data.longitud === 'number') {
      perfil.ubicacion = new admin.firestore.GeoPoint(data.latitud, data.longitud);
    }

    await tallerRef.set(perfil, { merge: false });
    return null;
  });
