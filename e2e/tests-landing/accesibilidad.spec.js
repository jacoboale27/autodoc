'use strict';

const { test, expect } = require('@playwright/test');
const { stubDirectorio } = require('./helpers');

// UX-03: movimiento, navegacion movil y semantica de la landing.
//
// Los tres defectos que cubre este archivo estaban VERIFICADOS a mano antes de
// escribirlo, y uno de ellos estaba descrito mas suave de lo que era:
//
//   1. **No hay menu movil que arreglar: no hay menu.** El enunciado pedia
//      "anadir menu movil accesible", como si existiera uno inaccesible. La
//      navegacion de `Header.tsx` es `hidden md:flex`: por debajo de 768 px los
//      tres enlaces de seccion simplemente DESAPARECEN, y "Iniciar Sesion" es
//      `hidden sm:block`, asi que a 320 px lo unico que queda es "Probar
//      Gratis". No es una molestia de accesibilidad: es navegacion que no
//      existe en el tamano en el que llega la mayoria del trafico.
//   2. **29 elementos animados con framer-motion y CERO guardas de
//      `prefers-reduced-motion`** en todo el proyecto (ni `useReducedMotion`,
//      ni `MotionConfig`, ni una `@media` en `globals.css`).
//   3. **`<Link><button>...</button></Link>`** en el CTA de la cabecera: un
//      boton dentro de un ancla es HTML invalido y deja un solo nodo con dos
//      roles interactivos.
//
// Sobre como se afirma lo del movimiento, que es lo unico delicado de aqui:
// mirar "la animacion no se ve" es una carrera contra el reloj y da verdes por
// casualidad en cuanto la animacion termina. Asi que se afirma sobre algo
// permanente. Las secciones de mas abajo se revelan con `whileInView` desde
// `initial={{opacity: 0}}`: si nadie hace scroll, sin la preferencia se quedan
// invisibles PARA SIEMPRE. Ese "para siempre" es lo que convierte la
// comprobacion en determinista, y por eso hay un caso de control sin la
// preferencia: sin el, borrar todas las animaciones pasaria la suite entera.

test.beforeEach(async ({ page }) => {
  await stubDirectorio(page);
});

/// El titulo de la seccion de talleres, muy por debajo del pliegue en
/// cualquier viewport: nunca entra en pantalla sin hacer scroll.
const bajoElPliegue = '[data-testid="workshops-titulo"]';

async function opacidadDe(page, selector) {
  return page.locator(selector).evaluate((el) => {
    return Number.parseFloat(getComputedStyle(el).opacity);
  });
}

// `test.use({ reducedMotion: 'reduce' })` NO surte efecto en la version de
// Playwright de este repo (1.62.1): dentro de la pagina,
// `matchMedia('(prefers-reduced-motion: reduce)').matches` seguia dando
// `false` y los tres casos de abajo fallaban aunque el arreglo ya estuviera
// puesto. Se comprobo midiendolo desde dentro del navegador. `emulateMedia`
// si funciona, y ademas deja explicito en cada caso que la preferencia se
// activa ANTES de navegar — que es lo que importa: framer-motion lee la
// preferencia al montar, asi que activarla despues del `goto` no cambiaria
// nada.
async function conMovimientoReducido(page) {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/es');
}

test.describe('movimiento reducido', () => {

  test('el contenido que se revela al hacer scroll ya llega visible', async ({
    page,
  }) => {
    await conMovimientoReducido(page);
    await expect(page.locator(bajoElPliegue)).toBeAttached();

    expect(await opacidadDe(page, bajoElPliegue)).toBe(1);
  });

  test('las transiciones CSS quedan anuladas', async ({ page }) => {
    await conMovimientoReducido(page);

    const duracion = await page
      .locator('header')
      .evaluate((el) => getComputedStyle(el).transitionDuration);

    // `transition-all duration-300` en la cabecera. Bajo la preferencia, la
    // media query global lo deja en un tiempo inapreciable.
    expect(Number.parseFloat(duracion)).toBeLessThan(0.05);
  });

  test('la cabecera no entra deslizandose desde fuera de pantalla', async ({
    page,
  }) => {
    await conMovimientoReducido(page);

    // `initial={{ y: -100 }}`: sin guarda, el primer pintado la deja 100 px
    // por encima de su sitio. Con la guarda no llega a aplicarse transform.
    const transform = await page
      .locator('header')
      .evaluate((el) => getComputedStyle(el).transform);

    expect(transform === 'none' || transform === 'matrix(1, 0, 0, 1, 0, 0)').toBe(
      true,
    );
  });
});

test.describe('sin preferencia de movimiento reducido', () => {

  // El control que impide que "arreglarlo" sea "borrar las animaciones". Si
  // este caso se pone rojo, el efecto de revelado desaparecio para todo el
  // mundo y los tres de arriba estarian pasando por la razon equivocada.
  test('el contenido de mas abajo si empieza oculto', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await page.goto('/es');
    await expect(page.locator(bajoElPliegue)).toBeAttached();

    expect(await opacidadDe(page, bajoElPliegue)).toBeLessThan(1);
  });
});

test.describe('HTML valido', () => {
  for (const ruta of ['/es', '/es/contact']) {
    test(`ningun control interactivo anidado dentro de otro en ${ruta}`, async ({
      page,
    }) => {
      await page.goto(ruta);

      // `<a><button>` es HTML invalido: el modelo de contenido de <a> excluye
      // el contenido interactivo. El navegador lo tolera, pero deja un nodo
      // con dos roles y un lector de pantalla anuncia "enlace, boton".
      await expect(page.locator('a button')).toHaveCount(0);
      await expect(page.locator('button a')).toHaveCount(0);
    });
  }
});

// Los cuatro anchos que pide el plan. 320 es el suelo real (iPhone SE en
// horizontal partido / Galaxy Fold cerrado) y es donde la cabecera actual se
// queda sin navegacion.
const ANCHOS_MOVILES = [320, 375, 390, 414];

for (const ancho of ANCHOS_MOVILES) {
  test.describe(`navegacion movil a ${ancho} px`, () => {
    test.use({ viewport: { width: ancho, height: 800 } });

    test('el menu se abre y da acceso a las secciones', async ({ page }) => {
      await page.goto('/es');

      const boton = page.getByTestId('menu-movil-boton');
      await expect(boton).toBeVisible();
      await expect(boton).toHaveAttribute('aria-expanded', 'false');

      const idPanel = await boton.getAttribute('aria-controls');
      expect(idPanel, 'el boton debe apuntar al panel que controla').toBeTruthy();

      await boton.click();

      await expect(boton).toHaveAttribute('aria-expanded', 'true');
      const panel = page.locator(`#${idPanel}`);
      await expect(panel).toBeVisible();
      await expect(panel.getByRole('link', { name: 'Para Talleres' })).toBeVisible();
      await expect(panel.getByRole('link', { name: 'Testimonios' })).toBeVisible();
      // "Iniciar Sesion" es `hidden sm:block` en la barra: a estos anchos el
      // menu es el UNICO sitio donde puede aparecer.
      await expect(panel.getByRole('link', { name: 'Iniciar Sesión' })).toBeVisible();
    });

    test('se abre y se cierra con el teclado y devuelve el foco', async ({
      page,
    }) => {
      await page.goto('/es');

      const boton = page.getByTestId('menu-movil-boton');
      await boton.focus();
      await page.keyboard.press('Enter');
      await expect(boton).toHaveAttribute('aria-expanded', 'true');

      // El foco tiene que entrar al panel; si no, tabular desde el boton se va
      // al contenido de detras y el menu abierto no sirve con teclado.
      const idPanel = await boton.getAttribute('aria-controls');
      await expect
        .poll(async () =>
          page.evaluate((id) => {
            const panel = document.getElementById(id);
            return Boolean(panel && panel.contains(document.activeElement));
          }, idPanel),
        )
        .toBe(true);

      await page.keyboard.press('Escape');
      await expect(boton).toHaveAttribute('aria-expanded', 'false');
      await expect(boton).toBeFocused();
    });

    test('al seguir un enlace del menu, el menu se cierra', async ({ page }) => {
      await page.goto('/es');

      const boton = page.getByTestId('menu-movil-boton');
      await boton.click();
      const idPanel = await boton.getAttribute('aria-controls');
      await page.locator(`#${idPanel}`).getByRole('link', { name: 'Testimonios' }).click();

      await expect(boton).toHaveAttribute('aria-expanded', 'false');
    });
  });
}

test.describe('escritorio', () => {
  test('el boton de menu movil no se muestra a 1280 px', async ({ page }) => {
    await page.goto('/es');

    await expect(page.getByTestId('menu-movil-boton')).toBeHidden();
    await expect(page.getByRole('link', { name: 'Testimonios' }).first()).toBeVisible();
  });

  test('los controles de idioma y tema se anuncian en el idioma de la pagina', async ({
    page,
  }) => {
    await page.goto('/es');

    // Estaban cableados en ingles (`aria-label="Toggle language"`) en un sitio
    // que existe en dos idiomas: un lector de pantalla en espanol los leia en
    // otro idioma.
    await expect(page.getByTestId('cambiar-idioma')).toHaveAttribute(
      'aria-label',
      /idioma/i,
    );
    await expect(page.getByTestId('cambiar-tema')).toHaveAttribute(
      'aria-label',
      /tema|oscuro|claro/i,
    );
  });
});
