#!/usr/bin/env node
'use strict';

// Siembra los fixtures de la suite E2E en los emuladores de Auth y Firestore.
//
// QA-01 pide "fixtures explicitos para propietario A/B, taller A/B, admin y
// superusuario; nunca usar usuarios de produccion". Antes de esto la suite
// iniciaba sesion con dos cuentas fijas contra el Firebase real y
// registro.spec.js creaba usuarios nuevos EN PRODUCCION en cada corrida.
//
// Dos detalles que rompen la suite entera si se ignoran:
//
// 1. `emailVerified: true`. SEC-02 hizo obligatoria la verificacion de correo:
//    el router manda a la pantalla de verificacion a cualquier sesion sin ella
//    y las callables privilegiadas la exigen. Un fixture sin verificar no
//    llega a ninguna pantalla que valga la pena probar, y el sintoma —todos
//    los specs rebotando al mismo sitio— no apunta al fixture.
//
// 2. El `estado` de los talleres. isMecanico() exige rol en
//    ['Mecanico','Taller'] Y estado en ['aprobado','activo']: un taller
//    'pendiente' no accede a datos aunque inicie sesion. tallerB nace
//    pendiente a proposito, para tener el negativo.

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const config = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'emulator-config.json'), 'utf8'),
);
const projectId = config.FIREBASE_PROJECT_ID;

// El Admin SDK habla con los emuladores solo si ve estas variables. Se fijan
// aqui y no en el entorno del usuario para que el script sea autocontenido: si
// faltaran, firebase-admin intentaria hablar con Google de verdad con unas
// credenciales que no existen.
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= 'localhost:9099';
process.env.FIRESTORE_EMULATOR_HOST ||= 'localhost:8080';
process.env.STORAGE_EMULATOR_HOST ||= 'localhost:9199';

admin.initializeApp({ projectId });
const auth = admin.auth();
const db = admin.firestore();

const CLAVE = 'e2e-password-123';

const ACTORES = {
  propietarioA: {
    uid: 'e2e-propietario-a',
    correo: 'propietario.a@e2e.test',
    nombre: 'Propietaria A',
    rol: 'Propietario',
    estado: 'activo',
  },
  propietarioB: {
    uid: 'e2e-propietario-b',
    correo: 'propietario.b@e2e.test',
    nombre: 'Propietario B',
    rol: 'Propietario',
    estado: 'activo',
  },
  tallerA: {
    uid: 'e2e-taller-a',
    correo: 'taller.a@e2e.test',
    nombre: 'Taller A',
    rol: 'Taller',
    estado: 'aprobado',
  },
  // Pendiente de aprobacion: es el negativo de isMecanico().
  tallerB: {
    uid: 'e2e-taller-b',
    correo: 'taller.b@e2e.test',
    nombre: 'Taller B',
    rol: 'Taller',
    estado: 'pendiente',
  },
  admin: {
    uid: 'e2e-admin',
    correo: 'admin@e2e.test',
    nombre: 'Administradora',
    rol: 'Administrador',
    estado: 'activo',
  },
  superusuario: {
    uid: 'e2e-superusuario',
    correo: 'super@e2e.test',
    nombre: 'Superusuario',
    rol: 'Superusuario',
    estado: 'activo',
  },
  // Cuenta desechable para el par "el admin NO puede borrar / el superusuario
  // SI puede borrar". Va aparte de los actores reales a proposito: si ese par
  // se ejerciera sobre propietarioB, el segundo test dejaria al primero sin
  // documento y el resultado de la suite pasaria a depender del orden.
  desechable: {
    uid: 'e2e-desechable',
    correo: 'desechable@e2e.test',
    nombre: 'Cuenta Desechable',
    rol: 'Propietario',
    estado: 'activo',
  },
};

/**
 * Una fecha a N dias, anclada al MEDIODIA de Bogota (17:00 UTC).
 *
 * El anclaje no es cosmetico. `construirAgenda` calcula los dias con
 * `diasLocalesEntre` y `DESFASE_MINUTOS_BOGOTA = -300`, o sea contando dias
 * de CALENDARIO local, no periodos de 24 h. Sembrar con `Date.now() + n*24h`
 * hace que el numero de dias que ve el asistente dependa de la hora a la que
 * se lance la suite: una corrida a las 23:00 daria n, y una a las 00:30 del
 * dia siguiente daria n-1. Es el mismo error que OPS-01 cometio calculando
 * «manana» en UTC y descoloco las citas de la tarde.
 *
 * Con el ancla al mediodia hay doce horas de margen por cada lado, asi que el
 * numero es estable venga la corrida a la hora que venga.
 */
const DESFASE_MINUTOS_BOGOTA = -300;

function enDiasAlMediodia(n) {
  // El dia de partida es el de BOGOTA, no el de UTC. Parece un detalle y no lo
  // es: entre las 00:00 y las 04:59 UTC son las 19:00-23:59 del dia ANTERIOR
  // en Bogota, asi que la fecha UTC ya paso de dia mientras la local no. Con
  // un ancla sobre `getUTCDate()`, una corrida lanzada en esa franja sembraba
  // todo un dia mas alla y el asistente veia 6 dias donde el spec esperaba 5.
  // Medido barriendo las 24 horas: desviaba en cinco de ellas.
  const local = new Date(Date.now() + DESFASE_MINUTOS_BOGOTA * 60000);
  const medianocheLocal = Date.UTC(
    local.getUTCFullYear(),
    local.getUTCMonth(),
    local.getUTCDate() + n
  );
  // Mediodia local, devuelto a UTC. Doce horas de margen por cada lado.
  return new Date(medianocheLocal + 12 * 3600000 - DESFASE_MINUTOS_BOGOTA * 60000);
}

async function crearUsuario(actor) {
  try {
    await auth.deleteUser(actor.uid);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
  }
  await auth.createUser({
    uid: actor.uid,
    email: actor.correo,
    password: CLAVE,
    displayName: actor.nombre,
    emailVerified: true,
  });
  await db.collection('usuarios').doc(actor.uid).set({
    id_usuario: actor.uid,
    correo: actor.correo,
    nombre_completo: actor.nombre,
    rol: actor.rol,
    estado: actor.estado,
    calificacion_promedio: 0,
    total_resenias: 0,
  });
}

async function main() {
  // Partir de cero: una corrida no debe ver lo que dejo la anterior. Es lo que
  // convierte "esta suite pasa" en "esta suite pasa desde un estado conocido".
  await limpiarFirestore();

  for (const actor of Object.values(ACTORES)) {
    await crearUsuario(actor);
  }

  // Un vehiculo por propietario, para tener el par permitido/denegado de
  // cualquier lectura cruzada.
  // IA-01: los vencimientos del vehiculo de A son RELATIVOS al momento de
  // sembrar, no fechas fijas. `construirAgenda` mira una ventana de 30 dias,
  // asi que una fecha escrita a mano deja de aparecer en la agenda en cuanto
  // pasa, y el spike del asistente se quedaria afirmando sobre una lista
  // vacia sin que nada se pusiera rojo — el peor modo de fallo de un fixture.
  //
  // `vencimiento_tarjeta` esta a proposito: se guarda y se parsea en
  // `VehicleModel` pero **no lo muestra ninguna pantalla de la app**. El
  // asistente es el primer sitio del producto donde ese dato le llega a
  // alguien, asi que el E2E lo cubre.
  await db.collection('vehiculos').doc('e2e-vehiculo-a').set({
    id_vehiculo: 'e2e-vehiculo-a',
    id_propietario: ACTORES.propietarioA.uid,
    placa: 'E2E-AAA',
    marca: 'Toyota',
    modelo: 'Corolla',
    anio: 2020,
    kilometraje_actual: 45000,
    vencimiento_soat: enDiasAlMediodia(5),
    vencimiento_tarjeta: enDiasAlMediodia(20),
    talleres_vinculados: [ACTORES.tallerA.uid],
    talleres_conocidos: [ACTORES.tallerA.uid],
  });
  await db.collection('vehiculos').doc('e2e-vehiculo-b').set({
    id_vehiculo: 'e2e-vehiculo-b',
    id_propietario: ACTORES.propietarioB.uid,
    placa: 'E2E-BBB',
    marca: 'Mazda',
    modelo: '3',
    anio: 2019,
    kilometraje_actual: 61000,
    talleres_vinculados: [],
    talleres_conocidos: [],
  });

  // INNO-01: dos servicios sobre el vehiculo de A, y los dos hacen falta.
  //
  // El pase de historial proyecta `auto_declarado`, que sale de si `id_taller`
  // es el centinela `'Manual (Propietario)'`. Sembrar solo uno de los dos
  // dejaria la demo E2E afirmando media cosa: con solo el del taller no se ve
  // que lo auto-declarado se marca distinto, y sin el del taller no se ve que
  // lo que un taller registro NO se marca. La distincion es la premisa entera
  // de la funcionalidad —si un vendedor puede escribirse el historial y sale
  // igual de respaldado, el QR deja de probar nada—, asi que el par es lo
  // minimo para que la suite la ejerza.
  await db.collection('servicios').doc('e2e-servicio-taller').set({
    id_vehiculo: 'e2e-vehiculo-a',
    id_propietario: ACTORES.propietarioA.uid,
    id_taller: ACTORES.tallerA.uid,
    tipo_servicio: 'Cambio de aceite',
    descripcion: 'Aceite sintetico 5W30 y filtro',
    kilometraje_servicio: 40000,
    costo: 250000,
    fecha: new Date('2026-03-01T15:00:00Z'),
  });
  await db.collection('servicios').doc('e2e-servicio-manual').set({
    id_vehiculo: 'e2e-vehiculo-a',
    id_propietario: ACTORES.propietarioA.uid,
    id_taller: 'Manual (Propietario)',
    tipo_servicio: 'Rotacion de llantas',
    descripcion: 'Hecho en casa',
    kilometraje_servicio: 38000,
    costo: 0,
    fecha: new Date('2026-01-15T15:00:00Z'),
  });

  // IA-01: una cita confirmada del taller A, dentro de la ventana.
  //
  // Es la OTRA rama de `construirAgenda`: la del taller resuelve el rol, su
  // estado y su taller efectivo, y lee `reservas` por `id_taller`. Sin este
  // documento, la mitad server-side que mas autorizacion tiene no la ejerce
  // nadie de punta a punta.
  //
  // `id_vehiculo` va aunque `reservas` no guarde `placa`: la placa la resuelve
  // el servidor con `leerPlacas`, y sin el id no tendria de donde sacarla —
  // el taller veria todas sus citas con `placa: null`.
  await db.collection('reservas').doc('e2e-reserva-taller-a').set({
    id_reserva: 'e2e-reserva-taller-a',
    id_taller: ACTORES.tallerA.uid,
    id_mecanico: ACTORES.tallerA.uid,
    id_propietario: ACTORES.propietarioA.uid,
    id_vehiculo: 'e2e-vehiculo-a',
    estado: 'confirmada',
    tipo_servicio: 'Cambio de aceite',
    fecha_hora_propuesta: enDiasAlMediodia(2),
  });

  // Ficha publica del taller aprobado, que es lo que alimenta el directorio.
  await db.collection('talleres').doc(ACTORES.tallerA.uid).set({
    id_taller: ACTORES.tallerA.uid,
    nombre_taller: 'Taller A',
    estado: 'aprobado',
    calificacion_promedio: 0,
    total_resenias: 0,
  });

  console.log('Fixtures sembrados en los emuladores:');
  for (const [nombre, a] of Object.entries(ACTORES)) {
    console.log(`  ${nombre.padEnd(14)} ${a.correo.padEnd(26)} ${a.rol}/${a.estado}`);
  }
}

async function limpiarFirestore() {
  const res = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}` +
      `/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  if (!res.ok) {
    throw new Error(
      `No se pudo limpiar Firestore (${res.status}). ¿Estan los emuladores arriba?`,
    );
  }
}

main().then(
  () => process.exit(0),
  (e) => {
    console.error('Fallo al sembrar:', e);
    process.exit(1);
  },
);
