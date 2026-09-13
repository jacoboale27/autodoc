'use strict';

// QA destructivo de H-01: rutas protegidas sin sesion y vuelta ATRAS tras
// cerrar sesion.
//
// El resto del checklist del plan vive donde ya estaba: vacio / invalido /
// duplicado / doble submit en `registro.spec.js`, refresh en
// `sesion-persistida.spec.js`, cross-tenant en `roles.spec.js` y rutas
// inexistentes en `deep-links.spec.js`. Aqui van los dos que no cubria nadie.
//
// Los dos casos van agrupados por arranque de app a proposito: cada boot
// cuesta CanvasKit + persistencia offline y degrada el emulador Java.

const { test, expect } = require('@playwright/test');
const { esperarAppLista, iniciarSesion, cerrarSesion, ACTORES } = require('./helpers');

// Una por familia de rol, incluidas las de admin: si el guard se evaluara solo
// en las de propietario, este test lo veria.
const PROTEGIDAS = [
  '/garage',
  '/dashboard',
  '/alerts',
  '/chat_list',
  '/mechanic_dashboard',
  '/admin/usuarios',
];

test('sin sesion, toda ruta protegida acaba en el login', async ({ page }) => {
  await page.goto('/');
  await esperarAppLista(page);

  for (const ruta of PROTEGIDAS) {
    await page.goto(ruta);
    // El redirect del router es sincrono con el cambio de ruta, pero la app
    // tarda en repintar; se espera a la URL, no a un rotulo.
    await expect
      .poll(() => new URL(page.url()).pathname, { timeout: 20000 })
      .toBe('/login');
  }
});

test('tras cerrar sesion, ATRAS no devuelve la pantalla con datos', async ({ page }) => {
  await page.goto('/');
  await iniciarSesion(page, ACTORES.propietarioA);
  await page.goto('/garage');
  // `goto` recarga la pagina entera: los globales de Firebase y el arbol de
  // Flutter vuelven a construirse desde cero, asi que hay que reesperar. Sin
  // esto, `cerrarSesion` encuentra `window.firebase_core` undefined.
  await esperarAppLista(page);
  await expect
    .poll(() => new URL(page.url()).pathname, { timeout: 30000 })
    .toBe('/garage');

  await cerrarSesion(page);

  // Sale a ruta publica, no necesariamente a /login: al cerrar sesion el
  // perfil queda en «cargando» un instante y el router manda a `/?redirect=`
  // antes de aplicar la regla de sesion cerrada (app_router.dart:252-268).
  // Lo que importa no es CUAL de las publicas, sino que /garage deje de estar
  // montada. Afirmar '/login' aqui seria atar el test a un detalle transitorio.
  const PUBLICAS = ['/', '/login', '/register', '/onboarding'];
  await expect
    .poll(() => new URL(page.url()).pathname, { timeout: 30000 })
    .toMatch(/^\/(login|register|onboarding)?$/);

  // La entrada de /garage sigue en el historial del navegador. Volver a ella
  // no puede montar la pantalla: el guard tiene que reevaluarse.
  await page.goBack();
  await page.waitForTimeout(4000);
  expect(
    PUBLICAS,
    'ATRAS tras el logout no puede dejar una pantalla protegida montada.',
  ).toContain(new URL(page.url()).pathname);

  // Y la sesion sigue cerrada: que la UI no pinte datos no prueba que la API
  // este cerrada. Se pregunta a Firestore lo mismo que preguntaria un atacante.
  const hayUsuario = await page.evaluate(() => {
    const app = window.firebase_core.getApps()[0];
    return !!window.firebase_auth.getAuth(app).currentUser;
  });
  expect(hayUsuario, 'No puede quedar sesion viva tras el logout.').toBe(false);
});
