'use strict';

const fs = require('fs');
const path = require('path');
const { test, expect } = require('@playwright/test');
const { ACTORES, esperarAppLista, iniciarSesion } = require('./helpers');

// UX-02. Hasta aqui la suite de la app entraba SIEMPRE por '/' y navegaba
// clicando, asi que nada probaba el caso que rompe en produccion: pegar una
// URL profunda en la barra o recargar sobre ella. Sin el rewrite SPA eso lo
// resuelve el servidor, no el router, y devuelve 404 antes de que la app
// llegue a arrancar.

// Flutter web solo construye el arbol de semantica tras una interaccion; sin
// esto ningun getByRole encuentra nada.
async function despertarSemantica(page) {
  await page.mouse.click(10, 10);
}

test.describe('deep links y recuperacion de errores', () => {
  // La app elige idioma por el del navegador (MaterialApp sin `locale`
  // explicito). Fijarlo aqui es lo que permite afirmar la copy en español en
  // vez de comparar contra lo que traiga la maquina de turno.
  test.use({ locale: 'es-ES' });

  test('el servidor entrega la app, no un 404, para una ruta profunda', async ({
    request,
  }) => {
    // El contrato del fallback SPA, medido en la respuesta HTTP y no en la UI.
    const res = await request.get('/garage');

    expect(res.status()).toBe(200);
    expect(res.headers()['content-type']).toContain('text/html');
  });

  test('firebase.json declara el mismo rewrite SPA que sirve la suite', async () => {
    // El servidor de la suite imita a Hosting; si la config real perdiera el
    // rewrite, la suite seguiria verde y produccion daria 404. Esta afirmacion
    // es lo que impide esa divergencia silenciosa.
    const cfg = JSON.parse(
      fs.readFileSync(path.join(__dirname, '..', '..', 'firebase.json'), 'utf8'),
    );
    const app = cfg.hosting.find((h) => h.target === 'app');

    expect(app.rewrites).toContainEqual({
      source: '**',
      destination: '/index.html',
    });
  });

  test('un deep link a una ruta publica arranca la app ahi y sobrevive a una '
    + 'recarga', async ({ page }) => {
    // Entrar directo, sin pasar por '/' ni clicar: es el caso del enlace
    // pegado en la barra o del marcador. Si el fallback SPA no estuviera, el
    // servidor responderia su propio 404 y no existiria `window.firebase_core`.
    //
    // El goto y la recarga van en el MISMO test a proposito. Cada arranque de
    // la app levanta CanvasKit y la persistencia offline de Firestore, y el
    // emulador Java se degrada bajo esa carga (ver CLAUDE.md): partirlo en dos
    // tests duplicaba los arranques y hacia caer specs ajenas por timeout.
    await page.goto('/register');
    await esperarAppLista(page);
    await despertarSemantica(page);

    expect(new URL(page.url()).pathname).toBe('/register');
    await expect(page.locator('flt-semantics').first()).toBeAttached({
      timeout: 30000,
    });

    await page.reload();
    await esperarAppLista(page);

    expect(new URL(page.url()).pathname).toBe('/register');
  });

  test('un deep link a una ruta inexistente: sin sesion lleva a /login, con '
    + 'sesion muestra el 404 de la app', async ({ page }) => {
    // Las dos mitades del mismo deep link van en el MISMO test, y no por
    // elegancia: cada carga completa levanta CanvasKit y la persistencia
    // offline de Firestore, y el emulador Java se degrada bajo esa carga (ver
    // CLAUDE.md). Asi son dos arranques en vez de tres.

    // 1. Sin sesion, el redirect del router manda a /login antes de llegar al
    //    errorBuilder (app_router.dart: `if (!isLoggedIn && !isPublicRoute)`).
    //    Lo que importa afirmar es que nunca es el 404 del servidor ni una
    //    pantalla en blanco.
    await page.goto('/ruta_que_no_existe');
    await esperarAppLista(page);
    await despertarSemantica(page);

    await expect
      .poll(() => new URL(page.url()).pathname, { timeout: 30000 })
      .toBe('/login');

    // 2. Con sesion si se llega al errorBuilder. Esta mitad estuvo sin cubrir
    //    mientras una sesion persistida rompia el cableado a emuladores en la
    //    siguiente carga completa; lo arregla e2e/scripts/shim-emuladores.js, y
    //    lo que sigue es lo que impide que el agujero vuelva en silencio.
    await iniciarSesion(page, ACTORES.propietarioA);

    // Navegacion de pagina completa CON la sesion ya persistida: el caso real
    // del enlace pegado en la barra por alguien que ya habia entrado.
    await page.goto('/ruta_que_no_existe');
    await esperarAppLista(page);
    await despertarSemantica(page);

    // El router retiene en el splash mientras carga el perfil
    // (`/?redirect=...`, app_router.dart:267) y navega al destino al terminar,
    // asi que se espera a la condicion y no a un tiempo fijo.
    await expect
      .poll(() => new URL(page.url()).pathname, { timeout: 60000 })
      .toBe('/ruta_que_no_existe');

    // La pantalla de verdad: copy localizada y la ruta que fallo a la vista.
    await expect(page.getByText('No encontramos esta página')).toBeVisible({
      timeout: 30000,
    });
    await expect(page.getByText('/ruta_que_no_existe')).toBeVisible();

    // Y la salida funciona, que es lo que separa un 404 util de un callejon.
    //
    // `.last()` no es un parche: Flutter emite DOS nodos de semantica por
    // boton —el contenedor y el que lleva el rotulo y el `flt-tappable`— y el
    // que recibe el clic es el segundo.
    await page.getByRole('button', { name: 'Ir al inicio' }).last().click();
    await expect
      .poll(() => new URL(page.url()).pathname, { timeout: 30000 })
      .not.toBe('/ruta_que_no_existe');
  });
});
