'use strict';

// Actores sembrados por scripts/seed-emulators.js. Se declaran aqui para que
// ningun spec vuelva a llevar credenciales incrustadas: esa fue exactamente la
// via por la que la suite acabo iniciando sesion contra produccion.
const ACTORES = {
  propietarioA: { correo: 'propietario.a@e2e.test', uid: 'e2e-propietario-a' },
  propietarioB: { correo: 'propietario.b@e2e.test', uid: 'e2e-propietario-b' },
  tallerA: { correo: 'taller.a@e2e.test', uid: 'e2e-taller-a' },
  tallerB: { correo: 'taller.b@e2e.test', uid: 'e2e-taller-b' },
  admin: { correo: 'admin@e2e.test', uid: 'e2e-admin' },
  superusuario: { correo: 'super@e2e.test', uid: 'e2e-superusuario' },
  // Solo para el par de borrado de cuenta; ver seed-emulators.js.
  desechable: { correo: 'desechable@e2e.test', uid: 'e2e-desechable' },
};
const CLAVE = 'e2e-password-123';

const VEHICULOS = { deA: 'e2e-vehiculo-a', deB: 'e2e-vehiculo-b' };

// NOTA (H-01): la app SI emite `aria-label` en los <input> de texto, al
// contrario de lo que decia la guia heredada. Medido en /register:
//   Email / salto / name@example.com / salto / Fill in email and password.
// O sea que `getByLabel` funciona sobre los campos, y el `errorText` de un
// validator viaja AHI y no como nodo de texto — `getByText` no puede verlo.
// Lo usa `registro.spec.js`.
//
// Los SDK se toman de `window.firebase_core` / `firebase_auth` /
// `firebase_firestore`, que es como flutterfire publica sus modulos en la
// pagina.
//
// La alternativa evidente —importar el SDK desde gstatic dentro de
// `page.evaluate`— NO sirve: un `import()` de otra copia del modulo crea su
// PROPIO registro de apps, asi que `getApps()` sale vacio y todo falla con
// "No Firebase App '[DEFAULT]' has been created", aunque la app este
// perfectamente inicializada dos lineas mas alla. Peor aun, esa copia no
// heredaria el `useAuthEmulator`/`useFirestoreEmulator` que main.dart aplico:
// hablaria con produccion desde dentro de una suite que cree estar aislada.
// Los globales son la MISMA instancia que usa la app, ya apuntada a los
// emuladores.

// Espera a que la app este lista Y REDIRIGIDA A LOS EMULADORES.
//
// La condicion obvia —que exista una app de Firebase— no sirve: `getApps()`
// deja de estar vacio en cuanto corre `Firebase.initializeApp`, que es ANTES
// de que main.dart llame a `conectarEmuladoresFirebase()`. En esa ventana el
// SDK todavia apunta a produccion, asi que un signIn lanzado ahi sale al
// endpoint real y muere con `auth/api-key-not-valid` — de forma intermitente,
// segun lo que tarde cada corrida. Costo cuatro tests rojos que pasaban al
// reintentarlos.
//
// `auth.emulatorConfig` solo deja de ser null cuando `connectAuthEmulator` ya
// se aplico, asi que esperar a el elimina la carrera y de paso afirma que
// estamos donde creemos estar.
//
// Desde el shim de scripts/shim-emuladores.js, Auth se conecta al emulador
// ANTES de que arranque Flutter. Eso arregla la sesion persistida pero rompe
// una implicacion en la que esta funcion se apoyaba sin decirlo: como
// main.dart cableaba Auth, Firestore y Storage en tres lineas seguidas, ver
// `emulatorConfig` puesto significaba que los tres estaban listos. Ya no —
// medido: Auth queda cableado en el arranque, `window.firebase_firestore` no
// existe hasta ~1s despues, y en esa ventana `getFirestore` devuelve una
// instancia apuntando a PRODUCCION. Los specs que leen Firestore nada mas
// entrar (roles.spec.js) fallaban ahi de forma intermitente.
//
// Asi que ahora se espera a las tres piezas de verdad: la app montada
// (`<flutter-view>`), Auth en el emulador, y Firestore en el suyo. Lo ultimo
// se lee de `_settings.host`, que es API privada del SDK; si algun dia deja de
// existir esta funcion se quedara esperando hasta agotar el timeout, que es el
// modo de fallo que queremos — ruidoso, y no un verde sobre produccion.
async function esperarAppLista(page) {
  await page.waitForFunction(
    () => {
      const core = window.firebase_core;
      const auth = window.firebase_auth;
      const firestore = window.firebase_firestore;
      if (!core || !auth || !firestore) return false;
      if (!core.getApps || core.getApps().length === 0) return false;
      const app = core.getApps()[0];
      if (!auth.getAuth(app).emulatorConfig) return false;
      const ajustes = firestore.getFirestore(app)._settings;
      if (!ajustes || !/^(localhost|127\.0\.0\.1):8080$/.test(ajustes.host)) {
        return false;
      }
      return !!document.querySelector('flutter-view');
    },
    null,
    { timeout: 120000 },
  );
}

async function proyectoDeLaApp(page) {
  return page.evaluate(() => window.firebase_core.getApps()[0].options.projectId);
}

// Inicia sesion por el SDK ya cargado, no por el formulario.
//
// No es un atajo por comodidad: el proxy de input de Flutter web pierde el
// valor del campo de correo al mover el foco al de contraseña, asi que el
// login por UI es intermitente y sus fallos no dicen nada sobre la app. La app
// reacciona sola al cambio de sesion, que es el comportamiento que interesa
// medir aqui. El formulario se prueba aparte, en su propio spec.
async function iniciarSesion(page, actor) {
  await esperarAppLista(page);
  const resultado = await page.evaluate(
    async ({ correo, clave }) => {
      try {
        const app = window.firebase_core.getApps()[0];
        const auth = window.firebase_auth.getAuth(app);
        const cred = await window.firebase_auth.signInWithEmailAndPassword(
          auth,
          correo,
          clave,
        );
        return {
          ok: true,
          uid: cred.user.uid,
          verificado: cred.user.emailVerified,
        };
      } catch (e) {
        return { ok: false, error: String(e) };
      }
    },
    { correo: actor.correo, clave: CLAVE },
  );
  if (!resultado.ok) {
    throw new Error(
      `No se pudo iniciar sesion como ${actor.correo}: ${resultado.error}`,
    );
  }
  return resultado;
}

async function cerrarSesion(page) {
  await page.evaluate(async () => {
    const app = window.firebase_core.getApps()[0];
    await window.firebase_auth.signOut(window.firebase_auth.getAuth(app));
  });
}

// Lee un documento CON LOS PERMISOS DEL USUARIO EN SESION.
//
// Es lo que convierte un spec de navegacion en un spec de autorizacion: la UI
// puede limitarse a no mostrar un boton, y eso no prueba nada — la API sigue
// accesible directamente. Aqui se pregunta a Firestore lo mismo que
// preguntaria un atacante con la sesion de ese rol.
async function leerDoc(page, ruta) {
  return page.evaluate(async (r) => {
    const app = window.firebase_core.getApps()[0];
    const fs = window.firebase_firestore;
    try {
      const snap = await fs.getDoc(fs.doc(fs.getFirestore(app), r));
      return { permitido: true, existe: snap.exists(), datos: snap.data() || null };
    } catch (e) {
      return { permitido: false, error: String(e) };
    }
  }, ruta);
}

// Escribe con los permisos del usuario en sesion. Mismo razonamiento.
async function escribirDoc(page, ruta, datos) {
  return page.evaluate(
    async ({ r, d }) => {
      const app = window.firebase_core.getApps()[0];
      const fs = window.firebase_firestore;
      try {
        await fs.updateDoc(fs.doc(fs.getFirestore(app), r), d);
        return { permitido: true };
      } catch (e) {
        return { permitido: false, error: String(e) };
      }
    },
    { r: ruta, d: datos },
  );
}

// Borra con los permisos del usuario en sesion.
async function borrarDoc(page, ruta) {
  return page.evaluate(async (r) => {
    const app = window.firebase_core.getApps()[0];
    const fs = window.firebase_firestore;
    try {
      await fs.deleteDoc(fs.doc(fs.getFirestore(app), r));
      return { permitido: true };
    } catch (e) {
      return { permitido: false, error: String(e) };
    }
  }, ruta);
}

module.exports = {
  ACTORES,
  CLAVE,
  VEHICULOS,
  esperarAppLista,
  proyectoDeLaApp,
  iniciarSesion,
  cerrarSesion,
  leerDoc,
  escribirDoc,
  borrarDoc,
};
