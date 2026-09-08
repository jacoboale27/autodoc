'use strict';

// ESTADO: los dos flujos de registro por UI estan marcados como `fixme`.
//
// Lo importante ya esta arreglado: este spec creaba usuarios nuevos EN
// PRODUCCION en cada corrida. Ahora la config apunta a los emuladores, asi que
// aunque estos tests corran no tocan nada real.
//
// Lo que sigue roto es el recorrido en si, y no por poco: la pantalla de auth
// se rehizo en SEC-01 y SEC-02 (invitacion sin contraseña compartida y gate de
// correo verificado), asi que los rotulos que buscan estos tests —empezando
// por "Regístrate gratis"— ya no existen. Ademas el llenado de formularios de
// Flutter web es inestable: el proxy de input pierde el valor del campo de
// correo al mover el foco al de contraseña.
//
// Rehacerlos exige redescubrir el recorrido completo de registro contra la UI
// actual, que es trabajo de UX-01/UX-03 y no de QA-01. Se dejan como `fixme`
// —que Playwright reporta aparte, no como verde— en vez de en rojo permanente:
// una suite que siempre tiene dos rojos deja de mirarse, y entonces el tercer
// rojo, el de verdad, tampoco se ve.
//
// La cobertura de autenticacion que QA-01 si necesita no depende de esto: vive
// en harness.spec.js (los seis roles inician sesion, con correo verificado) y
// en roles.spec.js (que puede y que no puede cada rol).

const { test, expect } = require('@playwright/test');

test.describe('Registro de Nuevos Usuarios', () => {
  test.fixme('Flujo de registro para Propietario', async ({ page }) => {
    await page.goto('/');

    // Flutter web no construye el arbol de semantica hasta que hay una
    // interaccion; sin esto ningun selector encuentra nada.
    await page.waitForTimeout(12000);
    await page.mouse.click(10, 10);
    await page.waitForTimeout(2000);

    // Navegar al registro.
    // Use getByLabel with a regex and increased timeout to account for 14s initial load
    await page.getByText(/Regístrate gratis|Sign up/i).first().click({ timeout: 25000 });
    
    // Llenar formulario de auth
    const id = Date.now();
    
    const emailField = page.getByLabel(/Correo|Email/i).first();
    await emailField.click({ timeout: 15000 });
    await emailField.fill(`propietario_${id}@test.com`);
    
    const passwordField = page.getByLabel(/Contraseña|Password/i).first();
    await passwordField.click({ timeout: 10000 });
    await passwordField.fill('hola1234');
    
    // Registrar
    await page.getByText(/Registrarse|Sign Up/i).first().click({ timeout: 10000 });
    
    // Verificamos que aparezca el diálogo de verificación
    await expect(page.getByText(/Verifica tu correo|Verify your email/i).first()).toBeVisible({ timeout: 20000 });
    
    // Click 'Entendido' or 'Understood' in the dialog
    await page.getByText(/Entendido|Understood/i).first().click({ timeout: 10000 });
    
    // Navigate to profile setup and wait for the name field
    const nameField = page.getByLabel(/NOMBRE COMPLETO|Ej. Juan/i).first();
    await nameField.click({ timeout: 20000 });
    await nameField.fill(`Propietario Test ${id}`);
    
    // Configurar Perfil - Seleccionar Propietario
    await page.getByText(/Propietario/i).first().click({ timeout: 10000 });
    
    // Finalizar
    await page.getByText(/Finalizar Configuración/i).first().click({ timeout: 10000 });
    
    // Verificar que llega al Dashboard
    await expect(page.getByText(/Dashboard|Mis Vehículos/i).first()).toBeVisible({ timeout: 20000 });
  });

  test.fixme('Flujo de registro para Mecánico', async ({ page }) => {
    await page.goto('/');

    // Flutter web no construye el arbol de semantica hasta que hay una
    // interaccion; sin esto ningun selector encuentra nada.
    await page.waitForTimeout(12000);
    await page.mouse.click(10, 10);
    await page.waitForTimeout(2000);

    // Navegar al registro.
    await page.getByText(/Regístrate gratis|Sign up/i).first().click({ timeout: 25000 });
    
    // Llenar formulario de auth
    const id = Date.now();
    
    const emailField = page.getByLabel(/Correo|Email/i).first();
    await emailField.click({ timeout: 15000 });
    await emailField.fill(`mecanico_${id}@test.com`);
    
    const passwordField = page.getByLabel(/Contraseña|Password/i).first();
    await passwordField.click({ timeout: 10000 });
    await passwordField.fill('hola1234');
    
    // Registrar
    await page.getByText(/Registrarse|Sign Up/i).first().click({ timeout: 10000 });
    
    // Verificamos que aparezca el diálogo de verificación
    await expect(page.getByText(/Verifica tu correo|Verify your email/i).first()).toBeVisible({ timeout: 20000 });
    
    // Click 'Entendido' or 'Understood' in the dialog
    await page.getByText(/Entendido|Understood/i).first().click({ timeout: 10000 });
    
    // Navigate to profile setup and wait for the name field
    const nameField = page.getByLabel(/NOMBRE COMPLETO|Ej. Juan/i).first();
    await nameField.click({ timeout: 20000 });
    await nameField.fill(`Mecánico Test ${id}`);
    
    // Configurar Perfil - Seleccionar Mecánico
    await page.getByText(/Mecánico|Mecanico/i).first().click({ timeout: 10000 });
    
    // Finalizar
    await page.getByText(/Finalizar Configuración/i).first().click({ timeout: 10000 });
    
    // Verificar que llega al Dashboard de Mecánico
    await expect(page.getByText(/Dashboard|Taller/i).first()).toBeVisible({ timeout: 20000 });
  });
});
