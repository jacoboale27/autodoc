'use strict';

const { test, expect } = require('@playwright/test');
const { limpiarSolicitudes, solicitudes, stubDirectorio } = require('./helpers');

// UX-01: el formulario de contacto tiene que informar del resultado REAL.
//
// El punto de partida era `<form action="#">`: pulsar "Enviar Mensaje"
// recargaba la pagina y no mandaba nada. No habia error ni exito porque no
// habia envio. Por eso cada caso de aqui mira las dos caras — lo que ve la
// persona y lo que quedo escrito en Firestore: un mensaje verde sin documento
// detras es exactamente el defecto que esta tarea cierra.

test.beforeEach(async ({ page }) => {
  await limpiarSolicitudes();
  await stubDirectorio(page);
});

test.describe('contacto: el envio llega a su destino', () => {
  test('un mensaje valido se persiste y la pantalla lo confirma', async ({ page }) => {
    await page.goto('/es/contact');

    await page.getByLabel('Nombre').fill('Ana Perez');
    await page.getByLabel('Correo Electrónico').fill('ana@example.com');
    await page.getByLabel('Mensaje').fill('¿Dan cobertura en Santa Ana?');
    await page.getByRole('button', { name: 'Enviar Mensaje' }).click();

    await expect(page.getByTestId('contacto-exito')).toBeVisible();

    const guardadas = await solicitudes('contacto');
    expect(guardadas).toHaveLength(1);
    expect(guardadas[0].correo).toBe('ana@example.com');
    expect(guardadas[0].mensaje).toBe('¿Dan cobertura en Santa Ana?');
    expect(guardadas[0].estado).toBe('nueva');
    // El endpoint guarda el hash, nunca la IP.
    expect(guardadas[0].ip_hash).toBeTruthy();
  });

  test('los campos vacios se avisan en la pagina y no se envia nada', async ({ page }) => {
    await page.goto('/es/contact');
    await page.getByRole('button', { name: 'Enviar Mensaje' }).click();

    await expect(page.getByTestId('contacto-error')).toBeVisible();
    expect(await solicitudes()).toHaveLength(0);
  });

  test('un correo con mala forma se avisa antes de gastar el viaje', async ({ page }) => {
    await page.goto('/es/contact');
    await page.getByLabel('Nombre').fill('Ana');
    await page.getByLabel('Correo Electrónico').fill('ana-arroba-ejemplo');
    await page.getByLabel('Mensaje').fill('Hola');
    await page.getByRole('button', { name: 'Enviar Mensaje' }).click();

    await expect(page.getByTestId('contacto-error')).toBeVisible();
    expect(await solicitudes()).toHaveLength(0);
  });

  // El caso que mas importa: si el destino falla, la persona tiene que
  // enterarse. Un formulario que muestra exito pase lo que pase es
  // indistinguible del `action="#"` que habia antes.
  test('si el endpoint falla, se dice que no se envio y se ofrece el correo', async ({ page }) => {
    await page.route('**/recibirSolicitudLanding', (ruta) => ruta.abort('failed'));

    await page.goto('/es/contact');
    await page.getByLabel('Nombre').fill('Ana');
    await page.getByLabel('Correo Electrónico').fill('ana@example.com');
    await page.getByLabel('Mensaje').fill('Hola');
    await page.getByRole('button', { name: 'Enviar Mensaje' }).click();

    await expect(page.getByTestId('contacto-error')).toBeVisible();
    await expect(page.getByTestId('contacto-exito')).toHaveCount(0);
    // La salida alternativa esta a la vista, no en un pie de pagina.
    await expect(page.getByRole('link', { name: 'soporte@autodoc.app' }).first()).toBeVisible();
    expect(await solicitudes()).toHaveLength(0);
  });

  test('al superar el cupo por IP se avisa, en vez de fingir que se envio', async ({ page }) => {
    await page.route('**/recibirSolicitudLanding', (ruta) =>
      ruta.fulfill({
        status: 429,
        contentType: 'application/json',
        headers: { 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ ok: false, error: 'demasiadas_solicitudes' }),
      }),
    );

    await page.goto('/es/contact');
    await page.getByLabel('Nombre').fill('Ana');
    await page.getByLabel('Correo Electrónico').fill('ana@example.com');
    await page.getByLabel('Mensaje').fill('Hola');
    await page.getByRole('button', { name: 'Enviar Mensaje' }).click();

    await expect(page.getByTestId('contacto-error')).toContainText('Espera un momento');
    await expect(page.getByTestId('contacto-exito')).toHaveCount(0);
  });
});

test.describe('contacto: ingles', () => {
  test('la pagina en /en esta traducida y el envio funciona igual', async ({ page }) => {
    await page.goto('/en/contact');

    await expect(page.getByRole('heading', { name: 'Contact us' })).toBeVisible();
    await page.getByLabel('Name').fill('Ann Doe');
    await page.getByLabel('Email').fill('ann@example.com');
    await page.getByLabel('Message').fill('Do you cover Santa Ana?');
    await page.getByRole('button', { name: 'Send message' }).click();

    await expect(page.getByTestId('contacto-exito')).toBeVisible();
    const guardadas = await solicitudes('contacto');
    expect(guardadas).toHaveLength(1);
    expect(guardadas[0].correo).toBe('ann@example.com');
  });
});

test.describe('contacto: teclado y trampa de spam', () => {
  test('se puede rellenar y enviar sin tocar el raton', async ({ page }) => {
    await page.goto('/es/contact');

    await page.getByLabel('Nombre').focus();
    await page.keyboard.type('Ana Perez');
    await page.keyboard.press('Tab');
    await page.keyboard.type('ana@example.com');
    await page.keyboard.press('Tab');
    await page.keyboard.type('Escribo con el teclado.');
    await page.keyboard.press('Tab');

    // El honeypot esta fuera del recorrido de tabulacion (tabIndex -1): el
    // siguiente foco tiene que ser ya el boton de enviar. Si cayera en el campo
    // trampa, quien navega con teclado lo rellenaria sin saberlo y su mensaje
    // se descartaria en silencio.
    const foco = await page.evaluate(() => document.activeElement?.id || '');
    expect(foco).not.toBe('contacto-sitio-web');

    await page.keyboard.press('Enter');
    await expect(page.getByTestId('contacto-exito')).toBeVisible();
    expect(await solicitudes('contacto')).toHaveLength(1);
  });

  test('un envio con el honeypot relleno se descarta sin decirselo al bot', async ({ page }) => {
    await page.goto('/es/contact');

    await page.getByLabel('Nombre').fill('Bot');
    await page.getByLabel('Correo Electrónico').fill('bot@spam.example');
    await page.getByLabel('Mensaje').fill('compra esto');
    // Como lo haria un bot: rellenando todos los inputs del formulario.
    await page.locator('#contacto-sitio-web').fill('http://spam.example', { force: true });
    await page.getByRole('button', { name: 'Enviar Mensaje' }).click();

    await expect(page.getByTestId('contacto-exito')).toBeVisible();
    expect(await solicitudes()).toHaveLength(0);
  });
});
