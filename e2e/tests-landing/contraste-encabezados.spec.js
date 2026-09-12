'use strict';

const { test, expect } = require('@playwright/test');
const { stubDirectorio } = require('./helpers');
const mensajes = require('../../landing-web/messages/es.json');

test.beforeEach(async ({ page }) => {
  await stubDirectorio(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
});

async function comprobarEncabezados(page, contexto) {
  // Incluye sr-only: sigue formando parte del arbol de accesibilidad.
  const encabezados = await page.getByRole('heading').evaluateAll((elementos) =>
    elementos.map((el) => ({
      nivel: Number(el.getAttribute('aria-level') || el.tagName.slice(1)),
      texto: el.textContent.trim(),
    })),
  );
  expect.soft(encabezados.filter(({ nivel }) => nivel === 1), contexto).toHaveLength(1);
  let anterior = 0;
  for (const { nivel, texto } of encabezados) {
    expect.soft(nivel - anterior, `${contexto}: h${anterior} -> h${nivel} ${texto}`)
      .toBeLessThanOrEqual(1);
    anterior = nivel;
  }
}

test('home, contact, privacy y terms en ES tienen un h1 y no saltan niveles', async ({ page }) => {
  for (const ruta of ['/es', '/es/contact', '/es/privacy', '/es/terms']) {
    await page.goto(ruta);
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    if (ruta === '/es') {
      await expect(page.getByRole('heading', { name: 'Taller Demo E2E' })).toBeAttached();
      const primero = page.locator('#features').getByRole('heading').first();
      expect.soft(await primero.evaluate((el) => el.tagName), 'Features necesita su propio h2')
        .toBe('H2');
    }
    await comprobarEncabezados(page, ruta);
  }
});

// Tailwind 4 devuelve oklch(), no necesariamente rgb(). El canvas convierte
// el color COMPUTADO a sRGB; no duplicamos la paleta ni fijamos fondos en el test.
async function medirContraste(elemento) {
  return elemento.evaluate((el) => {
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = 1;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    function rgba(css) {
      ctx.clearRect(0, 0, 1, 1);
      ctx.fillStyle = css;
      ctx.fillRect(0, 0, 1, 1);
      const [r, g, b, a] = ctx.getImageData(0, 0, 1, 1).data;
      return [r, g, b, a / 255];
    }
    function sobre(frente, fondo) {
      const alpha = frente[3] + fondo[3] * (1 - frente[3]);
      return alpha === 0 ? [0, 0, 0, 0] : [
        ...frente.slice(0, 3).map((c, i) =>
          (c * frente[3] + fondo[i] * fondo[3] * (1 - frente[3])) / alpha),
        alpha,
      ];
    }
    let texto = rgba(getComputedStyle(el).color);
    let fondo = [0, 0, 0, 0];
    for (let nodo = el; nodo; nodo = nodo.parentElement) {
      const estilo = getComputedStyle(nodo);
      // Los casos elegidos tienen fondos planos: no aceptar un verde falso
      // si en el futuro se introduce una imagen o un gradiente detras del texto.
      if (estilo.backgroundImage !== 'none') {
        throw new Error(`Fondo no uniforme en ${nodo.tagName}: ${estilo.backgroundImage}`);
      }
      const capa = rgba(estilo.backgroundColor);
      texto = sobre(texto, capa);
      fondo = sobre(fondo, capa);
      texto[3] *= Number(estilo.opacity);
      fondo[3] *= Number(estilo.opacity);
    }
    texto = sobre(texto, [255, 255, 255, 1]);
    fondo = sobre(fondo, [255, 255, 255, 1]);
    function luminancia(color) {
      const lineal = color.slice(0, 3).map((c) => {
        const s = c / 255;
        return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
      });
      return lineal[0] * 0.2126 + lineal[1] * 0.7152 + lineal[2] * 0.0722;
    }
    const a = luminancia(texto);
    const b = luminancia(fondo);
    return { texto, fondo, ratio: (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05) };
  });
}

async function comprobarContraste(elemento, caso, mediciones) {
  await expect(elemento).toBeVisible();
  // FeaturesGrid mantiene un fundido incluso bajo movimiento reducido.
  // Esperamos al estado final de sus ancestros sin esconder la opacidad del texto.
  await expect.poll(() => elemento.evaluate((el) => {
    let opacidad = 1;
    for (let padre = el.parentElement; padre; padre = padre.parentElement) {
      opacidad *= Number(getComputedStyle(padre).opacity);
    }
    return opacidad;
  })).toBe(1);
  const medicion = await medirContraste(elemento);
  mediciones.push({ caso, ...medicion });
  expect.soft(medicion.ratio, `${caso}: ${medicion.ratio.toFixed(3)}:1`).toBeGreaterThanOrEqual(4.5);
}

test('los cuatro casos de contraste cumplen 4.5:1 en claro y oscuro', async ({ page }, testInfo) => {
  const mediciones = [];
  for (const tema of ['light', 'dark']) {
    await page.emulateMedia({ colorScheme: tema, reducedMotion: 'reduce' });
    await page.goto('/es');
    await expect(page.locator('html')).toHaveClass(new RegExp(`\\b${tema}\\b`));
    const features = page.locator('#features');
    for (const clave of ['tabHistorySubtitle', 'tabAlertsSubtitle', 'tabSyncSubtitle']) {
      await comprobarContraste(features.getByText(mensajes[clave], { exact: true }),
        `${tema}: FeaturesGrid ${clave} inactivo`, mediciones);
    }
    await comprobarContraste(page.locator('#workshops').getByText('4.5', { exact: true }),
      `${tema}: calificacion`, mediciones);
    for (const clave of ['footerCopyright', 'footerContact', 'footerPrivacy', 'footerTerms']) {
      await comprobarContraste(page.locator('footer').getByText(mensajes[clave], { exact: true }),
        `${tema}: ${clave}`, mediciones);
    }
    await features.getByRole('heading', { name: mensajes.tabAlertsTitle, exact: true }).click();
    await comprobarContraste(features.getByText(mensajes.featuresAlertDesc, { exact: true }),
      `${tema}: alerta`, mediciones);
    await features.getByRole('heading', { name: mensajes.tabSyncTitle, exact: true }).click();
    await comprobarContraste(features.getByText('TALLER', { exact: true }),
      `${tema}: rotulo TALLER`, mediciones);
  }
  await testInfo.attach('ratios-contraste', {
    body: JSON.stringify(mediciones, null, 2), contentType: 'application/json',
  });
});
