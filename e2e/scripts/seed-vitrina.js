#!/usr/bin/env node
'use strict';

// Siembra fixtures PRESENTABLES para las capturas de la ficha de Google Play.
//
// Es hermano de seed-emulators.js, no su sustituto, y la diferencia es
// deliberada: aquel siembra el minimo que hace falta para ejercer una regla de
// autorizacion ("Propietaria A", placa E2E-AAA, un taller sin resenias), que es
// exactamente lo correcto para una suite de tests y exactamente lo peor posible
// para una captura de tienda. Una ficha con "Taller A" y cero estrellas dice
// "software sin terminar" antes de que nadie lea la descripcion.
//
// Reglas que se respetan aqui y conviene no romper al editar:
//
// 1. `emailVerified: true` en todos los actores. SEC-02 hizo obligatoria la
//    verificacion: sin ella el router manda a /verify_email y no se llega a
//    ninguna pantalla fotografiable.
// 2. El taller tiene `estado: 'aprobado'`. isMecanico() exige rol en
//    ['Mecanico','Taller'] Y estado en ['aprobado','activo']; un taller
//    'pendiente' inicia sesion y no ve nada.
// 3. Las placas cumplen `^[PMCA][0-9A-F]{1,3}-[0-9A-F]{3}$`
//    (lib/core/utils/plate_formatter.dart:127). Una placa fuera de formato se
//    guarda igual por Admin SDK pero se pinta mal en la UI, y la captura sale
//    con el error de validacion encima.
// 4. Las fechas son relativas a hoy, no absolutas. Un historial sembrado con
//    fechas fijas envejece: a los seis meses la captura dice "hace 8 meses" en
//    todo y parece una app abandonada.

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const config = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'emulator-config.json'), 'utf8'),
);
const projectId = config.FIREBASE_PROJECT_ID;

process.env.FIREBASE_AUTH_EMULATOR_HOST ||= 'localhost:9099';
process.env.FIRESTORE_EMULATOR_HOST ||= 'localhost:8080';
process.env.STORAGE_EMULATOR_HOST ||= 'localhost:9199';

admin.initializeApp({ projectId });
const auth = admin.auth();
const db = admin.firestore();

const CLAVE = 'vitrina-password-123';

/** Días atrás desde hoy, como Date. */
const hace = (dias) => new Date(Date.now() - dias * 24 * 60 * 60 * 1000);

/**
 * Como `hace`, pero sin salirse NUNCA del mes en curso.
 *
 * El panel del taller pinta «Ingresos (Mes)» y su variación contra el mes
 * anterior. Con el servicio mas reciente a 34 dias, el mes en curso salia
 * vacio y la captura mostraba **$0.00 con un −100.0% en rojo**: un taller que
 * parece arruinado, que es lo contrario de lo que la ficha tiene que decir.
 *
 * El recorte importa porque la fecha se calcula el dia que se corre el seed:
 * «hace 5 dias» cae en el mes anterior si hoy es dia 3, y entonces la captura
 * saldria bien o mal segun el dia del mes. Esto lo hace determinista.
 */
const esteMes = (dias) => {
  const objetivo = hace(dias);
  const primeroDelMes = new Date();
  primeroDelMes.setDate(1);
  primeroDelMes.setHours(12, 0, 0, 0);
  return objetivo < primeroDelMes ? primeroDelMes : objetivo;
};
/** Días adelante desde hoy, como Date. */
const dentroDe = (dias) => new Date(Date.now() + dias * 24 * 60 * 60 * 1000);

const ACTORES = {
  propietario: {
    uid: 'vit-propietario',
    correo: 'sofia@autodoc.demo',
    nombre: 'Sofía Mendoza',
    rol: 'Propietario',
    estado: 'activo',
  },
  taller: {
    uid: 'vit-taller',
    correo: 'taller@autodoc.demo',
    nombre: 'Talleres La Ceiba',
    rol: 'Taller',
    estado: 'aprobado',
  },
  // Segundo taller: el directorio con una sola ficha parece roto, y la captura
  // del mapa necesita mas de un pin para leerse como una red.
  taller2: {
    uid: 'vit-taller-2',
    correo: 'autoservicio@autodoc.demo',
    nombre: 'AutoServicio Cuscatlán',
    rol: 'Taller',
    estado: 'aprobado',
  },
  // Autores de las resenias. Sin usuarios reales detras, la lista de resenias
  // sale con nombres vacios.
  cliente1: {
    uid: 'vit-cliente-1',
    correo: 'ricardo@autodoc.demo',
    nombre: 'Ricardo Alvarenga',
    rol: 'Propietario',
    estado: 'activo',
  },
  cliente2: {
    uid: 'vit-cliente-2',
    correo: 'karla@autodoc.demo',
    nombre: 'Karla Portillo',
    rol: 'Propietario',
    estado: 'activo',
  },
};

async function crearUsuario(actor, extra = {}) {
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
  await db
    .collection('usuarios')
    .doc(actor.uid)
    .set({
      id_usuario: actor.uid,
      correo: actor.correo,
      nombre_completo: actor.nombre,
      rol: actor.rol,
      estado: actor.estado,
      calificacion_promedio: 0,
      total_resenias: 0,
      ...extra,
    });
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

async function main() {
  await limpiarFirestore();

  for (const actor of Object.values(ACTORES)) {
    await crearUsuario(actor);
  }

  // ── Vehiculos ────────────────────────────────────────────────────────────
  //
  // Tres, no uno: la captura del garaje tiene que enseñar que la app sirve para
  // la flota de una familia, que es el argumento de venta. Y `es_principal`
  // marca uno solo, porque la UI lo destaca.
  //
  // `vencimiento_soat` a 12 dias en el primero es lo que enciende la alerta de
  // la captura 6. Si se pone muy lejos no sale nada que fotografiar.
  const VEHICULOS = [
    {
      id: 'vit-vehiculo-1',
      placa: 'P482-731',
      marca: 'Toyota',
      modelo: 'Hilux',
      anio: 2021,
      color: 'Blanco',
      kilometraje_actual: 68400,
      es_principal: true,
      vencimiento_soat: dentroDe(12),
      vencimiento_tarjeta: dentroDe(94),
    },
    {
      id: 'vit-vehiculo-2',
      placa: 'P91-204',
      marca: 'Honda',
      modelo: 'CR-V',
      anio: 2019,
      color: 'Gris plata',
      kilometraje_actual: 112750,
      es_principal: false,
      vencimiento_soat: dentroDe(147),
      vencimiento_tarjeta: dentroDe(210),
    },
    {
      id: 'vit-vehiculo-3',
      placa: 'M12-508',
      marca: 'Yamaha',
      modelo: 'FZ 2.0',
      anio: 2023,
      color: 'Azul',
      kilometraje_actual: 14200,
      es_principal: false,
      vencimiento_soat: dentroDe(61),
      vencimiento_tarjeta: dentroDe(178),
    },
  ];

  for (const v of VEHICULOS) {
    await db
      .collection('vehiculos')
      .doc(v.id)
      .set({
        id_vehiculo: v.id,
        id_propietario: ACTORES.propietario.uid,
        placa: v.placa,
        marca: v.marca,
        modelo: v.modelo,
        anio: v.anio,
        color: v.color,
        kilometraje_actual: v.kilometraje_actual,
        es_principal: v.es_principal,
        vencimiento_soat: v.vencimiento_soat,
        vencimiento_tarjeta: v.vencimiento_tarjeta,
        talleres_vinculados: [ACTORES.taller.uid],
        talleres_conocidos: [ACTORES.taller.uid, ACTORES.taller2.uid],
      });
  }

  // ── Historial de servicios ───────────────────────────────────────────────
  //
  // Seis sobre la Hilux, que es el vehiculo de las capturas 2 y 3. Un historial
  // de dos lineas no enseña lo que la app hace; uno de seis se lee como un
  // expediente y es justo el argumento del video ("el carro que cuenta su
  // historia").
  //
  // Uno solo es `'Manual (Propietario)'`. Esa distincion es la premisa de
  // INNO-01 —lo auto-declarado se pinta distinto porque AutoDoc no lo
  // verifica— y la captura del pase tiene que enseñar los dos tipos, o el QR
  // no prueba nada a un comprador.
  const SERVICIOS = [
    {
      id: 'vit-srv-1',
      tipo: 'Cambio de aceite y filtros',
      desc: 'Aceite sintético 5W-30, filtro de aceite y filtro de aire.',
      km: 65000,
      costo: 78.5,
      // Dentro del mes en curso, para que «Ingresos (Mes)» del panel del
      // taller no salga en 0. Ver `esteMes` arriba.
      dias: 5,
      esteMes: true,
      taller: ACTORES.taller.uid,
    },
    {
      id: 'vit-srv-2',
      tipo: 'Frenos delanteros',
      desc: 'Pastillas cerámicas y rectificado de discos.',
      km: 61200,
      costo: 145.0,
      dias: 96,
      taller: ACTORES.taller.uid,
    },
    {
      id: 'vit-srv-3',
      tipo: 'Rotación de llantas',
      desc: 'Rotación y balanceo en casa.',
      km: 58000,
      costo: 0,
      dias: 121,
      taller: 'Manual (Propietario)',
    },
    {
      id: 'vit-srv-4',
      tipo: 'Servicio mayor 60.000 km',
      desc: 'Bujías, refrigerante, correa de accesorios y revisión de 40 puntos.',
      km: 59800,
      costo: 312.75,
      dias: 168,
      taller: ACTORES.taller.uid,
    },
    {
      id: 'vit-srv-5',
      tipo: 'Batería',
      desc: 'Reemplazo de batería 12V 75Ah.',
      km: 54300,
      costo: 96.0,
      dias: 243,
      taller: ACTORES.taller2.uid,
    },
    {
      id: 'vit-srv-6',
      tipo: 'Alineación y balanceo',
      desc: 'Alineación computarizada de las cuatro ruedas.',
      km: 51100,
      costo: 42.0,
      dias: 310,
      taller: ACTORES.taller.uid,
    },
  ];

  for (const s of SERVICIOS) {
    await db.collection('servicios').doc(s.id).set({
      id_servicio: s.id,
      id_vehiculo: 'vit-vehiculo-1',
      id_propietario: ACTORES.propietario.uid,
      id_taller: s.taller,
      tipo_servicio: s.tipo,
      descripcion: s.desc,
      kilometraje_servicio: s.km,
      costo: s.costo,
      fecha: s.esteMes ? esteMes(s.dias) : hace(s.dias),
    });
  }

  // ── Fichas publicas de los talleres ──────────────────────────────────────
  //
  // El campo es `nombre`, no `nombre_taller`: WorkshopModel.toMap() escribe
  // 'nombre' (lib/core/models/workshop_model.dart:47). seed-emulators.js usa
  // 'nombre_taller', que el directorio lee como cadena vacia — da igual en una
  // suite que no mira el rotulo, pero en una captura sale un taller sin nombre.
  await db.collection('talleres').doc(ACTORES.taller.uid).set({
    id_taller: ACTORES.taller.uid,
    nombre: 'Talleres La Ceiba',
    estado: 'aprobado',
    especialidad: 'Mecánica general y suspensión',
    ubicacion_municipio: 'Santa Tecla',
    departamento: 'La Libertad',
    telefono: '+503 2228 4410',
    calificacion_promedio: 4.8,
    total_resenias: 2,
  });
  await db.collection('talleres').doc(ACTORES.taller2.uid).set({
    id_taller: ACTORES.taller2.uid,
    nombre: 'AutoServicio Cuscatlán',
    estado: 'aprobado',
    especialidad: 'Electricidad automotriz',
    ubicacion_municipio: 'San Salvador',
    departamento: 'San Salvador',
    telefono: '+503 2510 7723',
    calificacion_promedio: 4.5,
    total_resenias: 0,
  });

  // ── Resenias ─────────────────────────────────────────────────────────────
  //
  // Dos, de clientes distintos, con texto que suena a persona. Una resenia de
  // cinco estrellas y sin comentario se lee como sembrada, y es justo lo que la
  // captura 8 tiene que desmentir.
  await db.collection('resenias').doc('vit-resenia-1').set({
    id_resenia: 'vit-resenia-1',
    id_taller: ACTORES.taller.uid,
    id_usuario: ACTORES.cliente1.uid,
    id_servicio: 'vit-srv-2',
    estrellas: 5,
    comentario:
      'Me explicaron el presupuesto antes de tocar nada y entregaron el mismo día. '
      + 'El historial quedó cargado en la app sin que yo hiciera nada.',
    fecha_resenia: hace(88),
    fotos: [],
    is_reported: false,
  });
  await db.collection('resenias').doc('vit-resenia-2').set({
    id_resenia: 'vit-resenia-2',
    id_taller: ACTORES.taller.uid,
    id_usuario: ACTORES.cliente2.uid,
    id_servicio: 'vit-srv-4',
    estrellas: 5,
    comentario:
      'Tercera vez que les llevo la camioneta. Precio justo y me avisaron por chat '
      + 'cuando estuvo lista.',
    fecha_resenia: hace(160),
    fotos: [],
    // OJO: `respuesta_taller` es un MAPA {texto, fecha}, no una cadena
    // (review_model.dart:66). Y el modo de fallo es silencioso: `parseRespuesta`
    // devuelve null ante cualquier cosa que no sea un Map
    // (review_model.dart:77), asi que una cadena no revienta — simplemente
    // desaparece, y la captura sale sin la respuesta del taller sin que nada
    // avise.
    respuesta_taller: {
      texto: '¡Gracias Karla! Nos vemos en el siguiente servicio.',
      fecha: hace(158),
    },
    is_reported: false,
  });

  console.log('Fixtures de VITRINA sembrados (para capturas de Play Store):');
  for (const [nombre, a] of Object.entries(ACTORES)) {
    console.log(`  ${nombre.padEnd(12)} ${a.correo.padEnd(28)} ${a.rol}/${a.estado}`);
  }
  console.log(`  clave de todos: ${CLAVE}`);
  console.log(
    `  ${VEHICULOS.length} vehiculos, ${SERVICIOS.length} servicios, 2 talleres, 2 resenias`,
  );
}

main().then(
  () => process.exit(0),
  (e) => {
    console.error('Fallo al sembrar la vitrina:', e);
    process.exit(1);
  },
);
