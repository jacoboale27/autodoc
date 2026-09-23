'use strict';

/**
 * Cliente de Gemini para el asistente de agenda.
 *
 * **Por que REST a pelo y no el SDK.** `functions/index.js` ya paga arranque
 * en frio por 34 callables, y este repo lleva una cicatriz concreta con eso:
 * el `require` sincrono de `index.js` tarda ~4 s en frio y tumbaba la suite de
 * Mocha por timeout. Node 20 trae `fetch` global, la API de Gemini es un POST
 * con un JSON, y el SDK arrastra dependencias para envolver justo eso. No se
 * anade ninguna dependencia nueva.
 *
 * **Por que el cliente se inyecta.** Es el patron de VER-01
 * (`FilePickerPlatform.instance`) y de FUNC-02 (inyectar Firestore, que puso
 * 13 tests en rojo de golpe al hacerlo, porque llevaban ejerciendo el camino
 * de fallo sin saberlo). Los tests-gate del asistente afirman sobre **la
 * peticion construida y el manejo de la respuesta**, nunca sobre la prosa que
 * devuelve el modelo: la prosa no es determinista y un test que la afirme es
 * un test que se rompe solo.
 *
 * **La clave nunca viaja en la URL.** Gemini admite `?key=`, y es lo que sale
 * en todos los ejemplos, pero una URL acaba en los logs de la plataforma, en
 * un mensaje de error y en cualquier traza de red. Va en la cabecera
 * `x-goog-api-key`, y hay un test que lo afirma en las dos direcciones.
 */

const PUNTO_FINAL = 'https://generativelanguage.googleapis.com/v1beta/models';

/**
 * Flash-lite, y **fijado, no un alias**.
 *
 * Elegido con datos del spike (`--probar` + una corrida por candidato), no de
 * catalogo:
 *
 *   - `gemini-2.5-flash`, el valor anterior, da **404 en v1 y en v1beta**.
 *     La feature no funcionaba con el.
 *   - Los alias `*-latest` solo responden en v1beta, y son los mas lentos
 *     (1739 ms frente a 381). Peor: un alias se mueve sin que tu despliegues,
 *     asi que cambian latencia, precio y prosa a la vez. Este repositorio ya
 *     tiene la cicatriz de «el fuente estaba bien, lo que cambio fue el
 *     artefacto» (incidente del 2026-09-13).
 *   - `gemini-3.5-flash` devolvio respuestas VACIAS al clasificar y un
 *     fragmento suelto al redactar. La hipotesis, sin confirmar, es que sus
 *     tokens de razonamiento se comen `maxOutputTokens`; queda anotado como
 *     gap, porque afecta a cualquier modelo que piense.
 *   - `gemini-3.1-flash-lite` redacta igual de bien y es ~60 ms mas rapido,
 *     pero **no nombra la placa**. Con dos vehiculos, «tu SOAT esta vencido»
 *     sin decir cual no sirve de nada. Esos 60 ms no compran eso.
 *
 * El elegido responde en **v1 y en v1beta**, lo que deja una salida si v1beta
 * cambia. Se puede pisar con `GEMINI_MODELO` sin tocar codigo.
 */
const MODELO_POR_DEFECTO = 'gemini-3.5-flash-lite';

/** Un asistente que tarda mas que esto ya perdio al usuario. */
const TIMEOUT_MS = 12000;

/** Codigos que el callable mapea tal cual a un `HttpsError`. */
const CODIGOS = {
  cuotaDelProveedor: 'resource-exhausted',
  configuracion: 'failed-precondition',
  timeout: 'deadline-exceeded',
  bloqueado: 'aborted',
  proveedor: 'unavailable',
};

function errorDeModelo(codigo, mensaje, detalle) {
  const e = new Error(mensaje);
  e.code = codigo;
  if (detalle !== undefined) e.detalle = detalle;
  return e;
}

/**
 * Lee la clave del entorno.
 *
 * **Falla en la primera invocacion, no al cargar el modulo**, y no puede ser
 * de otro modo: en Functions v1 un secreto solo se monta en runtime, y
 * `crearClienteDelModelo()` se llama dentro del handler. Lo que si se
 * consigue es que el fallo sea LEGIBLE: `failed-precondition` con el detalle
 * en el log, en vez del `internal` que parece un defecto de la pantalla.
 * (Antes este comentario decia «falla al arrancar»; era falso.)
 *
 * @param {object} [env]
 * @returns {string}
 */
function claveDelEntorno(env = process.env) {
  const clave = env && env.GEMINI_API_KEY;
  if (clave) return String(clave);
  throw errorDeModelo(
    CODIGOS.configuracion,
    'Falta GEMINI_API_KEY. Se define con `firebase functions:secrets:set ' +
      'GEMINI_API_KEY --project production`, nunca en un .env versionado.'
  );
}

/**
 * Crea un cliente de Gemini.
 *
 * @param {object} opciones
 * @param {string} opciones.apiKey
 * @param {Function} [opciones.fetch] inyectable; por defecto el global de Node 20.
 * @param {string} [opciones.modelo]
 * @param {object} [opciones.env] inyectable; por defecto `process.env`.
 * @param {number} [opciones.timeoutMs]
 * @returns {{modelo: string, generar: Function}}
 */
function crearClienteGemini(opciones = {}) {
  const apiKey = opciones.apiKey;
  if (!apiKey) {
    throw errorDeModelo(CODIGOS.configuracion, 'crearClienteGemini requiere apiKey.');
  }
  const hacerPeticion = opciones.fetch || globalThis.fetch;
  if (typeof hacerPeticion !== 'function') {
    throw errorDeModelo(
      CODIGOS.configuracion,
      'No hay `fetch` disponible. Node 20 lo trae global; en un test, inyectalo.'
    );
  }
  // `GEMINI_MODELO` se lee AQUI y no solo en el spike. Era una incoherencia:
  // el mensaje del 404 manda a fijar esa variable, pero la funcion desplegada
  // no la miraba, asi que el consejo era falso justo cuando mas falta hacia.
  // Llega por los `.env.<proyecto>` de `functions/`, igual que
  // `APP_CHECK_ENFORCEMENT`, y ahi es legitimo: es un nombre de modelo, no un
  // secreto. Permite sobrevivir a que el catalogo de Google retire un nombre
  // sin tocar codigo.
  const entorno = opciones.env || process.env;
  const modelo = opciones.modelo || (entorno && entorno.GEMINI_MODELO) || MODELO_POR_DEFECTO;
  const timeoutMs = opciones.timeoutMs === undefined ? TIMEOUT_MS : opciones.timeoutMs;

  /**
   * Una llamada. `sistema` son las instrucciones; `usuario` es lo unico que
   * cambia por peticion.
   *
   * `enumeracion` y `sinRazonar` existen para el clasificador, y cierran el
   * gap de `maxOutputTokens` frente a modelos que piensan:
   *
   *   - **`enumeracion`** pide la salida con un **esquema**
   *     (`responseSchema` con `enum`) en vez de con una instruccion en prosa.
   *     La decodificacion queda restringida al conjunto, asi que el modelo no
   *     puede devolver `fuera_de_alc` —doce de los dieciseis caracteres— ni
   *     una etiqueta inventada: o sale un valor del enum, o sale un error. La
   *     instruccion en prosa PIDE; el esquema OBLIGA.
   *   - **`sinRazonar`** pone el presupuesto de razonamiento a cero. Es la
   *     otra mitad: con `gemini-3.5-flash` el clasificador devolvia respuestas
   *     VACIAS porque los tokens de pensamiento se comian el presupuesto de
   *     salida antes de emitir la etiqueta. Clasificar en un enum de tres no
   *     necesita razonar, y lo que no se gasta pensando no puede agotarse.
   *
   * Las dos son opcionales y no se aplican al redactor, que si escribe prosa.
   *
   * @param {{sistema: string, usuario: string, maxTokens?: number,
   *          temperatura?: number, enumeracion?: string[], sinRazonar?: boolean}} peticion
   * @returns {Promise<string>} el texto, ya recortado.
   */
  async function generar(peticion) {
    const generationConfig = {
      // Temperatura baja a proposito: esto no escribe poesia, reformula
      // datos que ya vienen dados. Cuanta menos libertad, menos ocasiones
      // de inventar.
      temperature: peticion.temperatura === undefined ? 0.2 : peticion.temperatura,
      maxOutputTokens: peticion.maxTokens || 300,
    };

    if (peticion.enumeracion && peticion.enumeracion.length) {
      generationConfig.responseMimeType = 'text/x.enum';
      generationConfig.responseSchema = {
        type: 'STRING',
        enum: peticion.enumeracion.slice(),
      };
    }

    if (peticion.sinRazonar) {
      // Un modelo que no soporta `thinkingConfig` lo ignora; uno que si lo
      // soporta deja de gastar presupuesto pensando. En ninguno de los dos
      // casos cambia la etiqueta que sale.
      generationConfig.thinkingConfig = { thinkingBudget: 0 };
    }

    const cuerpo = {
      system_instruction: { parts: [{ text: peticion.sistema }] },
      contents: [{ role: 'user', parts: [{ text: peticion.usuario }] }],
      generationConfig,
    };

    const control = new AbortController();
    const reloj = setTimeout(() => control.abort(), timeoutMs);

    // **El reloj cubre TAMBIEN la lectura del cuerpo, y eso es el arreglo.**
    //
    // `fetch` resuelve al llegar las CABECERAS, no al terminar el cuerpo. Con
    // el `clearTimeout` en un `finally` que envolvia solo la peticion, un
    // proveedor que mandara las cabeceras y luego se colgara streameando el
    // body dejaba la invocacion sin ninguna cota: `TIMEOUT_MS` ya estaba
    // apagado y lo unico que quedaba era el `timeoutSeconds` del callable, que
    // devuelve `internal` en vez de `deadline-exceeded`. Lo levanto el gate de
    // rendimiento, y pesa mas desde que el camino de error tambien lee el
    // cuerpo: ahora se recorre hasta tres veces por instancia fria.
    let json;
    try {
      const respuesta = await hacerPeticion(
        PUNTO_FINAL + '/' + modelo + ':generateContent',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            // En la cabecera, NUNCA en la URL: una URL acaba en los logs.
            'x-goog-api-key': apiKey,
          },
          body: JSON.stringify(cuerpo),
          signal: control.signal,
        }
      );

      if (!respuesta.ok) {
        // Del cuerpo se rescata SOLO `error.status`, que es un enum cerrado
        // de la API (`INVALID_ARGUMENT`, `PERMISSION_DENIED`...).
        // `error.message` NO: puede traer de vuelta parte de la peticion, y la
        // peticion lleva datos del usuario. Ver el comentario de
        // `deEstadoHttp`.
        //
        // Y se lee **solo donde sirve de algo**: los unicos estados que
        // consumen `estadoProveedor` son 400/401/403. Para el resto, meterse a
        // bufferizar un cuerpo sin cota —la pagina HTML de un proxy delante de
        // Google, por ejemplo— seria gasto sin diagnostico.
        let estadoProveedor = null;
        if ([400, 401, 403].indexOf(respuesta.status) !== -1) {
          try {
            const datos = await respuesta.json();
            const bruto = datos && datos.error && datos.error.status;
            if (typeof bruto === 'string' && /^[A-Z_]{1,40}$/.test(bruto)) {
              estadoProveedor = bruto;
            }
          } catch (e) {
            // Un cuerpo ilegible no cambia el diagnostico: manda el HTTP.
          }
        }
        throw deEstadoHttp(respuesta.status, estadoProveedor);
      }

      try {
        json = await respuesta.json();
      } catch (e) {
        // Un aborto sube tal cual para que lo mapee el catch de fuera: no es
        // que el modelo devolviera basura, es que se acabo el tiempo.
        if (e && (e.name === 'AbortError' || e.code === 'ABORT_ERR')) throw e;
        throw errorDeModelo(
          CODIGOS.proveedor,
          'El modelo devolvio algo que no es JSON.',
          'proveedor'
        );
      }
    } catch (e) {
      if (e && (e.name === 'AbortError' || e.code === 'ABORT_ERR')) {
        throw errorDeModelo(CODIGOS.timeout, 'El modelo no respondio a tiempo.');
      }
      // Los errores ya clasificados (`deEstadoHttp`, el JSON ilegible) pasan
      // sin tocar: envolverlos otra vez los convertiria en «no se pudo hablar
      // con el modelo», que es justo el diagnostico equivocado.
      if (e && e.code) throw e;
      throw errorDeModelo(
        CODIGOS.proveedor,
        'No se pudo hablar con el modelo.',
        'proveedor'
      );
    } finally {
      clearTimeout(reloj);
    }

    return textoDeRespuesta(json);
  }

  return { modelo, generar };
}

/**
 * El 429 tiene mensaje propio porque es el unico que el usuario puede
 * entender y esperar: «se agoto la cuota de hoy». Mapearlo al generico
 * mandaria a revisar la conexion, que es el defecto que UX-04 documento con
 * `mensajeDeError` y que INNO-01 tuvo que corregir para el pase de historial.
 */
function deEstadoHttp(estado, estadoProveedor) {
  if (estado === 429) {
    return errorDeModelo(CODIGOS.cuotaDelProveedor, 'El proveedor agoto la cuota.');
  }
  // El 404 es de CONFIGURACION, no del proveedor, y distinguirlo importa: la
  // API de Gemini devuelve 404 cuando el nombre del modelo no existe para
  // esta clave o para esta version del endpoint. Mapearlo a `unavailable`
  // dice «el proveedor esta caido» y manda a buscar el problema donde no
  // esta — el defecto exacto que UX-04 documento con `mensajeDeError`.
  // Lo destapo el spike del §3.3, que es justo para lo que servia.
  if (estado === 404) {
    return errorDeModelo(
      CODIGOS.configuracion,
      'El modelo no existe para esta clave o para esta version del endpoint. ' +
        'Lista los disponibles con `node functions/spike_gemini.js --listar`, ' +
        'compruebalos con `--probar` y fija el que sirva en GEMINI_MODELO.'
    );
  }
  // 402 Payment Required: el modelo existe y la clave es valida, pero ese
  // modelo NO esta en el free tier de este proyecto. Es distinto del 429
  // (cuota agotada, mañana vuelve) y del 404 (no existe): aqui no hay nada que
  // esperar ni que reintentar, hay que cambiar de modelo o habilitar
  // facturacion. Lo destapo el spike del §3.3.
  if (estado === 402) {
    return errorDeModelo(
      CODIGOS.configuracion,
      'El modelo requiere facturacion habilitada (402). Elige uno del free ' +
        'tier con `node functions/spike_gemini.js --probar`.'
    );
  }
  if (estado === 400 || estado === 401 || estado === 403) {
    // Sin eco del cuerpo: un 400 de Gemini puede traer de vuelta parte de la
    // peticion, y la peticion lleva datos del usuario. Solo viaja
    // `error.status`, que es un enum cerrado de la API.
    //
    // **Y la lista de sospechosos importa.** Este mensaje decia «revisa
    // GEMINI_API_KEY y el modelo» y mandaba a buscar donde no estaba: el
    // 2026-09-22 el asistente llevaba caido al 100% con la clave y el modelo
    // perfectos, y lo que el proveedor rechazaba era un campo de
    // `generationConfig`. Costo media investigacion descartar las dos pistas
    // que este texto sugeria.
    return errorDeModelo(
      CODIGOS.configuracion,
      'El proveedor rechazo la peticion (' +
        estado +
        (estadoProveedor ? ' ' + estadoProveedor : '') +
        '): revisa GEMINI_API_KEY, GEMINI_MODELO y los campos de ' +
        '`generationConfig` que este modelo pueda no soportar ' +
        '(`thinkingConfig`, `responseSchema`). Aislalos con ' +
        '`node functions/spike_gemini.js`.'
    );
  }
  return errorDeModelo(
    CODIGOS.proveedor,
    'El modelo respondio ' + estado + '.',
    // El motivo viaja al cliente; el ESTADO no. Un `unavailable` del proveedor
    // y el interruptor apagado comparten codigo, y sin esto la pantalla no
    // puede saber si reintentar sirve de algo.
    'proveedor'
  );
}

/**
 * Extrae el texto.
 *
 * Una respuesta sin candidatos NO es un fallo de red: es el filtro de
 * seguridad de Google, o un `maxOutputTokens` demasiado corto. Distinguirlo
 * importa porque lo primero no se debe reintentar nunca y lo segundo si.
 */
function textoDeRespuesta(json) {
  const candidatos = (json && json.candidates) || [];
  if (!candidatos.length) {
    const motivo = json && json.promptFeedback && json.promptFeedback.blockReason;
    throw errorDeModelo(
      CODIGOS.bloqueado,
      'El modelo no devolvio ninguna respuesta.',
      motivo || 'sin_candidatos'
    );
  }

  const candidato = candidatos[0];
  const partes = (candidato.content && candidato.content.parts) || [];
  const texto = partes
    .map((p) => (typeof p.text === 'string' ? p.text : ''))
    .join('')
    .trim();

  if (!texto) {
    // **`MAX_TOKENS` no es un bloqueo de seguridad, y meterlo en el mismo
    // `aborted` tenia una consecuencia silenciosa.** `aborted` NO esta en
    // `CODIGOS_QUE_SUBEN`, a proposito: ahi significa «el filtro del
    // proveedor se nego a mirar esto», y degradar a `fuera_de_alcance` es la
    // lectura honesta. Pero un candidato sin texto por presupuesto agotado es
    // otra cosa: es configuracion nuestra.
    //
    // El spike lo produjo de verdad — `gemini-3.5-flash` devolvio respuestas
    // VACIAS al clasificar, probablemente porque sus tokens de razonamiento
    // se comen `maxOutputTokens`. Y ahora `GEMINI_MODELO` se lee en la
    // funcion desplegada, asi que basta un `.env` para que TODA pregunta
    // caiga a `fuera_de_alcance`: nadie ve un error, no hay boton de
    // reintentar, y los logs dicen que las consultas se atendieron. Es
    // exactamente el defecto que `CODIGOS_QUE_SUBEN` existe para impedir,
    // entrando por la puerta que ese bloque no cubria.
    if (candidato.finishReason === 'MAX_TOKENS') {
      throw errorDeModelo(
        CODIGOS.configuracion,
        'El modelo agoto su presupuesto de salida sin escribir nada. Suele ' +
          'significar que el modelo configurado razona antes de responder: ' +
          'sube maxOutputTokens o elige otro en GEMINI_MODELO.',
        'proveedor'
      );
    }
    throw errorDeModelo(
      CODIGOS.bloqueado,
      'El modelo devolvio una respuesta vacia.',
      candidato.finishReason || 'sin_texto'
    );
  }
  return texto;
}

module.exports = {
  PUNTO_FINAL,
  MODELO_POR_DEFECTO,
  TIMEOUT_MS,
  CODIGOS,
  claveDelEntorno,
  crearClienteGemini,
  deEstadoHttp,
};
