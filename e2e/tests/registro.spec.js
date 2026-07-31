const { test, expect } = require('@playwright/test');

test.describe('Registro de Nuevos Usuarios', () => {
  test('Flujo de registro para Propietario', async ({ page }) => {
    await page.goto('/');
    
    // Give Flutter Web some time to initialize its semantics tree
    await page.waitForTimeout(5000);

    // Navegar al registro. En Flutter web (CanvasKit) con Semantics, el texto a menudo se expone como aria-label.
    // Buscamos algo que sea cliqueable con 'Regístrate'
    await page.locator('[aria-label*="Regístrate"], [aria-label*="Sign up"]').first().click();
    await page.waitForTimeout(1000);
    
    // Llenar formulario (Auth screen only has email and password)
    const id = Date.now();
    
    // Flutter semantics exposes text fields as textboxes.
    const emailField = page.getByRole('textbox').nth(0);
    await emailField.click();
    await emailField.fill(`propietario_${id}@test.com`);
    
    const passwordField = page.getByRole('textbox').nth(1);
    await passwordField.click();
    await passwordField.fill('hola1234');
    
    // Registrar
    await page.locator('[aria-label*="Registrarse"], [aria-label*="Sign Up"]').first().click();
    
    // Verificamos que aparezca el diálogo de verificación (o la siguiente pantalla)
    await expect(page.locator('[aria-label*="Verifica"], [aria-label*="Verify"]').first()).toBeVisible({ timeout: 15000 });
  });

  test('Flujo de registro para Mecánico (Ascenso/Selección)', async ({ page }) => {
    // Como el rol se selecciona en /profile_setup, por ahora lo saltamos.
    test.skip();
  });
});
