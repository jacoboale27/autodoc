'use strict';

const { test, expect } = require('@playwright/test');
const {
  ACTORES,
  esperarAppLista,
  proyectoDeLaApp,
  iniciarSesion,
  cerrarSesion,
} = require('./helpers');

// Prueba del harness, no de la app. Si esto falla, cualquier otro resultado de
// la suite es ruido: significa que el bundle no arranco, que no habla con los
// emuladores, o que los fixtures no estan.
//
// La comprobacion de que apunta a emuladores es la que mas importa. La suite
// entera existia antes contra produccion, y el sintoma de esa averia era
// invisible: los tests pasaban. Aqui se afirma explicitamente.

test.describe('harness E2E', () => {
  test('el bundle arranca y su Firebase es el proyecto de emuladores', async ({ page }) => {
    await page.goto('/');
    await esperarAppLista(page);

    const proyecto = await proyectoDeLaApp(page);

    // Si esto dijera el proyecto real, la suite estaria escribiendo en
    // produccion otra vez.
    expect(proyecto).toBe('autodoc-e2e');
  });

  test('los fixtures existen y la sesion se establece verificada', async ({ page }) => {
    await page.goto('/');
    const r = await iniciarSesion(page, ACTORES.propietarioA);

    expect(r.uid).toBe(ACTORES.propietarioA.uid);
    // SEC-02 hizo obligatoria la verificacion de correo: un fixture sin
    // verificar nunca cruzaria el gate del router, y el sintoma seria toda la
    // suite rebotando a la pantalla de verificacion.
    expect(r.verificado).toBe(true);

    await cerrarSesion(page);
  });

  test('los seis actores del plan pueden iniciar sesion', async ({ page }) => {
    await page.goto('/');
    await esperarAppLista(page);

    for (const [nombre, actor] of Object.entries(ACTORES)) {
      const r = await iniciarSesion(page, actor);
      expect(r.uid, `actor ${nombre}`).toBe(actor.uid);
      await cerrarSesion(page);
    }
  });
});
