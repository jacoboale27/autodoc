// Script de un solo uso para poblar una demo con interacciones REALISTAS entre
// propietarios y un taller: conversación con mensajes, dos reservas (una
// pendiente y una confirmada), un servicio ya completado (historial) y la
// reseña que el propietario dejó sobre ese servicio.
//
// POR QUÉ EXISTE
//
// Para la demo hace falta que las pantallas de chat, citas, servicios y
// reseñas no se vean vacías. Crear eso a mano desde la UI implicaría escribir
// cada mensaje y esperar los listeners; este script usa el Admin SDK para
// escribirlo todo de una vez, en el mismo formato que espera el cliente
// (mismos nombres de campo que ConversacionModel, MensajeModel, ReservaModel,
// la colección `servicios` y ReviewModel — ver
// lib/features/chat/data/models/*.dart,
// lib/features/dashboard/presentation/providers/alert_provider.dart y
// lib/core/models/review_model.dart).
//
// Reutiliza cuentas de QA ya existentes en producción en vez de crear cuentas
// nuevas. Por defecto siembra interacciones entre CINCO propietarios
// (nadie@gmail.com y las cuatro cuentas nuevas pedidas para la demo) y UN
// taller (taller1@taller.com). Si alguna cuenta no existe, el script falla
// con un mensaje claro en vez de crearla por su cuenta.
//
// Respeta el invariante "quien propone no resuelve" (docs/superpowers, commit
// ad0bc14): la reserva confirmada la propuso el taller y la aceptó el
// propietario; la pendiente la propuso el propietario y queda a la espera de
// que el taller la acepte/cotice.
//
// IDs deterministas por propietario (`demo-<slug>-...`) para que correr el
// script dos veces no duplique nada: la segunda corrida sobreescribe los
// mismos documentos. `nadie@gmail.com` conserva los IDs originales
// (`demo-vehiculo-corolla`, `demo-conversacion-1`, ...) para no duplicar ni
// huérfanar lo que ya está en producción de antes de que este script
// sembrara varias cuentas.
//
// Uso (contra producción, con functions/serviceAccountKey.json ya presente):
//   node seed_demo_interacciones.js                  # dry-run: informa, no escribe
//   node seed_demo_interacciones.js --apply           # escribe de verdad, las 5 cuentas
//   node seed_demo_interacciones.js --apply --propietario-email otro@x.com --taller-email otro@taller.com
//
// Uso (contra el emulador, para probar el script antes de tocar producción):
//   FIRESTORE_EMULATOR_HOST=localhost:8080 FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
//     node seed_demo_interacciones.js --apply

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS
  || path.join(__dirname, 'serviceAccountKey.json');

if (!process.env.FIRESTORE_EMULATOR_HOST && fs.existsSync(keyPath)) {
  admin.initializeApp({
    credential: admin.credential.cert(require(keyPath)),
    projectId: 'autodoc-6ef5a',
  });
} else {
  admin.initializeApp({ projectId: 'autodoc-6ef5a' });
}

const auth = admin.auth();
const db = admin.firestore();

const APPLY = process.argv.includes('--apply');

function argValue(flag, fallback) {
  const idx = process.argv.indexOf(flag);
  return idx !== -1 ? process.argv[idx + 1] : fallback;
}

const TALLER_EMAIL = argValue('--taller-email', 'taller1@taller.com');
const PROPIETARIO_EMAIL_OVERRIDE = argValue('--propietario-email', null);

// Cuentas de propietario que reciben interacciones con el taller. La cuarteta
// nueva son cuentas de QA ya creadas para la demo; se mantiene nadie@gmail.com
// porque ya tiene historial en producción de corridas anteriores del script.
const DEFAULT_PROPIETARIO_EMAILS = [
  'nadie@gmail.com',
  'Jon@gmail.com',
  'Georges@gmail.com',
  'Khabib@gmail.com',
  'Demetrious@gmail.com',
];

const PROPIETARIO_EMAILS = PROPIETARIO_EMAIL_OVERRIDE
  ? [PROPIETARIO_EMAIL_OVERRIDE]
  : DEFAULT_PROPIETARIO_EMAILS;

// Un vehículo y una narrativa distintos por cuenta para que la demo no se vea
// repetida entre propietarios. Se indexan por el slug derivado del correo
// (ver `slugify`); `nadie` usa el Corolla original.
const PERFILES = {
  nadie: {
    vehiculo: { marca: 'Toyota', modelo: 'Corolla', anio: 2019, placa: 'DEMO-001', kilometraje_actual: 52000 },
    problema: 'un ruido raro al frenar',
    servicio: 'Revisión de frenos y cambio de aceite',
  },
  jon: {
    vehiculo: { marca: 'Honda', modelo: 'Civic', anio: 2020, placa: 'DEMO-002', kilometraje_actual: 38000 },
    problema: 'que el aire acondicionado ya no enfría',
    servicio: 'Revisión de aire acondicionado y cambio de aceite',
  },
  georges: {
    vehiculo: { marca: 'Ford', modelo: 'Ranger', anio: 2018, placa: 'DEMO-003', kilometraje_actual: 71000 },
    problema: 'una vibración en el volante a alta velocidad',
    servicio: 'Balanceo y alineación',
  },
  khabib: {
    vehiculo: { marca: 'Toyota', modelo: 'Hilux', anio: 2021, placa: 'DEMO-004', kilometraje_actual: 45000 },
    problema: 'que la suspensión suena al pasar sobre baches',
    servicio: 'Revisión de suspensión delantera',
  },
  demetrious: {
    vehiculo: { marca: 'Mazda', modelo: '3', anio: 2019, placa: 'DEMO-005', kilometraje_actual: 29000 },
    problema: 'que el motor tarda en encender en las mañanas',
    servicio: 'Diagnóstico de batería y sistema de encendido',
  },
};

function slugify(email) {
  const local = email.split('@')[0].toLowerCase();
  return PERFILES[local] ? local : local.replace(/[^a-z0-9]/g, '') || 'demo';
}

function idsFor(slug) {
  if (slug === 'nadie') {
    return {
      vehiculo: 'demo-vehiculo-corolla',
      conversacion: 'demo-conversacion-1',
      reservaPendiente: 'demo-reserva-pendiente',
      reservaConfirmada: 'demo-reserva-confirmada',
      servicioHistorico: 'demo-servicio-historico',
    };
  }
  return {
    vehiculo: `demo-vehiculo-${slug}`,
    conversacion: `demo-conversacion-${slug}`,
    reservaPendiente: `demo-reserva-pendiente-${slug}`,
    reservaConfirmada: `demo-reserva-confirmada-${slug}`,
    servicioHistorico: `demo-servicio-historico-${slug}`,
  };
}

function horaHoy(hora, minutos = 0) {
  const d = new Date();
  d.setHours(hora, minutos, 0, 0);
  return admin.firestore.Timestamp.fromDate(d);
}

function enDias(dias, hora, minutos = 0) {
  const d = new Date();
  d.setDate(d.getDate() + dias);
  d.setHours(hora, minutos, 0, 0);
  return admin.firestore.Timestamp.fromDate(d);
}

function haceMeses(meses, hora, minutos = 0) {
  const d = new Date();
  d.setMonth(d.getMonth() - meses);
  d.setHours(hora, minutos, 0, 0);
  return admin.firestore.Timestamp.fromDate(d);
}

/// Arma todo lo que hace falta escribir (batch) para UN propietario, dado su
/// uid/nombre y los del taller ya resueltos. `mesesAtras` desfasa el servicio
/// histórico entre cuentas para que las fechas de la demo no sean idénticas.
function construirDatosPropietario({
  propietarioUid,
  nombrePropietario,
  tallerUid,
  nombreTaller,
  slug,
  mesesAtras,
  vehiculosExistentes,
}) {
  const ids = idsFor(slug);
  const perfil = PERFILES[slug] || PERFILES.nadie;

  let vehiculoId;
  let vehiculoDatos;
  let vehiculoNuevo;
  if (!vehiculosExistentes.empty) {
    vehiculoId = vehiculosExistentes.docs[0].id;
    vehiculoDatos = vehiculosExistentes.docs[0].data();
    vehiculoNuevo = false;
  } else {
    vehiculoId = ids.vehiculo;
    vehiculoDatos = {
      id_propietario: propietarioUid,
      ...perfil.vehiculo,
    };
    vehiculoNuevo = true;
  }

  const mensajes = [
    {
      id: `${ids.conversacion}-msg-1`,
      id_remitente: propietarioUid,
      contenido: `Hola, mi carro tiene ${perfil.problema}, ¿podrían revisarlo?`,
      tipo: 'texto',
      timestamp: horaHoy(9, 0),
      estado: 'visto',
    },
    {
      id: `${ids.conversacion}-msg-2`,
      id_remitente: tallerUid,
      contenido: '¡Hola! Claro que sí. ¿Qué vehículo es y hace cuánto fue la última revisión?',
      tipo: 'texto',
      timestamp: horaHoy(9, 4),
      estado: 'visto',
    },
    {
      id: `${ids.conversacion}-msg-3`,
      id_remitente: propietarioUid,
      contenido: `Es un ${vehiculoDatos.marca} ${vehiculoDatos.modelo} ${vehiculoDatos.anio}, placa ${vehiculoDatos.placa}.`,
      tipo: 'texto',
      timestamp: horaHoy(9, 6),
      estado: 'visto',
    },
    {
      id: `${ids.conversacion}-msg-4`,
      id_remitente: tallerUid,
      contenido: `Perfecto, te propongo una cita para ${perfil.servicio.toLowerCase()}. Te dejo la propuesta aquí abajo.`,
      tipo: 'texto',
      timestamp: horaHoy(9, 8),
      estado: 'visto',
    },
    {
      id: `${ids.conversacion}-msg-5`,
      id_remitente: tallerUid,
      contenido: 'Cita propuesta',
      tipo: 'reserva_card',
      metadata: { id_reserva: ids.reservaConfirmada },
      timestamp: horaHoy(9, 9),
      estado: 'visto',
    },
    {
      id: `${ids.conversacion}-msg-6`,
      id_remitente: propietarioUid,
      contenido: 'Me parece bien, ahí estaré. ¡Gracias!',
      tipo: 'texto',
      timestamp: horaHoy(9, 15),
      estado: 'visto',
    },
    {
      id: `${ids.conversacion}-msg-7`,
      id_remitente: tallerUid,
      contenido: 'Servicio finalizado',
      tipo: 'review_card',
      metadata: { tallerNombre: nombreTaller, estado: 'completada' },
      timestamp: horaHoy(9, 20),
      estado: 'visto',
    },
    {
      id: `${ids.conversacion}-msg-8`,
      id_remitente: propietarioUid,
      contenido: 'De paso, ¿también podrían revisar la suspensión otro día?',
      tipo: 'texto',
      timestamp: horaHoy(9, 25),
      estado: 'entregado',
    },
  ];

  const ultimoMensaje = mensajes[mensajes.length - 1];

  const conversacionDatos = {
    id_propietario: propietarioUid,
    id_mecanico: tallerUid,
    nombre_propietario: nombrePropietario,
    nombre_mecanico: nombreTaller,
    id_taller: tallerUid,
    id_vehiculo: vehiculoId,
    ultimo_mensaje: ultimoMensaje.contenido,
    ultimo_mensaje_ts: ultimoMensaje.timestamp,
    // El último mensaje lo mandó el propietario: queda 1 sin leer para el
    // taller, así la demo muestra el badge de no leídos en ese lado.
    no_leidos_propietario: 0,
    no_leidos_mecanico: 1,
    estado: 'activo',
  };

  const reservaConfirmadaDatos = {
    id_conversacion: ids.conversacion,
    id_propietario: propietarioUid,
    id_mecanico: tallerUid,
    id_vehiculo: vehiculoId,
    id_taller: tallerUid,
    id_proponente: tallerUid,
    fecha_hora_propuesta: enDias(1, 9, 0),
    fecha_hora_confirmada: enDias(1, 9, 0),
    tipo_servicio: perfil.servicio,
    descripcion: `${perfil.problema[0].toUpperCase()}${perfil.problema.slice(1)}, reportado por el propietario.`,
    estado: 'confirmada',
    cotizacion_estimada: 65,
    recordatorio_enviado_24h: false,
    recordatorio_enviado_1h: false,
    fecha_creacion: horaHoy(9, 9),
  };

  const reservaPendienteDatos = {
    id_conversacion: ids.conversacion,
    id_propietario: propietarioUid,
    id_mecanico: tallerUid,
    id_vehiculo: vehiculoId,
    id_taller: tallerUid,
    id_proponente: propietarioUid,
    fecha_hora_propuesta: enDias(3, 15, 0),
    tipo_servicio: 'Revisión de suspensión',
    descripcion: 'Seguimiento pedido por el propietario en el chat.',
    estado: 'pendiente',
    recordatorio_enviado_24h: false,
    recordatorio_enviado_1h: false,
    fecha_creacion: horaHoy(9, 25),
  };

  const fechaServicioHistorico = haceMeses(mesesAtras, 11, 0);

  const servicioHistoricoDatos = {
    id_vehiculo: vehiculoId,
    id_propietario: propietarioUid,
    id_taller: tallerUid,
    tipo_servicio: perfil.servicio,
    fecha: fechaServicioHistorico,
    kilometraje_servicio: vehiculoDatos.kilometraje_actual ? vehiculoDatos.kilometraje_actual - 3000 : 49000,
    descripcion: `${perfil.servicio} realizado sin novedad.`,
    costo: 45,
    mano_de_obra: 20,
    // Lista de repuestos (ServiceRecordModel.materiales / CotizacionItem),
    // NO un monto: un numero suelto aqui rompe `List.from` al leerlo en
    // "Mis Servicios" con un TypeError de Iterable para TODO el historial
    // del taller, no solo para este documento.
    materiales: [
      { nombre: 'Aceite sintético 5W-30', costo: 15 },
      { nombre: 'Filtro de aceite', costo: 10 },
    ],
    estado: 'completado',
  };

  // Reseña que el propietario dejó sobre ese servicio histórico. Mismo id
  // determinista que usa ReviewService._reviewDocId (idServicio_userId), así
  // ReviewChatCard/mechanic_reviews_screen la reconocen como "ya reseñado".
  const reseniaId = `${ids.servicioHistorico}_${propietarioUid}`;
  const reseniaDatos = {
    id_resenia: reseniaId,
    id_usuario: propietarioUid,
    id_taller: tallerUid,
    id_servicio: ids.servicioHistorico,
    estrellas: 5,
    comentario: `Excelente atención con el ${vehiculoDatos.marca} ${vehiculoDatos.modelo}, quedó como nuevo.`,
    fecha_resenia: haceMeses(mesesAtras, 12, 0),
    is_reported: false,
    fotos: [],
  };

  return {
    ids,
    vehiculoId,
    vehiculoDatos,
    vehiculoNuevo,
    mensajes,
    conversacionDatos,
    reservaConfirmadaDatos,
    reservaPendienteDatos,
    servicioHistoricoDatos,
    reseniaId,
    reseniaDatos,
  };
}

async function main() {
  console.log(APPLY ? 'MODO APLICAR' : 'MODO DRY-RUN (no escribe nada)');
  console.log(`Propietarios: ${PROPIETARIO_EMAILS.join(', ')}`);
  console.log(`Taller:       ${TALLER_EMAIL}`);
  console.log('---');

  const tallerUser = await auth.getUserByEmail(TALLER_EMAIL).catch(() => null);
  if (!tallerUser) {
    throw new Error(`No existe ningún usuario de Auth con el correo ${TALLER_EMAIL}. Créalo desde la app o pasa --taller-email.`);
  }
  const tallerUid = tallerUser.uid;

  const [tallerUsuarioDoc, tallerDoc] = await Promise.all([
    db.collection('usuarios').doc(tallerUid).get(),
    db.collection('talleres').doc(tallerUid).get(),
  ]);
  if (!tallerUsuarioDoc.exists || !tallerDoc.exists) {
    throw new Error(`El usuario ${TALLER_EMAIL} (${tallerUid}) no tiene documento en 'usuarios' y/o 'talleres'. ¿Está aprobado como taller?`);
  }
  const nombreTaller = tallerDoc.get('nombre') || tallerUsuarioDoc.get('nombre_completo') || 'Taller';
  console.log(`Taller: ${nombreTaller} (${tallerUid})`);
  console.log('---');

  const batch = db.batch();
  let mesesAtras = 1;

  for (const propietarioEmail of PROPIETARIO_EMAILS) {
    const propietarioUser = await auth.getUserByEmail(propietarioEmail).catch(() => null);
    if (!propietarioUser) {
      throw new Error(`No existe ningún usuario de Auth con el correo ${propietarioEmail}. Créalo desde la app o pasa --propietario-email.`);
    }
    const propietarioUid = propietarioUser.uid;

    const propietarioDoc = await db.collection('usuarios').doc(propietarioUid).get();
    if (!propietarioDoc.exists) {
      throw new Error(`El usuario ${propietarioEmail} (${propietarioUid}) no tiene documento en 'usuarios'.`);
    }
    const nombrePropietario = propietarioDoc.get('nombre_completo') || 'Propietario';

    const slug = slugify(propietarioEmail);
    const vehiculosExistentes = await db.collection('vehiculos')
      .where('id_propietario', '==', propietarioUid)
      .limit(1)
      .get();

    const datos = construirDatosPropietario({
      propietarioUid,
      nombrePropietario,
      tallerUid,
      nombreTaller,
      slug,
      mesesAtras,
      vehiculosExistentes,
    });
    mesesAtras += 1;

    console.log(`${nombrePropietario} (${propietarioEmail}) — vehículo ${datos.vehiculoDatos.marca} ${datos.vehiculoDatos.modelo} (${datos.vehiculoNuevo ? 'nuevo' : 'existente'})`);
    console.log(`  conversaciones/${datos.ids.conversacion} (${datos.mensajes.length} mensajes)`);
    console.log(`  reservas/${datos.ids.reservaConfirmada}, reservas/${datos.ids.reservaPendiente}`);
    console.log(`  servicios/${datos.ids.servicioHistorico}`);
    console.log(`  resenias/${datos.reseniaId} (${datos.reseniaDatos.estrellas}★)`);

    if (!APPLY) continue;

    if (datos.vehiculoNuevo) {
      batch.set(db.collection('vehiculos').doc(datos.vehiculoId), datos.vehiculoDatos);
    }

    const conversacionRef = db.collection('conversaciones').doc(datos.ids.conversacion);
    batch.set(conversacionRef, { ...datos.conversacionDatos, id: datos.ids.conversacion });

    for (const m of datos.mensajes) {
      const { id, ...campos } = m;
      batch.set(conversacionRef.collection('mensajes').doc(id), campos);
    }

    batch.set(db.collection('reservas').doc(datos.ids.reservaConfirmada), datos.reservaConfirmadaDatos);
    batch.set(db.collection('reservas').doc(datos.ids.reservaPendiente), datos.reservaPendienteDatos);
    batch.set(db.collection('servicios').doc(datos.ids.servicioHistorico), datos.servicioHistoricoDatos);
    batch.set(db.collection('resenias').doc(datos.reseniaId), datos.reseniaDatos);
  }

  console.log('---');
  if (!APPLY) {
    console.log('Nada se escribió (dry-run). Vuelve a correr con --apply para aplicar.');
    return;
  }

  await batch.commit();
  console.log(`Listo. Interacciones escritas para ${PROPIETARIO_EMAILS.length} propietario(s) con ${TALLER_EMAIL}.`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
