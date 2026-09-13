'use strict';

const { test, expect } = require('@playwright/test');
const { ACTORES, iniciarSesion } = require('./helpers');

// Antes iniciaba sesion con `taller1@taller.com` contra PRODUCCION. Ahora usa
// el fixture `tallerA`, que nace 'aprobado' — un taller 'pendiente' no cruza
// isMecanico() y no veria ninguna de estas pantallas.
//
// Los rotulos tambien estaban desfasados ("Escanear Placa", "Historial"); hoy
// el panel dice "Buscar Vehículo" y "Mis Servicios".
//
// Los clics usan `getByRole`, no `getByLabel`. La app no emite ni un solo
// `aria-label`: Flutter web expone la semantica como elementos
// <flt-semantics role="button"> cuyo rotulo es su texto. `getByLabel` no
// puede casar con eso, asi que TODOS los selectores de la version anterior de
// este spec estaban condenados a expirar, apuntaran a la etiqueta que
// apuntaran.

test.describe('Flujos del Mecánico', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await iniciarSesion(page, ACTORES.tallerA);
    await page.waitForTimeout(5000);
    await page.mouse.click(10, 10);
    await page.waitForTimeout(2000);
  });

  test('aterriza en el panel de taller', async ({ page }) => {
    // Timeout explicito, no el de 5 s por defecto: el `beforeEach` espera una
    // duracion fija y el router se queda en `/?redirect=...` mientras carga el
    // perfil, asi que bajo carga esa espera adivinada se queda corta. Esperar a
    // la CONDICION en vez de a un reloj es lo que quita la intermitencia.
    await expect(page).toHaveURL(/mechanic_dashboard/, { timeout: 30000 });
    await expect(page.getByText('Panel de Taller').first()).toBeVisible({ timeout: 20000 });
  });

  test('navega a Buscar Vehículo', async ({ page }) => {
    await page.getByRole('button', { name: /Buscar Vehículo/ }).first().click({ timeout: 15000 });
    await page.waitForTimeout(4000);
    await expect(page).toHaveURL(/search|buscar|vehicle/i);
  });

  test('navega a Mis Servicios', async ({ page }) => {
    await page.getByRole('button', { name: /Mis Servicios/ }).first().click({ timeout: 15000 });
    await page.waitForTimeout(4000);
    await expect(page).toHaveURL(/servic/i);
  });

  test('navega a Reparaciones', async ({ page }) => {
    await page.getByRole('button', { name: /Reparaciones/ }).first().click({ timeout: 15000 });
    await page.waitForTimeout(4000);
    await expect(page).toHaveURL(/reparacion|kanban/i);
  });
});
