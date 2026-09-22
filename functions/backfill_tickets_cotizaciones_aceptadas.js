// Script de mantenimiento único (no es una Cloud Function desplegada) para
// las cotizaciones que ya estaban en 'aceptada' ANTES de que
// `onCotizacionAceptada` existiera en producción.
//
// Por qué hace falta: el trigger es `onUpdate`, y `debeAbrirTicket` solo
// devuelve `true` cuando el estado PASA a 'aceptada'. Una cotización que ya
// nació —o quedó— aceptada mientras la función no estaba desplegada nunca va
// a disparar nada, y tocarla no sirve: el cambio no sería una transición a
// 'aceptada'. Tampoco se puede "volver a aceptar" desde la app, porque
// `firestore.rules` no admite el camino de vuelta a 'pendiente' (y hace bien).
//
// La revisión adversarial del 6-sep-2026 encontró exactamente ese estado en
// producción: 6 cotizaciones en 'aceptada', 0 reparaciones con
// `id_cotizacion`, 0 tickets en 'pendiente_recepcion'. El cliente veía su
// cotización aceptada y el taller no tenía nada que recibir.
//
// Reutiliza `abrirTicketDeReparacion` tal cual, sin copiar su lógica: aplica
// las mismas comprobaciones (el vehículo tiene que ser del cliente de la
// cotización), la misma idempotencia por id derivado, el mismo dedup por
// vehículo+taller y la misma escritura del vínculo `talleres_vinculados`.
// Ejecutarlo dos veces no duplica nada.
//
// Uso (contra producción, con las credenciales del proyecto):
//   node backfill_tickets_cotizaciones_aceptadas.js           # dry-run
//   node backfill_tickets_cotizaciones_aceptadas.js --apply   # escribe
//
// DESPLIEGA PRIMERO las functions y las reglas. Si se corre antes, abre los
// tickets pero deja el resto del sistema en la versión vieja.
//
// Observaciones del 2026-09-18: también rescata las cotizaciones aceptadas
// SIN `id_vehiculo` pero con su cita (`id_reserva`) — el caso de las capturas
// 4 y 5 —, porque `abrirTicketDeReparacion` recupera ahora el coche de la
// cita. Al abrirlas les borra el `error_apertura_ticket` que dejó el trigger.

'use strict';

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const {
  abrirTicketDeReparacion,
  idTicketDeCotizacion,
  ErrorAutorizacionPermanente,
  ErrorTicketNoAplicable,
} = require('./src/aceptarCotizacion');

const APLICAR = process.argv.includes('--apply');

async function main() {
  const snap = await db
    .collection('cotizaciones')
    .where('estado', '==', 'aceptada')
    .get();

  console.log(
    `${snap.size} cotizaciones en 'aceptada'.` +
      (APLICAR ? '' : ' (dry-run: no se escribe nada)')
  );

  let abiertos = 0;
  let yaTenian = 0;
  const problemas = [];

  for (const doc of snap.docs) {
    const datos = doc.data();
    const idTicket = idTicketDeCotizacion(doc.id);
    const existente = await db.collection('reparaciones').doc(idTicket).get();
    if (existente.exists) {
      yaTenian++;
      continue;
    }

    if (!APLICAR) {
      console.log(`  [dry-run] abriría ticket ${idTicket} para cotizacion ${doc.id}`);
      abiertos++;
      continue;
    }

    try {
      // `antes` finge el estado previo para que `debeAbrirTicket` vea la
      // transición que en su día nadie llegó a observar. Es lo único que este
      // script simula; todo lo demás son las comprobaciones reales.
      // `abrirTicketDeReparacion` devuelve `{id, ticket}` desde el residual
      // 7.8; comprobar el objeto entero daba siempre "abierto".
      const { id } = await abrirTicketDeReparacion(db, {
        cotizacionId: doc.id,
        antes: { ...datos, estado: 'pendiente' },
        despues: datos,
        ahora: new Date(),
      });
      if (id) {
        abiertos++;
        console.log(`  abierto ${id} para cotizacion ${doc.id}`);
        // Observaciones del 2026-09-18: una cotizacion que el trigger no
        // pudo abrir (p. ej. sin id_vehiculo, ahora recuperado de su cita)
        // arrastra `error_apertura_ticket`, y la tarjeta seguiria pintando
        // el aviso rojo con el ticket ya abierto.
        if (datos.error_apertura_ticket) {
          await doc.ref.update({
            error_apertura_ticket: admin.firestore.FieldValue.delete(),
          });
        }
      } else {
        yaTenian++;
      }
    } catch (error) {
      const esperado =
        error instanceof ErrorAutorizacionPermanente ||
        error instanceof ErrorTicketNoAplicable;
      problemas.push({ cotizacion: doc.id, motivo: error.message });
      console.log(
        `  ${esperado ? 'omitida' : 'ERROR'} ${doc.id}: ${error.message}`
      );
      if (esperado) {
        // Mismo registro que hace el trigger, para que la tarjeta de la
        // cotización se lo explique al taller en vez de callar.
        await doc.ref.set(
          {
            error_apertura_ticket: {
              mensaje: error.message,
              fecha: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          { merge: true }
        );
      }
    }
  }

  console.log(
    `\nResumen: ${abiertos} ticket(s) abiertos, ${yaTenian} que ya tenían, ` +
      `${problemas.length} sin poder abrirse.`
  );
  if (problemas.length) {
    console.log('Sin poder abrirse (registrado en error_apertura_ticket):');
    for (const p of problemas) console.log(`  ${p.cotizacion}: ${p.motivo}`);
  }
}

main().then(
  () => process.exit(0),
  (e) => {
    console.error(e);
    process.exit(1);
  }
);
