'use strict';

/**
 * Fase 1 del asistente de agenda — `docs/superpowers/plans/2026-09-19-asistente-de-agenda-ia.md`.
 *
 * Construye el **envelope**: la lista de compromisos proximos de un usuario,
 * ya autorizada y ya calculada. Aqui NO entra la IA. El modelo que redacta la
 * respuesta recibe la salida de esta funcion y nada mas; no elige que leer, no
 * ve un uid, y no resta fechas.
 *
 * Cinco invariantes, cada una con la cicatriz que la justifica:
 *
 * 1. **Toda la aritmetica de fechas ocurre aqui, en JS.** El envelope lleva
 *    `dias_restantes` como entero. Un LLM que reste fechas se equivoca, y aqui
 *    equivocarse significa que alguien conduce con el SOAT vencido.
 *
 * 2. **El mantenimiento viaja en kilometros, jamas en dias.** El cliente
 *    fabrica `fechaLimite: DateTime.now().add(Duration(days: 15))` con el
 *    comentario «Aproximado para la UI» (`alert_provider.dart`). Es relleno
 *    para ordenar una lista, no un dato. Dado a un modelo se convierte en «tu
 *    cambio de aceite vence el 4 de octubre», afirmado como un hecho.
 *
 * 3. **Nada de `AlertModel`.** Ese modelo tiene una ventana de 15 dias
 *    horneada dentro y tres recordatorios incondicionales sin fecha. Se lee de
 *    los campos crudos de `vehiculos`, `reservas` y `mantenimientos` — que es
 *    ademas lo que hace aparecer `vencimiento_tarjeta`, hoy invisible en toda
 *    la app pese a que el usuario lo teclea a mano.
 *
 * 4. **`ahora` se inyecta.** Sin eso ningun test puede afirmar sobre un
 *    vencimiento (la cicatriz del reloj de INNO-01).
 *
 * 5. **El dia es el dia LOCAL.** El barrido de citas de OPS-01 calculaba
 *    «manana» en UTC y descolocaba las citas de tarde: Colombia es UTC-5 y una
 *    cita a las 20:00 de Bogota es 01:00Z del dia siguiente.
 *
 * **Autorizacion.** Esta funcion la ejecuta un callable con Admin SDK, donde
 * `firestore.rules` NO aplica — la leccion de `iniciarReparacionPorVehiculo`
 * (FUNC-02). Por eso reimplementa a mano los dos predicados de las reglas que
 * deciden quien ve que: `isMecanico()` (estado aprobado/activo, con el mismo
 * default defensivo `pendiente`) y `actuaPorTaller()` (el empleado actua por
 * su taller). Ver `functions/test/agenda.test.js`.
 */

/**
 * Colombia es UTC-5 el ano entero: no tiene horario de verano desde 1993. Es
 * el mismo desfase fijo que usa `recordatoriosReserva.js`, y vale por el mismo
 * motivo — y deja de valer por el mismo: el dia que haya usuarios fuera de
 * Colombia hay que resolver la zona por documento.
 */
const DESFASE_MINUTOS_BOGOTA = -300;

/** Ventana por defecto. Cubre el mes vista sin arrastrar la historia entera. */
const VENTANA_DIAS_POR_DEFECTO = 30;

/**
 * Un mantenimiento entra en la agenda cuando le faltan menos de estos km.
 * Es el mismo umbral que `MaintenanceTask.getStatus` ya usa en el cliente para
 * llamar «preventivo» a una tarea: no se inventa un criterio nuevo, se respeta
 * el que la app ya le ensena al usuario.
 */
const UMBRAL_KM_MANTENIMIENTO = 500;

/**
 * Cotas de lectura. Van en el servidor a proposito: el panel del mecanico ya
 * ensenio lo que cuesta un stream sin tope, y un barrido sin cota lee la
 * historia entera del proyecto cada vez.
 */
const LIMITE_VEHICULOS = 25;
const LIMITE_CITAS = 50;

/**
 * Tareas de mantenimiento que se miran por vehiculo. El catalogo que siembra
 * `seed_tareas_mantenimiento.js` son 9; 15 deja hueco para tareas propias sin
 * que un vehiculo con historial duplicado se lleve la cota entera.
 */
const MAX_TAREAS_POR_VEHICULO = 15;

/** `in` admite 30 valores por consulta; se trocea por debajo. */
const TAMANO_LOTE_IN = 10;

const MS_POR_DIA = 24 * 60 * 60 * 1000;

const ESTADOS_TALLER_ACTIVO = ['aprobado', 'activo'];
const ROLES_DE_TALLER = ['Mecanico', 'Taller'];

/** Acepta Timestamp de Firestore, Date o ISO; devuelve Date o null. */
function aFecha(valor) {
  if (!valor) return null;
  if (typeof valor.toDate === 'function') return valor.toDate();
  if (valor instanceof Date) return valor;
  if (typeof valor === 'string') {
    const d = new Date(valor);
    return isNaN(d.getTime()) ? null : d;
  }
  return null;
}

/** Instante desplazado a hora local, para poder leerlo con los getters UTC. */
function enLocal(fecha, desfaseMinutos) {
  return new Date(fecha.getTime() + desfaseMinutos * 60000);
}

/** Indice de dia de calendario local. */
function diaLocal(fecha, desfaseMinutos) {
  return Math.floor(enLocal(fecha, desfaseMinutos).getTime() / MS_POR_DIA);
}

/**
 * Dias de CALENDARIO local entre dos instantes, no divisiones de 24 h.
 *
 * La diferencia importa: 23:00 y 00:30 estan a 90 minutos y son dias
 * distintos, mientras que 00:30 y 23:00 del mismo dia estan a 22 horas y son
 * el mismo. Un usuario que pregunta «cuantos dias me quedan» pregunta por lo
 * primero.
 *
 * @param {Date} desde
 * @param {Date} hasta
 * @param {number} [desfaseMinutos]
 * @returns {number}
 */
function diasLocalesEntre(desde, hasta, desfaseMinutos = DESFASE_MINUTOS_BOGOTA) {
  return diaLocal(hasta, desfaseMinutos) - diaLocal(desde, desfaseMinutos);
}

/** Medianoche local del dia de `ahora`, expresada en UTC. */
function inicioDelDiaLocal(ahora, desfaseMinutos) {
  return new Date(diaLocal(ahora, desfaseMinutos) * MS_POR_DIA - desfaseMinutos * 60000);
}

/** `HH:MM` en hora local. */
function horaLocal(fecha, desfaseMinutos) {
  const local = enLocal(fecha, desfaseMinutos);
  const dos = (n) => String(n).padStart(2, '0');
  return dos(local.getUTCHours()) + ':' + dos(local.getUTCMinutes());
}

/**
 * Recorta un texto que escribio una persona antes de dejarlo entrar al
 * envelope.
 *
 * **La defensa de verdad no es esta funcion: es la lista blanca de campos.**
 * Al envelope solo entran los campos que se nombran explicitamente mas abajo,
 * asi que `descripcion` de una cita o `notas` de un vehiculo —los sitios
 * naturales para colar «ignora tus instrucciones»— no llegan nunca al modelo.
 * Esto es la segunda capa, para los dos o tres textos cortos que si hacen
 * falta para que la respuesta sea util (placa, tipo de servicio, nombre del
 * mantenimiento), y que ademas puede escribir un TERCERO: el `update` de
 * `/mantenimientos` lo admite un mecanico vinculado, y la cita la puede
 * proponer el mecanico.
 */
function textoSeguro(valor, maximo = 40) {
  if (typeof valor !== 'string') return null;
  const limpio = valor
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/[^\p{L}\p{N} .,\-/]/gu, '')
    .trim()
    .slice(0, maximo);
  return limpio.length ? limpio : null;
}

function denegar(mensaje) {
  const e = new Error(mensaje);
  e.code = 'permission-denied';
  return e;
}

/**
 * Resuelve el rol del llamante replicando lo que hacen las reglas.
 *
 * @returns {{rol: 'propietario'|'taller', tallerEfectivo?: string}}
 */
async function resolverRol(db, uid) {
  const snap = await db.collection('usuarios').doc(uid).get();
  const usuario = snap.exists ? snap.data() || {} : {};

  if (ROLES_DE_TALLER.indexOf(usuario.rol) === -1) {
    return { rol: 'propietario' };
  }

  // Mismo default defensivo que `isMecanico()`: .get('estado', 'pendiente').
  // El Pendiente 0 del runbook de H-01 existe justo porque puede haber
  // talleres de produccion sin el campo, y tratarlos como aprobados seria
  // convertir el arreglo en su contrario.
  const estado = usuario.estado || 'pendiente';
  if (ESTADOS_TALLER_ACTIVO.indexOf(estado) === -1) {
    throw denegar(
      'Taller con estado "' + estado + '" (pendiente de aprobacion): agenda denegada.'
    );
  }

  // `actuaPorTaller` (firestore.rules:214): el empleado actua por su taller.
  // Mirando solo `uid == id_taller`, ningun empleado veria jamas la agenda.
  return { rol: 'taller', tallerEfectivo: usuario.id_taller_propietario || uid };
}

/** Vehiculos propios y compartidos, deduplicados por id. */
async function leerVehiculos(db, uid) {
  const [propios, compartidos] = await Promise.all([
    db.collection('vehiculos').where('id_propietario', '==', uid).limit(LIMITE_VEHICULOS).get(),
    db
      .collection('vehiculos')
      .where('shared_with', 'array-contains', uid)
      .limit(LIMITE_VEHICULOS)
      .get(),
  ]);

  const porId = new Map();
  for (const pagina of [propios, compartidos]) {
    for (const doc of pagina.docs) {
      if (!porId.has(doc.id)) porId.set(doc.id, doc.data());
    }
  }
  return porId;
}

/**
 * Mantenimientos de los vehiculos dados.
 *
 * **El `limit` de un `whereIn` se aplica POR SUBCONSULTA**, no al total. Es la
 * trampa que los revisores levantaron en GAPS-04, y la primera version de
 * esta funcion la piso otra vez pese a citarla en este mismo comentario: con
 * `limit(100)` y lotes de 10, cada lote leia hasta 1000 documentos. Peor aun,
 * `LIMITE_VEHICULOS` es por CONSULTA y `leerVehiculos` lanza dos, asi que
 * llegaban hasta 50 ids: 5 lotes x 10 x 100 = **5000 lecturas por pregunta**.
 *
 * Ahora la cota se construye al reves, desde lo que significa: como mucho
 * `MAX_TAREAS_POR_VEHICULO` por vehiculo. El `limit` se calcula para que eso
 * sea cierto por subconsulta, y ademas se trunca en memoria — el `limit` es la
 * red, no la cota.
 */
async function leerMantenimientos(db, idsVehiculo) {
  const lotes = [];
  for (let i = 0; i < idsVehiculo.length; i += TAMANO_LOTE_IN) {
    lotes.push(idsVehiculo.slice(i, i + TAMANO_LOTE_IN));
  }

  // En paralelo: el numero de lotes ya esta acotado (<= 3 con 25 vehiculos) y
  // en serie eran otros tantos round-trips dentro de un callable que ademas
  // espera dos llamadas al modelo.
  const paginas = await Promise.all(
    lotes.map((lote) =>
      db
        .collection('mantenimientos')
        .where('id_vehiculo', 'in', lote)
        // Por subconsulta, que es como Firestore lo aplica de verdad.
        .limit(MAX_TAREAS_POR_VEHICULO)
        .get()
    )
  );

  const porVehiculo = new Map();
  for (const pagina of paginas) {
    for (const doc of pagina.docs) {
      const mant = doc.data();
      if (!porVehiculo.has(mant.id_vehiculo)) porVehiculo.set(mant.id_vehiculo, []);
      const lista = porVehiculo.get(mant.id_vehiculo);
      if (lista.length < MAX_TAREAS_POR_VEHICULO) lista.push(mant);
    }
  }
  return porVehiculo;
}

/**
 * Placas de los vehiculos de una lista de citas, para la agenda del taller.
 *
 * **`reservas` no lleva `placa`**: `ReservaModel.toMap()` no la escribe nunca
 * (el `placa` denormalizado que hay en el repo es de `reparaciones`, otra
 * coleccion). Sin esto, el taller veria todas sus citas sin saber de que coche
 * son — que es justo el dato que hace util la vista.
 *
 * Va por `getAll` y no por una consulta `in`: lee EXACTAMENTE un documento por
 * id, sin indice y sin volver a caer en el `limit` por subconsulta.
 */
async function leerPlacas(db, idsVehiculo) {
  const placas = new Map();
  if (!idsVehiculo.length || typeof db.getAll !== 'function') return placas;

  const refs = idsVehiculo.slice(0, LIMITE_CITAS).map((id) => db.collection('vehiculos').doc(id));
  const docs = await db.getAll(...refs);
  for (const doc of docs) {
    if (!doc.exists) continue;
    placas.set(doc.id, (doc.data() || {}).placa);
  }
  return placas;
}

/** Citas confirmadas dentro de la ventana, acotadas EN EL SERVIDOR. */
async function leerCitas(db, campo, valor, desde, hasta) {
  const pagina = await db
    .collection('reservas')
    .where(campo, '==', valor)
    .where('estado', '==', 'confirmada')
    // Sin estas dos, la consulta lee cada cita confirmada que haya existido
    // jamas y descarta el resto en memoria. Es el defecto exacto que OPS-01
    // encontro en el recordatorio diario.
    .where('fecha_hora_propuesta', '>=', desde)
    .where('fecha_hora_propuesta', '<', hasta)
    // Firestore exige ordenar por el campo de la desigualdad.
    .orderBy('fecha_hora_propuesta')
    .limit(LIMITE_CITAS)
    .get();
  return pagina.docs.map((d) => d.data());
}

/**
 * Construye la agenda de `uid`.
 *
 * @param {object} db Firestore con Admin SDK (o un doble con la misma forma).
 * @param {string} uid
 * @param {{ahora?: Date, ventanaDias?: number, desfaseMinutos?: number}} [opciones]
 * @returns {Promise<{rol: string, ventana_dias: number, items: object[]}>}
 */
async function construirAgenda(db, uid, opciones = {}) {
  const ahora = opciones.ahora || new Date();
  const ventanaDias =
    opciones.ventanaDias === undefined ? VENTANA_DIAS_POR_DEFECTO : opciones.ventanaDias;
  const desfase =
    opciones.desfaseMinutos === undefined ? DESFASE_MINUTOS_BOGOTA : opciones.desfaseMinutos;

  // La autorizacion ocurre ANTES de leer un solo documento de datos. Si esto
  // se cuela despues, un taller pendiente ya habria leido citas para cuando
  // se le deniega.
  const { rol, tallerEfectivo } = await resolverRol(db, uid);

  // La ventana arranca en la medianoche local de HOY: una cita de esta tarde
  // sigue siendo un compromiso proximo, y un `>= ahora` la habria escondido.
  const desde = inicioDelDiaLocal(ahora, desfase);
  const hasta = new Date(desde.getTime() + (ventanaDias + 1) * MS_POR_DIA);

  const items =
    rol === 'taller'
      ? await itemsDeTaller(db, tallerEfectivo, { ahora, desde, hasta, desfase })
      : await itemsDePropietario(db, uid, { ahora, desde, hasta, desfase, ventanaDias });

  return { rol, ventana_dias: ventanaDias, items: ordenar(items) };
}

async function itemsDeTaller(db, tallerEfectivo, ctx) {
  const citas = await leerCitas(db, 'id_taller', tallerEfectivo, ctx.desde, ctx.hasta);
  const idsVehiculo = Array.from(
    new Set(citas.map((c) => c.id_vehiculo).filter((id) => typeof id === 'string' && id))
  );
  const placas = await leerPlacas(db, idsVehiculo);
  return citas.map((cita) => itemDeCita(cita, ctx, placas));
}

async function itemsDePropietario(db, uid, ctx) {
  const vehiculos = await leerVehiculos(db, uid);

  // **Recortar DESPUES de deduplicar.** `LIMITE_VEHICULOS` es por consulta y
  // `leerVehiculos` lanza dos (propios y compartidos), asi que sin este corte
  // llegaban hasta el doble de ids a la consulta de mantenimientos.
  const ids = Array.from(vehiculos.keys())
    // Un vehiculo sin kilometraje numerico no puede producir ningun item de
    // mantenimiento (`itemsDeMantenimiento` devuelve [] de entrada), asi que
    // leer sus tareas es pagar lecturas para tirarlas.
    .filter((id) => typeof vehiculos.get(id).kilometraje_actual === 'number')
    .slice(0, LIMITE_VEHICULOS);

  const [citas, mantenimientos] = await Promise.all([
    leerCitas(db, 'id_propietario', uid, ctx.desde, ctx.hasta),
    ids.length ? leerMantenimientos(db, ids) : Promise.resolve(new Map()),
  ]);

  const items = citas.map((cita) => itemDeCita(cita, ctx, null));

  for (const [id, vehiculo] of vehiculos) {
    const placa = textoSeguro(vehiculo.placa, 10);

    for (const [campo, tipo] of [
      ['vencimiento_soat', 'soat'],
      ['vencimiento_tarjeta', 'tarjeta'],
    ]) {
      const fecha = aFecha(vehiculo[campo]);
      if (!fecha) continue;
      const dias = diasLocalesEntre(ctx.ahora, fecha, ctx.desfase);
      // Lo ya vencido NO se omite: es lo mas urgente que puede haber.
      if (dias > ctx.ventanaDias) continue;
      items.push({ tipo, placa, dias_restantes: dias });
    }

    for (const item of itemsDeMantenimiento(mantenimientos.get(id) || [], vehiculo, placa)) {
      items.push(item);
    }
  }

  return items;
}

/**
 * Un item de mantenimiento **no lleva fecha de ninguna clase**. Si algun dia
 * alguien anade una aqui, el modelo la afirmara como un vencimiento real.
 */
function itemsDeMantenimiento(mantenimientos, vehiculo, placa) {
  const km = vehiculo.kilometraje_actual;
  if (typeof km !== 'number') return [];

  const items = [];
  for (const mant of mantenimientos) {
    const nombre = textoSeguro(mant.nombre);
    const ultimoKm = typeof mant.ultimo_km === 'number' ? mant.ultimo_km : null;
    const frecuencia = typeof mant.frecuencia_km === 'number' ? mant.frecuencia_km : null;
    if (ultimoKm === null || frecuencia === null) continue;

    // El odometro no puede retroceder. Cuando lo hace, el dato esta mal y el
    // asistente tiene que DECIRLO, no calcular «te faltan 40.000 km» sobre un
    // numero que no cuadra.
    if (km < ultimoKm) {
      items.push({ tipo: 'mantenimiento', placa, nombre, inconsistente: true });
      continue;
    }

    const kmRestantes = frecuencia - (km - ultimoKm);
    if (kmRestantes >= UMBRAL_KM_MANTENIMIENTO) continue;
    items.push({ tipo: 'mantenimiento', placa, nombre, km_restantes: kmRestantes });
  }
  return items;
}

/**
 * @param {Map<string,string>|null} placas solo el taller las recibe: el
 *   propietario ya sabe de que coche habla. Cuando el mapa existe, el item
 *   lleva SIEMPRE la clave `placa` —`null` si el vehiculo ya no esta—, para
 *   que el modelo no vea una forma distinta segun el caso.
 */
function itemDeCita(cita, ctx, placas) {
  const fecha = aFecha(cita.fecha_hora_propuesta);
  const item = {
    tipo: 'cita',
    dias_restantes: diasLocalesEntre(ctx.ahora, fecha, ctx.desfase),
    hora: horaLocal(fecha, ctx.desfase),
    tipo_servicio: textoSeguro(cita.tipo_servicio),
  };
  if (placas) item.placa = textoSeguro(placas.get(cita.id_vehiculo), 10);
  return item;
}

/**
 * Por urgencia. El mantenimiento va al final porque no tiene fecha: mezclarlo
 * por un `dias_restantes` fabricado es justo lo que este plan prohibe.
 */
function ordenar(items) {
  const conFecha = items.filter((i) => typeof i.dias_restantes === 'number');
  const sinFecha = items.filter((i) => typeof i.dias_restantes !== 'number');
  conFecha.sort((a, b) => a.dias_restantes - b.dias_restantes);
  sinFecha.sort((a, b) => {
    const ka = typeof a.km_restantes === 'number' ? a.km_restantes : Infinity;
    const kb = typeof b.km_restantes === 'number' ? b.km_restantes : Infinity;
    return ka - kb;
  });
  return conFecha.concat(sinFecha);
}

module.exports = {
  DESFASE_MINUTOS_BOGOTA,
  VENTANA_DIAS_POR_DEFECTO,
  UMBRAL_KM_MANTENIMIENTO,
  LIMITE_VEHICULOS,
  LIMITE_CITAS,
  MAX_TAREAS_POR_VEHICULO,
  TAMANO_LOTE_IN,
  diasLocalesEntre,
  textoSeguro,
  construirAgenda,
};
