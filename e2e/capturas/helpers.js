'use strict';

// Helpers de la suite de capturas.
//
// Reutiliza `esperarAppLista` de ../tests/helpers.js —la espera a las tres
// piezas (flutter-view montado, Auth en su emulador, Firestore en el suyo) es
// exactamente la misma y duplicarla seria condenarla a divergir— pero trae su
// propio login, porque el de alli lleva incrustada la clave de
// seed-emulators.js y la vitrina usa otra.

const { expect } = require('@playwright/test');
const path = require('path');
const { esperarAppLista } = require('../tests/helpers');

// Actores de scripts/seed-vitrina.js. Se declaran aqui por el mismo motivo que
// en la suite de tests: ningun spec lleva credenciales sueltas.
const ACTORES = {
  propietario: { correo: 'sofia@autodoc.demo', uid: 'vit-propietario' },
  taller: { correo: 'taller@autodoc.demo', uid: 'vit-taller' },
};
const CLAVE = 'vitrina-password-123';

const DIR_SALIDA = path.join(__dirname, 'out');

/**
 * Abre una ruta de la app y la deja lista para fotografiar.
 *
 * El clic no es opcional ni supersticion: Flutter web solo construye el arbol
 * de semantica cuando detecta interaccion, y sin el ningun `getByRole`
 * encuentra nada. Se hace en (10,10) para no pulsar ningun control real.
 */
async function abrirApp(page, ruta = '/') {
  await page.goto(ruta);
  await esperarAppLista(page);
  await page.mouse.click(10, 10);
}

/**
 * Inicia sesion por el SDK ya cargado en la pagina, no por el formulario.
 *
 * Igual que en la suite de tests: el proxy de input de Flutter web pierde el
 * valor del campo de correo al mover el foco, asi que el login por UI es
 * intermitente. Aqui ademas da igual el flujo — lo que se fotografia es lo que
 * hay DESPUES de entrar.
 */
async function entrarComo(page, actor) {
  await esperarAppLista(page);
  const r = await page.evaluate(
    async ({ correo, clave }) => {
      try {
        const app = window.firebase_core.getApps()[0];
        const auth = window.firebase_auth.getAuth(app);
        const cred = await window.firebase_auth.signInWithEmailAndPassword(
          auth,
          correo,
          clave,
        );
        return { ok: true, uid: cred.user.uid };
      } catch (e) {
        return { ok: false, error: String(e) };
      }
    },
    { correo: actor.correo, clave: CLAVE },
  );
  if (!r.ok) {
    throw new Error(`No se pudo entrar como ${actor.correo}: ${r.error}`);
  }
  return r;
}

/**
 * Guarda de idioma y de contenido, en una sola llamada.
 *
 * Las dos afirmaciones existen por un fallo distinto y las dos han ocurrido:
 *
 *  - `enEspanol`: el bundle se renderiza en INGLES si el locale no se fuerza, y
 *    como los rotulos fuera del ARB siguen en español, una captura en ingles no
 *    se distingue de una buena a ojo rapido. La config ya fuerza es-CO; esto es
 *    el cinturon que avisa si alguien la toca.
 *  - `conDatos`: una pantalla que no cargo sus datos sale limpia y vacia, que
 *    es justo lo que una captura de tienda no puede permitirse. Sin esta
 *    afirmacion, un fallo de siembra produce ocho PNGs preciosos y vacios.
 */
async function comprobarPantalla(page, { enEspanol, conDatos }) {
  for (const texto of enEspanol) {
    await expect(
      page.getByText(texto, { exact: false }).first(),
      `Rotulo en español ausente: "${texto}". ¿Se renderizo en ingles?`,
    ).toBeVisible({ timeout: 30000 });
  }
  for (const texto of conDatos) {
    await expect(
      page.getByText(texto, { exact: false }).first(),
      `Dato de vitrina ausente: "${texto}". ¿Fallo la siembra?`,
    ).toBeVisible({ timeout: 30000 });
  }
}

/**
 * Deja el PNG en capturas/out/NN-nombre.png.
 *
 * El `waitForTimeout` es deliberado y no se puede sustituir por
 * `waitForLoadState('networkidle')`: lo que falta asentar no es red, son las
 * animaciones de entrada de Flutter, y una captura tomada a mitad de un fundido
 * sale translucida. `pumpAndSettle` no existe aqui — eso es del lado Dart.
 */
async function capturar(page, orden, nombre) {
  await page.waitForTimeout(1200);
  const archivo = path.join(
    DIR_SALIDA,
    `${String(orden).padStart(2, '0')}-${nombre}.png`,
  );
  await page.screenshot({ path: archivo, fullPage: false });
  return archivo;
}

module.exports = { ACTORES, CLAVE, DIR_SALIDA, abrirApp, entrarComo, comprobarPantalla, capturar };
