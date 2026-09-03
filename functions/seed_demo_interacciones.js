// Script de un solo uso para poblar una demo con interacciones REALISTAS entre
// un propietario y un taller: conversación con mensajes, dos reservas (una
// pendiente y una confirmada) y un servicio ya completado (historial).
//
// POR QUÉ EXISTE
//
// Para la demo hace falta que las pantallas de chat, citas y servicios no se
// vean vacías. Crear eso a mano desde la UI implicaría escribir cada mensaje
// y esperar los listeners; este script usa el Admin SDK para escribirlo todo
// de una vez, en el mismo formato que espera el cliente (mismos nombres de
// campo que ConversacionModel, MensajeModel, ReservaModel y la colección
// `servicios` — ver lib/features/chat/data/models/*.dart y
// lib/features/dashboard/presentation/providers/alert_provider.dart).
//
// Reutiliza las cuentas de QA ya existentes en producción en vez de crear
// cuentas nuevas: nadie@gmail.com (Propietario) y taller1@taller.com (Taller
// aprobado). Si no existen, el script falla con un mensaje claro en vez de
// crear cuentas nuevas por su cuenta.
//
// Respeta el invariante "quien propone no resuelve" (docs/superpowers, commit
// ad0bc14): la reserva confirmada la propuso el taller y la aceptó el
// propietario; la pendiente la propuso el propietario y queda a la espera de
// que el taller la acepte/cotice.
//
// IDs deterministas (prefijo `demo-`) para que correr el script dos veces no
// duplique nada: la segunda corrida sobreescribe los mismos documentos.
//
// Uso (contra producción, con functions/serviceAccountKey.json ya presente):
//   node seed_demo_interacciones.js                  # dry-run: informa, no escribe
//   node seed_demo_interacciones.js --apply           # escribe de verdad
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

const PROPIETARIO_EMAIL = argValue('--propietario-email', 'nadie@gmail.com');
const TALLER_EMAIL = argValue('--taller-email', 'taller1@taller.com');

// IDs deterministas de todo lo que crea este script, para que sea idempotente
// y fácil de borrar a mano si hace falta limpiar después de la demo.
const IDS = {
  vehiculo: 'demo-vehiculo-corolla',
  conversacion: 'demo-conversacion-1',
  reservaPendiente: 'demo-reserva-pendiente',
  reservaConfirmada: 'demo-reserva-confirmada',
  servicioHistorico: 'demo-servicio-historico',
};

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

async function main() {
  console.log(APPLY ? 'MODO APLICAR' : 'MODO DRY-RUN (no escribe nada)');
  console.log(`Propietario: ${PROPIETARIO_EMAIL}`);
  console.log(`Taller:      ${TALLER_EMAIL}`);
  console.log('---');

  const [propietarioUser, tallerUser] = await Promise.all([
    auth.getUserByEmail(PROPIETARIO_EMAIL).catch(() => null),
    auth.getUserByEmail(TALLER_EMAIL).catch(() => null),
  ]);

  if (!propietarioUser) {
    throw new Error(`No existe ningún usuario de Auth con el correo ${PROPIETARIO_EMAIL}. Créalo desde la app o pasa --propietario-email.`);
  }
  if (!tallerUser) {
    throw new Error(`No existe ningún usuario de Auth con el correo ${TALLER_EMAIL}. Créalo desde la app o pasa --taller-email.`);
  }

  const propietarioUid = propietarioUser.uid;
  const tallerUid = tallerUser.uid;

  const [propietarioDoc, tallerUsuarioDoc, tallerDoc] = await Promise.all([
    db.collection('usuarios').doc(propietarioUid).get(),
    db.collection('usuarios').doc(tallerUid).get(),
    db.collection('talleres').doc(tallerUid).get(),
  ]);

  if (!propietarioDoc.exists) {
    throw new Error(`El usuario ${PROPIETARIO_EMAIL} (${propietarioUid}) no tiene documento en 'usuarios'.`);
  }
  if (!tallerUsuarioDoc.exists || !tallerDoc.exists) {
    throw new Error(`El usuario ${TALLER_EMAIL} (${tallerUid}) no tiene documento en 'usuarios' y/o 'talleres'. ¿Está aprobado como taller?`);
  }

  const nombrePropietario = propietarioDoc.get('nombre_completo') || 'Propietario';
  const nombreTaller = tallerDoc.get('nombre') || tallerUsuarioDoc.get('nombre_completo') || 'Taller';

  console.log(`Propietario: ${nombrePropietario} (${propietarioUid})`);
  console.log(`Taller:      ${nombreTaller} (${tallerUid})`);

  // --- Vehículo: reutiliza uno existente del propietario si lo hay; si no,
  // crea uno determinista para no inflar el garage con vehículos random cada
  // vez que se corre el script.
  const vehiculosExistentes = await db.collection('vehiculos')
    .where('id_propietario', '==', propietarioUid)
    .limit(1)
    .get();

  let vehiculoId;
  let vehiculoDatos;
  if (!vehiculosExistentes.empty) {
    vehiculoId = vehiculosExistentes.docs[0].id;
    vehiculoDatos = vehiculosExistentes.docs[0].data();
    console.log(`Vehículo existente reutilizado: ${vehiculoId} (${vehiculoDatos.marca} ${vehiculoDatos.modelo}, placa ${vehiculoDatos.placa})`);
  } else {
    vehiculoId = IDS.vehiculo;
    vehiculoDatos = {
      id_propietario: propietarioUid,
      marca: 'Toyota',
      modelo: 'Corolla',
      anio: 2019,
      placa: 'DEMO-001',
      kilometraje_actual: 52000,
    };
    console.log(`Vehículo nuevo a crear: ${vehiculoId} (${vehiculoDatos.marca} ${vehiculoDatos.modelo}, placa ${vehiculoDatos.placa})`);
  }

  const ahora = admin.firestore.Timestamp.now();

  // --- Conversación + mensajes: narrativa de un ruido al frenar que termina
  // en una cita agendada.
  const mensajes = [
    {
      id: 'demo-msg-1',
      id_remitente: propietarioUid,
      contenido: 'Hola, mi carro está haciendo un ruido raro al frenar, ¿podrían revisarlo?',
      tipo: 'texto',
      timestamp: horaHoy(9, 0),
      estado: 'visto',
    },
    {
      id: 'demo-msg-2',
      id_remitente: tallerUid,
      contenido: '¡Hola! Claro que sí. ¿Qué vehículo es y hace cuánto fue la última revisión de frenos?',
      tipo: 'texto',
      timestamp: horaHoy(9, 4),
      estado: 'visto',
    },
    {
      id: 'demo-msg-3',
      id_remitente: propietarioUid,
      contenido: `Es un ${vehiculoDatos.marca} ${vehiculoDatos.modelo} ${vehiculoDatos.anio}, placa ${vehiculoDatos.placa}. La última revisión fue hace unos 6 meses.`,
      tipo: 'texto',
      timestamp: horaHoy(9, 6),
      estado: 'visto',
    },
    {
      id: 'demo-msg-4',
      id_remitente: tallerUid,
      contenido: 'Perfecto, te propongo una cita mañana a las 9:00 am para revisar frenos y hacer cambio de aceite. Te dejo la propuesta aquí abajo.',
      tipo: 'texto',
      timestamp: horaHoy(9, 8),
      estado: 'visto',
    },
    {
      id: 'demo-msg-5',
      id_remitente: tallerUid,
      contenido: 'Cita propuesta',
      tipo: 'reserva_card',
      metadata: { id_reserva: IDS.reservaConfirmada },
      timestamp: horaHoy(9, 9),
      estado: 'visto',
    },
    {
      id: 'demo-msg-6',
      id_remitente: propietarioUid,
      contenido: 'Me parece bien, ahí estaré. ¡Gracias!',
      tipo: 'texto',
      timestamp: horaHoy(9, 15),
      estado: 'visto',
    },
    {
      id: 'demo-msg-7',
      id_remitente: propietarioUid,
      contenido: 'De paso, ¿también podrían revisar la suspensión delantera otro día? Siento un golpeteo leve.',
      tipo: 'texto',
      timestamp: horaHoy(9, 16),
      estado: 'visto',
    },
    {
      id: 'demo-msg-8',
      id_remitente: tallerUid,
      contenido: 'Claro, propón el horario que te acomode y lo revisamos.',
      tipo: 'texto',
      timestamp: horaHoy(9, 20),
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
    // El último mensaje lo mandó el taller: queda 1 sin leer para el
    // propietario, así la demo muestra el badge de no leídos.
    no_leidos_propietario: 1,
    no_leidos_mecanico: 0,
    estado: 'activo',
  };

  // --- Reservas: una confirmada (la propuso el taller, la aceptó el
  // propietario) y una pendiente (la propuso el propietario, a la espera de
  // que el taller la acepte o cotice) — cubre ambos lados del invariante
  // "quien propone no resuelve".
  const reservaConfirmadaDatos = {
    id_conversacion: IDS.conversacion,
    id_propietario: propietarioUid,
    id_mecanico: tallerUid,
    id_vehiculo: vehiculoId,
    id_taller: tallerUid,
    id_proponente: tallerUid,
    fecha_hora_propuesta: enDias(1, 9, 0),
    fecha_hora_confirmada: enDias(1, 9, 0),
    tipo_servicio: 'Revisión de frenos y cambio de aceite',
    descripcion: 'Ruido al frenar reportado por el propietario.',
    estado: 'confirmada',
    cotizacion_estimada: 65,
    recordatorio_enviado_24h: false,
    recordatorio_enviado_1h: false,
    fecha_creacion: horaHoy(9, 9),
  };

  const reservaPendienteDatos = {
    id_conversacion: IDS.conversacion,
    id_propietario: propietarioUid,
    id_mecanico: tallerUid,
    id_vehiculo: vehiculoId,
    id_taller: tallerUid,
    id_proponente: propietarioUid,
    fecha_hora_propuesta: enDias(3, 15, 0),
    tipo_servicio: 'Revisión de suspensión delantera',
    descripcion: 'Golpeteo leve al pasar sobre baches.',
    estado: 'pendiente',
    recordatorio_enviado_24h: false,
    recordatorio_enviado_1h: false,
    fecha_creacion: horaHoy(9, 16),
  };

  // --- Servicio histórico (ya completado, hace 2 meses) para que el
  // historial del vehículo, las métricas del taller y la pantalla de reseñas
  // no se vean vacías.
  const fechaServicioHistorico = (() => {
    const d = new Date();
    d.setMonth(d.getMonth() - 2);
    d.setHours(11, 0, 0, 0);
    return admin.firestore.Timestamp.fromDate(d);
  })();

  const servicioHistoricoDatos = {
    id_vehiculo: vehiculoId,
    id_propietario: propietarioUid,
    id_taller: tallerUid,
    tipo_servicio: 'Cambio de aceite y filtro',
    fecha: fechaServicioHistorico,
    kilometraje_servicio: vehiculoDatos.kilometraje_actual ? vehiculoDatos.kilometraje_actual - 3000 : 49000,
    descripcion: 'Cambio de aceite sintético 5W-30 y filtro de aceite.',
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

  console.log('---');
  console.log(`Conversación:        ${IDS.conversacion} (${mensajes.length} mensajes)`);
  console.log(`Reserva confirmada:  ${IDS.reservaConfirmada} — mañana 9:00am`);
  console.log(`Reserva pendiente:   ${IDS.reservaPendiente} — en 3 días, propuesta por el propietario`);
  console.log(`Servicio histórico:  ${IDS.servicioHistorico} — hace 2 meses, $${servicioHistoricoDatos.costo}`);
  console.log('---');

  if (!APPLY) {
    console.log('Nada se escribió (dry-run). Vuelve a correr con --apply para aplicar.');
    return;
  }

  const batch = db.batch();

  if (vehiculosExistentes.empty) {
    batch.set(db.collection('vehiculos').doc(vehiculoId), vehiculoDatos);
  }

  const conversacionRef = db.collection('conversaciones').doc(IDS.conversacion);
  batch.set(conversacionRef, { ...conversacionDatos, id: IDS.conversacion });

  for (const m of mensajes) {
    const { id, ...datos } = m;
    batch.set(conversacionRef.collection('mensajes').doc(id), datos);
  }

  batch.set(db.collection('reservas').doc(IDS.reservaConfirmada), reservaConfirmadaDatos);
  batch.set(db.collection('reservas').doc(IDS.reservaPendiente), reservaPendienteDatos);
  batch.set(db.collection('servicios').doc(IDS.servicioHistorico), servicioHistoricoDatos);

  await batch.commit();

  console.log('Listo. Documentos escritos en producción:');
  console.log(`  vehiculos/${vehiculoId}${vehiculosExistentes.empty ? ' (nuevo)' : ' (existente, no tocado)'}`);
  console.log(`  conversaciones/${IDS.conversacion} + ${mensajes.length} mensajes`);
  console.log(`  reservas/${IDS.reservaConfirmada}`);
  console.log(`  reservas/${IDS.reservaPendiente}`);
  console.log(`  servicios/${IDS.servicioHistorico}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
