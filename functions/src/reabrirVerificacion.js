const admin = require('firebase-admin');

/**
 * Campos de `usuarios/{uid}` cuyo cambio obliga a volver a verificar el
 * taller, con la etiqueta con la que se le enseñan al administrador.
 *
 * La lista NO es "todo lo publico". Es, a proposito, la misma que
 * `AppEstadoVerificacion.camposFaltantes`
 * (lib/core/models/estado_verificacion.dart): lo que se exigio para poder
 * verificar es exactamente lo que hay que re-verificar si cambia. Un campo
 * que no bloqueaba la aprobacion tampoco deberia reabrirla.
 *
 * Se le añaden dos alias heredados que `construirPerfilPublico` sigue
 * proyectando al directorio: `nombre` (que tiene precedencia sobre
 * `nombre_completo` al construir la ficha publica, asi que cambiarlo cambia el
 * nombre que ve el cliente) y `direccion`, que es literalmente lo que atestigua
 * la foto de fachada del expediente.
 *
 * Lo que deliberadamente NO esta aqui:
 * - `calificacion_promedio` / `total_resenias`: los escribe el sistema a
 *   partir de reseñas, no el taller. Incluirlos reabriria el expediente cada
 *   vez que alguien deja una reseña.
 * - `estado`: es la cerradura, y es justo lo que escribe la resolucion del
 *   expediente. Incluirlo crearia un ciclo aprobar -> reabrir -> aprobar.
 * - `foto_perfil_url` y `galeria`: son escaparate comercial, se cambian a
 *   menudo y no son lo que el administrador contrasto contra el NIT. Ver la
 *   limitacion conocida en reabrirSiCambioLaIdentidad.
 */
const CAMPOS_DE_IDENTIDAD = {
  nombre_completo: 'Nombre del taller',
  nombre: 'Nombre del taller',
  telefono: 'Teléfono de contacto',
  especialidad: 'Especialidad',
  direccion: 'Dirección',
  departamento: 'Departamento',
  municipio: 'Municipio',
  latitud: 'Ubicación en el mapa',
  longitud: 'Ubicación en el mapa',
};

/**
 * Estado del expediente que significa "ya lo miro un humano y dijo que si".
 * Es el unico origen desde el que tiene sentido reabrir.
 */
const ESTADO_APROBADA = 'aprobada';

/**
 * Estado al que vuelve un expediente reabierto: a la cola, SIN dueño.
 *
 * No se reabre directamente a 'en_revision' —que significa "un administrador
 * lo tiene abierto"— porque eso saltaria el paso de tomar el caso, que es lo
 * unico que impide que dos administradores resuelvan el mismo expediente a la
 * vez. Un expediente reabierto no lo esta mirando nadie todavia.
 */
const ESTADO_REABIERTA = 'listo_para_revision';

/**
 * Normaliza un valor para compararlo entre el antes y el despues.
 *
 * Ausente, `null` y cadena vacia son el mismo hecho —"no hay dato"— y no deben
 * contar como un cambio entre si: un `set(merge:false)` que deja de escribir
 * una clave opcional no es una edicion del taller.
 */
function normalizar(valor) {
  if (valor === undefined || valor === null) return '';
  if (typeof valor === 'string') return valor.trim();
  return valor;
}

/**
 * Etiquetas de los campos de identidad que cambiaron entre dos versiones del
 * documento de usuario, sin repetir (latitud y longitud comparten etiqueta).
 *
 * @param {object} antes documento `usuarios/{uid}` previo
 * @param {object} despues documento `usuarios/{uid}` resultante
 * @returns {string[]} etiquetas legibles, en orden estable
 */
function camposDeIdentidadCambiados(antes, despues) {
  const previo = antes || {};
  const actual = despues || {};
  const etiquetas = [];

  for (const campo of Object.keys(CAMPOS_DE_IDENTIDAD)) {
    if (normalizar(previo[campo]) === normalizar(actual[campo])) continue;
    const etiqueta = CAMPOS_DE_IDENTIDAD[campo];
    if (!etiquetas.includes(etiqueta)) etiquetas.push(etiqueta);
  }

  return etiquetas;
}

/**
 * Parche a aplicar sobre `verificaciones/{uid}` para reabrir el expediente.
 *
 * `fecha_envio` se pisa con la fecha de la reapertura a proposito: la bandeja
 * del administrador ordena por ese campo para atender primero a quien lleva
 * mas tiempo esperando, y un expediente reabierto que conservara la fecha de
 * su envio original —de hace meses— se colaria siempre en cabeza, por delante
 * de talleres que todavia no pueden operar. Cuando se envio la primera vez
 * sigue registrado en `fecha_revision` y en admin_logs.
 *
 * `revisado_por` y `fecha_revision` NO se tocan: son el rastro de quien aprobo
 * la version anterior, y es justo lo que el siguiente revisor quiere ver.
 *
 * @param {string} uid
 * @param {string[]} campos etiquetas de camposDeIdentidadCambiados
 * @param {*} fecha valor de fecha a escribir (Timestamp, Date o sentinel)
 */
function construirReapertura(uid, campos, fecha) {
  return {
    id_taller: uid,
    estado_verificacion: ESTADO_REABIERTA,
    fecha_envio: fecha,
    // Sin esto el administrador abre la bandeja, se encuentra ahi un taller
    // que el mismo aprobo la semana pasada y no tiene forma de saber que
    // mirar.
    reapertura: { fecha: fecha, campos: campos },
  };
}

/**
 * Reabre el expediente de `uid` si el taller cambio datos ya verificados.
 *
 * ## Por que esto vive en una Cloud Function y no en el cliente
 *
 * Es la unica forma de que sea obligatorio. Si la reapertura la disparase la
 * app al guardar el perfil, bastaria con escribir en Firestore sin pasar por
 * esa pantalla —o con una version modificada de la app— para cambiar nombre y
 * direccion despues de aprobado sin que nadie lo mirase otra vez. Aqui se
 * dispara desde el propio write, con SDK de Admin, y no hay camino que lo
 * esquive.
 *
 * ## Por que NO cierra la cuenta
 *
 * La reapertura mueve el expediente y deja `usuarios.estado` intacto: el
 * taller sigue operando y sigue en el directorio mientras se le vuelve a
 * mirar. La alternativa —suspender en cada edicion— convierte corregir una
 * errata en la direccion en quedarse fuera del directorio hasta que un
 * administrador tenga tiempo, lo que en la practica enseña a los talleres a no
 * corregir nunca sus datos: se cambia un riesgo por datos rancios, que es
 * peor.
 *
 * El riesgo residual es real y conviene decirlo: entre la edicion y la mirada
 * del administrador, los datos nuevos ESTAN publicados. Lo que garantiza el
 * sistema es que esa mirada ocurre siempre, y que un rechazo posterior cierra
 * la cuenta (`_resolver` en VerificacionService escribe 'rechazado').
 *
 * ## Limitacion conocida
 *
 * Solo vigila campos de texto. Un taller aprobado puede cambiar su logo por el
 * de una franquicia y suplantarla sin disparar nada, porque el texto dentro de
 * una imagen no se compara. Cubrirlo exigiria reabrir en cada cambio de foto
 * —muy caro para un escaparate que se toca a menudo— o revision de imagenes.
 * Queda como deuda consciente.
 *
 * @param {object} db instancia de Firestore (inyectable para tests)
 * @param {string} uid
 * @param {object} antes documento previo
 * @param {object} despues documento resultante
 * @param {*} [sello] valor de fecha a escribir; por defecto serverTimestamp
 * @returns {Promise<string[]|null>} campos que provocaron la reapertura, o
 *   null si no hubo nada que reabrir
 */
async function reabrirSiCambioLaIdentidad(db, uid, antes, despues, sello) {
  const campos = camposDeIdentidadCambiados(antes, despues);
  if (campos.length === 0) return null;

  const fecha =
    sello !== undefined
      ? sello
      : admin.firestore.FieldValue.serverTimestamp();
  const ref = db.collection('verificaciones').doc(uid);

  // En transaccion porque esto es una maquina de estados: sin ella, una
  // edicion que llegue en el mismo instante en que un administrador resuelve
  // el expediente podria reabrir sobre una lectura ya vieja.
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    // Un expediente que no existe, o que no esta aprobado, no se reabre: o
    // todavia no ha pasado por una revision, o ya esta en la cola. Forzarlo
    // seria sacar de 'perfil_incompleto' a un taller a medio rellenar.
    if (!snapshot.exists) return null;
    const datos = snapshot.data() || {};
    if (datos.estado_verificacion !== ESTADO_APROBADA) return null;

    tx.set(ref, construirReapertura(uid, campos, fecha), { merge: true });
    return campos;
  });
}

module.exports = {
  CAMPOS_DE_IDENTIDAD,
  ESTADO_APROBADA,
  ESTADO_REABIERTA,
  camposDeIdentidadCambiados,
  construirReapertura,
  reabrirSiCambioLaIdentidad,
};
