// Comprobación BLOQUEANTE previa al despliegue de las reglas de H-01.
// No es una Cloud Function desplegada y NO escribe nada: solo cuenta y lista.
//
// **Por qué existe.** H-01 endurece dos sitios que antes miraban solo el `rol`:
//
//   - `storage.rules` → `isVinculadoAlVehiculo()` pasa a exigir taller
//     aprobado. Afecta a `facturas/{vehicleId}` y a la galería
//     `vehiculos/{vehicleId}/**`.
//   - `firestore.rules` → abrir conversación como propietario exige que el
//     `id_mecanico` nombrado sea un taller aprobado.
//
// Ambas resuelven el estado con `.get('estado', 'pendiente')`. O sea: un
// usuario con rol `Mecanico` o `Taller` al que le FALTE el campo `estado`, o
// lo tenga con un valor heredado fuera de `['aprobado','activo']`, pierde de
// golpe el acceso a las facturas y a la galería de los vehículos a los que
// está vinculado, y deja de poder recibir chats nuevos de propietarios.
//
// **Ninguna suite puede avisar de esto**: `test_rules/storage.test.js:17`
// siembra siempre `estado: 'activo'` y las suites nuevas siembran el caso a
// propósito. Es la misma trampa que el backfill de `abierto` en `fix/gaps-02`:
// una igualdad sobre un campo ausente no devuelve nada.
//
// **El filtro se hace en memoria, a propósito.** Firestore no sabe consultar
// "el campo no existe": no hay operador de ausencia, y `where('estado','not-in',
// [...])` EXCLUYE los documentos sin el campo — justo los que más importan
// aquí. Por eso se traen todos los mecánicos y talleres y se clasifican en
// cliente. La colección `usuarios` es pequeña y esto corre una sola vez.
//
// Uso (contra el proyecto real, con sus credenciales):
//   node contar_talleres_sin_estado.js
//   node contar_talleres_sin_estado.js --csv > talleres_a_revisar.csv
//
// **No existe un modo --apply, y es deliberado.** El runbook prohíbe el
// backfill ciego a 'aprobado': los talleres realmente pendientes o suspendidos
// DEBEN perder el acceso, que es justo el defecto que H-01 cierra. Convertir
// esto en una escritura masiva volvería el arreglo en su contrario. Ojo: ya
// existen en el repo dos scripts que sí hacen esa escritura ciega
// (`src/aprobarTodosTalleres.js` y `src/backfillEstadoMecanicos.js`); NO son
// la respuesta a esta comprobación.

'use strict';

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

/// Los mismos dos roles que miran `esTallerAprobado()` en `storage.rules` y
/// `esMecanicoAprobado()` en `firestore.rules`.
const ROLES = ['Mecanico', 'Taller'];

/// Los mismos dos valores que aceptan esas dos reglas. Cualquier otro valor
/// —y la ausencia del campo— deniega.
const ESTADOS_QUE_PASAN = ['aprobado', 'activo'];

const TAMANO_PAGINA = 500;

function clasificar(datos) {
  if (!Object.prototype.hasOwnProperty.call(datos, 'estado')) return 'ausente';
  const estado = datos.estado;
  if (typeof estado !== 'string') return 'no_es_cadena';
  if (ESTADOS_QUE_PASAN.includes(estado)) return 'pasa';
  return 'valor_denegado';
}

async function recorrerMecanicos(alEncontrar) {
  // `where in` admite hasta 30 valores; con dos roles va sobrado, pero se
  // pagina igualmente por `__name__` porque `usuarios` puede crecer y una
  // lectura completa sin cota es justo el patrón que este repo lleva cuatro
  // tandas retirando.
  let ultimo = null;
  let leidos = 0;

  for (;;) {
    let consulta = db
      .collection('usuarios')
      .where('rol', 'in', ROLES)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(TAMANO_PAGINA);

    if (ultimo) consulta = consulta.startAfter(ultimo);

    const pagina = await consulta.get();
    if (pagina.empty) break;

    for (const doc of pagina.docs) {
      leidos += 1;
      alEncontrar(doc);
    }

    ultimo = pagina.docs[pagina.docs.length - 1];
    if (pagina.size < TAMANO_PAGINA) break;
  }

  return leidos;
}

async function main() {
  const comoCsv = process.argv.includes('--csv');

  const afectados = [];
  const porMotivo = { ausente: 0, no_es_cadena: 0, valor_denegado: 0, pasa: 0 };

  const leidos = await recorrerMecanicos((doc) => {
    const datos = doc.data() || {};
    const motivo = clasificar(datos);
    porMotivo[motivo] += 1;

    if (motivo === 'pasa') return;

    afectados.push({
      uid: doc.id,
      rol: datos.rol,
      estado: Object.prototype.hasOwnProperty.call(datos, 'estado')
        ? JSON.stringify(datos.estado)
        : '(ausente)',
      motivo,
      correo: datos.correo || datos.email || '',
      nombre: datos.nombre_completo || datos.nombre || '',
    });
  });

  if (comoCsv) {
    console.log('uid,rol,estado,motivo,correo,nombre');
    for (const f of afectados) {
      const campos = [f.uid, f.rol, f.estado, f.motivo, f.correo, f.nombre];
      console.log(campos.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(','));
    }
    return afectados.length;
  }

  console.log('');
  console.log(`Proyecto:            ${serviceAccount.project_id}`);
  console.log(`Mecanicos/Talleres:  ${leidos}`);
  console.log('');
  console.log(`  estado valido (${ESTADOS_QUE_PASAN.join(' | ')}): ${porMotivo.pasa}`);
  console.log(`  campo 'estado' AUSENTE:                ${porMotivo.ausente}`);
  console.log(`  'estado' con valor denegado:           ${porMotivo.valor_denegado}`);
  console.log(`  'estado' que no es una cadena:         ${porMotivo.no_es_cadena}`);
  console.log('');
  console.log(`>>> PERDERIAN ACCESO AL DESPLEGAR: ${afectados.length}`);
  console.log('');

  if (afectados.length === 0) {
    console.log('Cero afectados: despliega reglas y app juntas. No hace falta nada mas.');
    return 0;
  }

  console.log('Hay que decidir DOCUMENTO A DOCUMENTO antes de desplegar:');
  console.log("  - operativo  -> escribirle estado: 'aprobado'");
  console.log('  - pendiente o suspendido -> dejarlo; perder el acceso es el arreglo');
  console.log('');
  console.log('NO hagas un backfill ciego a \'aprobado\': convierte el arreglo en su contrario.');
  console.log('');

  const tabla = afectados.slice(0, 50);
  for (const f of tabla) {
    console.log(
      `  ${f.uid}  ${String(f.rol).padEnd(9)}  ${String(f.estado).padEnd(16)}  ${f.motivo.padEnd(14)}  ${f.correo}`,
    );
  }
  if (afectados.length > tabla.length) {
    console.log(`  ... y ${afectados.length - tabla.length} mas. Usa --csv para la lista completa.`);
  }

  return afectados.length;
}

main()
  .then((afectados) => {
    // Codigo de salida distinto de cero si hay trabajo que decidir, para que
    // un pipeline de despliegue se PARE aqui en vez de seguir.
    process.exit(afectados > 0 ? 1 : 0);
  })
  .catch((e) => {
    console.error('Fallo la comprobacion:', e);
    process.exit(2);
  });
