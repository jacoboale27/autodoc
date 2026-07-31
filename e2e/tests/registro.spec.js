const { test, expect } = require('@playwright/test');

test.describe('Registro de Nuevos Usuarios', () => {
  test('Flujo de registro para Propietario', async ({ page }) => {
    await page.goto('/');
    
    // Navegar al registro.
    // Use getByLabel with a regex and increased timeout to account for 14s initial load
    await page.getByLabel(/Regístrate gratis|Sign up/i).first().click({ timeout: 25000 });
    
    // Llenar formulario de auth
    const id = Date.now();
    
    const emailField = page.getByLabel(/Correo|Email/i).first();
    await emailField.click({ timeout: 15000 });
    await emailField.fill(`propietario_${id}@test.com`);
    
    const passwordField = page.getByLabel(/Contraseña|Password/i).first();
    await passwordField.click({ timeout: 10000 });
    await passwordField.fill('hola1234');
    
    // Registrar
    await page.getByLabel(/Registrarse|Sign Up/i).first().click({ timeout: 10000 });
    
    // Verificamos que aparezca el diálogo de verificación
    await expect(page.getByLabel(/Verifica tu correo|Verify your email/i).first()).toBeVisible({ timeout: 20000 });
    
    // Click 'Entendido' or 'Understood' in the dialog
    await page.getByLabel(/Entendido|Understood/i).first().click({ timeout: 10000 });
    
    // Navigate to profile setup and wait for the name field
    const nameField = page.getByLabel(/NOMBRE COMPLETO|Ej. Juan/i).first();
    await nameField.click({ timeout: 20000 });
    await nameField.fill(`Propietario Test ${id}`);
    
    // Configurar Perfil - Seleccionar Propietario
    await page.getByLabel(/Propietario/i).first().click({ timeout: 10000 });
    
    // Finalizar
    await page.getByLabel(/Finalizar Configuración/i).first().click({ timeout: 10000 });
    
    // Verificar que llega al Dashboard
    await expect(page.getByLabel(/Dashboard|Mis Vehículos/i).first()).toBeVisible({ timeout: 20000 });
  });

  test('Flujo de registro para Mecánico', async ({ page }) => {
    await page.goto('/');
    
    // Navegar al registro.
    await page.getByLabel(/Regístrate gratis|Sign up/i).first().click({ timeout: 25000 });
    
    // Llenar formulario de auth
    const id = Date.now();
    
    const emailField = page.getByLabel(/Correo|Email/i).first();
    await emailField.click({ timeout: 15000 });
    await emailField.fill(`mecanico_${id}@test.com`);
    
    const passwordField = page.getByLabel(/Contraseña|Password/i).first();
    await passwordField.click({ timeout: 10000 });
    await passwordField.fill('hola1234');
    
    // Registrar
    await page.getByLabel(/Registrarse|Sign Up/i).first().click({ timeout: 10000 });
    
    // Verificamos que aparezca el diálogo de verificación
    await expect(page.getByLabel(/Verifica tu correo|Verify your email/i).first()).toBeVisible({ timeout: 20000 });
    
    // Click 'Entendido' or 'Understood' in the dialog
    await page.getByLabel(/Entendido|Understood/i).first().click({ timeout: 10000 });
    
    // Navigate to profile setup and wait for the name field
    const nameField = page.getByLabel(/NOMBRE COMPLETO|Ej. Juan/i).first();
    await nameField.click({ timeout: 20000 });
    await nameField.fill(`Mecánico Test ${id}`);
    
    // Configurar Perfil - Seleccionar Mecánico
    await page.getByLabel(/Mecánico|Mecanico/i).first().click({ timeout: 10000 });
    
    // Finalizar
    await page.getByLabel(/Finalizar Configuración/i).first().click({ timeout: 10000 });
    
    // Verificar que llega al Dashboard de Mecánico
    await expect(page.getByLabel(/Dashboard|Taller/i).first()).toBeVisible({ timeout: 20000 });
  });
});
