'use strict';

const fs = require('fs');
const path = require('path');
const { test, expect } = require('@playwright/test');
const { ACTORES, iniciarSesion, esperarAppLista } = require('./helpers');

// INNO-01 — la demo del pase temporal de historial por QR.
//
// Lo que esta suite tiene que probar, y por que cada pieza:
//
//   1. **Que el propietario puede emitir un pase desde la app.** El backend
//      existia desde el commit anterior y no tenia ni un llamador: la unica
//      referencia a `PaseHistorialService` estaba en su propia declaracion.
//      Un callable desplegado que ninguna pantalla invoca no es una
//      funcionalidad, es codigo.
//   2. **Que quien escanea distingue lo auto-declarado.** `firestore.rules`
//      deja al propietario registrar servicios sobre su propio vehiculo con
//      `id_taller == 'Manual (Propietario)'`. Si la pantalla los pinta igual
//      que los de un taller, el pase deja de probar nada y pasa a ser la
//      palabra del vendedor con el sello de AutoDoc encima. Los dos fixtures
//      de `seed-emulators.js` existen para esto.
//   3. **Que el importe NO cruza.** La proyeccion del servidor es allowlist y
//      deja fuera `costo`. El fixture del taller lleva `costo: 250000`
//      justamente para poder afirmar que ese numero no aparece en ninguna
//      parte de la pantalla del que escanea.
//   4. **Que un pase muerto lo dice, y dice CUAL de las tres muertes.**
//      Caducado, revocado e inexistente son tres mensajes distintos porque son
//      tres situaciones distintas para quien mira la pantalla.
//
// **LA APP DEL BUNDLE E2E SE RENDERIZA EN INGLES, y eso no estaba anotado en
// ninguna parte.** Chromium arranca con el locale del sistema (en-US) y Flutter
// resuelve `AppLocalizations` con `navigator.language`, asi que todo el copy
// que pasa por el ARB sale en ingles aunque el repo se escriba en espanol. El
// primer intento de este spec afirmaba los rotulos en espanol y fallaba
// diciendo "no encuentro el boton" con el boton delante — el snapshot de
// accesibilidad lo enseno como `button "Share history"`. Los rotulos que NO
// pasan por el ARB (los de los otros specs: "Garaje", "Talleres") siguen en
// espanol, que es justo lo que hace que la trampa no salte a la vista.
//
// Los pases de los casos 2 y 3 se siembran directamente en Firestore por la API
// del emulador (que salta las reglas, igual que el Admin SDK) en vez de
// emitirse por la UI. No es un atajo: cada arranque de la app en un test cuesta
// CanvasKit + la persistencia offline de Firestore y degrada el emulador Java,
// y encadenar tests por un token que produjo el anterior los vuelve
// dependientes del orden. La emision por UI la prueban el primer test y el
// cuarto, que es donde toca.

const config = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'emulator-config.json'), 'utf8'),
);
const PROYECTO = config.FIREBASE_PROJECT_ID;
const FIRESTORE = `http://127.0.0.1:8080/v1/projects/${PROYECTO}/databases/(default)/documents`;

/**
 * 64 hex, que es la forma que `FORMA_TOKEN` exige del lado servidor.
 *
 * **La comprobacion de la semilla no es paranoia.** La primera version de este
 * archivo sembraba con `'b2caduca'` y `'c3revoca'`, que se leen como hex y no
 * lo son ('u' y 'v' no son digitos hexadecimales). El servidor los rechazaba
 * con `invalid-argument` **antes de mirar la caducidad**, asi que el test del
 * pase caducado veia el mensaje «ese codigo no es un pase» y parecia que la
 * pantalla mapeaba mal los errores. El fallo estaba en el fixture, y sin este
 * assert costaria la misma media hora la proxima vez.
 */
function tokenDePrueba(semilla) {
  if (!/^[0-9a-f]+$/.test(semilla)) {
    throw new Error(
      `La semilla "${semilla}" no es hexadecimal; el servidor rechazaria el ` +
        'pase por su forma y el test mediria otra cosa.',
    );
  }
  return semilla.padEnd(64, '0').slice(0, 64);
}

async function sembrarPase(token, { expiraEn, revocado = false, canjes = 0 }) {
  const res = await fetch(`${FIRESTORE}/tokens_historial/${token}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer owner',
    },
    body: JSON.stringify({
      fields: {
        id_vehiculo: { stringValue: 'e2e-vehiculo-a' },
        id_propietario: { stringValue: ACTORES.propietarioA.uid },
        creado_en: { integerValue: String(Date.now()) },
        expira_en: { integerValue: String(expiraEn) },
        revocado: { booleanValue: revocado },
        canjes: { integerValue: String(canjes) },
      },
    }),
  });
  if (!res.ok) {
    throw new Error(`No se pudo sembrar el pase (${res.status}).`);
  }
}

async function leerPases() {
  const res = await fetch(`${FIRESTORE}/tokens_historial`, {
    headers: { Authorization: 'Bearer owner' },
  });
  if (!res.ok) throw new Error(`No se pudo leer tokens_historial (${res.status}).`);
  const cuerpo = await res.json();
  return (cuerpo.documents || []).map((d) => ({
    token: d.name.split('/').pop(),
    campos: d.fields,
  }));
}

/**
 * El pase emitido mas recientemente.
 *
 * Se elige por `creado_en` y NO por la posicion en la lista: la API del
 * emulador devuelve los documentos ordenados por su id, y el id de un pase es
 * un token hexadecimal aleatorio. Coger el ultimo del array parece lo mismo y
 * da el pase equivocado en cuanto hay mas de uno en la coleccion — que es lo
 * normal en esta suite, donde dos tests emiten.
 */
async function ultimoPase() {
  const pases = await leerPases();
  expect(pases.length).toBeGreaterThan(0);
  return pases.reduce((a, b) =>
    Number(b.campos.creado_en.integerValue) >
    Number(a.campos.creado_en.integerValue)
      ? b
      : a,
  );
}

/** Flutter web no construye el arbol de semantica hasta que hay interaccion. */
async function despertarSemantica(page) {
  await page.mouse.click(10, 10);
  await page.waitForTimeout(2000);
}

test.describe('INNO-01 — pase temporal de historial', () => {
  test('el propietario emite un pase desde su historial de servicios', async ({
    page,
  }) => {
    await page.goto('/');
    await iniciarSesion(page, ACTORES.propietarioA);
    await esperarAppLista(page);
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 30000 });

    await page.goto('/service_history/e2e-vehiculo-a');
    await esperarAppLista(page);
    await despertarSemantica(page);

    // El punto de entrada: el boton del historial. Su rotulo accesible es el
    // tooltip del IconButton.
    await page
      .getByRole('button', { name: /Share history/ })
      .first()
      .click({ timeout: 20000 });

    await expect(page).toHaveURL(/compartir_historial/, { timeout: 20000 });
    await page.waitForTimeout(4000);

    // El pase existe DEL LADO SERVIDOR. Afirmar solo lo que se ve en pantalla
    // dejaria pasar una pantalla que pinta un QR de cualquier cosa: es
    // exactamente el falso verde que ya se comio este repo en UX-02, donde el
    // SDK quedaba perfecto mientras Flutter caia a la pantalla de error.
    const emitido = await ultimoPase();
    expect(emitido.campos.id_vehiculo.stringValue).toBe('e2e-vehiculo-a');
    expect(emitido.campos.id_propietario.stringValue).toBe(
      ACTORES.propietarioA.uid,
    );
    expect(Number(emitido.campos.expira_en.integerValue)).toBeGreaterThan(
      Date.now(),
    );
    expect(emitido.campos.revocado.booleanValue).toBe(false);

    // Y el token que el servidor genero es el que la pantalla ensena: sin esta
    // igualdad, un QR con el token de otro pase pasaria igual de verde.
    await expect(page.getByText(emitido.token, { exact: false })).toBeVisible({
      timeout: 20000,
    });
    await expect(page.getByText(/Expires in \d\d:\d\d/)).toBeVisible();
  });

  test('quien escanea ve el historial y distingue lo auto-declarado', async ({
    page,
  }) => {
    const token = tokenDePrueba('a1c0ffee');
    await sembrarPase(token, { expiraEn: Date.now() + 15 * 60 * 1000 });

    // El taller es el caso realista de quien escanea: no es el propietario y
    // no tiene por que tener relacion con el vehiculo.
    await page.goto('/');
    await iniciarSesion(page, ACTORES.tallerA);
    await esperarAppLista(page);

    await page.goto(`/historial_compartido/${token}`);
    await esperarAppLista(page);
    await despertarSemantica(page);

    await expect(page.getByText('Cambio de aceite').first()).toBeVisible({
      timeout: 25000,
    });
    await expect(page.getByText('Rotacion de llantas').first()).toBeVisible();

    // La distincion, que es la premisa de la funcionalidad.
    await expect(page.getByText('Recorded by a workshop').first()).toBeVisible();
    await expect(
      page.getByText('Declared by the owner').first(),
    ).toBeVisible();

    // Y el importe del servicio del taller no cruza por ningun lado.
    await expect(page.getByText('250000')).toHaveCount(0);
    await expect(page.getByText('250.000')).toHaveCount(0);
  });

  test('un pase caducado lo dice, y no ofrece reintentar', async ({ page }) => {
    const token = tokenDePrueba('cadaced0');
    await sembrarPase(token, { expiraEn: Date.now() - 60 * 1000 });

    await page.goto('/');
    await iniciarSesion(page, ACTORES.tallerA);
    await esperarAppLista(page);

    await page.goto(`/historial_compartido/${token}`);
    await esperarAppLista(page);
    await despertarSemantica(page);

    await expect(page.getByText(/expired/i).first()).toBeVisible({
      timeout: 25000,
    });
    // Reintentar un pase vencido no puede funcionar nunca.
    await expect(page.getByRole('button', { name: 'Retry' })).toHaveCount(0);
    // Y por supuesto no se filtra el historial.
    await expect(page.getByText('Cambio de aceite')).toHaveCount(0);
  });

  test('el propietario revoca su pase desde la app y deja de servir', async ({
    page,
  }) => {
    await page.goto('/');
    await iniciarSesion(page, ACTORES.propietarioA);
    await esperarAppLista(page);

    // Emite por la UI, no por la siembra: lo que se prueba aqui es la pareja
    // emitir/revocar tal como la usa una persona. Que un pase VIVO si sirve lo
    // prueba el test anterior; aqui lo que importa es que deja de servir.
    await page.goto('/compartir_historial/e2e-vehiculo-a');
    await esperarAppLista(page);
    await despertarSemantica(page);
    await expect(page.getByText(/Expires in \d\d:\d\d/)).toBeVisible({
      timeout: 25000,
    });

    // El token se lee DE LA PANTALLA, no de Firestore, y el cambio no es
    // cosmetico: desde GAPS-05 el servidor REUTILIZA el pase vivo del mismo
    // vehiculo en vez de acunar otro, asi que «el pase mas reciente de la
    // coleccion» dejo de significar «el que esta pantalla ensena» — los tests
    // de arriba siembran pases del mismo vehiculo con `creado_en` posterior.
    // Preguntarle a la pantalla es ademas lo que el test dice comprobar: que
    // se revoca EL PASE QUE SE ESTA ENSENANDO.
    const token = (
      await page.getByText(/^[0-9a-f]{64}$/).first().textContent()
    ).trim();
    expect(token).toMatch(/^[0-9a-f]{64}$/);

    await page
      .getByRole('button', { name: 'Revoke now' })
      .first()
      .click({ timeout: 20000 });

    // Esperar a la CONDICION y no a un reloj. La primera version esperaba
    // 4 s fijos y leia Firestore: el callable todavia estaba en vuelo, el
    // documento seguia sin revocar y el test acusaba a `revocarPaseHistorial`
    // de no escribir. El snapshot lo delataba — el boton seguia `[disabled]`,
    // o sea en su estado de carga.
    await expect(page.getByText(/revoked/i).first()).toBeVisible({
      timeout: 25000,
    });

    // El estado vive en el servidor, no en la pantalla: que el QR desaparezca
    // no prueba que el pase se haya anulado para quien ya lo fotografio.
    const pases = await leerPases();
    const revocado = pases.find((p) => p.token === token);
    expect(revocado.campos.revocado.booleanValue).toBe(true);

    await page.goto(`/historial_compartido/${token}`);
    await esperarAppLista(page);
    await despertarSemantica(page);

    await expect(page.getByText(/revoked/i).first()).toBeVisible({
      timeout: 25000,
    });
    await expect(page.getByText('Cambio de aceite')).toHaveCount(0);
  });
});
