'use strict';

/**
 * Endpoint unico de los formularios de la landing (contacto y afiliacion de
 * talleres).
 *
 * La landing es un export estatico de Next (`output: "export"`), asi que no
 * tiene servidor propio donde recibir un POST. Hasta UX-01 eso se resolvia mal
 * de dos maneras distintas:
 *
 *  - el formulario de contacto era `<form action="#">`: no enviaba nada;
 *  - el de afiliacion hacia un POST sin autenticar a la REST API de Firestore
 *    contra `/talleres`, cuya regla es `allow create: if isAdmin()`. Es decir,
 *    siempre 403: un formulario con estados de carga y de exito inalcanzables.
 *
 * Aqui el destino es real y el Admin SDK escribe en `solicitudes_landing`, una
 * coleccion cerrada a los clientes (ver firestore.rules). Nada de esto abre una
 * puerta nueva a `/talleres`: una solicitud es una solicitud, y el alta del
 * taller la sigue haciendo un administrador.
 *
 * Todo el estado externo (Firestore, reloj, timestamp del servidor) entra por
 * `crearManejador`, para poder ejercitar el manejador entero sin montar
 * credenciales — leer `admin.firestore` dispara `ensureApp()`.
 */

const crypto = require('crypto');

const TIPOS = ['contacto', 'afiliacion'];

// Campos que pueden llegar a un documento. Un cuerpo con claves extra no las
// arrastra: se copia campo declarado a campo declarado, nunca el objeto entero.
// Sin esto, un POST con `rol: 'Superusuario'` acabaria persistido tal cual.
const CAMPOS = {
  contacto: {
    obligatorios: ['nombre', 'correo', 'mensaje'],
    opcionales: [],
  },
  afiliacion: {
    obligatorios: ['nombre', 'correo', 'telefono', 'ubicacion'],
    opcionales: ['representante', 'especialidad'],
  },
};

const LARGO_MAXIMO = {
  nombre: 120,
  correo: 160,
  mensaje: 2000,
  telefono: 40,
  ubicacion: 120,
  representante: 120,
  especialidad: 80,
};

// Campo trampa: invisible para una persona (ver ContactForm.tsx), irresistible
// para un bot que rellena todo lo que encuentra.
const HONEYPOT = 'sitio_web';

const ORIGENES = [
  'https://autodoc.app',
  'https://www.autodoc.app',
  'https://autodoc-6ef5a.web.app',
  'https://autodoc-6ef5a.firebaseapp.com',
];

// Ventana y cupo del limitador por IP. Diez por hora es holgado para una
// persona —incluye los intentos que se van en un correo mal escrito, porque el
// cupo se cuenta ANTES de validar— y estrecho para un script.
//
// El cupo se comparte entre todos los que salen por la misma IP publica (una
// oficina tras NAT, una red movil con CGNAT). Es el precio de limitar sin
// identificar a nadie; por eso el cupo no es de tres.
const VENTANA_MS = 60 * 60 * 1000;
const LIMITE_POR_VENTANA = 10;

const COLECCION = 'solicitudes_landing';
const COLECCION_CONTROL = 'solicitudes_landing_control';

function origenPermitido(origen) {
  if (!origen) return false;
  if (ORIGENES.includes(origen)) return true;
  // Desarrollo y E2E: `next dev` y el servidor estatico de la suite.
  return /^http:\/\/localhost(:\d+)?$/.test(origen);
}

function texto(valor) {
  return typeof valor === 'string' ? valor.trim() : '';
}

// Deliberadamente laxo: aqui no se valida que el buzon exista, solo que el
// dato tenga forma de correo. Una expresion estricta rechaza direcciones
// validas y no detiene a nadie.
function correoConForma(valor) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(valor);
}

/**
 * Valida y normaliza el cuerpo. Devuelve `{ ok: true, datos }` o
 * `{ ok: false, motivo }`; el motivo es para los tests y los logs, nunca para
 * la respuesta HTTP (ver `crearManejador`).
 */
function validarSolicitud(cuerpo) {
  const entrada = cuerpo && typeof cuerpo === 'object' ? cuerpo : {};
  const tipo = texto(entrada.tipo);

  if (!TIPOS.includes(tipo)) return { ok: false, motivo: 'tipo' };

  // El honeypot se mira antes que nada: si esta relleno, lo demas da igual.
  if (texto(entrada[HONEYPOT]) !== '') {
    return { ok: false, motivo: 'honeypot', silencioso: true };
  }

  const contrato = CAMPOS[tipo];
  const datos = { tipo };

  for (const campo of contrato.obligatorios) {
    const valor = texto(entrada[campo]);
    if (valor === '') return { ok: false, motivo: 'campos' };
    datos[campo] = valor;
  }

  for (const campo of contrato.opcionales) {
    const valor = texto(entrada[campo]);
    if (valor !== '') datos[campo] = valor;
  }

  // El correo se guarda en minusculas: es el campo por el que un administrador
  // buscara despues, y 'Ana@' y 'ana@' son el mismo buzon.
  datos.correo = datos.correo.toLowerCase();
  if (!correoConForma(datos.correo)) return { ok: false, motivo: 'correo' };

  for (const [campo, valor] of Object.entries(datos)) {
    const maximo = LARGO_MAXIMO[campo];
    if (maximo && valor.length > maximo) return { ok: false, motivo: 'largo' };
  }

  return { ok: true, datos };
}

// Solo se persiste el hash: para limitar por IP basta con distinguirlas, y
// guardar la IP en claro convierte el buzon de contacto en un registro de
// datos personales que nadie pidio.
//
// El hash solo protege si la sal es secreta: el espacio IPv4 son 2^32 valores,
// asi que con la sal a la vista invertir `ip_hash` es un barrido de minutos. Por
// eso fuera del emulador la variable es OBLIGATORIA y la funcion se niega a
// arrancar sin ella, en vez de caer en una sal versionada que daria una
// sensacion de anonimato que no existe.
const SAL_DE_PRUEBAS = 'autodoc-landing-emulador';

function salDeIp() {
  const configurada = process.env.SOLICITUDES_LANDING_SALT;
  if (configurada) return configurada;
  if (process.env.FUNCTIONS_EMULATOR === 'true' || process.env.NODE_ENV === 'test') {
    return SAL_DE_PRUEBAS;
  }
  throw new Error(
    'Falta SOLICITUDES_LANDING_SALT: sin sal secreta el hash de IP es reversible.',
  );
}

function hashIp(ip) {
  return crypto.createHash('sha256').update(salDeIp() + '|' + ip).digest('hex').slice(0, 32);
}

// NUNCA el primer elemento de X-Forwarded-For.
//
// La cabecera llega como `<lo que mando el cliente>, <IP real>, <GFE>`: el
// balanceador de Google no la reemplaza, la AMPLIA por la derecha. El primer
// elemento es justo el trozo que controla quien llama, asi que leerlo deja el
// limitador en decoracion — `curl -H 'X-Forwarded-For: 10.0.$i.$j'` cae en un
// cubo distinto en cada peticion y el cupo no se toca jamas.
//
// La IP real es la penultima cuando hay un proxy delante (el caso normal en
// Cloud Functions) y la unica cuando la cadena trae un solo elemento. Se
// prefiere esto a `req.ip` porque si el framework no tuviera `trust proxy`
// activo, `req.ip` seria la IP interna del proxy: TODO el trafico caeria en un
// unico cubo y el cupo se convertiria en un limite global de diez envios por
// hora para el mundo entero. Un limitador que falla asi tumba la landing
// entera, no solo al atacante.
function ipDe(req) {
  const cruda = (req.headers && req.headers['x-forwarded-for']) || '';
  // Acotar antes de partir: la cadena la puede inflar quien llama.
  const partes = String(cruda).slice(0, 512).split(',').map((p) => p.trim()).filter(Boolean);
  if (partes.length >= 2) return partes[partes.length - 2];
  if (partes.length === 1) return partes[0];
  return req.ip || 'desconocida';
}

/**
 * Cupo por IP con un contador transaccional en vez de una consulta por rango.
 * Contar documentos de la ventana obligaria a un indice compuesto y a leer N
 * documentos por peticion; el contador es una lectura y una escritura fijas.
 */
async function dentroDelCupo(db, ipHash, ahoraMs) {
  const ref = db.collection(COLECCION_CONTROL).doc(ipHash);
  return db.runTransaction(
    async (tx) => {
      const snap = await tx.get(ref);
      const previo = snap.exists ? snap.data() : null;
      const inicio = previo && previo.ventana_inicio ? previo.ventana_inicio : 0;
      const vigente = ahoraMs - inicio < VENTANA_MS;
      const conteo = vigente ? previo.conteo || 0 : 0;

      if (conteo >= LIMITE_POR_VENTANA) return false;

      const arranque = vigente ? inicio : ahoraMs;
      tx.set(ref, {
        ventana_inicio: arranque,
        conteo: conteo + 1,
        // Para la politica TTL de Firestore sobre este campo: sin ella la
        // coleccion crece un documento por IP y no se borra nunca, aunque solo
        // se lea durante una hora. Tiene que ser Timestamp, no milisegundos.
        expira_en: new Date(arranque + VENTANA_MS),
      });
      return true;
    },
    // Dos intentos, no los cinco por defecto: cada reintento repite el `get`, y
    // las peticiones que se pisan sobre el mismo cubo son justo las de un
    // ataque. Es mejor rechazar rapido que multiplicar por cinco las lecturas.
    { maxAttempts: 2 },
  );
}

function crearManejador(opciones) {
  const db = opciones.db;
  const ahora = opciones.ahora || (() => Date.now());
  const timestamp = opciones.timestamp;

  return async function manejador(req, res) {
    const origen = req.headers ? req.headers.origin : undefined;

    // Un origen desconocido no recibe cabeceras CORS ni respuesta util. No es
    // una barrera de seguridad —CORS no autentica a nadie— pero evita que la
    // landing de otro sea la que rellene este buzon.
    if (origen && !origenPermitido(origen)) {
      return res.status(403).json({ ok: false, error: 'origen_no_permitido' });
    }
    if (origen) {
      res.set('Access-Control-Allow-Origin', origen);
      res.set('Vary', 'Origin');
      res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Content-Type');
      res.set('Access-Control-Max-Age', '3600');
    }

    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') {
      return res.status(405).json({ ok: false, error: 'metodo_no_permitido' });
    }

    // El cupo se cuenta ANTES de validar, a proposito. Si se contara despues,
    // una peticion basura —o una con el honeypot relleno— no gastaria cupo y
    // el bot podria repetirla sin fin: se ahorraria la escritura, pero cada
    // intento sigue costando una invocacion, que es el gasto dominante aqui.
    try {
      // Dentro del try: si falta la sal, `hashIp` lanza, y una excepcion suelta
      // aqui mataria la instancia en vez de devolver un error.
      const ipHash = hashIp(ipDe(req));

      if (!(await dentroDelCupo(db, ipHash, ahora()))) {
        return res.status(429).json({ ok: false, error: 'demasiadas_solicitudes' });
      }

      const validacion = validarSolicitud(req.body);

      // Al bot se le responde exactamente lo mismo que a una persona. Decirle
      // "honeypot detectado" seria ensenarle cual es el campo trampa.
      if (!validacion.ok && validacion.silencioso) {
        return res.status(200).json({ ok: true });
      }
      if (!validacion.ok) {
        // Un solo codigo para todos los motivos: el detalle vale para depurar,
        // no para quien envia. Un error por campo es un oraculo de validacion.
        return res.status(400).json({ ok: false, error: 'datos_invalidos' });
      }

      const documento = Object.assign({}, validacion.datos, {
        estado: 'nueva',
        origen: 'landing_web',
        ip_hash: ipHash,
        creado_en: timestamp ? timestamp() : new Date(ahora()).toISOString(),
      });

      await db.collection(COLECCION).add(documento);

      return res.status(200).json({ ok: true });
    } catch (e) {
      // Sin este catch, un fallo de Firestore (transaccion abortada, cuota,
      // UNAVAILABLE) escapa como unhandled rejection: el runtime de Functions
      // MATA la instancia y escribe su error sobre la respuesta de la ultima
      // peticion vista por el proceso, que puede ser la de otra persona. Y esa
      // respuesta sale sin las cabeceras CORS, asi que en el navegador se ve
      // como un error opaco de CORS en lugar de como un fallo del servidor.
      console.error('recibirSolicitudLanding fallo:', e);
      return res.status(503).json({ ok: false, error: 'no_disponible' });
    }
  };
}

module.exports = {
  validarSolicitud,
  crearManejador,
  origenPermitido,
  hashIp,
  TIPOS,
  LIMITE_POR_VENTANA,
  VENTANA_MS,
  COLECCION,
  COLECCION_CONTROL,
};
