// Script de mantenimiento único (no es una Cloud Function desplegada) para el
// cambio de la ronda 6: el ticket de reparación gana un estado TERMINAL,
// 'entregado', y `listo_para_entrega` deja de cerrar la visita.
//
// Por qué hace falta, en tres partes:
//
// 1. `listo_para_entrega` era el último estado del pipeline y por eso contaba
//    como cerrado (`ESTADOS_TICKET_CERRADO`). Con el cambio pasa a contar como
//    ABIERTO — que es lo correcto para un coche que sigue en el taller
//    esperando a que lo recojan, y lo incorrecto para los tickets históricos
//    que llevan meses ahí y cuyo coche se fue hace mucho. Sin este backfill
//    esos tickets "reviven": bloquean el dedup de una cotización aceptada
//    nueva del mismo cliente y se quedan en el tablero para siempre.
//
// 2. `watchReparacionesActivas` pasa a filtrar con `whereIn` sobre los estados
//    del tablero. `whereIn` EXCLUYE los documentos que no tienen el campo, así
//    que los tickets anteriores a A4b (sin `estado`, nacidos en 'recibido')
//    desaparecerían del tablero en silencio. Se les escribe el estado que
//    siempre tuvieron implícito.
//
// 3. `talleres_vinculados` arrastra vínculos de visitas ya terminadas: la
//    revocación automática (`revocarVinculoAlCerrarTicket`) solo dispara en la
//    TRANSICIÓN de abierto a cerrado, así que todo lo que se cerró antes de
//    que existiera ese trigger sigue vinculado. Este script deja en cada
//    vehículo únicamente los talleres que tienen el coche AHORA.
//
// El corte de la parte 1 es deliberado: un ticket en `listo_para_entrega`
// tocado hace menos de --dias-entregado (7 por defecto) puede ser un coche que
// de verdad está esperando a que lo recojan, y ese se queda en el tablero. Los
// más viejos se dan por entregados — que es exactamente como los trataba ya el
// sistema anterior (cerrados para el dedup y para el vínculo), así que
// moverlos no cambia ningún comportamiento que hoy exista.
//
// Uso (contra producción, con las credenciales del proyecto):
//   node backfill_entregado.js                      # dry-run: no escribe nada
//   node backfill_entregado.js --apply
//   node backfill_entregado.js --apply --dias-entregado=14
//
// ORDEN DE DESPLIEGUE: primero `firebase deploy --only functions`, luego este
// script, y solo después la app web. Entre el deploy y el script hay una
// ventana en la que los `listo_para_entrega` viejos cuentan como abiertos;
// córrelos seguidos. El orden NO es negociable: hasta que las functions estén
// desplegadas el servidor no reconoce 'entregado' como estado cerrado — se
// comprobó contra producción llamando a `recibirVehiculoDelTicket` sobre un
// ticket ya entregado, y la versión desplegada lo ACEPTÓ, es decir habría
// devuelto el vínculo al vehículo de un coche ya entregado.
//
// CENTINELA `migracion_ronda6`: cada escritura sobre `reparaciones` lleva este
// campo a `true`, y los dos triggers de la colección lo miran para no actuar.
// Sin él, esta migración le manda al propietario un push y una fila permanente
// en su centro de notificaciones por CADA ticket que toca — "PLACA: Entregado"
// sobre un coche que se llevó hace meses — porque
// `notifyOnReparacionStatusChange` es un `onUpdate` que solo compara
// `before.estado !== after.estado`. Verificado en producción: una sola entrega
// de prueba subió el contador del propietario de 7 a 10 filas.
// `revocarVinculoAlCerrarTicket` también se corta, y a propósito: la pasada 3
// hace esa misma limpieza de forma determinista, y dejar al trigger corriendo
// en paralelo sobre los mismos vehículos es justo la carrera que la pasada 3
// evita al usar `arrayRemove`.

'use strict';

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const {
  ESTADOS_TICKET_CERRADO,
  ESTADOS_VEHICULO_EN_TALLER,
} = require('./src/aceptarCotizacion');
const { CAMPO_MIGRACION } = require('./src/migracion');

const APLICAR = process.argv.includes('--apply');
const DIAS_ENTREGADO = (() => {
  const arg = process.argv.find((a) => a.startsWith('--dias-entregado='));
  if (!arg) return 7;
  const valor = Number(arg.split('=')[1]);
  if (!Number.isFinite(valor) || valor < 0) {
    throw new Error(`--dias-entregado inválido: ${arg}`);
  }
  return valor;
})();

/** Tope de operaciones por lote; el límite duro de Firestore es 500. */
const TAM_LOTE = 400;

/**
 * Aplica escrituras en lotes. En dry-run no escribe: solo cuenta.
 *
 * @param {Array<{ref: FirebaseFirestore.DocumentReference, data: object}>} ops
 */
async function aplicar(ops) {
  if (!APLICAR || ops.length === 0) return;
  for (let i = 0; i < ops.length; i += TAM_LOTE) {
    const lote = db.batch();
    for (const { ref, data } of ops.slice(i, i + TAM_LOTE)) {
      lote.update(ref, data);
    }
    await lote.commit();
  }
}

/** Marca de migración que los triggers de `reparaciones` usan para callarse. */
const CENTINELA = { [CAMPO_MIGRACION]: true };

/** `fecha_actualizacion` tolerante: sin fecha se trata como muy antiguo. */
function fechaActualizacion(data) {
  const valor = data.fecha_actualizacion || data.fecha_creacion;
  if (valor && typeof valor.toDate === 'function') return valor.toDate();
  if (valor instanceof Date) return valor;
  return new Date(0);
}

async function main() {
  const corte = new Date(Date.now() - DIAS_ENTREGADO * 24 * 60 * 60 * 1000);
  console.log(
    `Backfill 'entregado'${APLICAR ? '' : ' (DRY-RUN: no se escribe nada)'}.\n` +
      `Corte de entrega: tickets en 'listo_para_entrega' sin tocar desde ` +
      `${corte.toISOString()} (${DIAS_ENTREGADO} días).`
  );

  const snap = await db.collection('reparaciones').get();
  console.log(`\n${snap.size} tickets en total.`);

  // El estado resultante de cada ticket, ya con las pasadas 1 y 2 aplicadas.
  // Se calcula en memoria para que la pasada 3 vea el mundo POSTERIOR al
  // backfill también en dry-run, y así el informe sea el de verdad.
  const estadoFinal = new Map();
  const opsTickets = [];
  let sinEstado = 0;
  let recibidosSinEstado = 0;
  let entregadosSinEstado = 0;
  let entregados = 0;
  let sigueEsperando = 0;

  // Cierra un ticket como 'entregado' SIN mover la fecha: `fecha_actualizacion`
  // y el sello del historial conservan el momento real de la ultima actividad,
  // que es el unico registro de cuando salio el coche. Poner `new Date()` aqui
  // hacia que todo ticket historico dijera que se entrego el dia de la
  // migracion.
  const marcarEntregado = (doc, data) => {
    opsTickets.push({
      ref: doc.ref,
      data: {
        ...CENTINELA,
        estado: 'entregado',
        historial_estados: admin.firestore.FieldValue.arrayUnion({
          estado: 'entregado',
          timestamp: fechaActualizacion(data),
        }),
      },
    });
  };

  for (const doc of snap.docs) {
    const data = doc.data();
    let estado = data.estado ? data.estado.toString() : '';
    const viejo = fechaActualizacion(data) < corte;

    if (!estado) {
      // Ticket anterior a A4b: nacio en 'recibido' y nunca escribio el campo.
      //
      // Escribirle 'recibido' a TODOS era el error de la primera version: como
      // 'recibido' esta en ESTADOS_VEHICULO_EN_TALLER, la pasada 3 les
      // conservaba el vinculo — y estos son precisamente los tickets mas
      // viejos del sistema, la poblacion de vinculos permanentes rancios que
      // la ronda 5 existe para revocar. Encima aparecian en el tablero como
      // trabajo activo. Se parten por el mismo corte que los
      // `listo_para_entrega`: el que lleva meses sin tocarse es una visita
      // terminada, no un coche esperando en el patio.
      sinEstado += 1;
      if (viejo) {
        estado = 'entregado';
        entregadosSinEstado += 1;
        marcarEntregado(doc, data);
      } else {
        estado = 'recibido';
        recibidosSinEstado += 1;
        opsTickets.push({ ref: doc.ref, data: { ...CENTINELA, estado } });
      }
    } else if (estado === 'listo_para_entrega') {
      if (viejo) {
        estado = 'entregado';
        entregados += 1;
        marcarEntregado(doc, data);
      } else {
        sigueEsperando += 1;
      }
    }

    estadoFinal.set(doc.id, {
      estado,
      idVehiculo: (data.id_vehiculo || '').toString(),
      idTaller: (data.id_taller || '').toString(),
    });
  }

  console.log(
    `  ${sinEstado} sin 'estado': ${recibidosSinEstado} recientes -> ` +
      `'recibido' (siguen en el tablero), ${entregadosSinEstado} viejos -> ` +
      `'entregado'`
  );
  console.log(`  ${entregados} 'listo_para_entrega' viejos -> 'entregado'`);
  console.log(
    `  ${sigueEsperando} 'listo_para_entrega' recientes se quedan en el tablero`
  );
  await aplicar(opsTickets);

  // Pasada 3: el vínculo solo sobrevive si ese taller tiene ESE coche ahora.
  const posesion = new Set();
  for (const { estado, idVehiculo, idTaller } of estadoFinal.values()) {
    if (!idVehiculo || !idTaller) continue;
    if (ESTADOS_VEHICULO_EN_TALLER.includes(estado)) {
      posesion.add(`${idVehiculo}|${idTaller}`);
    }
  }

  const vehiculos = await db.collection('vehiculos').get();
  const opsVehiculos = [];
  let vinculosRevocados = 0;
  let vehiculosTocados = 0;

  let conocidosSembrados = 0;

  for (const doc of vehiculos.docs) {
    const vinculados = doc.data().talleres_vinculados;
    if (!Array.isArray(vinculados) || vinculados.length === 0) continue;

    // Siembra de `talleres_conocidos` ("ha tenido este coche alguna vez"): el
    // array nace en esta migración, y sin sembrarlo con los vínculos que HOY
    // existen, todo taller con una relación real se quedaría sin poder añadir
    // un servicio más — el carve-out nuevo de firestore.rules mira este array,
    // no `talleres_vinculados`. Se siembra con TODOS los vinculados actuales,
    // sobrevivan o no a la revocación de abajo: precisamente los que no
    // sobreviven son los que ya atendieron el coche.
    const yaConocidos = doc.data().talleres_conocidos;
    const porSembrar = vinculados.filter(
      (t) => !Array.isArray(yaConocidos) || !yaConocidos.includes(t)
    );
    if (porSembrar.length > 0) {
      conocidosSembrados += porSembrar.length;
      opsVehiculos.push({
        ref: doc.ref,
        data: {
          talleres_conocidos:
            admin.firestore.FieldValue.arrayUnion(...porSembrar),
        },
      });
    }

    const sobran = vinculados.filter((t) => !posesion.has(`${doc.id}|${t}`));
    if (sobran.length === 0) continue;
    vinculosRevocados += sobran.length;
    vehiculosTocados += 1;
    // `arrayRemove` de los que se van, NO un `set` del array que sobrevive.
    // Ese array se calcula sobre un snapshot tomado al principio de la
    // corrida; escribirlo entero pisa cualquier `arrayUnion` ocurrido mientras
    // tanto — es decir, un taller que reciba un coche durante la migracion se
    // queda sin el vinculo que el callable acababa de otorgarle, y su mecanico
    // ve "tu taller todavia no tiene acceso" sin ningun error a la vista.
    // `arrayRemove` conmuta con las escrituras concurrentes y es idempotente,
    // asi que reejecutar el script tampoco hace dano.
    opsVehiculos.push({
      ref: doc.ref,
      data: {
        talleres_vinculados: admin.firestore.FieldValue.arrayRemove(...sobran),
      },
    });
  }

  console.log(
    `\n${vehiculos.size} vehículos. ${vinculosRevocados} vínculos de visitas ` +
      `ya terminadas se revocan, en ${vehiculosTocados} vehículos.\n` +
      `  ${conocidosSembrados} entradas sembradas en 'talleres_conocidos' ` +
      `(relaciones existentes que conservan permiso de escritura).`
  );
  await aplicar(opsVehiculos);

  console.log(
    APLICAR
      ? '\nHecho.'
      : '\nDry-run terminado: vuelve a correrlo con --apply para escribir.'
  );
  // Referenciado para dejar claro que las dos listas vienen del mismo sitio
  // que las usa en producción, y que este script no las redefine.
  console.log(`(cerrados = ${ESTADOS_TICKET_CERRADO.join(', ')})`);
}

main().then(
  () => process.exit(0),
  (error) => {
    console.error(error);
    process.exit(1);
  }
);
