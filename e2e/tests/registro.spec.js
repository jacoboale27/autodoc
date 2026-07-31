const { test, expect } = require('@playwright/test');

test.describe('Registro de Nuevos Usuarios', () => {
  test('Flujo de registro para Propietario', async ({ page }) => {
    await page.goto('/');
    
    // Give Flutter Web some time to initialize its DOM
    await page.waitForTimeout(3000);

    // Navegar al registro.
    await page.getByText(/Regístrate|Sign up/i).first().click();
    await page.waitForTimeout(1000);
    
    // Llenar formulario de auth (Auth screen only has email and password)
    const id = Date.now();
    
    // In HTML renderer, Flutter uses standard inputs often without accessible labels immediately identifiable by getByRole,
    // so we can fallback to standard locators if aria-labels aren't perfect, but let's try standard roles:
    const emailField = page.locator('input[type="email"], input[aria-label*="Correo"], input[aria-label*="Email"]').first();
    const passwordField = page.locator('input[type="password"], input[aria-label*="Contraseña"], input[aria-label*="Password"]').first();
    
    // If specific types aren't found, fallback to textbox index
    if (await emailField.count() === 0) {
      await page.getByRole('textbox').nth(0).fill(`propietario_${id}@test.com`);
      await page.getByRole('textbox').nth(1).fill('hola1234');
    } else {
      await emailField.fill(`propietario_${id}@test.com`);
      await passwordField.fill('hola1234');
    }
    
    // Registrar
    await page.locator('text=/Registrarse|Sign Up/i, [aria-label*="Registrarse"], [aria-label*="Sign Up"]').first().click();
    
    // Verificamos que aparezca el diálogo de verificación
    await expect(page.locator('text=/Verifica tu correo|Verify your email/i, [aria-label*="Verifica tu correo"], [aria-label*="Verify your email"]').first()).toBeVisible({ timeout: 15000 });
    
    // Click 'Entendido' or 'Understood' in the dialog
    await page.locator('text=/Entendido|Understood/i, [aria-label*="Entendido"], [aria-label*="Understood"]').first().click();
    
    // Navigate to profile setup
    await expect(page.locator('text=/NOMBRE COMPLETO/i, [aria-label*="NOMBRE COMPLETO"]')).toBeVisible({ timeout: 15000 });
    
    // Configurar Perfil
    await page.locator('text=/Propietario/i, [aria-label*="Propietario"]').first().click();
    
    // Rellenar nombre
    const nameField = page.locator('input[type="text"]').first();
    if (await nameField.count() > 0) {
      await nameField.fill(`Propietario Test ${id}`);
    } else {
      await page.getByRole('textbox').first().fill(`Propietario Test ${id}`);
    }
    
    // Finalizar
    await page.locator('text=/Finalizar Configuración/i, [aria-label*="Finalizar Configuración"]').first().click();
    
    // Verificar que llega al Dashboard
    await expect(page.locator('text=/Dashboard|Mis Vehículos/i, [aria-label*="Dashboard"], [aria-label*="Mis Vehículos"]').first()).toBeVisible({ timeout: 15000 });
  });

  test('Flujo de registro para Mecánico', async ({ page }) => {
    await page.goto('/');
    
    // Give Flutter Web some time to initialize its DOM
    await page.waitForTimeout(3000);

    // Navegar al registro.
    await page.getByText(/Regístrate|Sign up/i).first().click();
    await page.waitForTimeout(1000);
    
    // Llenar formulario de auth (Auth screen only has email and password)
    const id = Date.now();
    
    const emailField = page.locator('input[type="email"], input[aria-label*="Correo"], input[aria-label*="Email"]').first();
    const passwordField = page.locator('input[type="password"], input[aria-label*="Contraseña"], input[aria-label*="Password"]').first();
    
    // If specific types aren't found, fallback to textbox index
    if (await emailField.count() === 0) {
      await page.getByRole('textbox').nth(0).fill(`mecanico_${id}@test.com`);
      await page.getByRole('textbox').nth(1).fill('hola1234');
    } else {
      await emailField.fill(`mecanico_${id}@test.com`);
      await passwordField.fill('hola1234');
    }
    
    // Registrar
    await page.locator('text=/Registrarse|Sign Up/i, [aria-label*="Registrarse"], [aria-label*="Sign Up"]').first().click();
    
    // Verificamos que aparezca el diálogo de verificación
    await expect(page.locator('text=/Verifica tu correo|Verify your email/i, [aria-label*="Verifica tu correo"], [aria-label*="Verify your email"]').first()).toBeVisible({ timeout: 15000 });
    
    // Click 'Entendido' or 'Understood' in the dialog
    await page.locator('text=/Entendido|Understood/i, [aria-label*="Entendido"], [aria-label*="Understood"]').first().click();
    
    // Navigate to profile setup
    await expect(page.locator('text=/NOMBRE COMPLETO/i, [aria-label*="NOMBRE COMPLETO"]')).toBeVisible({ timeout: 15000 });
    
    // Configurar Perfil
    await page.locator('text=/Mecánico|Mecanico/i, [aria-label*="Mecánico"], [aria-label*="Mecanico"]').first().click();
    
    // Rellenar nombre
    const nameField = page.locator('input[type="text"]').first();
    if (await nameField.count() > 0) {
      await nameField.fill(`Mecánico Test ${id}`);
    } else {
      await page.getByRole('textbox').first().fill(`Mecánico Test ${id}`);
    }
    
    // Finalizar
    await page.locator('text=/Finalizar Configuración/i, [aria-label*="Finalizar Configuración"]').first().click();
    
    // Verificar que llega al Dashboard de Mecánico
    await expect(page.locator('text=/Dashboard|Taller/i, [aria-label*="Dashboard"], [aria-label*="Taller"]').first()).toBeVisible({ timeout: 15000 });
  });
});
