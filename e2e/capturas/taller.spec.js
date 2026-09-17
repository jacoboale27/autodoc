'use strict';

// Capturas del lado TALLER — las dos ultimas de la ficha.
//
// Van al final porque quien busca la app en Play es casi siempre el
// propietario, pero no se omiten: enseñar el panel del mecanico es lo que
// separa a AutoDoc de un cuaderno de notas con fotos. Un comprador entiende de
// un vistazo que al otro lado hay un taller que escribe el historial, y eso es
// lo que hace creible el "verificado" de las capturas 2 y 3.

const { test } = require('@playwright/test');
const {
  ACTORES,
  abrirApp,
  entrarComo,
  comprobarPantalla,
  capturar,
} = require('./helpers');

test('capturas del taller', async ({ page }) => {
  await abrirApp(page, '/');
  await entrarComo(page, ACTORES.taller);

  // ── 07 · Panel del mecanico ────────────────────────────────────────────
  // El otro lado del mercado.
  await page.goto('/mechanic_dashboard');
  await comprobarPantalla(page, {
    enEspanol: ['Taller'],
    conDatos: [],
  });
  await capturar(page, 7, 'panel-mecanico');

  // ── 08 · Reseñas del taller ────────────────────────────────────────────
  // Confianza. La vitrina siembra dos resenias CON TEXTO y una de ellas con
  // respuesta del taller: cinco estrellas sin comentario se leen como
  // sembradas, que es justo lo que esta captura tiene que desmentir.
  //
  // Se afirma sobre el COMENTARIO, no sobre el nombre del autor: `ReviewModel`
  // no tiene campo de nombre (solo `idUsuario`), asi que la tarjeta no lo
  // pinta. Afirmar «Ricardo» aqui era esperar un dato que la pantalla no
  // muestra, y habria fallado cada corrida.
  await page.goto('/mechanic_reviews');
  await comprobarPantalla(page, {
    enEspanol: [],
    conDatos: ['Me explicaron el presupuesto'],
  });
  await capturar(page, 8, 'resenias');
});
