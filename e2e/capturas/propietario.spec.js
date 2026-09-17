'use strict';

// Capturas del lado PROPIETARIO — las seis primeras de la ficha.
//
// El numero del fichero es el orden de la FICHA, no el orden en que se toman:
// Play enseña las dos o tres primeras en los resultados de busqueda, asi que
// van las de mas valor percibido delante (garaje, historial, pase con QR). El
// orden de EJECUCION es otro, y lo impone la app — ver el bloque siguiente.
//
// ── Por que no se puede navegar todo con `goto` ─────────────────────────────
//
// `page.goto` recarga la pagina entera, asi que reinicia la app y vacia los
// providers. Y hay pantallas que NO cargan sus propios datos:
//
//   - /garage solo LEE `vehicleProvider.vehicles` (garage_screen.dart:39). El
//     unico sitio que llama a `fetchVehicles` al entrar es el dashboard
//     (dashboard_screen.dart:54).
//   - /alerts depende de `vehicleProvider.selectedVehicle` y pinta «Selecciona
//     un vehículo primero» si es null (alerts_screen.dart:64).
//
// Medido: un `goto('/garage')` en frio da la pantalla vacia «No tienes
// vehículos en tu garaje» con tres vehiculos sembrados. (Eso es tambien un
// defecto de PRODUCCION —cualquiera que recargue con F5 estando en el garaje
// ve lo mismo— pero arreglarlo no es trabajo de esta suite.)
//
// Asi que: se entra UNA vez por el dashboard, que es quien carga los vehiculos,
// y desde ahi se navega DENTRO de la app. Solo las pantallas que se cargan
// solas —el historial con su StreamBuilder y el pase con su initState— se
// permiten un `goto`, y van al final para no tirar el provider antes de tiempo.
//
// Todo en un solo `test` a proposito: cada arranque de la app cuesta caro
// (CanvasKit + persistencia offline de Firestore) y degrada el emulador Java.

const { test, expect } = require('@playwright/test');
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

  // ── 06 · Inicio ────────────────────────────────────────────────────────
  // Va PRIMERA en la ejecucion porque es la unica pantalla que carga los
  // vehiculos en el provider, del que dependen el garaje y las alertas.
  await page.goto('/dashboard');
  await comprobarPantalla(page, {
    enEspanol: ['Alertas Activas'],
    conDatos: [],
  });
  await capturar(page, 6, 'inicio');

  // ── 01 · Garaje ────────────────────────────────────────────────────────
  // "Todos mis carros en un sitio". Es la que se entiende sin leer.
  // Por la pestaña, NO por goto: ver la cabecera de este fichero.
  await page.getByRole('tab', { name: 'Garaje' }).click();
  await comprobarPantalla(page, {
    enEspanol: ['Mis Vehículos'],
    conDatos: ['Hilux'],
  });
  await capturar(page, 1, 'garaje');

  // ── 04 · Directorio de talleres ────────────────────────────────────────
  // Que exista una red, no una app vacia. Por eso la vitrina siembra DOS
  // talleres: con uno solo el directorio parece roto.
  await page.getByRole('tab', { name: 'Talleres' }).click();
  await comprobarPantalla(page, {
    enEspanol: ['Talleres'],
    conDatos: ['La Ceiba'],
  });
  await capturar(page, 4, 'directorio-talleres');

  // ── 05 · Alertas ───────────────────────────────────────────────────────
  // "Me avisa antes de la multa". El SOAT del vehiculo 1 vence dentro de 12
  // dias en el seed justamente para que aqui haya algo que fotografiar.
  //
  // Se llega por el «Ver Todas» de la seccion «Alertas Activas» del dashboard
  // (dashboard_screen.dart:856). El rotulo de alertas es «Ver Todas» y el de
  // talleres «Ver todos», asi que no chocan aunque compartan pantalla.
  await page.getByRole('tab', { name: 'Inicio' }).click();
  await page.getByRole('button', { name: 'Ver Todas' }).click();
  await comprobarPantalla(page, {
    enEspanol: ['Alertas'],
    conDatos: [],
  });
  // En negativo: es el unico modo de fallo que produce un PNG bonito y vacio.
  await expect(
    page.getByText('Selecciona un vehículo primero'),
    'La pantalla de alertas se quedo sin vehiculo seleccionado.',
  ).toHaveCount(0);
  await capturar(page, 5, 'alertas');

  // ── 02 · Historial de servicios ────────────────────────────────────────
  // El corazon del producto. Seis servicios sembrados para que se lea como un
  // expediente y no como una lista vacia con un boton de "+".
  //
  // Aqui SI vale `goto`: la pantalla monta su propio StreamBuilder sobre
  // Firestore con el vehiculoId de la ruta, asi que no necesita el provider.
  await page.goto('/service_history/vit-vehiculo-1');
  await comprobarPantalla(page, {
    enEspanol: ['Historial de Servicios'],
    conDatos: ['Cambio de aceite'],
  });
  await capturar(page, 2, 'historial');

  // ── 03 · Pase de historial (QR) ────────────────────────────────────────
  // El diferenciador, y la escena del video elegido ("el carro que cuenta su
  // historia"). Emite en `initState`, asi que tampoco necesita el provider.
  //
  // OJO al editar: lleva una cuenta atras viva (Timer.periodic), asi que nunca
  // queda "sin trabajo pendiente". Cualquier espera basada en inactividad se
  // colgaria; `capturar` usa un timeout fijo por eso.
  await page.goto('/compartir_historial/vit-vehiculo-1');
  await comprobarPantalla(page, {
    enEspanol: ['Compartir historial'],
    conDatos: ['Caduca en'],
  });
  await capturar(page, 3, 'pase-historial');
});
