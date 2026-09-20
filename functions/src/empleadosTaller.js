'use strict';

/**
 * Alta de empleados cuyo correo YA tiene cuenta en AutoDoc.
 *
 * Observaciones del 2026-09-19, punto 4: «Al mecánico no le deja invitar a
 * una persona como mecánico». `crearEmpleadoTaller` solo sabía CREAR cuentas
 * nuevas: si el correo ya existía, respondía `already-exists` y la app lo
 * pintaba como «No se pudo completar la operación. Ese dato ya existe.», sin
 * decir qué dato ni qué hacer. Pasaba en los dos casos más comunes de la
 * vida real: la persona ya se había registrado en AutoDoc (como propietario)
 * o era un ex empleado del propio taller que se quería volver a dar de alta.
 *
 * Qué pasa ahora con un correo que ya tiene cuenta:
 *
 * - **Ex empleado de ESTE taller** que el propio taller desactivó: se
 *   reactiva. Si la cuenta la CREÓ el taller, con la contraseña temporal
 *   nueva; si entró por invitación, la cuenta es de esa persona y conserva
 *   SU contraseña — ponerle una el taller sería quedarse con ella.
 *   Una suspensión de administración no la levanta el taller.
 * - **Cuenta de propietario, o sin perfil todavía**: se le INVITA. Convertir
 *   la cuenta de otra persona en cuenta de taller sin que lo acepte sería
 *   quitársela, así que la invitación le llega a sus notificaciones y es ella
 *   quien acepta (`responderInvitacion`). Conserva su contraseña.
 * - **Empleado de otro taller, cuenta de taller o de administración**: no se
 *   puede, con un mensaje que no dice cuál de las tres es.
 *
 * `db` y `auth` se inyectan (mismo motivo que en `aceptarCotizacion.js`):
 * leer `admin.firestore`/`admin.auth` dispara `ensureApp()`.
 */

/** Fallo con un código de `HttpsError`; el callable lo traduce tal cual. */
class ErrorEmpleado extends Error {
  constructor(codigo, mensaje) {
    super(mensaje);
    this.codigo = codigo;
  }
}

/** Días que una invitación sigue vigente. */
const DIAS_INVITACION = 7;

/**
 * Invitaciones VIVAS (pendientes y sin caducar) que un taller puede tener a
 * la vez, y cuántas se miran al barrer.
 *
 * Lo que acota es el ENVÍO DE NOTIFICACIONES A TERCEROS: cada correo nuevo que
 * acierte con una cuenta verificada le manda un aviso a esa persona, y sin
 * cupo el alta de empleados servía de lista de difusión. NO acota el sondeo de
 * correos: `motivoCuentaNoIncorporable`, el `emailVerified` y la rama de
 * reactivación ocurren ANTES que esto, así que un taller con el cupo lleno
 * sigue pudiendo distinguir por el mensaje si un correo tiene cuenta. Veinte
 * es holgado para dar de alta a una plantilla y corto para difundir.
 *
 * El barrido mira hasta 60 y no hace falta más: el único creador es la
 * escritura de abajo, `responderInvitacion` borra el documento en todas sus
 * ramas y el taller puede retirarlas desde el cliente, así que todo documento
 * que existe está `pendiente` y tras un alta quedan `vivas + 1 <= 20`. Los 60
 * son holgura para la ventana de una ráfaga concurrente, y están muy por
 * debajo del tope de 500 escrituras de una transacción: no lo subas sin
 * mirar ese límite.
 */
const INVITACIONES_VIVAS_MAX = 20;
const INVITACIONES_BARRIDO_MAX = 60;

/** Espejo de `isMecanico()` (componente de rol) en firestore.rules. */
const ROLES_TALLER = ['Mecanico', 'Taller'];
/** Espejo de `isAdmin()` en firestore.rules. */
const ROLES_ADMIN = ['admin', 'Administrador', 'Superusuario'];
/** Espejo del `estado` que exige `isMecanico()`. */
const ESTADOS_APROBADOS = ['aprobado', 'activo'];

function etiquetaRol(rol) {
  return rol === 'Recepcionista' ? 'recepcionista' : 'mecánico';
}

function aMilisegundos(valor) {
  if (!valor) return 0;
  if (typeof valor.toMillis === 'function') return valor.toMillis();
  if (valor instanceof Date) return valor.getTime();
  if (typeof valor === 'number') return valor;
  return 0;
}

/**
 * ¿Por qué esta cuenta NO puede ser empleada de un taller? `null` si puede.
 *
 * @param {?object} perfil `usuarios/{uid}` de la cuenta, o `null` si no hay
 */
function motivoCuentaNoIncorporable(perfil) {
  if (!perfil) return null;
  // Un solo mensaje para los tres casos: distinguirlos le diría a cualquier
  // taller qué tipo de cuenta hay detrás de un correo (de otro taller, de
  // administración…) con solo probarlo.
  const noIncorporable =
    Boolean(perfil.id_taller_propietario) ||
    ROLES_TALLER.includes(perfil.rol) ||
    ROLES_ADMIN.includes(perfil.rol);
  return noIncorporable
    ? 'Ese correo ya pertenece a una cuenta que no puede unirse como ' +
        'empleado de tu taller.'
    : null;
}

/**
 * Da de alta como empleado un correo que YA tiene cuenta: reactiva a un ex
 * empleado del taller, o invita a la persona (ver arriba).
 *
 * @returns {Promise<{resultado: 'reactivado'|'invitado', idEmpleado: string}>}
 * @throws {ErrorEmpleado}
 */
async function incorporarCuentaExistente({
  db,
  auth,
  idTaller,
  nombreTaller,
  correo,
  nombreCompleto,
  telefono,
  rolEmpleado,
  password,
  ahora,
  escribirNotificacion,
}) {
  const cuenta = await auth.getUserByEmail(correo);
  const uid = cuenta.uid;
  if (uid === idTaller) {
    throw new ErrorEmpleado(
      'failed-precondition',
      'Ese es el correo de tu propia cuenta.'
    );
  }

  const perfilSnap = await db.collection('usuarios').doc(uid).get();
  const perfil = perfilSnap.exists ? perfilSnap.data() || {} : null;

  // Ex empleado de ESTE taller: se reactiva.
  if (perfil && perfil.id_taller_propietario === idTaller) {
    const activo = !cuenta.disabled && ESTADOS_APROBADOS.includes(perfil.estado);
    if (activo) {
      throw new ErrorEmpleado(
        'already-exists',
        `${perfil.nombre_completo || 'Esa persona'} ya es empleado de tu taller.`
      );
    }
    const empleadoRef = db
      .collection('talleres')
      .doc(idTaller)
      .collection('empleados')
      .doc(uid);
    const empleadoSnap = await empleadoRef.get();
    const empleado = empleadoSnap.exists ? empleadoSnap.data() || {} : null;
    // Solo se levanta lo que bajó el propio taller: `desactivarEmpleadoTaller`
    // deja `activo: false` en `empleados`, y una suspensión de administración
    // no toca ese documento.
    if (!empleado || empleado.activo !== false) {
      throw new ErrorEmpleado(
        'failed-precondition',
        'Esa cuenta está suspendida por administración: no puedes ' +
          'reactivarla desde aquí.'
      );
    }
    // Entró por invitación: la cuenta es de esa persona. Se reabre tal cual,
    // con SU contraseña; el taller no puede ponerle otra.
    const deInvitacion = empleado.origen === 'invitacion';
    await auth.updateUser(
      uid,
      deInvitacion
        ? { disabled: false }
        : { disabled: false, password, displayName: nombreCompleto }
    );
    const lote = db.batch();
    lote.set(
      db.collection('usuarios').doc(uid),
      deInvitacion
        ? { estado: 'activo', rol: 'Taller' }
        : { estado: 'activo', rol: 'Taller', nombre_completo: nombreCompleto },
      { merge: true }
    );
    lote.set(
      empleadoRef,
      Object.assign(
        {
          id_taller_propietario: idTaller,
          telefono: telefono || null,
          rol: rolEmpleado,
          activo: true,
          fecha_reactivacion: ahora,
        },
        deInvitacion ? {} : { nombre_completo: nombreCompleto, correo }
      ),
      { merge: true }
    );
    await lote.commit();
    return {
      resultado: deInvitacion ? 'reactivado_con_su_contrasena' : 'reactivado',
      idEmpleado: uid,
    };
  }

  const motivo = motivoCuentaNoIncorporable(perfil);
  if (motivo) throw new ErrorEmpleado('already-exists', motivo);

  // Sin correo verificado no se sabe si la cuenta es de verdad de quien el
  // taller quiere invitar: invitarla le enseñaría a un impostor el teléfono y
  // el nombre que el taller tecleó (la app ya exige verificar para entrar).
  if (!cuenta.emailVerified) {
    throw new ErrorEmpleado(
      'failed-precondition',
      'Ese correo tiene una cuenta sin verificar. Pídele a esa persona que ' +
        'entre a AutoDoc y verifique su correo, y vuelve a intentarlo.'
    );
  }

  // Cuenta de propietario (o sin perfil todavía): se le invita. Si ya tiene
  // una invitación de este taller viva, no se reescribe ni se le vuelve a
  // avisar: repetir el alta no puede servir para llenarle de notificaciones.
  //
  // Todo va en UNA transacción, y lo pidió la revisión de gate:
  //  - contar fuera y escribir después dejaba el cupo en «20 por ronda
  //    secuencial»; N altas simultáneas leen todas `vivas = 0` y las N
  //    escriben, que es justo la ráfaga que el cupo viene a impedir.
  //  - el borrado de una caducada sin precondición podía llevarse por delante
  //    una invitación que otra llamada acababa de renovar: la persona se
  //    quedaba con un aviso que al abrirlo decía «ya no está disponible».
  const invitacionesRef = db
    .collection('talleres')
    .doc(idTaller)
    .collection('invitaciones');
  const invitacionRef = invitacionesRef.doc(uid);

  const hayQueAvisar = await db.runTransaction(async (tx) => {
    const previa = await tx.get(invitacionRef);
    const previaDatos = previa.exists ? previa.data() || {} : null;
    if (
      previaDatos &&
      previaDatos.estado === 'pendiente' &&
      aMilisegundos(previaDatos.expira) > ahora.getTime()
    ) {
      return false;
    }

    // Cupo por taller, y de paso barrido de las caducadas: nadie las borraba
    // (la pantalla del taller solo las escondía), así que sin esto bastaba
    // con esperar a que caducaran para seguir invitando sin límite.
    const abiertas = await tx.get(invitacionesRef.limit(INVITACIONES_BARRIDO_MAX));
    const aBorrar = [];
    let vivas = 0;
    for (const snap of abiertas.docs) {
      // La propia se reescribe al final de esta misma transacción.
      if (snap.id === uid) continue;
      const datos = snap.data() || {};
      // Lo que no sea una invitación pendiente no se toca: el barrido borra,
      // y borrar por no reconocer un documento es la forma cara de
      // equivocarse.
      if (datos.estado !== 'pendiente') continue;
      const expira = aMilisegundos(datos.expira);
      if (expira === 0) {
        // `aMilisegundos` devuelve 0 cuando falta el campo o no es una fecha
        // (una cadena ISO, por ejemplo). Eso NO es «caducada»: se deja
        // quieta y se cuenta, porque una atascada se ve y se arregla y una
        // viva borrada en silencio no. Es el mismo defecto que GAPS-06
        // documenta con `fecha_limite` en cadena.
        console.warn(
          `invitaciones: ${idTaller}/${snap.id} tiene un 'expira' ilegible; ` +
            'no se barre.'
        );
        vivas += 1;
        continue;
      }
      if (expira <= ahora.getTime()) aBorrar.push(snap.ref);
      else vivas += 1;
    }

    if (vivas >= INVITACIONES_VIVAS_MAX) {
      throw new ErrorEmpleado(
        'resource-exhausted',
        `Tu taller tiene ${vivas} invitaciones sin responder. Espera a que ` +
          'las contesten o retira alguna antes de invitar a más personas.'
      );
    }

    for (const ref of aBorrar) tx.delete(ref);
    tx.set(invitacionRef, {
      id_taller: idTaller,
      id_invitado: uid,
      nombre_taller: nombreTaller,
      // El nombre que tecleó el taller, NUNCA el del perfil: el taller lee
      // sus invitaciones, y con el del perfil bastaría escribir un correo
      // cualquiera para averiguar cómo se llama su dueño.
      nombre_completo: nombreCompleto,
      correo,
      telefono: telefono || null,
      rol: rolEmpleado,
      estado: 'pendiente',
      fecha_creacion: ahora,
      expira: new Date(ahora.getTime() + DIAS_INVITACION * 86400000),
    });
    return true;
  });

  if (!hayQueAvisar) return { resultado: 'invitado', idEmpleado: uid };

  await escribirNotificacion(uid, {
    tipo: 'invitacion_empleo',
    titulo: 'Te invitaron a trabajar en un taller',
    body:
      `${nombreTaller} te invitó a unirte a su taller como ` +
      `${etiquetaRol(rolEmpleado)}. Acepta o rechaza la invitación aquí.`,
    deepLink: '/notifications',
    metadata: { id_taller: idTaller, nombre_taller: nombreTaller, rol: rolEmpleado },
  });
  return { resultado: 'invitado', idEmpleado: uid };
}

/**
 * La persona invitada acepta o rechaza la invitación de un taller.
 *
 * Aceptar convierte SU cuenta en cuenta de empleado de ese taller. Por eso
 * todo se vuelve a comprobar aquí, en el momento de aceptar: que la
 * invitación siga viva, que el taller siga pudiendo tener empleados, que la
 * cuenta no se haya vuelto de taller mientras tanto y que no tenga
 * vehículos — una cuenta de taller no ve sus vehículos, así que aceptar le
 * quitaría el acceso a ellos.
 *
 * @returns {Promise<{resultado: 'aceptada'|'rechazada'}>}
 * @throws {ErrorEmpleado}
 */
async function responderInvitacion({
  db,
  auth,
  uid,
  idTaller,
  aceptar,
  ahora,
  escribirNotificacion,
}) {
  const ref = db
    .collection('talleres')
    .doc(idTaller)
    .collection('invitaciones')
    .doc(uid);
  const snap = await ref.get();
  const invitacion = snap.exists ? snap.data() || {} : null;
  if (!invitacion || invitacion.estado !== 'pendiente') {
    throw new ErrorEmpleado(
      'failed-precondition',
      'Esta invitación ya no está disponible.'
    );
  }
  const nombre = invitacion.nombre_completo || 'La persona invitada';
  const caducada = aMilisegundos(invitacion.expira) <= ahora.getTime();

  // Rechazar una caducada es lo mismo que rechazarla a tiempo: se limpia, sin
  // error. Solo aceptar exige que siga viva.
  if (caducada && aceptar) {
    await ref.delete();
    throw new ErrorEmpleado(
      'failed-precondition',
      'La invitación caducó. Pídele al taller que te invite de nuevo.'
    );
  }

  if (!aceptar) {
    await ref.delete();
    await escribirNotificacion(idTaller, {
      tipo: 'invitacion_empleo_respuesta',
      titulo: 'Invitación rechazada',
      body: `${nombre} rechazó tu invitación para unirse al taller.`,
      deepLink: '/mechanic/empleados',
      metadata: { id_invitado: uid },
    });
    return { resultado: 'rechazada' };
  }

  // Quien acepta tiene que ser de verdad el dueño del correo invitado: sin
  // esto, una cuenta registrada con el correo de otra persona (y nunca
  // verificada) podía quedarse con el puesto que el taller le ofrecía a ella.
  const cuenta = await auth.getUser(uid);
  if (!cuenta.emailVerified) {
    throw new ErrorEmpleado(
      'failed-precondition',
      'Verifica tu correo antes de aceptar la invitación.'
    );
  }

  const tallerSnap = await db.collection('usuarios').doc(idTaller).get();
  const taller = tallerSnap.exists ? tallerSnap.data() || {} : null;
  const tallerValido =
    taller &&
    ROLES_TALLER.includes(taller.rol) &&
    !taller.id_taller_propietario &&
    ESTADOS_APROBADOS.includes(taller.estado);
  if (!tallerValido) {
    await ref.delete();
    throw new ErrorEmpleado(
      'failed-precondition',
      'El taller que te invitó ya no puede sumar empleados.'
    );
  }

  const perfilSnap = await db.collection('usuarios').doc(uid).get();
  const perfil = perfilSnap.exists ? perfilSnap.data() || {} : null;
  const motivo = motivoCuentaNoIncorporable(perfil);
  if (motivo) {
    await ref.delete();
    throw new ErrorEmpleado(
      'failed-precondition',
      'Tu cuenta ya es de un taller o de administración: no puede unirse ' +
        'como empleado.'
    );
  }

  const vehiculos = await db
    .collection('vehiculos')
    .where('id_propietario', '==', uid)
    .limit(1)
    .get();
  if (!vehiculos.empty) {
    throw new ErrorEmpleado(
      'failed-precondition',
      'Tu cuenta tiene vehículos registrados, y una cuenta de taller no puede ' +
        'verlos. Para trabajar en el taller usa otro correo, o elimina antes ' +
        'tus vehículos.'
    );
  }

  // La escritura va en una transacción que VUELVE a leer la invitación y el
  // perfil: entre las comprobaciones de arriba y aquí el taller pudo retirar
  // la invitación, o la persona aceptar la de OTRO taller (dos pestañas, doble
  // toque). Sin releer, las dos aceptaciones pasaban y la cuenta quedaba en
  // `empleados` de dos talleres; y borrar una invitación que ya no existe no
  // falla, así que una retirada no impedía entrar.
  const usuarioRef = db.collection('usuarios').doc(uid);
  const empleadoRef = db
    .collection('talleres')
    .doc(idTaller)
    .collection('empleados')
    .doc(uid);
  const nombreCompleto = await db.runTransaction(async (tx) => {
    const [invSnap, perfilActualSnap] = [
      await tx.get(ref),
      await tx.get(usuarioRef),
    ];
    const inv = invSnap.exists ? invSnap.data() || {} : null;
    if (!inv || inv.estado !== 'pendiente') {
      throw new ErrorEmpleado(
        'failed-precondition',
        'Esta invitación ya no está disponible.'
      );
    }
    const perfilActual = perfilActualSnap.exists
      ? perfilActualSnap.data() || {}
      : null;
    if (motivoCuentaNoIncorporable(perfilActual)) {
      throw new ErrorEmpleado(
        'failed-precondition',
        'Tu cuenta ya es de un taller o de administración: no puede unirse ' +
          'como empleado.'
      );
    }

    const nombreFinal = (perfilActual && perfilActual.nombre_completo) || nombre;
    const correoFinal = inv.correo || cuenta.email || '';
    tx.set(
      usuarioRef,
      Object.assign(
        {
          id_usuario: uid,
          nombre_completo: nombreFinal,
          correo: correoFinal,
          rol: 'Taller',
          id_taller_propietario: idTaller,
          estado: 'activo',
        },
        perfilActual ? {} : { fecha_registro: ahora }
      ),
      { merge: true }
    );
    tx.set(empleadoRef, {
      id_taller_propietario: idTaller,
      nombre_completo: nombreFinal,
      correo: correoFinal,
      telefono: inv.telefono || null,
      rol: inv.rol || 'Mecanico',
      activo: true,
      fecha_creacion: ahora,
      // La cuenta es de la persona: si el taller la desactiva y la vuelve a
      // dar de alta, se reabre con SU contraseña (ver arriba).
      origen: 'invitacion',
    });
    // CONVENTIONS: todo cambio de rol deja rastro en `admin_logs`.
    tx.set(db.collection('admin_logs').doc(), {
      admin_uid: 'sistema',
      accion: 'cambio_rol_por_invitacion',
      modulo: 'empleados',
      referencia_id: uid,
      detalle:
        `${(perfilActual && perfilActual.rol) || 'Sin perfil'} -> Taller: ` +
        `aceptó la invitación del taller ${idTaller}.`,
      fecha: ahora,
    });
    tx.delete(ref);
    return nombreFinal;
  });

  await escribirNotificacion(idTaller, {
    tipo: 'invitacion_empleo_respuesta',
    titulo: 'Invitación aceptada',
    body: `${nombreCompleto} aceptó tu invitación: ya es parte de tu taller.`,
    deepLink: '/mechanic/empleados',
    metadata: { id_invitado: uid },
  });
  return { resultado: 'aceptada' };
}

module.exports = {
  ErrorEmpleado,
  DIAS_INVITACION,
  motivoCuentaNoIncorporable,
  incorporarCuentaExistente,
  responderInvitacion,
};
