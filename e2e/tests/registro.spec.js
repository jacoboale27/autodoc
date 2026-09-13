'use strict';

// Registro por UI: valido, vacio, invalido, duplicado y doble submit.
//
// Es la primera fila del plan Playwright minimo (§8 del plan de remediacion) y
// hasta H-01 estaba entera en `fixme`. El comentario que justificaba ese
// `fixme` daba dos razones y solo una era cierta:
//
//   - «los rotulos que buscan estos tests ya no existen» — FALSO.
//     `authRegisterFree`, `authCreateAccount` y `authRegisterButton` siguen
//     vivos en los ARB. Lo que cambio fue el FINAL del recorrido: ya no hay
//     dialogo de verificacion, el router empuja a /verify_email. El test
//     esperaba un dialogo que la app dejo de tener, y eso se anoto como si la
//     pantalla entera se hubiera rehecho.
//
//   - «el proxy de input de Flutter web pierde el valor del campo de correo al
//     mover el foco» — CIERTO con `fill()`, que escribe en el <input> del
//     proxy y Flutter descarta al cambiar de foco. Tecleando con
//     `keyboard.type` se pasa por la editing connection, que si respeta, y el
//     recorrido entero es estable.
//
// Las cuentas se comprueban contra la API REST del emulador de Auth, no contra
// la UI: que la pantalla diga «listo» no prueba que exista la cuenta, y que
// diga «error» no prueba que NO exista. Este spec crea usuarios, pero solo en
// el emulador — nunca toca produccion.

const { test, expect } = require('@playwright/test');
const { esperarAppLista, CLAVE, ACTORES } = require('./helpers');

const PROYECTO = 'autodoc-e2e';
const AUTH = `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/${PROYECTO}`;

async function cuentas() {
  const res = await fetch(`${AUTH}/accounts:query`, {
    method: 'POST',
    headers: {
      Authorization: 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({}),
  });
  const { userInfo = [] } = await res.json();
  return userInfo;
}

async function cuentasCon(correo) {
  const todas = await cuentas();
  return todas.filter((u) => (u.email || '').toLowerCase() === correo.toLowerCase());
}

async function irARegistro(page) {
  await page.goto('/register');
  await esperarAppLista(page);
  // Flutter no construye el arbol de semantica hasta que hay una interaccion.
  await page.mouse.click(10, 10);
  await page.waitForTimeout(2000);
}

// Teclea en vez de `fill()`. Ver la cabecera: es la diferencia entre un
// recorrido estable y el que llevaba dos anos en `fixme`.
async function teclear(page, etiqueta, valor) {
  const campo = page.getByLabel(etiqueta).first();
  await campo.click();
  await page.keyboard.type(valor, { delay: 20 });
}

const CORREO = /Email|Correo/i;
const CLAVE_CAMPO = /Password|Contrase/i;
const ENVIAR = /^(Sign Up|Registrarse)$/i;

// Mensajes de los validator de auth_screen.dart:353-389, en los dos idiomas.
// Afirmarlos es lo que separa «la validacion de cliente corto el envio» de
// «Firebase rechazo la peticion»: sin esto, borrar los validator dejaria estos
// tests igual de verdes, porque un correo vacio o mal formado tampoco crea
// cuenta en el servidor.
//
// Se miran en el `aria-label` del <input>, no con `getByText`. En Flutter web
// el `errorText` de un campo NO es un nodo de texto del arbol de semantica: se
// concatena al aria-label del input del proxy, asi:
//   Email / salto / name@example.com / salto / Fill in email and password.
// Medido en esta misma pantalla. `getByText` no puede encontrarlo nunca, y
// afirmarlo aqui prueba ademas que el error se ANUNCIA a un lector de
// pantalla, que es la propiedad que de verdad importa.
const FALTAN_CREDENCIALES = /Fill in email and password|Completa correo y contrase/i;
const CORREO_INVALIDO = /Enter a valid email address|Ingresa un correo electr/i;

// El errorText de cada campo vive aqui; ver la nota de arriba.
async function ariaDeLosCampos(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll('input')].map((i) => i.getAttribute('aria-label') || ''),
  );
}

async function enviar(page) {
  await page.getByRole('button', { name: ENVIAR }).first().click();
}

test.describe('Registro de nuevos usuarios', () => {
  test('un registro valido crea la cuenta y la deja SIN verificar', async ({ page }) => {
    const correo = `h01-valido-${Date.now()}@e2e.test`;
    await irARegistro(page);
    await teclear(page, CORREO, correo);
    await teclear(page, CLAVE_CAMPO, CLAVE);
    await enviar(page);

    await expect
      .poll(async () => (await cuentasCon(correo)).length, { timeout: 30000 })
      .toBe(1);

    const [cuenta] = await cuentasCon(correo);
    expect(
      cuenta.emailVerified,
      'SEC-02 exige que nadie entre sin verificar: una cuenta recien creada no puede nacer verificada',
    ).toBeFalsy();
  });

  // Los tres rechazos van en UN SOLO test, y no por pereza: cada arranque de
  // la app cuesta CanvasKit mas la persistencia offline de Firestore y degrada
  // el emulador Java. Con cinco arranques en este archivo, uno de cada dos
  // pasadas moria en `esperarAppLista` a los 120 s — el modo de fallo que
  // CLAUDE.md ya tiene documentado. Los tres casos comparten pantalla y no se
  // contaminan: ninguno debe crear cuenta.
  test('vacio, mala forma y duplicado: ninguno crea cuenta', async ({ page }) => {
    const antes = (await cuentas()).length;
    await irARegistro(page);

    // 1. Vacio.
    await enviar(page);
    await page.waitForTimeout(2000);
    expect(
      await ariaDeLosCampos(page),
      'La validacion de cliente tiene que decir que faltan credenciales.',
    ).toEqual(expect.arrayContaining([expect.stringMatching(FALTAN_CREDENCIALES)]));

    // 2. Correo con mala forma.
    await teclear(page, CORREO, 'esto-no-es-un-correo');
    await teclear(page, CLAVE_CAMPO, CLAVE);
    await enviar(page);
    await page.waitForTimeout(2000);
    expect(
      await ariaDeLosCampos(page),
      'La validacion de cliente tiene que senalar la forma del correo.',
    ).toEqual(expect.arrayContaining([expect.stringMatching(CORREO_INVALIDO)]));

    // Ni el vacio ni la mala forma pueden haber llegado a Auth.
    expect((await cuentas()).length).toBe(antes);
    expect(page.url(), 'La pantalla debe quedarse en el registro.').toContain('/register');

    // 3. Correo ya registrado. Se limpia el campo antes de reescribirlo.
    const duplicado = ACTORES.propietarioA.correo;
    expect(
      (await cuentasCon(duplicado)).length,
      'el fixture propietarioA tiene que existir antes de esta prueba',
    ).toBe(1);

    const campoCorreo = page.getByLabel(CORREO).first();
    await campoCorreo.click();
    await page.keyboard.press('Control+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.type(duplicado, { delay: 20 });
    await enviar(page);
    await page.waitForTimeout(5000);

    expect(
      (await cuentasCon(duplicado)).length,
      'Un correo duplicado no puede duplicar la cuenta.',
    ).toBe(1);
  });

  test('pulsar dos veces seguidas no crea dos cuentas', async ({ page }) => {
    const correo = `h01-doble-${Date.now()}@e2e.test`;
    await irARegistro(page);
    await teclear(page, CORREO, correo);
    await teclear(page, CLAVE_CAMPO, CLAVE);

    // Dos clics sin esperar al primero: es lo que hace una persona con la
    // pagina lenta. `AuthProvider.isLoading` deshabilita el boton y `_submit`
    // corta con un guard (auth_screen.dart:519-522); este test es lo que
    // impide que alguien retire cualquiera de los dos sin enterarse.
    const boton = page.getByRole('button', { name: ENVIAR }).first();
    await boton.click();
    await boton.click({ force: true, noWaitAfter: true }).catch(() => {});

    await expect
      .poll(async () => (await cuentasCon(correo)).length, { timeout: 30000 })
      .toBe(1);
    await page.waitForTimeout(3000);
    expect((await cuentasCon(correo)).length).toBe(1);
  });
});
