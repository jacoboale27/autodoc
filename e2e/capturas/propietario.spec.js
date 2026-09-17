'use strict';

// Capturas del lado PROPIETARIO — las seis primeras de la ficha.
//
// El orden del numero de fichero es el orden de la ficha, y no es el orden
// cronologico del producto: Play enseña las dos o tres primeras en los
// resultados de busqueda, asi que van las de mas valor percibido delante. El
// garaje primero porque se entiende sin leer nada; el pase con QR tercero
// porque es lo unico que ningun competidor tiene.
//
// Todo en un solo `test` a proposito. Cada arranque de la app cuesta caro
// (CanvasKit + persistencia offline de Firestore) y degrada el emulador Java:
// en esta suite, partir las capturas en seis tests hacia que las ultimas
// cayeran por timeout. Se navega con `goto` entre pantalla y pantalla dentro
// de la misma sesion.

const { test } = require('@playwright/test');
const {
  ACTORES,
  abrirApp,
  entrarComo,
  comprobarPantalla,
  capturar,
} = require('./helpers');

test('capturas del propietario', async ({ page }) => {
  await abrirApp(page, '/');
  await entrarComo(page, ACTORES.propietario);

  // ── 01 · Garaje ────────────────────────────────────────────────────────
  // "Todos mis carros en un sitio". Es la que se entiende sin leer.
  await page.goto('/garage');
  await comprobarPantalla(page, {
    enEspanol: ['Mis Vehículos'],
    conDatos: ['Hilux'],
  });
  await capturar(page, 1, 'garaje');

  // ── 02 · Historial de servicios ────────────────────────────────────────
  // El corazon del producto. Seis servicios sembrados para que se lea como un
  // expediente y no como una lista vacia con un boton de "+".
  await page.goto('/service_history/vit-vehiculo-1');
  await comprobarPantalla(page, {
    enEspanol: ['Historial de Servicios'],
    conDatos: ['Cambio de aceite'],
  });
  await capturar(page, 2, 'historial');

  // ── 03 · Pase de historial (QR) ────────────────────────────────────────
  // El diferenciador, y la escena del video elegido ("el carro que cuenta su
  // historia"). La pantalla emite al abrirse, asi que no hay que pulsar nada.
  //
  // OJO al editar: esta pantalla lleva una cuenta atras viva (Timer.periodic),
  // asi que nunca queda "sin trabajo pendiente". Cualquier espera basada en
  // red o en inactividad se colgaria; `capturar` usa un timeout fijo por eso.
  await page.goto('/compartir_historial/vit-vehiculo-1');
  await comprobarPantalla(page, {
    enEspanol: ['Compartir historial'],
    conDatos: ['Caduca en'],
  });
  await capturar(page, 3, 'pase-historial');

  // ── 04 · Directorio de talleres ────────────────────────────────────────
  // Que exista una red, no una app vacia. Por eso la vitrina siembra DOS
  // talleres: con uno solo el directorio parece roto.
  await page.goto('/workshop_directory');
  await comprobarPantalla(page, {
    enEspanol: ['Directorio de Talleres'],
    conDatos: ['La Ceiba'],
  });
  await capturar(page, 4, 'directorio-talleres');

  // ── 05 · Alertas ───────────────────────────────────────────────────────
  // "Me avisa antes de la multa". El SOAT del vehiculo 1 vence dentro de 12
  // dias en el seed justamente para que aqui haya algo que fotografiar.
  await page.goto('/alerts');
  await comprobarPantalla(page, {
    enEspanol: ['Alertas'],
    conDatos: [],
  });
  await capturar(page, 5, 'alertas');

  // ── 06 · Inicio ────────────────────────────────────────────────────────
  // Va la ultima de las seis porque resume, y una captura que resume se
  // entiende mejor cuando ya se han visto las partes.
  await page.goto('/dashboard');
  await comprobarPantalla(page, {
    enEspanol: ['Talleres Cercanos'],
    conDatos: [],
  });
  await capturar(page, 6, 'inicio');
});
