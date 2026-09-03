const { test, expect } = require('@playwright/test');

test.describe('Flujos del Mecánico', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    
    // Adjust timeouts and selectors based on CanvasKit delays (14s load, 3s transition)
    await page.waitForTimeout(15000);
    
    // Click to force flutter semantics tree
    await page.mouse.click(10, 10);
    
    const emailField = page.getByLabel(/Correo|Email/i).first();
    await emailField.click({ timeout: 120000 });
    await emailField.fill('taller1@taller.com');
    
    const passwordField = page.getByLabel(/Contraseña|Password/i).first();
    await passwordField.click({ timeout: 10000 });
    await passwordField.fill('hola123');
    
    await page.getByLabel(/Iniciar Sesión|Log In/i).first().click({ timeout: 10000 });
    
    // Esperar a que cargue el Dashboard del Taller
    await expect(page.getByLabel(/Dashboard|Servicios|Taller|Mecánico/i).first()).toBeVisible({ timeout: 35000 });
  });

  test('Verificación de Pantalla de Escáner', async ({ page }) => {
    // Necesitamos esperar la transición y habilitar semánticas si es necesario
    await page.waitForTimeout(3000);
    await page.getByLabel(/Escanear Placa|Nuevo Servicio|Escanear/i).first().click({ timeout: 10000 });
    await expect(page.getByLabel(/Placa|Vehículo|Buscar/i).first()).toBeVisible({ timeout: 15000 });
  });

  test('Historial de Servicios del Taller', async ({ page }) => {
    await page.waitForTimeout(3000);
    await page.getByLabel(/Historial|Servicios/i).first().click({ timeout: 10000 });
    await expect(page.getByLabel(/Terminado|Fecha|Completado/i).first()).toBeVisible({ timeout: 15000 });
  });
});
