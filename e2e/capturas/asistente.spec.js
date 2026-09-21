'use strict';

// Verificacion VISUAL del asistente de agenda (IA-01), tal y como queda en la
// app ya integrada en `integracion/ola-2`.
//
// **Que es esto y que no es.** No sustituye a `tests/asistente.spec.js`, que
// es el gate: aquella afirma sobre las siete rutas de la pantalla con el
// viewport de escritorio y en ingles. Esta corre en el viewport de TELEFONO y
// en español —o sea, lo que una persona va a ver— y deja PNGs para mirar la
// pantalla, que es lo unico que ninguna asercion puede hacer por nosotros: los
// defectos de esta tanda que mas caro salieron (la barra del panel pintada dos
// veces en 13.1) compilan, analizan limpio y pasan todos los tests.
//
// **Afirma ademas de fotografiar, y eso no es adorno.** La leccion de
// `capturas/helpers.js` es literal: una pantalla que no cargo sus datos sale
// limpia y vacia, asi que sin aserciones un fallo de siembra produce PNGs
// preciosos e inservibles. Cada captura exige antes el dato que la hace
// significar algo.
//
// **El modelo es el doble** (`functions/src/modeloFalso.js`), como en el gate:
// el emulador no tiene Secret Manager. La prosa se DERIVA del envelope, asi
// que la placa que se lee en la captura solo puede venir del vehiculo de este
// usuario leido por el servidor. Lo que un modelo de verdad escribe se mide en
// los evals, a mano.

const fs = require('fs');
const path = require('path');
const { test, expect } = require('@playwright/test');
const { ACTORES, abrirApp, entrarComo } = require('./helpers');

// Los rotulos se LEEN del ARB, nunca se teclean aqui: asi la spec no puede
// desincronizarse del copy. En español, porque la config de capturas fuerza
// es-CO (ver el bloque `locale` de playwright.capturas.config.js).
const ARB = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', '..', 'lib', 'l10n', 'app_es.arb'), 'utf8'),
);
const T = (clave) => {
  const valor = ARB[clave];
  if (typeof valor !== 'string') {
    throw new Error(`La clave ${clave} no esta en app_es.arb: la spec y el ARB se desincronizaron.`);
  }
  return valor;
};

// Directorio PROPIO. Las capturas de la ficha de Google Play viven en
// `capturas/out` numeradas del 01 al 08 y son un entregable; mezclar aqui
// sobreescribiria una de ellas con una pantalla que Play no pidio.
const SALIDA = path.join(__dirname, 'out-asistente');

const config = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'emulator-config.json'), 'utf8'),
);
const FIRESTORE =
  `http://127.0.0.1:8080/v1/projects/${config.FIREBASE_PROJECT_ID}` +
  '/databases/(default)/documents';

/** Vehiculo 1 de la vitrina: SOAT a 12 dias, tarjeta a 94. */
const PLACA = 'P482-731';

/**
 * Escribe saltandose las reglas, igual que el Admin SDK.
 *
 * Las tres colecciones del asistente estan cerradas a todo cliente, asi que no
 * hay via por la UI para dejar el cupo agotado. Y la vitrina no siembra
 * `reservas` —no le hacian falta para la ficha de Play—, asi que la agenda del
 * taller se siembra aqui.
 */
async function sembrar(ruta, fields) {
  const res = await fetch(`${FIRESTORE}/${ruta}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) throw new Error(`No se pudo sembrar ${ruta} (${res.status}).`);
}

async function borrar(ruta) {
  await fetch(`${FIRESTORE}/${ruta}`, {
    method: 'DELETE',
    headers: { Authorization: 'Bearer owner' },
  });
}

/**
 * Localiza un texto mire donde mire Flutter web: nodo de texto O `aria-label`.
 *
 * Es la misma union que `capturas/helpers.js` documenta — Flutter mete tarjetas
 * enteras en un solo `flt-semantics` cuyo rotulo concatena todo, asi que
 * `getByText` no encuentra lo que el ojo lee perfectamente.
 */
function visible(page, texto) {
  return page
    .getByText(texto, { exact: false })
    .or(page.locator(`[aria-label*=${JSON.stringify(texto)}]`))
    .first();
}

/** Deja el PNG en out-asistente/NN-nombre.png. */
async function capturar(page, orden, nombre) {
  // El raton se aparta antes de disparar: un control en hover pinta su tooltip
  // flotando sobre la captura, y el PNG pasa todas las aserciones igual.
  await page.mouse.move(5, 5);
  await page.waitForTimeout(900);
  fs.mkdirSync(SALIDA, { recursive: true });
  const archivo = path.join(SALIDA, `${String(orden).padStart(2, '0')}-${nombre}.png`);
  await page.screenshot({ path: archivo, fullPage: false });
  return archivo;
}

/**
 * Escribe la pregunta y espera a que la pantalla deje de pensar.
 *
 * `fill()` NO sirve en Flutter web y falla en silencio: escribe en el `<input>`
 * del proxy y Flutter lo descarta al cambiar de foco. Que el boton se habilite
 * ES la prueba de que el texto llego — afirmarlo convierte un timeout mudo en
 * un fallo que dice lo que paso.
 */
async function preguntar(page, texto) {
  const campo = page.getByRole('textbox').first();
  await campo.click();
  await page.keyboard.type(texto);

  const enviar = page.getByRole('button', { name: T('asistenteEnviar'), exact: true });
  await expect(enviar).toBeEnabled({ timeout: 30000 });
  await enviar.click();
  await expect(page.getByText(T('asistentePensando'))).toBeHidden({ timeout: 20000 });
}

test.describe('IA-01 — como queda el asistente en la app', () => {
  test.afterEach(async () => {
    // El cupo y el interruptor son estado GLOBAL del proyecto: dejarlos puestos
    // hace fallar al siguiente por un motivo que no es el suyo. Es la leccion
    // de `env.clearStorage()` en GAPS-05.
    await borrar('configuracion/asistente_ia');
    await borrar(`consultas_ia_control/${ACTORES.propietario.uid}`);
    await borrar('consultas_ia_control/_global');
    await borrar('reservas/vit-cita-asistente');
  });

  test('el recorrido del propietario', async ({ page }) => {
    // Un solo test a proposito: cada arranque de la app cuesta caro (CanvasKit
    // + persistencia offline de Firestore) y degrada el emulador Java.
    await abrirApp(page, '/');
    await entrarComo(page, ACTORES.propietario);

    // ── 01 · La entrada ────────────────────────────────────────────────────
    // Que el backend funcione no sirve de nada si no hay como llegar: es la
    // razon literal por la que el juez bajo la nota de INNO-01. El dashboard
    // primero, porque es el unico sitio que carga los vehiculos en el provider
    // del que depende /alerts.
    await page.goto('/dashboard');
    await abrirApp(page, '/alerts');
    await expect(
      page.getByRole('button', { name: T('asistenteAbrir') }),
      'No hay boton de entrada al asistente en /alerts.',
    ).toBeVisible({ timeout: 30000 });
    await capturar(page, 1, 'entrada-desde-alertas');

    // ── 02 · El estado inicial ─────────────────────────────────────────────
    await page.getByRole('button', { name: T('asistenteAbrir') }).click();
    // Timeout explicito: medido sobre este bundle, el boton entra en el arbol
    // de semantica a los ~5,1 s tras una navegacion en frio, y el defecto de
    // `expect` son 5 s. Ver el bloque equivalente de tests/asistente.spec.js.
    await expect(
      page.getByRole('button', { name: T('asistenteEnviar'), exact: true }),
    ).toBeVisible({ timeout: 30000 });
    // El descargo de alcance es parte del producto, no decoracion: es lo que
    // dice que esto no diagnostica averias. Si desaparece de la pantalla, la
    // captura tiene que dejar de pasar.
    await expect(
      visible(page, T('asistenteAlcance')),
      'El descargo de alcance no esta en pantalla.',
    ).toBeVisible();
    await expect(visible(page, T('asistenteVacio'))).toBeVisible();
    await capturar(page, 2, 'estado-inicial');

    // ── 03 · La respuesta con la agenda real ───────────────────────────────
    await preguntar(page, 'que se me vence en los proximos dias');
    // La placa es la prueba de que cruzo las cinco capas: no esta en la
    // pregunta, no esta en la pantalla, y solo puede venir del vehiculo de
    // este usuario leido por el servidor.
    await expect(
      visible(page, PLACA),
      `La respuesta no menciona ${PLACA}: el envelope no llego o es de otro usuario.`,
    ).toBeVisible({ timeout: 30000 });
    await expect(visible(page, 'SOAT')).toBeVisible();
    await capturar(page, 3, 'respuesta-vencimientos');

    // ── 04 · Fuera de alcance ──────────────────────────────────────────────
    // El rechazo es texto FIJO del servidor y no pasa por el modelo: pedirle a
    // un modelo que redacte su propia negativa es darle una ocasion de no
    // negarse. El distintivo importa — sin el, un rechazo se lee como si el
    // asistente hubiera contestado.
    await page.getByRole('button', { name: T('asistenteOtraPregunta') }).click();
    await preguntar(page, 'por que suena el motor cuando freno');
    await expect(visible(page, T('asistenteEtiquetaFueraDeAlcance'))).toBeVisible();
    await expect(visible(page, PLACA)).toBeHidden();
    await capturar(page, 4, 'fuera-de-alcance');

    // ── 05 · Sin cupo ──────────────────────────────────────────────────────
    // El estado de error que mas se va a ver, y el que peor queda si el copy
    // no cabe en 360 dp de ancho. El boton de reintentar se RETIRA, no se deja
    // gris: hoy no puede funcionar.
    await sembrar(`consultas_ia_control/${ACTORES.propietario.uid}`, {
      ventana_inicio: { integerValue: String(Date.now()) },
      conteo: { integerValue: '10' },
    });
    await page.getByRole('button', { name: T('asistenteOtraPregunta') }).click();
    await preguntar(page, 'que se me vence en los proximos dias');
    await expect(visible(page, T('asistenteErrorCupo'))).toBeVisible();
    await expect(page.getByRole('button', { name: T('errorReintentar') })).toBeHidden();
    await capturar(page, 5, 'sin-cupo');
  });

  test('la agenda del taller', async ({ page }) => {
    // La otra rama de `construirAgenda`, la que mas autorizacion lleva: rol,
    // estado del taller y taller efectivo. La vitrina no siembra `reservas`,
    // asi que la cita se pone aqui.
    const manana = new Date(Date.now() + 26 * 60 * 60 * 1000);
    await sembrar('reservas/vit-cita-asistente', {
      id_taller: { stringValue: ACTORES.taller.uid },
      id_propietario: { stringValue: ACTORES.propietario.uid },
      id_vehiculo: { stringValue: 'vit-vehiculo-1' },
      estado: { stringValue: 'confirmada' },
      fecha_hora_propuesta: { timestampValue: manana.toISOString() },
    });

    await abrirApp(page, '/');
    await entrarComo(page, ACTORES.taller);
    await abrirApp(page, '/asistente');

    await preguntar(page, 'que citas tengo');
    // La placa la resuelve `leerPlacas` por `getAll`: `reservas` no la lleva.
    // Que aparezca prueba esa segunda lectura, que es lo que hace util la
    // vista para el taller.
    await expect(
      visible(page, PLACA),
      'La cita del taller sale sin placa: fallo `leerPlacas`.',
    ).toBeVisible({ timeout: 30000 });
    // Un taller NO recibe los vencimientos de documentos de su cliente: su
    // agenda son citas. Si esto apareciera, el envelope mezclaria ramas.
    await expect(visible(page, 'SOAT')).toBeHidden();
    await capturar(page, 6, 'agenda-del-taller');
  });
});
