'use strict';

const { test, expect } = require('@playwright/test');
const { ACTORES, esperarAppLista, iniciarSesion } = require('./helpers');

// El defecto que este spec fija, y por que no es un capricho del harness.
//
// `Firebase.initializeApp()` en web ESPERA a que firebase_auth_web termine su
// `ensurePluginInitialized`, que a su vez hace `await onWaitInitState()`: el
// primer evento de `onAuthStateChanged`. Con una sesion persistida en
// IndexedDB, ese evento no llega hasta que el SDK de JS refresca el token
// guardado — o sea, una peticion de red — y todo eso ocurre ANTES de que
// `initializeApp` retorne. Como main.dart solo puede llamar a
// `conectarEmuladoresFirebase()` DESPUES, la peticion sale al Auth de
// PRODUCCION y, peor, deja el instance de Auth ya usado: el
// `connectAuthEmulator` que viene detras no tiene efecto y `emulatorConfig`
// se queda en null para siempre.
//
// Consecuencia practica: sin arreglar esto, ningun flujo E2E que necesite
// sesion MAS una navegacion de pagina completa se puede ejercer.
test.describe('sesion persistida y cableado a emuladores', () => {
  test('la sesion sobrevive a una recarga sin salir a produccion', async ({
    page,
  }) => {
    // Un solo test, con las dos cargas dentro: cada arranque de la app levanta
    // CanvasKit y la persistencia offline de Firestore, y el emulador Java se
    // degrada bajo esa carga (ver CLAUDE.md).
    // Solo los backends REALES de Firebase. No vale filtrar por
    // `googleapis.com` a secas: Flutter web pide fuentes a
    // fonts.googleapis.com en cada arranque y el test daria falsos rojos.
    const BACKENDS_REALES = [
      'identitytoolkit.googleapis.com',
      'securetoken.googleapis.com',
      'firestore.googleapis.com',
      'firebasestorage.googleapis.com',
    ];
    const aProduccion = [];
    page.on('request', (req) => {
      const host = new URL(req.url()).hostname;
      if (BACKENDS_REALES.includes(host)) aProduccion.push(req.url());
    });

    // Sin esto el test se puede poner verde con la app ROTA, y de hecho lo
    // hizo: el primer intento de arreglo dejaba el SDK de JS perfecto —
    // emulatorConfig puesto, sesion restaurada— mientras
    // `Firebase.initializeApp` de Dart moria con `auth/already-initialized` y
    // Flutter caia a la pantalla de error de arranque. Todas las afirmaciones
    // de abajo miran el SDK, que es la capa equivocada para detectar eso.
    const erroresDeArranque = [];
    page.on('console', (m) => {
      const t = m.text();
      if (t.includes('ERROR al inicializar Firebase')) erroresDeArranque.push(t);
    });

    await page.goto('/');
    await esperarAppLista(page);
    const { uid } = await iniciarSesion(page, ACTORES.propietarioA);

    // La recarga es el punto exacto del fallo: aqui la sesion ya esta
    // persistida, asi que la siguiente carga la restaura durante el
    // initializeApp.
    await page.reload();

    // Si el cableado se pierde, esto es lo que se queda colgado.
    await esperarAppLista(page);

    const sesion = await page.evaluate(() => {
      const app = window.firebase_core.getApps()[0];
      const auth = window.firebase_auth.getAuth(app);
      return {
        uid: auth.currentUser ? auth.currentUser.uid : null,
        emulador: auth.emulatorConfig ? auth.emulatorConfig.port : null,
      };
    });

    expect(sesion.emulador).toBe(9099);
    expect(sesion.uid).toBe(uid);

    // Y la app de Flutter arranco de verdad, no la pantalla de error.
    expect(erroresDeArranque).toEqual([]);
    await page.mouse.click(10, 10); // Flutter solo emite semantica tras un clic.
    await expect(page.locator('flt-semantics').first()).toBeAttached({
      timeout: 30000,
    });

    // La afirmacion que cierra el agujero: ni una sola peticion a los
    // endpoints reales de Google en toda la corrida. Sin el arreglo hay un 400
    // contra el Auth de produccion al restaurar la sesion.
    expect(aProduccion).toEqual([]);
  });
});
