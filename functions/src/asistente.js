'use strict';

/**
 * Fase 2 del asistente de agenda — el orquestador.
 *
 * **Enrutamiento por intencion cerrada.** Un asistente con caja de texto
 * abierta sobre datos de usuario es un *confused deputy*: este codigo corre
 * con Admin SDK, donde `firestore.rules` NO aplica — la leccion que dejo
 * `iniciarReparacionPorVehiculo` en FUNC-02, un callable que se otorgaba
 * acceso a vehiculos porque las reglas no le alcanzaban.
 *
 * Por eso el modelo **nunca elige que leer**:
 *
 *   1. CLASIFICAR  el modelo devuelve UNA etiqueta de un enum cerrado. No
 *                  texto libre, no nombres de coleccion, no consultas.
 *   2. EJECUTAR    el SERVIDOR corre la consulta determinista de esa
 *                  intencion. Toda la autorizacion ocurre AQUI, antes de que
 *                  el modelo vea un solo dato.
 *   3. REDACTAR    el modelo convierte el envelope en prosa. No puede
 *                  inventar datos porque solo tiene el envelope.
 *
 * No hay function calling, no hay tool use, no hay RAG. La superficie de
 * inyeccion de prompt se cierra por construccion: lo que un tercero escribe
 * (la descripcion de una cita, las notas de un vehiculo) no entra nunca al
 * envelope, y aunque entrara, el modelo no tiene ninguna capacidad que
 * pudiera usar.
 *
 * **El asistente es de SOLO LECTURA.** No agenda citas, no marca nada como
 * hecho, no escribe en ninguna coleccion de datos. Lo unico que escribe es su
 * propio contador de cuota y su cache de explicaciones. Un asistente que
 * escribe es otro plan y otro modelo de riesgo.
 */

const crypto = require('crypto');

const { construirAgenda: construirAgendaReal } = require('./agenda');

/**
 * El enum cerrado. **Cualquier cosa que el modelo devuelva y no este aqui cae
 * a `fuera_de_alcance`**: no se reintenta, no se interpreta, no se parsea con
 * heuristica.
 *
 * `estado` e `historial` NO estan, a proposito. Son el stretch del plan, y
 * cada etiqueta de mas es una ocasion mas de clasificar mal. Anadirlas es
 * anadir una entrada aqui y su rama en `ejecutar()`.
 */
const INTENCIONES = ['agenda', 'explicar', 'fuera_de_alcance'];
const FUERA_DE_ALCANCE = 'fuera_de_alcance';

/**
 * Presupuesto de salida del clasificador.
 *
 * **Estaba en 10 y no daba para la etiqueta mas larga del propio enum.** El
 * spike lo midio: los dos modelos probados devolvieron exactamente
 * `fuera_de_alc` —doce de los dieciseis caracteres de `fuera_de_alcance`— en
 * las dos preguntas que debian rechazarse.
 *
 * Lo venenoso era que el resultado seguia siendo correcto: `fuera_de_alc` no
 * esta en el enum, asi que caia al fail-safe y el fail-safe devuelve
 * `fuera_de_alcance`. **Acertaba por accidente.** Y mientras tanto la red que
 * protege de una etiqueta inventada por el modelo se disparaba en TODAS las
 * preguntas fuera de alcance, con lo que dejaba de poder distinguir «el
 * modelo clasifico bien» de «el modelo devolvio basura» — justo la
 * distincion para la que existe.
 *
 * Se deriva del enum en vez de fijar un numero: si manana entra una etiqueta
 * mas larga, el presupuesto la acompaña. Cuatro tokens por caracter es
 * holgura deliberada; a 10 tokens de salida esto no cuesta nada.
 */
const MAX_TOKENS_ETIQUETA =
  4 * INTENCIONES.reduce((mayor, etiqueta) => Math.max(mayor, etiqueta.length), 0);

const COLECCION_CUOTA = 'consultas_ia_control';
const COLECCION_CACHE = 'explicaciones_ia';
const DOC_CONFIGURACION = 'configuracion/asistente_ia';

/** Cubo global, en la misma coleccion. Ningun uid de Firebase empieza por `_`. */
const DOC_CUOTA_GLOBAL = '_global';

const VENTANA_MS = 24 * 60 * 60 * 1000;

/**
 * Cuanto vive una explicacion cacheada. 30 dias: lo que explica que es el SOAT
 * no cambia de una semana para otra, pero una entrada no debe ser eterna —
 * entre otras cosas porque el dia que se ajuste `SISTEMA_EXPLICADOR` las
 * respuestas viejas seguirian sirviendose con las instrucciones antiguas.
 */
const VIDA_CACHE_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * El free tier de Gemini Flash da ~1500 peticiones/dia y 10 RPM. El corte
 * global va MUY por debajo a proposito: quedarse sin cuota del proveedor a
 * media demo no se arregla con un despliegue, mientras que subir este numero
 * es cambiar una constante.
 */
const LIMITE_POR_USUARIO = 10;
const LIMITE_GLOBAL = 200;

/** Una pregunta mas larga que esto no es una pregunta. */
const LARGO_MAXIMO_PREGUNTA = 500;

const IDIOMAS = ['es', 'en'];
const IDIOMA_POR_DEFECTO = 'es';

/**
 * Texto fijo y localizado para el rechazo.
 *
 * Va **sin llamar al redactor**: ahorra una llamada de cuota y, sobre todo,
 * hace el rechazo determinista. Pedirle a un modelo que redacte su propia
 * negativa es darle una ocasion de no negarse.
 */
const TEXTO_FUERA_DE_ALCANCE = {
  es:
    'Solo puedo ayudarte con los vencimientos, las citas y los mantenimientos ' +
    'de tus vehiculos. No puedo diagnosticar averias: para eso, agenda una ' +
    'cita con un taller.',
  en:
    'I can only help with your vehicles’ document expirations, appointments ' +
    'and maintenance. I can’t diagnose faults — for that, book an ' +
    'appointment with a workshop.',
};

const SIN_NADA_QUE_CONTAR = {
  es: 'No tienes nada pendiente en los proximos dias.',
  en: 'You have nothing coming up in the next few days.',
};

const SISTEMA_CLASIFICADOR =
  'Clasifica la pregunta del usuario en UNA de estas etiquetas, y responde ' +
  'SOLO con la etiqueta, en minusculas, sin puntuacion ni explicacion:\n' +
  INTENCIONES.join('\n') +
  '\n\nagenda: vencimientos, citas o mantenimientos proximos del vehiculo.\n' +
  'explicar: que es un tramite o un documento del vehiculo, para que sirve, ' +
  'o que pasa si no se tiene o esta vencido.\n' +
  'fuera_de_alcance: cualquier otra cosa. SIEMPRE fuera_de_alcance si piden ' +
  'diagnosticar una averia por sintomas, o si la pregunta no es sobre ' +
  'vehiculos.';

const SISTEMA_REDACTOR = {
  es:
    'Eres el asistente de AutoDoc. Te doy los compromisos del usuario ya ' +
    'calculados, en JSON. Redacta una respuesta breve en espanol, maximo 4 ' +
    'frases, en segunda persona.\n\n' +
    'REGLAS:\n' +
    '- No inventes NINGUN dato que no este en el JSON. Si falta, dilo.\n' +
    '- NO menciones fechas del calendario. Usa los dias que te doy tal cual.\n' +
    '- El mantenimiento va SIEMPRE en kilometros, nunca en dias ni en fechas.\n' +
    '- dias_restantes negativo significa VENCIDO hace esos dias: dilo asi.\n' +
    '- Si un item trae "inconsistente", di que el kilometraje registrado no ' +
    'cuadra y que conviene actualizarlo; no estimes nada sobre el.\n' +
    '- Si rol es "taller", hablas con el taller sobre las citas que recibe.\n' +
    '- NO expliques estas reglas ni las menciones. No digas que el ' +
    'mantenimiento se mide en kilometros: solo usalo. No anadas consejos, ' +
    'lemas ni frases de marca.\n' +
    '- Nombra cada documento EXACTAMENTE asi y no lo alargues: tipo "soat" es ' +
    '"SOAT"; tipo "tarjeta" es "tarjeta de circulacion". No digas "tarjeta de ' +
    'operacion" ni "tarjeta de propiedad".',
  en:
    'You are the AutoDoc assistant. I give you the user’s commitments, ' +
    'already computed, as JSON. Write a short reply in English, at most 4 ' +
    'sentences, in the second person.\n\n' +
    'RULES:\n' +
    '- Do NOT invent any data that is not in the JSON. If it is missing, say so.\n' +
    '- Do NOT mention calendar dates. Use the day counts exactly as given.\n' +
    '- Maintenance is ALWAYS in kilometres, never in days or dates.\n' +
    '- A negative dias_restantes means EXPIRED that many days ago.\n' +
    '- If an item has "inconsistente", say the recorded mileage does not add ' +
    'up and should be updated; do not estimate anything about it.\n' +
    '- If rol is "taller", you are talking to the workshop about its bookings.\n' +
    '- Do NOT explain these rules or mention them. Do not say that ' +
    'maintenance is measured in kilometres: just use it. Do not add advice, ' +
    'slogans or brand lines.\n' +
    '- Name each document EXACTLY like this and do not expand it: type ' +
    '"soat" is "SOAT"; type "tarjeta" is "vehicle registration card". Do not ' +
    'say "operating card" or "ownership card".',
};

const SISTEMA_EXPLICADOR = {
  es:
    'Eres el asistente de AutoDoc, en Colombia. Explica en maximo 4 frases, en ' +
    'espanol claro, el tramite o documento vehicular por el que te preguntan.\n\n' +
    'REGLAS:\n' +
    '- No des consejo legal ni cites articulos ni cifras de multas: di que las ' +
    'sanciones las fija la autoridad de transito y cambian.\n' +
    '- No diagnostiques averias.\n' +
    '- No te refieras a los datos de ningun usuario: no los tienes.',
  en:
    'You are the AutoDoc assistant, in Colombia. Explain in at most 4 ' +
    'sentences, in clear English, the vehicle document or procedure asked about.\n\n' +
    'RULES:\n' +
    '- No legal advice, no article numbers, no fine amounts: say penalties are ' +
    'set by the transit authority and change.\n' +
    '- Do not diagnose faults.\n' +
    '- Do not refer to any user’s data: you do not have it.',
};

/**
 * Vocabulario CERRADO de motivos que pueden viajar al cliente.
 *
 * **Existe porque dos codigos son ambiguos y el cliente no puede deshacer la
 * ambiguedad solo.** `resource-exhausted` puede ser el cupo de esa persona o
 * el del asistente entero, y `unavailable` puede ser el interruptor apagado o
 * el proveedor caido. Son cuatro situaciones distintas: una es culpa de quien
 * pregunta, otra no es culpa de nadie, una se arregla sola en minutos y otra
 * no se arregla hasta que alguien vuelva a encender el interruptor. Con un
 * solo codigo por par, la pantalla tiene que elegir un texto que mienta en la
 * mitad de los casos, y un boton de reintentar que sobra en la otra mitad.
 *
 * **Es una lista blanca, no un `e.detalle` reenviado tal cual**, y esa es la
 * mitad que importa: `detalle` tambien lo rellena `textoDeRespuesta()` de
 * `modeloGemini.js` con el `blockReason` que devuelve Google —texto del
 * proveedor, no nuestro— y `details` de un `HttpsError` viaja al cliente
 * literal. Reenviarlo seria abrir un canal por el que un tercero escribe en
 * la app. Lo que no esta en esta lista no sale.
 */
const MOTIVOS = ['cupo_usuario', 'cupo_global', 'apagado', 'proveedor'];

/**
 * Mensajes que SI pueden salir del servidor, uno por codigo.
 *
 * **El `message` de un `HttpsError` viaja al cliente igual de literal que
 * `details`**, asi que filtrar uno y reenviar el otro es poner una puerta
 * blindada al lado de una ventana abierta. Y lo que hay al otro lado no es
 * inocuo: los mensajes de `modeloGemini.js` estan escritos para quien
 * despliega —nombran `GEMINI_API_KEY`, `GEMINI_MODELO` y
 * `functions/spike_gemini.js`— porque su destino era el log, no una pantalla.
 *
 * Lo destapo el gate de rendimiento al revisar el cierre de este mismo gap, y
 * **el alcance es nuevo**: hasta que `clasificar` empezo a dejar subir
 * `failed-precondition`, un modelo mal configurado moria en la primera
 * llamada y se degradaba a `fuera_de_alcance`, asi que ese texto no salia
 * nunca. Ahora sale, y sale en el caso mas probable de todos — que el nombre
 * del modelo caduque, que es justo lo que `MODELO_POR_DEFECTO` advierte.
 *
 * Retirarlo no cuesta nada: el cliente **no usa** el mensaje del servidor.
 * `mensaje_de_asistente.dart` compone el texto desde el codigo y el motivo, y
 * nunca pinta `error.message`. Hoy ese mensaje cruza la red para no usarse.
 * El detalle real no se pierde, se queda en `console.error`.
 */
const MENSAJES_PUBLICOS = {
  unauthenticated: 'Debes iniciar sesion.',
  'invalid-argument': 'La pregunta no es valida.',
  'permission-denied': 'No puedes consultar esta agenda.',
  'resource-exhausted': 'Se alcanzo el limite de consultas de hoy.',
  unavailable: 'El asistente no esta disponible ahora mismo.',
  'deadline-exceeded': 'El asistente tardo demasiado en responder.',
  'failed-precondition': 'El asistente no esta disponible ahora mismo.',
  aborted: 'No se pudo preparar una respuesta.',
};

/**
 * El mensaje publicable de un codigo.
 *
 * `hasOwnProperty` y no `MENSAJES_PUBLICOS[codigo]` a secas: con el acceso
 * directo, un codigo `constructor` o `toString` devuelve algo heredado del
 * prototipo en vez de `undefined`, y lo que se publicaria seria el codigo
 * fuente de una funcion. Es la misma trampa que `motivoPublico` evita usando
 * un array en vez de un objeto como mapa.
 *
 * @param {string} codigo
 * @returns {string}
 */
function mensajePublico(codigo) {
  return Object.prototype.hasOwnProperty.call(MENSAJES_PUBLICOS, codigo)
    ? MENSAJES_PUBLICOS[codigo]
    : 'No se pudo responder.';
}

/**
 * El motivo publicable de un error, o `undefined`.
 *
 * Se exporta para que `functions/index.js` no tenga que conocer el
 * vocabulario ni repetir el filtro: alli es una linea, y aqui tiene test.
 *
 * @param {Error & {detalle?: unknown}} error
 * @returns {string|undefined}
 */
function motivoPublico(error) {
  const detalle = error && error.detalle;
  return MOTIVOS.indexOf(detalle) !== -1 ? detalle : undefined;
}

function errorDeAsistente(codigo, mensaje, detalle) {
  const e = new Error(mensaje);
  e.code = codigo;
  if (detalle !== undefined) e.detalle = detalle;
  return e;
}

/** Normaliza la pregunta para que la cache no guarde N copias de lo mismo. */
function normalizar(pregunta) {
  return String(pregunta || '')
    .slice(0, LARGO_MAXIMO_PREGUNTA)
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^\p{L}\p{N} ]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function claveDeCache(preguntaNormalizada, idioma) {
  return crypto
    .createHash('sha256')
    .update(idioma + '|' + preguntaNormalizada)
    .digest('hex')
    .slice(0, 32);
}

function idiomaValido(idioma) {
  const bruto = String(idioma || '')
    .slice(0, 5)
    .toLowerCase()
    .split(/[-_]/)[0];
  return IDIOMAS.indexOf(bruto) !== -1 ? bruto : IDIOMA_POR_DEFECTO;
}

/**
 * Interruptor de apagado sin desplegar.
 *
 * Es la leccion del 2026-09-13 aplicada: aquel dia el unico modo de quitar el
 * bundle contaminado de produccion era volver a compilar y volver a
 * desplegar. Un interruptor que necesita un build no sirve el dia que hace
 * falta. Ante un fallo de lectura se sigue ADELANTE: si Firestore no responde,
 * la feature ya va a fallar sola en el paso siguiente, y apagarla por una
 * lectura transitoria seria apagarla por nada.
 */
async function estaEncendido(db) {
  try {
    const [coleccion, doc] = DOC_CONFIGURACION.split('/');
    const snap = await db.collection(coleccion).doc(doc).get();
    if (!snap.exists) return true;
    return (snap.data() || {}).activo !== false;
  } catch (e) {
    console.error('asistente: no se pudo leer el kill switch:', e && e.code ? e.code : e);
    return true;
  }
}

/**
 * Cupo por usuario y global, **en la misma transaccion**.
 *
 * Es el contador de `solicitudes_landing_control` (UX-01) con uid en vez de
 * hash de IP: contar documentos por rango obligaria a un indice compuesto y a
 * leer N documentos por peticion; esto son dos lecturas y dos escrituras
 * fijas.
 *
 * Los dos cubos van juntos a proposito. Separados, un usuario podria pasar su
 * propio cupo y morir en el global dejando su contador ya incrementado, o al
 * reves — y el segundo caso regala consultas.
 */
async function dentroDelCupo(db, uid, ahoraMs) {
  const refUsuario = db.collection(COLECCION_CUOTA).doc(uid);
  const refGlobal = db.collection(COLECCION_CUOTA).doc(DOC_CUOTA_GLOBAL);

  return db.runTransaction(
    async (tx) => {
      // Las dos lecturas van ANTES de cualquier escritura: Firestore lo exige
      // dentro de una transaccion.
      const [snapUsuario, snapGlobal] = await Promise.all([tx.get(refUsuario), tx.get(refGlobal)]);

      const cubo = (snap) => {
        const previo = snap.exists ? snap.data() : null;
        const inicio = previo && previo.ventana_inicio ? previo.ventana_inicio : 0;
        const vigente = ahoraMs - inicio < VENTANA_MS;
        return {
          inicio: vigente ? inicio : ahoraMs,
          conteo: vigente ? previo.conteo || 0 : 0,
        };
      };

      const usuario = cubo(snapUsuario);
      const global = cubo(snapGlobal);

      if (usuario.conteo >= LIMITE_POR_USUARIO) {
        return { ok: false, motivo: 'usuario' };
      }
      if (global.conteo >= LIMITE_GLOBAL) {
        return { ok: false, motivo: 'global' };
      }

      const escribir = (ref, estado) =>
        tx.set(ref, {
          ventana_inicio: estado.inicio,
          conteo: estado.conteo + 1,
          // Para la politica TTL de Firestore. Tiene que ser Date/Timestamp,
          // no milisegundos, o la politica no lo mira. Sin TTL esta coleccion
          // crece un documento por usuario y no se vacia nunca.
          expira_en: new Date(estado.inicio + VENTANA_MS),
        });

      escribir(refUsuario, usuario);
      escribir(refGlobal, global);
      return { ok: true };
    },
    // Cinco intentos, no dos. `_global` es un documento CALIENTE: lo escribe
    // toda peticion del asistente, y Firestore admite ~1 escritura sostenida
    // por documento y segundo. Con dos intentos, una sola colision agota los
    // reintentos y el usuario recibe `aborted` — un error que no significa
    // nada para el y que ademas viaja hasta la UI, porque `aborted` esta en la
    // lista de codigos conocidos del callable.
    //
    // Es la diferencia con el contador de `solicitudes_landing_control`, de
    // donde viene este codigo: alli los dos intentos son correctos porque las
    // peticiones que se pisan sobre el mismo cubo son las de un ataque y
    // rechazar rapido es lo deseable. Aqui el cubo compartido es el camino
    // normal de todo el mundo.
    { maxAttempts: 5 }
  );
}

/**
 * Codigos que NO deben cobrar cupo GLOBAL, porque el proveedor no llego a
 * atender la consulta.
 *
 * **Lo levanto el gate de rendimiento, y es consecuencia directa de dejar
 * subir los fallos de infraestructura.** Antes, un Gemini caido devolvia 200
 * con un texto plausible y la persona paraba de preguntar. Ahora devuelve
 * error y la pantalla pinta un boton de reintentar, asi que durante una caida
 * los reintentos se comen `LIMITE_GLOBAL` — y cuando Gemini se recupera el
 * asistente sigue muerto hasta que ruede la ventana de 24 h. **La caida
 * sobrevive a la caida**, y el interruptor no sirve de nada: solo apaga.
 *
 * El cubo global existe para no quedarse sin cuota DEL PROVEEDOR (§ la nota
 * de `LIMITE_GLOBAL`), asi que cobrarle una llamada que el proveedor no
 * atendio no es solo inconveniente: es contar mal.
 *
 * **El cubo del usuario SI se cobra**, y esa mitad no es negociable: es el
 * freno que impide que una sola persona reintente sin limite contra un
 * proveedor roto. Devolver los dos quitaria el freno y cambiaria un problema
 * por otro peor.
 *
 * `resource-exhausted` no esta: dentro del flujo solo puede venir de un 429
 * del proveedor —el cupo propio se corta ANTES de incrementar nada—, y ahi el
 * proveedor si esta diciendo que no queda cuota. Devolver el cupo seria
 * insistirle. `aborted` tampoco: el modelo respondio, aunque fuera para
 * negarse.
 */
const CODIGOS_SIN_CARGO_GLOBAL = ['unavailable', 'deadline-exceeded', 'failed-precondition'];

/**
 * Devuelve al cubo global la consulta que el proveedor no atendio.
 *
 * Solo toca el documento global, y solo si la ventana sigue siendo la misma:
 * si ya rodo, el contador vale cero y restar ahi escribiria un negativo por
 * una consulta de ayer. El `Math.max(0, ...)` es la segunda red para el mismo
 * caso.
 *
 * Un fallo aqui se traga a proposito: esto corre dentro del camino de error,
 * y tapar el error original con otro dejaria a la persona sin saber que paso.
 */
async function devolverCupoGlobal(db, ahoraMs) {
  const ref = db.collection(COLECCION_CUOTA).doc(DOC_CUOTA_GLOBAL);
  try {
    await db.runTransaction(
      async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) return;
        const datos = snap.data() || {};
        const inicio = datos.ventana_inicio || 0;
        if (ahoraMs - inicio >= VENTANA_MS) return;
        tx.set(ref, {
          ventana_inicio: inicio,
          conteo: Math.max(0, (datos.conteo || 0) - 1),
          expira_en: new Date(inicio + VENTANA_MS),
        });
      },
      { maxAttempts: 5 }
    );
  } catch (e) {
    console.error('asistente: no se pudo devolver el cupo global:', e && e.code ? e.code : e);
  }
}

/**
 * Codigos que `clasificar` deja SUBIR en vez de tragarse.
 *
 * **Un fallo de infraestructura no es una pregunta fuera de alcance.** La
 * clasificacion es la PRIMERA llamada al modelo, asi que con Gemini caido o
 * mal configurado fallaba siempre aqui — y este `catch` convertia eso en
 * «solo puedo ayudarte con los vencimientos». La persona recibia una negativa
 * segura de si misma en vez de un error: no hay reintento, no hay aviso, y
 * quien mire los logs vera consultas atendidas. Es el mismo defecto que UX-04
 * persigue, con la agravante de que aqui la app parece funcionar.
 *
 * `aborted` NO esta, y es deliberado: significa que el filtro del proveedor
 * bloqueo la pregunta al clasificarla, o sea que el modelo se nego a mirarla.
 * Ahi «fuera de alcance» es la lectura correcta, no un disfraz.
 */
const CODIGOS_QUE_SUBEN = [
  'resource-exhausted',
  'unavailable',
  'deadline-exceeded',
  'failed-precondition',
];

/**
 * Clasifica. **Cualquier etiqueta que no este en el enum es
 * `fuera_de_alcance`**: no se reintenta, no se interpreta, no se parsea con
 * heuristica. Lo que SI sube es el fallo de infraestructura
 * ([CODIGOS_QUE_SUBEN]), porque no es una respuesta del modelo: es su
 * ausencia.
 */
async function clasificar(cliente, pregunta) {
  let bruto;
  try {
    bruto = await cliente.generar({
      sistema: SISTEMA_CLASIFICADOR,
      usuario: pregunta,
      maxTokens: MAX_TOKENS_ETIQUETA,
      temperatura: 0,
    });
  } catch (e) {
    // Estos suben: son accionables y la persona los entiende. Tragarselos
    // convierte una averia en un rechazo, que es la peor de las dos.
    if (e && CODIGOS_QUE_SUBEN.indexOf(e.code) !== -1) throw e;
    console.error('asistente: fallo clasificando:', e && e.code ? e.code : e);
    return FUERA_DE_ALCANCE;
  }

  const etiqueta = String(bruto || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z_]/g, '');
  return INTENCIONES.indexOf(etiqueta) !== -1 ? etiqueta : FUERA_DE_ALCANCE;
}

/**
 * Crea el asistente.
 *
 * @param {object} opciones
 * @param {object} opciones.db Firestore con Admin SDK.
 * @param {{generar: Function}} opciones.cliente cliente del modelo, INYECTADO.
 * @param {Function} [opciones.ahora]
 * @param {Function} [opciones.construirAgenda]
 */
function crearAsistente(opciones) {
  const db = opciones.db;
  const cliente = opciones.cliente;
  const ahora = opciones.ahora || (() => new Date());
  const agenda = opciones.construirAgenda || construirAgendaReal;

  /**
   * @param {{uid: string, pregunta: string, idioma?: string}} peticion
   * @returns {Promise<{intencion: string, texto: string, cacheada?: boolean, items?: number}>}
   */
  async function responder(peticion) {
    const uid = peticion && peticion.uid;
    if (!uid) throw errorDeAsistente('unauthenticated', 'Hace falta iniciar sesion.');

    const idioma = idiomaValido(peticion.idioma);
    const pregunta = normalizar(peticion.pregunta);
    if (!pregunta) {
      throw errorDeAsistente('invalid-argument', 'La pregunta viene vacia.');
    }

    if (!(await estaEncendido(db))) {
      throw errorDeAsistente(
        'unavailable',
        'El asistente esta desactivado temporalmente.',
        'apagado'
      );
    }

    const ahoraMs = ahora().getTime();
    const cupo = await dentroDelCupo(db, uid, ahoraMs);
    if (!cupo.ok) {
      throw errorDeAsistente(
        'resource-exhausted',
        cupo.motivo === 'global'
          ? 'El asistente alcanzo su limite diario. Intentalo manana.'
          : 'Alcanzaste tu limite de consultas de hoy. Intentalo manana.',
        cupo.motivo === 'global' ? 'cupo_global' : 'cupo_usuario'
      );
    }

    // A partir de aqui el cupo YA esta cobrado, asi que un fallo del proveedor
    // deja pagada una consulta que nadie recibio. El cargo del usuario se
    // queda (es el freno contra reintentar sin limite); el global se devuelve,
    // porque ese cubo representa la cuota del PROVEEDOR y el proveedor no
    // atendio nada.
    try {
      return await ejecutar();
    } catch (e) {
      if (e && CODIGOS_SIN_CARGO_GLOBAL.indexOf(e.code) !== -1) {
        await devolverCupoGlobal(db, ahoraMs);
      }
      throw e;
    }

    async function ejecutar() {
      // La cache va DESPUES del cupo: un acierto de cache ahorra la llamada al
      // modelo, que es lo caro y lo limitado, pero sigue costando lecturas de
      // Firestore. Cobrar el cupo igual mantiene el limite superior acotado.
      const clave = claveDeCache(pregunta, idioma);
      const cacheada = await leerCache(clave);
      if (cacheada) return { intencion: 'explicar', texto: cacheada, cacheada: true };

      const intencion = await clasificar(cliente, pregunta);

      if (intencion === FUERA_DE_ALCANCE) {
        return { intencion, texto: TEXTO_FUERA_DE_ALCANCE[idioma] };
      }

      if (intencion === 'explicar') {
        const texto = await cliente.generar({
          sistema: SISTEMA_EXPLICADOR[idioma],
          usuario: pregunta,
          maxTokens: 250,
        });
        // Solo se cachea `explicar`, y se puede porque su respuesta **no
        // contiene datos de nadie**: no se ha leido ni un documento del usuario
        // para producirla. Cachear `agenda` seria servirle a una persona los
        // vencimientos de otra.
        await escribirCache(clave, texto, idioma);
        return { intencion, texto };
      }

      // `agenda`. La autorizacion entera ocurre aqui dentro, ANTES de que el
      // modelo vea un solo dato: rol, estado del taller y taller efectivo.
      const envelope = await agenda(db, uid, { ahora: ahora() });

      if (!envelope.items.length) {
        // Sin nada que contar no se gasta una llamada al modelo. Ademas evita
        // el peor fallo posible: un modelo al que se le pide redactar sobre una
        // lista vacia tiende a rellenarla.
        return { intencion, texto: SIN_NADA_QUE_CONTAR[idioma], items: 0 };
      }

      const texto = await cliente.generar({
        sistema: SISTEMA_REDACTOR[idioma],
        // El envelope y NADA MAS. Ni el uid, ni la pregunta cruda, ni ids de
        // documento, ni texto escrito por terceros.
        usuario: JSON.stringify(envelope),
        maxTokens: 350,
      });

      return { intencion, texto, items: envelope.items.length };
    }
  }

  async function leerCache(clave) {
    try {
      const snap = await db.collection(COLECCION_CACHE).doc(clave).get();
      if (!snap.exists) return null;
      const datos = snap.data() || {};
      return typeof datos.texto === 'string' && datos.texto ? datos.texto : null;
    } catch (e) {
      // Una cache que no se puede leer es una cache fria, no una averia.
      console.error('asistente: cache ilegible:', e && e.code ? e.code : e);
      return null;
    }
  }

  async function escribirCache(clave, texto, idioma) {
    try {
      const ahoraMs = ahora().getTime();
      await db
        .collection(COLECCION_CACHE)
        .doc(clave)
        .set({
          texto,
          idioma,
          creada_en: new Date(ahoraMs),
          // Sin `expira_en` esta coleccion no es siquiera CANDIDATA a una
          // politica TTL: crece un documento por pregunta distinta y no se vacia
          // nunca, y una entrada mala se queda para siempre sin ningun camino de
          // servidor para retirarla. Lo levanto el gate de reglas. Tiene que ser
          // Date/Timestamp, no milisegundos, o la politica no lo mira.
          expira_en: new Date(ahoraMs + VIDA_CACHE_MS),
        });
    } catch (e) {
      console.error('asistente: no se pudo cachear:', e && e.code ? e.code : e);
    }
  }

  return { responder };
}

module.exports = {
  INTENCIONES,
  // Los prompts se EXPORTAN para que los evals midan los de verdad.
  // `spike_gemini.js` lleva una copia propia del clasificador, y esa copia
  // fue exactamente lo que hizo que el arreglo del presupuesto de tokens se
  // quedara a medias: se subio aqui y el spike siguio midiendo con el valor
  // viejo, o sea siguio dando rojo sobre codigo ya arreglado. Un eval que
  // mide un prompt copiado no mide nada.
  SISTEMA_CLASIFICADOR,
  SISTEMA_REDACTOR,
  SISTEMA_EXPLICADOR,
  MAX_TOKENS_ETIQUETA,
  CODIGOS_QUE_SUBEN,
  CODIGOS_SIN_CARGO_GLOBAL,
  MOTIVOS,
  motivoPublico,
  MENSAJES_PUBLICOS,
  mensajePublico,
  FUERA_DE_ALCANCE,
  COLECCION_CUOTA,
  COLECCION_CACHE,
  DOC_CONFIGURACION,
  DOC_CUOTA_GLOBAL,
  LIMITE_POR_USUARIO,
  LIMITE_GLOBAL,
  LARGO_MAXIMO_PREGUNTA,
  TEXTO_FUERA_DE_ALCANCE,
  VENTANA_MS,
  VIDA_CACHE_MS,
  normalizar,
  idiomaValido,
  crearAsistente,
};
