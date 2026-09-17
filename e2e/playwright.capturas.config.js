const { defineConfig } = require('@playwright/test');

// Suite de CAPTURAS para la ficha de Google Play. No prueba nada: produce PNGs.
//
// Comparte backend y bundle con la suite de tests (mismos emuladores, mismo
// `serve-web.js`) y se separa en su propia config por tres motivos que no son
// de estilo:
//
//   1. Siembra otros fixtures (scripts/seed-vitrina.js). Los dos seeds empiezan
//      borrando Firestore, asi que no pueden convivir en una misma corrida.
//   2. El viewport es de TELEFONO, no de escritorio. Play acepta capturas de
//      320 a 3840 px con ratio entre 16:9 y 9:16; una captura con el layout
//      ancho de `Desktop Chrome` es inservible y ademas no se parece a lo que
//      el usuario va a instalar.
//   3. El locale se fuerza. Ver el comentario de `locale` mas abajo: es la
//      trampa que mas tiempo cuesta en este repo.
//
// No lleva `retries`: un reintento en una suite de capturas solo sirve para
// tapar que la app tardo en pintar, y el resultado seria un PNG a medio
// renderizar dado por bueno.

module.exports = defineConfig({
  testDir: './capturas',
  timeout: 180000,
  retries: 0,
  // En serie. La E2E de la app en paralelo NO es reproducible en Windows: el
  // emulador Java de Firestore no da abasto con cuatro arranques simultaneos de
  // la app y se pierde la primera lectura del perfil, con lo que el router
  // manda a /profile_setup y la captura sale de la pantalla equivocada. Aqui
  // ademas no hay nada que ganar: son ocho capturas.
  workers: 1,
  globalSetup: require.resolve('./scripts/global-setup-vitrina.js'),
  reporter: [['list']],
  use: {
    baseURL: 'http://localhost:5555',

    // ── El locale, que es LA trampa de este repo ──────────────────────────
    //
    // El bundle de E2E se renderiza en INGLES si no se fuerza: Chromium arranca
    // con el locale del sistema y Flutter resuelve AppLocalizations con
    // `navigator.language`. Lo que lo esconde es que los rotulos que NO pasan
    // por el ARB —«Garaje», «Talleres», «Fechas»— siguen en español, asi que la
    // pantalla parece medio traducida en vez de rota, y una captura en ingles
    // subida a la ficha es peor que no tener captura.
    //
    // Hacen falta LAS DOS: `locale` fija navigator.language, y `--lang` fija el
    // idioma de la UI de Chromium (dialogos de permisos, menus contextuales)
    // que tambien puede colarse en una captura.
    locale: 'es-CO',
    launchOptions: { args: ['--lang=es-CO'] },
    timezoneId: 'America/El_Salvador',

    // ── Tamaño de telefono ────────────────────────────────────────────────
    //
    // 412x915 es un Pixel moderno. Con deviceScaleFactor 3 el PNG sale a
    // 1236x2745, que entra holgado en el rango de Play (320-3840 px, ratio
    // entre 16:9 y 9:16 — este es 1:2.22) y se ve nitido en pantallas densas.
    viewport: { width: 412, height: 915 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,

    // Una captura fallida no deja rastro util por defecto: el video y la traza
    // son lo unico que explica por que la pantalla salio vacia.
    trace: 'retain-on-failure',
    video: 'retain-on-failure',
  },
  projects: [{ name: 'telefono' }],
  webServer: [
    {
      // Identico al de playwright.config.js, y por los mismos motivos:
      // `emulators:start` (no `exec`) porque tienen que seguir vivos toda la
      // corrida, y `functions` porque el pase de historial —la captura 3, la
      // que mas vende— vive entero en tres callables.
      command:
        'npx firebase emulators:start --only auth,firestore,storage,functions --project autodoc-e2e',
      cwd: '..',
      // El puerto del hub. Llegar aqui NO significa que los emuladores
      // respondan; la espera que cuenta esta en global-setup-vitrina.js.
      port: 4400,
      timeout: 120 * 1000,
      reuseExistingServer: true,
      stdout: 'pipe',
    },
    {
      command: 'node scripts/serve-web.js',
      port: 5555,
      timeout: 60 * 1000,
      reuseExistingServer: true,
    },
  ],
});
