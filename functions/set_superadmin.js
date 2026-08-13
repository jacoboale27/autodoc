// Script de mantenimiento único (no es una Cloud Function desplegada) para
// habilitar el rol 'Superusuario' (ver docs/superpowers/plans/superadmin_implementation_plan.md
// y las reglas isSuperUser() en firestore.rules) en la cuenta
// superadmin@autodocsv.com.
//
// Busca la cuenta en Firebase Auth por correo (debe existir ya) y crea/actualiza
// su doc en usuarios/{uid} con rol: 'Superusuario', estado: 'activo'. Si el doc
// no existe, lo crea con los campos que UserModel espera (ver
// lib/core/models/user_model.dart:119-129).
//
// Uso (contra producción, con las credenciales del proyecto):
//   node set_superadmin.js                    # dry-run, solo imprime qué cambiaría
//   node set_superadmin.js --apply            # aplica el cambio
//   node set_superadmin.js --apply --correo otro@correo.com   # otro correo
//
// Uso (contra el emulador):
//   FIRESTORE_EMULATOR_HOST=localhost:8080 FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 node set_superadmin.js --apply

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Contra producción hace falta una service account key (ADC no está
// configurado en esta máquina): Firebase Console > Configuración del
// proyecto > Cuentas de servicio > Generar nueva clave privada, guardarla
// como functions/serviceAccountKey.json (ya está en .gitignore) o apuntar
// GOOGLE_APPLICATION_CREDENTIALS a su ruta. Contra el emulador no hace falta
// ninguna credencial real.
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
const db = admin.firestore();
const auth = admin.auth();

const APPLY = process.argv.includes('--apply');
const correoIdx = process.argv.indexOf('--correo');
const CORREO = (correoIdx !== -1 ? process.argv[correoIdx + 1] : 'superadmin@autodocsv.com')
  .trim()
  .toLowerCase();

async function main() {
  console.log(APPLY ? 'Modo: APLICAR cambios' : 'Modo: DRY-RUN (usa --apply para escribir)');
  console.log(`Correo objetivo: ${CORREO}`);

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(CORREO);
  } catch (err) {
    if (err && err.code === 'auth/user-not-found') {
      console.error(`No existe ninguna cuenta de Auth con el correo ${CORREO}.`);
      console.error('Crea la cuenta primero (registro normal en la app o Firebase Console) y vuelve a correr este script.');
      process.exitCode = 1;
      return;
    }
    throw err;
  }

  console.log(`Cuenta encontrada: uid=${userRecord.uid}`);

  const docRef = db.collection('usuarios').doc(userRecord.uid);
  const docSnap = await docRef.get();

  if (!docSnap.exists) {
    console.log('No existe doc en usuarios/ para esta cuenta. Se creará uno nuevo con rol Superusuario.');
    const nuevoDoc = {
      id_usuario: userRecord.uid,
      nombre_completo: userRecord.displayName || 'Superadmin',
      correo: CORREO,
      rol: 'Superusuario',
      estado: 'activo',
      fecha_registro: admin.firestore.Timestamp.now(),
    };
    console.log('Doc a crear:', JSON.stringify(nuevoDoc, null, 2));
    if (APPLY) {
      await docRef.set(nuevoDoc);
      console.log('Doc creado.');
    }
    return;
  }

  const data = docSnap.data();
  console.log(`Doc actual: rol=${data.rol}, estado=${data.estado}`);

  const update = {};
  if (data.rol !== 'Superusuario') update.rol = 'Superusuario';
  if (data.estado !== 'activo') update.estado = 'activo';

  if (Object.keys(update).length === 0) {
    console.log('La cuenta ya es Superusuario y está activa. Nada que hacer.');
    return;
  }

  console.log('Cambios a aplicar:', JSON.stringify(update, null, 2));
  if (APPLY) {
    await docRef.update(update);
    console.log('Doc actualizado.');
  } else {
    console.log('Nada se escribió (dry-run). Vuelve a correr con --apply para aplicar.');
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
