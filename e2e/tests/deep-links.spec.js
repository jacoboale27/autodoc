'use strict';

const fs = require('fs');
const path = require('path');
const { test, expect } = require('@playwright/test');
const { esperarAppLista } = require('./helpers');

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

  test('un deep link a una ruta inexistente no deja al usuario varado', async ({
    page,
  }) => {
    // Sin sesion el redirect del router manda a /login antes de llegar al
    // errorBuilder (app_router.dart: `if (!isLoggedIn && !isPublicRoute)`), asi
    // que lo que se afirma aqui es lo que importa: nunca es el 404 del
    // servidor ni una pantalla en blanco, siempre una pantalla util.
    //
    // El 404 propiamente dicho, con su copy localizada y su boton de salida,
    // esta cubierto en test/core/router/app_router_not_found_screen_test.dart.
    // No se puede ejercer aqui: exige sesion, y una sesion persistida rompe el
    // cableado a emuladores en la siguiente carga completa (ver la nota de
    // docs/evidencia/UX-02-errores-y-deep-links.md).
    await page.goto('/ruta_que_no_existe');
    await esperarAppLista(page);
    await despertarSemantica(page);

    await expect
      .poll(() => new URL(page.url()).pathname, { timeout: 30000 })
      .toBe('/login');
    await expect(page.locator('flt-semantics').first()).toBeAttached({
      timeout: 30000,
    });
  });
});
