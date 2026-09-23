#!/usr/bin/env node
'use strict';

/**
 * Spike del §3.3 del plan del asistente de agenda. **Timebox: 2 horas.**
 *
 * Responde a UNA pregunta: ¿contesta Gemini desde aqui, con esta clave, con el
 * nombre de modelo que el codigo trae por defecto, y en un tiempo que un
 * usuario aguante? Si la respuesta es no, el plan se aborta y se pierde medio
 * dia en vez de cinco. Es el unico punto de salida barato que tiene este
 * trabajo.
 *
 * Ejercita **el cliente real** (`src/modeloGemini.js`), no un throwaway: lo
 * que aprenda aqui vale para el callable. Y ejercita los dos trabajos que el
 * modelo va a hacer en produccion, que son distintos entre si:
 *
 *   1. CLASIFICAR — devolver una etiqueta de un enum cerrado. Lo que se mide
 *      es si se ciñe al enum, no si acierta.
 *   2. REDACTAR — convertir un envelope ya calculado en prosa. Lo que se mide
 *      es si respeta los numeros que se le dan y si se inventa fechas.
 *
 * No toca Firestore, no despliega nada, no lee datos de nadie: el envelope de
 * abajo esta escrito a mano.
 *
 *   PowerShell:  $env:GEMINI_API_KEY='...'; node functions/spike_gemini.js
 *   bash:        GEMINI_API_KEY=... node functions/spike_gemini.js
 *
 * La clave se lee del entorno y no se imprime nunca.
 */

const { claveDelEntorno, crearClienteGemini, MODELO_POR_DEFECTO } = require('./src/modeloGemini');

/**
 * **El enum, el presupuesto y el prompt del clasificador se IMPORTAN.**
 *
 * Aqui habia una copia a mano, y no era inocua: llevaba cinco etiquetas
 * cuando produccion tiene tres, su propio prompt y su propio presupuesto. Un
 * eval que mide un prompt copiado no mide nada — el propio `asistente.js` lo
 * dice en sus exports, y aun asi la copia seguia aqui.
 */
const {
  INTENCIONES,
  MAX_TOKENS_ETIQUETA,
  MAX_TOKENS_ETIQUETA_PENSANDO,
  SISTEMA_CLASIFICADOR,
} = require('./src/asistente');

const SISTEMA_REDACTOR =
  'Eres el asistente de AutoDoc. Te doy los compromisos del vehiculo del ' +
  'usuario ya calculados, en JSON. Redacta una respuesta breve en espanol, ' +
  'maximo 4 frases.\n\n' +
  'REGLAS:\n' +
  '- No inventes NINGUN dato que no este en el JSON. Si falta, dilo.\n' +
  '- NO calcules ni menciones fechas del calendario. Usa los dias que te doy ' +
  'tal cual ("en 3 dias").\n' +
  '- El mantenimiento va SIEMPRE en kilometros, nunca en dias ni en fechas.\n' +
  '- dias_restantes negativo significa VENCIDO hace esos dias.\n' +
  '- Si un item trae "inconsistente", di que el kilometraje registrado no ' +
  'cuadra y que conviene actualizarlo. No estimes nada sobre el.';

// Escrito a mano, con los casos que mas facil le resultaria estropear a un
// modelo: un vencido, un mantenimiento (que NO puede salir con fecha) y un
// odometro inconsistente.
const ENVELOPE = {
  rol: 'propietario',
  ventana_dias: 30,
  items: [
    { tipo: 'soat', placa: 'ABC123', dias_restantes: -10 },
    { tipo: 'tarjeta', placa: 'ABC123', dias_restantes: 3 },
    { tipo: 'cita', dias_restantes: 2, hora: '14:00', tipo_servicio: 'Cambio de aceite' },
    { tipo: 'mantenimiento', placa: 'ABC123', nombre: 'Frenos', km_restantes: 200 },
    { tipo: 'mantenimiento', placa: 'XYZ789', nombre: 'Aceite', inconsistente: true },
  ],
};

const PREGUNTAS = [
  ['que alertas tengo en los proximos dias', 'agenda'],
  ['que es el SOAT y que pasa si se vence', 'explicar'],
  ['por que suena raro el motor cuando freno', 'fuera_de_alcance'],
  ['cual es la capital de Francia', 'fuera_de_alcance'],
];

/**
 * Modo `--listar`: pregunta a la API que modelos existen PARA ESTA CLAVE.
 *
 * Existe porque el primer spike murio con 404 en las cinco llamadas, y un 404
 * de Gemini no dice cual de las dos cosas esta mal: el nombre del modelo o la
 * version del endpoint. Adivinar nombres a mano es lo que este modo evita — la
 * respuesta autoritativa la tiene la propia clave.
 *
 * Se prueban las dos versiones del endpoint porque el catalogo NO es el mismo
 * en `v1` y en `v1beta`, y un modelo puede existir en una y no en la otra.
 */
async function listar(clave) {
  for (const version of ['v1beta', 'v1']) {
    const url = 'https://generativelanguage.googleapis.com/' + version + '/models';
    process.stdout.write('\n--- ' + version + ' ---------------------------------------------\n');
    try {
      const respuesta = await fetch(url, { headers: { 'x-goog-api-key': clave } });
      if (!respuesta.ok) {
        console.log('  HTTP ' + respuesta.status + ' — esta version no responde con esta clave.');
        continue;
      }
      const json = await respuesta.json();
      const modelos = (json.models || [])
        // Solo los que sirven para lo que hacemos: generar contenido.
        .filter((m) => (m.supportedGenerationMethods || []).indexOf('generateContent') !== -1)
        .map((m) => String(m.name || '').replace(/^models\//, ''));

      if (!modelos.length) {
        console.log('  ninguno admite generateContent.');
        continue;
      }
      // Flash primero: es el unico con cuota gratuita util (~1500 req/dia).
      const flash = modelos.filter((n) => n.indexOf('flash') !== -1);
      const resto = modelos.filter((n) => n.indexOf('flash') === -1);
      for (const n of flash) console.log('  [flash] ' + n);
      for (const n of resto) console.log('          ' + n);
    } catch (e) {
      console.log('  no se pudo consultar: ' + (e && e.message ? e.message : e));
    }
  }
  console.log('');
  console.log('Elige uno de los [flash] y relanza el spike asi:');
  console.log("  $env:GEMINI_MODELO='<nombre>'; node functions/spike_gemini.js");
}

/**
 * Modo `--probar`: **llama de verdad** a cada candidato y dice que devuelve.
 *
 * `--listar` no basta, y eso es lo que aprendimos a base de round-trips:
 * `gemini-2.5-flash` aparece en el catalogo de las DOS versiones y aun asi
 * responde 404 a `generateContent`, mientras que `gemini-3.1-flash-lite`
 * responde 402. O sea que **estar en la lista no significa que se pueda
 * usar**, y los tres motivos por los que no se puede son distintos entre si:
 *
 *   404  el nombre no sirve para generar contenido por esa version.
 *   402  existe, pero requiere facturacion: no esta en el free tier.
 *   429  esta bien, pero se agoto la cuota (se reintenta mas tarde).
 *   200  sirve.
 *
 * Ninguna documentacion responde esto para UNA clave concreta. La unica
 * respuesta autoritativa es llamar.
 *
 * Las llamadas son minimas (un token de salida) y van en serie con una pausa,
 * porque el free tier son 10 peticiones por minuto y un barrido en paralelo se
 * comeria la cuota del dia con 429 que no significan nada.
 */
async function probar(clave) {
  // Curado a proposito: solo Flash —lo unico con cuota gratuita util— y sin
  // las variantes de imagen, audio o TTS, que no generan texto.
  const CANDIDATOS = [
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.6-flash',
    'gemini-3.1-flash-lite',
  ];

  const pausa = (ms) => new Promise((r) => setTimeout(r, ms));
  const sirven = [];

  for (const version of ['v1beta', 'v1']) {
    process.stdout.write('\n--- ' + version + ' ---------------------------------------------\n');
    for (const modelo of CANDIDATOS) {
      const url =
        'https://generativelanguage.googleapis.com/' + version + '/models/' + modelo +
        ':generateContent';
      let veredicto;
      try {
        const t0 = Date.now();
        const respuesta = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'x-goog-api-key': clave },
          body: JSON.stringify({
            contents: [{ role: 'user', parts: [{ text: 'di solo: ok' }] }],
            generationConfig: { maxOutputTokens: 5, temperature: 0 },
          }),
        });
        const ms = Date.now() - t0;
        if (respuesta.ok) {
          veredicto = 'SIRVE (' + ms + ' ms)';
          sirven.push({ version, modelo, ms });
        } else if (respuesta.status === 402) {
          veredicto = '402 requiere facturacion: fuera del free tier';
        } else if (respuesta.status === 404) {
          veredicto = '404 no disponible para generateContent en ' + version;
        } else if (respuesta.status === 429) {
          veredicto = '429 cuota agotada — SIRVE, pero hoy no responde';
        } else {
          veredicto = String(respuesta.status);
        }
      } catch (e) {
        veredicto = 'error de red: ' + (e && e.message ? e.message : e);
      }
      console.log('  ' + modelo.padEnd(28) + veredicto);
      // 10 RPM en el free tier: ~7 s entre llamadas seria lo correcto, pero
      // los que fallan por 402/404 no consumen cuota. 400 ms basta para no
      // disparar el limitador con los que si responden.
      await pausa(400);
    }
  }

  console.log('');
  console.log('===============================================================');
  if (!sirven.length) {
    console.log('NINGUN candidato responde. El plan se aborta aqui: sin un modelo del');
    console.log('free tier, esta feature necesita facturacion habilitada y eso es una');
    console.log('decision de presupuesto, no de codigo.');
    process.exitCode = 1;
    return;
  }
  const mejor = sirven[0];
  console.log('SIRVEN ' + sirven.length + '. El mas conservador es:');
  console.log('  ' + mejor.modelo + '  (' + mejor.version + ')');
  console.log('');
  console.log("  $env:GEMINI_MODELO='" + mejor.modelo + "'; node functions/spike_gemini.js");
  if (mejor.version !== 'v1beta') {
    console.log('');
    console.log('OJO: solo responde en ' + mejor.version + ', asi que hay que cambiar');
    console.log('PUNTO_FINAL en functions/src/modeloGemini.js, no solo el nombre.');
  }
}

async function main() {
  const clave = claveDelEntorno();

  if (process.argv.indexOf('--listar') !== -1) {
    console.log('Clave: presente (' + clave.length + ' caracteres, no se imprime)');
    return listar(clave);
  }

  if (process.argv.indexOf('--probar') !== -1) {
    console.log('Clave: presente (' + clave.length + ' caracteres, no se imprime)');
    return probar(clave);
  }

  const modelo = process.env.GEMINI_MODELO || MODELO_POR_DEFECTO;
  const cliente = crearClienteGemini({ apiKey: clave, modelo });

  console.log('Modelo:', modelo);
  console.log('Clave: presente (' + clave.length + ' caracteres, no se imprime)');
  console.log('');

  let fallos = 0;

  // **Los DOS escalones de la escalera, no solo el primero.**
  //
  // El escalon 1 es la peticion que produjo el 400 del 2026-09-22, asi que
  // sirve para reproducir el incidente. Pero el que atiende el trafico es el
  // 2 —`clasificar` degrada el razonamiento y conserva el enum—, y sin
  // medirlo aqui no hay ninguna comprobacion contra la API real del camino
  // que de verdad corre en produccion. Lo levanto el gate de rendimiento.
  const ESCALONES = [
    { nombre: '1. CLASIFICAR (escalon 1: enum + sinRazonar)', sinRazonar: true, maxTokens: MAX_TOKENS_ETIQUETA },
    { nombre: '1b. CLASIFICAR (escalon 2: enum, razonando)', sinRazonar: false, maxTokens: MAX_TOKENS_ETIQUETA_PENSANDO },
  ];
  for (const escalon of ESCALONES) {
  console.log('--- ' + escalon.nombre + ' ---------------');
  for (const [pregunta, esperada] of PREGUNTAS) {
    const t0 = Date.now();
    try {
      // **Llama EXACTAMENTE como produccion.** Sin `enumeracion` ni
      // `sinRazonar` este spike no tocaba el camino real, y por ese hueco
      // paso el 400 de `thinkingConfig` que dejo el asistente caido al 100%
      // el 2026-09-22: el spike daba verde sobre un asistente averiado.
      const bruto = await cliente.generar({
        sistema: SISTEMA_CLASIFICADOR,
        usuario: pregunta,
        maxTokens: escalon.maxTokens,
        temperatura: 0,
        enumeracion: INTENCIONES,
        sinRazonar: escalon.sinRazonar,
      });
      const etiqueta = bruto.trim().toLowerCase();
      // En produccion, cualquier cosa fuera del enum cae a
      // `fuera_de_alcance`: no se reintenta ni se interpreta.
      const enElEnum = INTENCIONES.indexOf(etiqueta) !== -1;
      const marca = !enElEnum ? 'FUERA DEL ENUM' : etiqueta === esperada ? 'ok' : 'distinta';
      if (!enElEnum) fallos += 1;
      console.log(
        '  [' + marca + '] ' + (Date.now() - t0) + ' ms  "' + pregunta + '"' + '\n' +
          '      esperada: ' + esperada + '   devuelta: ' + JSON.stringify(bruto)
      );
    } catch (e) {
      fallos += 1;
      console.log('  [ERROR ' + (e.code || '?') + '] ' + e.message);
    }
  }

  }

  console.log('');
  console.log('--- 2. REDACTAR -----------------------------------------------');
  const t0 = Date.now();
  try {
    const prosa = await cliente.generar({
      sistema: SISTEMA_REDACTOR,
      usuario: JSON.stringify(ENVELOPE),
      maxTokens: 300,
    });
    console.log('  ' + (Date.now() - t0) + ' ms');
    console.log('  ---8<---');
    console.log(prosa.split('\n').map((l) => '  ' + l).join('\n'));
    console.log('  ---8<---');
    console.log('');
    console.log('  Revisalo A MANO. Lo que invalida el spike:');
    console.log('   - cualquier fecha de calendario (el envelope no lleva ninguna)');
    console.log('   - el mantenimiento expresado en dias en vez de en km');
    console.log('   - decir que al SOAT le quedan 10 dias (esta VENCIDO hace 10)');
    const fechas = prosa.match(/\b\d{1,2}\s+de\s+\p{L}+/giu) || [];
    if (fechas.length) {
      console.log('   !! detectadas posibles fechas inventadas: ' + JSON.stringify(fechas));
      fallos += 1;
    }
  } catch (e) {
    fallos += 1;
    console.log('  [ERROR ' + (e.code || '?') + '] ' + e.message);
  }

  console.log('');
  console.log('===============================================================');
  if (fallos) {
    console.log('SPIKE CON ' + fallos + ' PROBLEMA(S). Leelos antes de seguir al dia 2.');
    process.exitCode = 1;
  } else {
    console.log('SPIKE OK. El camino del §5 es viable.');
  }
}

main().catch((e) => {
  console.error('[' + (e.code || 'error') + '] ' + e.message);
  // El mensaje de `claveDelEntorno` habla de Secret Manager porque esta
  // escrito para la funcion DESPLEGADA, que es quien lo usa. El spike corre
  // en tu maquina y lee la variable de entorno de esta shell: tener el
  // secreto bien puesto en Secret Manager no le sirve de nada. Costo un viaje
  // de ida y vuelta averiguarlo, asi que aqui queda dicho.
  if (/GEMINI_API_KEY/.test(e.message || '')) {
    console.error('');
    console.error('El spike NO lee Secret Manager: lee la variable de entorno de esta shell.');
    console.error('Traetela del propio secreto para esta corrida (PowerShell):');
    console.error('');
    console.error(
      "  $env:GEMINI_API_KEY = ((firebase functions:secrets:access GEMINI_API_KEY " +
        "--project production) -join '').Trim()"
    );
    console.error('  node functions/spike_gemini.js --probar');
    console.error('');
    console.error('Se pierde al cerrar la terminal; es a proposito.');
  }
  process.exitCode = 1;
});
