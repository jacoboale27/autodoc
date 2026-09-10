'use strict';

const { test, expect } = require('@playwright/test');
const { limpiarSolicitudes, solicitudes, talleres, stubDirectorio } = require('./helpers');

// UX-01, segunda mitad: "ningun CTA apunta a un placeholder" y "destinos
// externos sin navegacion rota".
//
// Los destinos se comprueban pidiendolos, no leyendo el href: un enlace bien
// escrito a una ruta que no existe se ve perfecto en el DOM y da 404 al
// pulsarlo. Eso es exactamente lo que pasaba con los legales, que apuntaban a
// autodoc.app/privacidad mientras la landing servia /es/privacy.

test.beforeEach(async ({ page }) => {
  await stubDirectorio(page);
});

test.describe('directorio publico', () => {
  test('renderiza una calificacion serializada por Firestore REST sin tumbar la pagina', async ({ page }) => {
    const errores = [];
    page.on('pageerror', (error) => errores.push(error.message));

    await page.goto('/es');

    await expect(page.getByText('Taller Demo E2E')).toBeVisible();
    await expect(page.getByText('4.5', { exact: true })).toBeVisible();
    expect(errores).toEqual([]);
  });

  test('no solicita el endpoint de Vercel Analytics en Firebase Hosting', async ({ page }) => {
    const solicitudesVercel = [];
    page.on('request', (request) => {
      if (request.url().includes('/_vercel/insights/')) {
        solicitudesVercel.push(request.url());
      }
    });

    await page.goto('/es');
    await expect(page.getByText('Taller Demo E2E')).toBeVisible();

    expect(solicitudesVercel).toEqual([]);
  });
});

test.describe('CTAs de descarga', () => {
  test('ningun enlace apunta ya al id de ejemplo de la App Store', async ({ page }) => {
    for (const ruta of ['/es', '/en', '/es/contact']) {
      await page.goto(ruta);
      const placeholder = page.locator('a[href*="apps.apple.com/app/id123456789"]');
      await expect(placeholder, `placeholder de iOS en ${ruta}`).toHaveCount(0);
    }
  });

  test('el badge de iOS no se muestra mientras no haya ficha publica', async ({ page }) => {
    await page.goto('/es');
    // No es que el enlace este roto: es que no se ofrece la descarga hasta que
    // exista. Prometer una app que no se puede instalar es el defecto.
    await expect(page.locator('a[href*="apps.apple.com"]')).toHaveCount(0);
  });

  test('el badge de Android apunta al applicationId real de la app', async ({ page }) => {
    await page.goto('/es');
    const play = page.locator('a[href*="play.google.com"]').first();
    await expect(play).toBeVisible();
    await expect(play).toHaveAttribute(
      'href',
      'https://play.google.com/store/apps/details?id=com.autodoc.app',
    );
  });

  test('el CTA principal lleva al login de la web app desplegada', async ({ page }) => {
    await page.goto('/es');
    const cta = page.locator('a[href="https://autodoc-6ef5a.web.app/login"]').first();
    await expect(cta).toHaveCount(1);
  });
});

test.describe('navegacion interna: los enlaces llegan', () => {
  test('los legales del pie abren las paginas de la propia landing', async ({ page }) => {
    await page.goto('/es');

    await page.getByRole('link', { name: 'Política de Privacidad' }).click();
    await expect(page).toHaveURL(/\/es\/privacy$/);

    await page.goto('/es');
    await page.getByRole('link', { name: 'Términos de Servicio' }).click();
    await expect(page).toHaveURL(/\/es\/terms$/);
  });

  test('el pie enlaza la pagina de contacto, que antes no enlazaba nadie', async ({ page }) => {
    await page.goto('/es');
    await page.getByRole('link', { name: 'Soporte' }).click();
    await expect(page).toHaveURL(/\/es\/contact$/);
    await expect(page.getByTestId('contacto-form')).toBeVisible();
  });

  // Las anclas eran `href="#features"`: desde /es/contact no van a ninguna
  // parte, porque esa seccion vive en la home.
  test('desde contacto, la navegacion vuelve a la home del idioma activo', async ({ page }) => {
    await page.goto('/es/contact');
    await page.getByRole('link', { name: 'Para Dueños' }).first().click();
    await expect(page).toHaveURL(/\/es\/?#features$/);
  });

  test('recargar una ruta profunda responde 200, no 404', async ({ page }) => {
    for (const ruta of ['/es/contact', '/en/contact', '/es/privacy', '/en/terms']) {
      const res = await page.goto(ruta);
      expect(res?.status(), `estado de ${ruta}`).toBe(200);
    }
  });
});

test.describe('afiliacion de talleres', () => {
  test.beforeEach(async () => {
    await limpiarSolicitudes();
  });

  // Este formulario POSTeaba sin autenticar a la REST API de Firestore contra
  // /talleres, cuya regla es `allow create: if isAdmin()`. Siempre 403: el
  // estado de exito estaba implementado y era inalcanzable.
  test('la solicitud del taller llega al buzon y la pantalla lo confirma', async ({ page }) => {
    await page.goto('/es');

    const form = page.getByTestId('afiliacion-form');
    await form.scrollIntoViewIfNeeded();
    await form.getByLabel('Nombre del Taller').fill('AutoFix E2E');
    await form.getByLabel('Correo Electrónico').fill('taller@example.com');
    await form.getByLabel('Teléfono de Contacto').fill('+503 7777-8888');
    await form.getByLabel('Municipio / Departamento').fill('San Salvador');
    await page.getByRole('button', { name: 'Enviar Solicitud de Afiliación' }).click();

    await expect(page.getByTestId('afiliacion-exito')).toBeVisible();

    const guardadas = await solicitudes('afiliacion');
    expect(guardadas).toHaveLength(1);
    expect(guardadas[0].nombre).toBe('AutoFix E2E');
    expect(guardadas[0].telefono).toBe('+503 7777-8888');
    expect(guardadas[0].estado).toBe('nueva');
  });

  test('la solicitud NO crea un taller en el directorio publico', async ({ page }) => {
    await page.goto('/es');

    const form = page.getByTestId('afiliacion-form');
    await form.scrollIntoViewIfNeeded();
    await form.getByLabel('Nombre del Taller').fill('Taller Colado');
    await form.getByLabel('Correo Electrónico').fill('colado@example.com');
    await form.getByLabel('Teléfono de Contacto').fill('+503 7000-0000');
    await form.getByLabel('Municipio / Departamento').fill('Santa Ana');
    await page.getByRole('button', { name: 'Enviar Solicitud de Afiliación' }).click();
    await expect(page.getByTestId('afiliacion-exito')).toBeVisible();

    // El alta en /talleres la sigue haciendo un administrador. Que el envio
    // funcione no puede significar que cualquiera se publique en el directorio.
    //
    // Se pregunta a Firestore con el Admin SDK y no se mira la pantalla: la
    // lectura del directorio esta interceptada en esta suite (ver
    // stubDirectorio), asi que "no aparece en la pagina" no probaria nada. Esto
    // mira la coleccion de verdad.
    expect(await talleres()).toHaveLength(0);
  });
});
