const { test, expect } = require('@playwright/test');

test.describe('Flujos del Propietario', () => {
  test.beforeEach(async ({ page }) => {
    // Iniciar sesión con credenciales de prueba
    await page.goto('/');
    
    // Adjust timeouts and selectors based on CanvasKit delays (14s load, 3s transition)
    await page.waitForTimeout(15000);
    
    // Click to force flutter semantics tree
    await page.mouse.click(10, 10);
    
    const emailField = page.getByLabel(/Correo|Email/i).first();
    await emailField.click({ timeout: 25000 });
    await emailField.fill('nadie@gmail.com');
    
    const passwordField = page.getByLabel(/Contraseña|Password/i).first();
    await passwordField.click({ timeout: 10000 });
    await passwordField.fill('hola123');
    
    await page.getByLabel(/Iniciar Sesión|Log In/i).first().click({ timeout: 10000 });
    
    // Esperar a que cargue el Dashboard
    await expect(page.getByLabel(/Dashboard|Mis Vehículos/i).first()).toBeVisible({ timeout: 25000 });
  });

  test('Navegación a Mis Vehículos', async ({ page }) => {
    // Buscar el acceso a mis vehículos y hacer click
    await page.getByLabel(/Mis Vehículos/i).first().click({ timeout: 10000 });
    // Verificar que estamos en la lista de vehículos
    await expect(page.getByLabel(/Agregar Vehículo|Placa/i).first()).toBeVisible({ timeout: 15000 });
  });

  test('Navegación a Directorio de Talleres', async ({ page }) => {
    // Regresar si es necesario o usar menú
    // Asumimos que el Drawer o BottomNav tiene el directorio
    await page.getByLabel(/Directorios|Talleres/i).first().click({ timeout: 10000 });
    await expect(page.getByLabel(/Buscar Taller|Calificación/i).first()).toBeVisible({ timeout: 15000 });
  });

  test('Navegación a Alertas', async ({ page }) => {
    await page.getByLabel(/Alertas|Recordatorios/i).first().click({ timeout: 10000 });
    await expect(page.getByLabel(/Pendiente/i).first()).toBeVisible({ timeout: 15000 });
  });
});
