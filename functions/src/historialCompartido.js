'use strict';

const crypto = require('crypto');

/**
 * INNO-01 — pase temporal de historial por QR.
 *
 * **Que resuelve.** Vender un coche usado obliga hoy a fiarse de la palabra
 * del vendedor sobre su mantenimiento. AutoDoc ya tiene ese historial; lo que
 * faltaba era una forma de ENSENARLO a alguien que no tiene relacion con el
 * vehiculo, sin darle acceso permanente ni obligarle a nada. El propietario
 * genera un QR que caduca; quien lo escanea ve QUE se hizo y CUANDO.
 *
 * **Por que un callable y no reglas de Firestore.** Una regla no puede recibir
 * un parametro: para autorizar con un token habria que meterlo en la ruta o en
 * los claims, y entonces el token deja rastro en cada lectura del cliente y se
 * vuelve enumerable. Aqui el token se valida server-side con Admin SDK y
 * `tokens_historial` queda cerrada a TODO cliente en `firestore.rules` — no se
 * puede leer, listar ni escribir desde la app. Esa es la parte que las reglas
 * si hacen, y es la que impide barrer la coleccion en busca de tokens vivos.
 *
 * **Tres decisiones que conviene no deshacer sin pensarlo:**
 *
 * 1. **El vencimiento se mide contra el reloj del servidor.** El llamante no
 *    aporta la hora en ningun punto de esta API. Si la aportara, el
 *    vencimiento seria decorativo.
 * 2. **La proyeccion es allowlist y deja fuera el dinero.** Quien escanea ve
 *    tipo de servicio, fecha, kilometraje y descripcion. No ve `costo`, ni
 *    `mano_de_obra`, ni `materiales`, ni `foto_factura_url` — una factura es
 *    un documento financiero del propietario, y un comprador no necesita
 *    saber lo que se pago para comprobar que el mantenimiento se hizo. Al ser
 *    allowlist, un campo que se agregue manana a `servicios` queda fuera por
 *    construccion y no por acordarse de excluirlo.
 * 3. **`shared_with` no alcanza para emitir.** Compartir la ficha es dar
 *    lectura a alguien concreto; emitir un pase que abre el historial a
 *    cualquiera que vea un QR es una decision distinta, y es del propietario.
 *
 * `db` se inyecta, como en `aceptarCotizacion.js` y `obtenerPerfilPublico.js`:
 * leer `admin.firestore()` aqui dentro dispara `ensureApp()` y vuelve hostil
 * el stub desde tests sin emulador.
 */

/** Minutos que vive un pase. Corto a proposito: se ensena en persona. */
const VIGENCIA_MINUTOS = 15;

/** Tope de servicios que devuelve un pase. Cota explicita, no confianza. */
const MAX_SERVICIOS = 100;

/**
 * Canjes que admite un pase antes de agotarse.
 *
 * Cada canje cuesta hasta `MAX_SERVICIOS + 2` lecturas. Sin tope, un QR
 * fotografiado es un amplificador de ~102x sobre la cuota de Firestore durante
 * toda la ventana de vigencia, y App Check no lo frena porque su modo por
 * defecto es `monitor` (decision de SEC-04). La caducidad acota la VENTANA; el
 * contador acota el VOLUMEN dentro de ella. Hacen falta las dos.
 *
 * 20 deja margen de sobra para el uso real —ensenar el coche a varias
 * personas, recargar la pantalla— sin dejar la puerta abierta a un bucle.
 */
const MAX_CANJES = 20;

/**
 * Margen entre que un pase caduca y que el TTL lo borra.
 *
 * No es cosmetico. Si el TTL borrara justo al vencer, un pase caducado pasaria
 * de responder "el pase ya caduco" (`deadline-exceeded`) a "no existe"
 * (`not-found`), que es un mensaje peor y distinto. Ningun test puede verlo:
 * el emulador no ejecuta politicas TTL.
 */
const MARGEN_PURGA_MS = 48 * 60 * 60 * 1000;

/**
 * Cuantos pases se miran al buscar uno reutilizable.
 *
 * No es el numero de pases que puede haber, es el coste que se acepta pagar
 * por la busqueda. Con la reutilizacion puesta, lo normal es que haya 0 o 1
 * por vehiculo; los demas serian revocados o caducados de las ultimas 48 h
 * (lo que tarda el TTL en purgarlos). Si no cabe ninguno vivo en la ventana,
 * se acuna uno nuevo — o sea se degrada al comportamiento anterior, nunca a un
 * fallo.
 */
const MAX_PASES_INSPECCIONADOS = 10;

/** Centinela que `firestore.rules:729` exige para un servicio del propietario. */
const TALLER_MANUAL = 'Manual (Propietario)';

/**
 * Un token es siempre 64 hex (32 bytes). Validarlo antes de tocar Firestore
 * evita que `.doc('a/b')` lance un Error corriente del Admin SDK por numero de
 * segmentos, que saldria al cliente como `internal` en vez de como una
 * denegacion limpia.
 */
const FORMA_TOKEN = /^[0-9a-f]{64}$/;

/**
 * Subconjunto de un documento de `servicios` que ve quien escanea el QR.
 *
 * ALLOWLIST. Ver la decision 2 de la cabecera.
 *
 * **`auto_declarado` es el campo que hace honesta a esta funcionalidad.**
 * `firestore.rules:728-729` autoriza al propietario a crear servicios sobre su
 * propio vehiculo con `id_taller == 'Manual (Propietario)'`. Es una regla
 * correcta: nadie puede prohibir el mantenimiento propio, y registrarlo tiene
 * valor. Pero significa que un vendedor puede escribirse diez servicios
 * inventados y ensenar el QR.
 *
 * Sin esta bandera, esos diez llegan al comprador **indistinguibles** de los
 * que registro un taller, con el sello de AutoDoc encima — o sea, lo contrario
 * exacto de lo que la cabecera de este modulo dice que la funcionalidad evita.
 * Lo detecto el gate de revision de reglas; el diseno original omitia
 * `id_taller` "por minimalismo" y con eso se llevaba por delante la premisa.
 *
 * Ante la ausencia de `id_taller` se marca como auto-declarado: fail-safe
 * hacia la etiqueta que NO otorga confianza.
 *
 * @param {object} data documento de `servicios`
 */
function proyeccionServicioCompartido(data) {
  const d = data || {};
  const idTaller = typeof d.id_taller === 'string' ? d.id_taller : null;
  return {
    tipo_servicio: d.tipo_servicio || null,
    fecha: normalizarFecha(d.fecha),
    kilometraje_servicio: d.kilometraje_servicio || null,
    descripcion: d.descripcion || null,
    id_taller: idTaller,
    auto_declarado: idTaller === null || idTaller === TALLER_MANUAL,
  };
}

/**
 * `servicios.fecha` es un Timestamp, y el Admin SDK lo serializa como
 * `{_seconds,_nanoseconds}` al cruzar el callable — no como ISO ni como
 * numero. Normalizar aqui, y no en el cliente, porque este es el unico punto
 * que conoce la forma de origen.
 */
function normalizarFecha(f) {
  if (f === null || f === undefined) return null;
  if (typeof f === 'number') return f;
  if (typeof f.toMillis === 'function') return f.toMillis();
  if (typeof f._seconds === 'number') return f._seconds * 1000;
  if (f instanceof Date) return f.getTime();
  return null;
}

/**
 * Error con la forma que `functions.https.HttpsError` espera en el
 * entrypoint. Se lanza como `Error` con el codigo en el mensaje para que este
 * modulo siga siendo probable sin cargar firebase-functions.
 */
function fallo(codigo, mensaje) {
  const e = new Error(`${codigo}: ${mensaje}`);
  e.codigo = codigo;
  return e;
}

/** Token opaco de 256 bits. No es un id de Firestore: no se enumera. */
function generarTokenAleatorio() {
  return crypto.randomBytes(32).toString('hex');
}

/**
 * Emite un pase temporal para el historial de un vehiculo.
 *
 * @param {object} args
 * @param {object} args.db Firestore (inyectado)
 * @param {string} args.uid quien llama
 * @param {string} args.idVehiculo vehiculo cuyo historial se comparte
 * @param {number} args.ahora epoch ms del SERVIDOR
 * @param {function} [args.generarId] solo para pruebas deterministas
 */
async function crearTokenHistorial({ db, uid, idVehiculo, ahora, generarId }) {
  if (!uid) throw fallo('unauthenticated', 'Debes iniciar sesion.');
  if (!idVehiculo) {
    throw fallo('invalid-argument', 'Debes indicar el vehiculo.');
  }

  const vehiculo = await db.collection('vehiculos').doc(idVehiculo).get();
  if (!vehiculo.exists) {
    throw fallo('not-found', 'El vehiculo no existe.');
  }

  // Solo el propietario. Ver la decision 3 de la cabecera: `shared_with` no
  // se consulta aqui a proposito.
  if (vehiculo.data().id_propietario !== uid) {
    throw fallo(
      'permission-denied',
      'Solo el propietario puede compartir el historial de su vehiculo.',
    );
  }

  // GAPS-05 — se REUTILIZA el pase vivo de este vehiculo en vez de acunar otro.
  // Cierra los gaps 1 y 2 de INNO-01 con el mismo cambio:
  //
  //   - La pantalla emite al abrirse, asi que cada visita escribia un
  //     documento: entrar y salir en bucle no tenia tope ninguno (gap 2).
  //   - El boton de revocar solo existe en la pantalla que emitio ESE pase, asi
  //     que salir de ella dejaba el pase vivo y sin ninguna via para anularlo
  //     (gap 1). Devolviendo el mismo, volver a la pantalla vuelve a poner el
  //     boton delante.
  //
  // La consulta es de IGUALDADES PURAS a proposito —sin `orderBy` y sin
  // rango—: Firestore sirve eso con los indices automaticos, asi que no anade
  // ningun indice compuesto que desplegar. El vencimiento y el cupo se
  // comprueban aqui, sobre los pocos documentos que quedan tras el filtro.
  //
  // El `limit` acota el coste; si por lo que sea hubiera mas pases de los que
  // caben, lo peor que pasa es que se acune uno nuevo, que es el
  // comportamiento anterior.
  const vivos = await db
    .collection('tokens_historial')
    .where('id_vehiculo', '==', idVehiculo)
    .where('id_propietario', '==', uid)
    .where('revocado', '==', false)
    .limit(MAX_PASES_INSPECCIONADOS)
    .get();

  for (const doc of vivos.docs) {
    const t = doc.data();
    // Las tres condiciones que hacen util un pase. Devolver uno agotado o
    // caducado seria peor que no reutilizar nada: la pantalla pintaria un QR
    // que solo puede fallar.
    const vigente = typeof t.expira_en === 'number' && ahora <= t.expira_en;
    const conCupo = (typeof t.canjes === 'number' ? t.canjes : 0) < MAX_CANJES;
    if (vigente && conCupo) {
      // NO se renueva `expira_en`: refrescarlo al reutilizar convertiria
      // reabrir la pantalla en una forma de extender el pase indefinidamente,
      // que es justo lo que la vigencia corta viene a impedir.
      return {
        token: doc.id,
        expira_en: t.expira_en,
        vigencia_minutos: VIGENCIA_MINUTOS,
      };
    }
  }

  const token = (generarId || generarTokenAleatorio)();
  const expiraEn = ahora + VIGENCIA_MINUTOS * 60 * 1000;

  await db.collection('tokens_historial').doc(token).set({
    id_vehiculo: idVehiculo,
    id_propietario: uid,
    creado_en: ahora,
    // Epoch ms: es lo que `leerHistorialPorToken` compara con `Date.now()`.
    expira_en: expiraEn,
    // Date, NO milisegundos. La politica TTL de Firestore solo borra por un
    // campo Timestamp; con un numero la politica se crea y no borra nada
    // nunca, y esta coleccion —que guarda {id_vehiculo, id_propietario}, o sea
    // un mapa de quien tiene que coche— creceria para siempre sin que nadie la
    // auditase, porque nadie puede leerla. `solicitudesLanding.js:210-213` ya
    // dejo escrito este mismo precedente en este repo.
    purgar_en: new Date(expiraEn + MARGEN_PURGA_MS),
    revocado: false,
    canjes: 0,
  });

  return { token, expira_en: expiraEn, vigencia_minutos: VIGENCIA_MINUTOS };
}

/**
 * Canjea un pase y devuelve el historial minimo del vehiculo.
 *
 * Cualquier cuenta autenticada con un token valido puede leer: ese es el
 * sentido de la funcionalidad. Lo que acota el riesgo no es quien llama, sino
 * que el token caduca, se puede revocar, es opaco de 256 bits y la proyeccion
 * deja fuera lo sensible.
 */
async function leerHistorialPorToken({ db, uid, token, ahora }) {
  if (!uid) throw fallo('unauthenticated', 'Debes iniciar sesion.');
  if (!token) throw fallo('invalid-argument', 'Debes indicar el pase.');
  if (!FORMA_TOKEN.test(String(token))) {
    throw fallo('invalid-argument', 'El pase no tiene una forma valida.');
  }

  const ref = db.collection('tokens_historial').doc(String(token));
  const doc = await ref.get();
  if (!doc.exists) {
    throw fallo('not-found', 'El pase no existe o ya caduco.');
  }

  const t = doc.data();

  if (t.revocado === true) {
    throw fallo('permission-denied', 'El pase fue revocado.');
  }

  // Reloj del servidor. Ver la decision 1 de la cabecera.
  // El `typeof` no es defensivo de mas: sin el, un documento sin `expira_en`
  // daria `ahora > undefined` === false, o sea un pase ETERNO.
  if (typeof t.expira_en !== 'number' || ahora > t.expira_en) {
    throw fallo('deadline-exceeded', 'El pase ya caduco.');
  }

  // Tope de volumen. Ver `MAX_CANJES`.
  const canjes = typeof t.canjes === 'number' ? t.canjes : 0;
  if (canjes >= MAX_CANJES) {
    throw fallo('resource-exhausted', 'El pase ya se uso demasiadas veces.');
  }

  const vehiculo = await db.collection('vehiculos').doc(t.id_vehiculo).get();
  if (!vehiculo.exists) {
    throw fallo('not-found', 'El vehiculo ya no existe.');
  }
  const v = vehiculo.data();

  const servicios = await db
    .collection('servicios')
    .where('id_vehiculo', '==', t.id_vehiculo)
    .orderBy('fecha', 'desc')
    .limit(MAX_SERVICIOS)
    .get();

  // Se contabiliza DESPUES de servir: si la lectura falla, el canje no se
  // gasta. No hace falta transaccion — esto es un tope de coste, no un
  // contador contable, y serializarlo costaria mas de lo que protege.
  await ref.update({ canjes: canjes + 1 });

  return {
    placa: v.placa || null,
    marca: v.marca || null,
    modelo: v.modelo || null,
    anio: v.anio || null,
    kilometraje_actual: v.kilometraje_actual || 0,
    expira_en: t.expira_en,
    servicios: servicios.docs.map((d) => proyeccionServicioCompartido(d.data())),
  };
}

/**
 * Revoca un pase antes de que caduque. Solo el emisor.
 *
 * **Marca en vez de borrar, y la razon es esta y no otra:** el documento tiene
 * que seguir existiendo hasta que el TTL lo purgue, porque es lo unico que
 * impide que el pase reviva. Si se borrase, el `expira_en` se iria con el, y
 * quedaria un token de 64 hex sin documento — indistinguible de uno nunca
 * emitido, lo cual esta bien, pero tambien sin rastro para el emisor.
 *
 * (Una version anterior de este comentario decia que marcar hacia
 * indistinguibles el borrado y el token inexistente. Era falso: `leerHistorial`
 * distingue los tres casos con codigos distintos —`not-found`,
 * `permission-denied`, `deadline-exceeded`—. Se deja dicho porque en este repo
 * una razon escrita que no se cumple es justo lo que hace que la ronda
 * siguiente "arregle" el lado que ya estaba bien.)
 */
async function revocarTokenHistorial({ db, uid, token }) {
  if (!uid) throw fallo('unauthenticated', 'Debes iniciar sesion.');
  if (!token) throw fallo('invalid-argument', 'Debes indicar el pase.');
  // Misma validacion que al canjear, y por el mismo motivo: `.doc('a/b')`
  // lanza un Error del SDK que saldria como `internal`.
  if (!FORMA_TOKEN.test(String(token))) {
    throw fallo('invalid-argument', 'El pase no tiene una forma valida.');
  }

  const ref = db.collection('tokens_historial').doc(String(token));
  const doc = await ref.get();
  if (!doc.exists) {
    throw fallo('not-found', 'El pase no existe.');
  }
  if (doc.data().id_propietario !== uid) {
    throw fallo('permission-denied', 'Solo quien emitio el pase puede revocarlo.');
  }

  await ref.update({ revocado: true });
}

module.exports = {
  VIGENCIA_MINUTOS,
  MAX_SERVICIOS,
  MAX_CANJES,
  MARGEN_PURGA_MS,
  TALLER_MANUAL,
  proyeccionServicioCompartido,
  crearTokenHistorial,
  leerHistorialPorToken,
  revocarTokenHistorial,
};
