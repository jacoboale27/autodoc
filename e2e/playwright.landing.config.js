const { defineConfig, devices } = require('@playwright/test');

// Suite de la landing (UX-01). Va aparte de playwright.config.js porque no
// necesita el bundle de Flutter —que tarda varios minutos en compilar— ni el
// emulador de Auth: la landing no autentica a nadie.
//
// Tres piezas:
//   1. emuladores de Functions y Firestore: el destino real de los formularios;
//   2. el export estatico servido como lo sirve Firebase Hosting (cleanUrls);
//   3. nada mas — no hay fixtures que sembrar, cada test limpia su buzon.
//
// El export se compila aparte (`npm run build:landing`) porque incrusta las
// `NEXT_PUBLIC_*` en tiempo de compilacion: sin ese paso el bundle apunta a la
// Cloud Function y al Firestore de PRODUCCION.

module.exports = defineConfig({
  testDir: './tests-landing',
  timeout: 60000,
  retries: 0,
  // Un solo worker a proposito: el cupo del limitador es POR IP, y dos workers
  // salen por la misma. En paralelo se roban el cupo entre ellos y ademas cada
  // uno limpia el contador del otro a media prueba — un rojo que no dice nada
  // del codigo.
  workers: 1,
  globalSetup: require.resolve('./scripts/global-setup-landing.js'),
  reporter: [['json', { outputFile: 'results/landing-results.json' }], ['list']],
  use: {
    baseURL: 'http://localhost:5556',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: [
    {
      command:
        'npx firebase emulators:start --only functions,firestore --project autodoc-e2e',
      cwd: '..',
      // El hub. Esperar a el NO garantiza que Functions y Firestore
      // respondan — abre antes que los dos. La espera real esta en
      // scripts/global-setup-landing.js, contra Firestore (8080) y el propio
      // endpoint de la funcion (5001).
      port: 4400,
      timeout: 180 * 1000,
      reuseExistingServer: true,
      stdout: 'pipe',
    },
    {
      command: 'node scripts/serve-landing.js',
      port: 5556,
      timeout: 60 * 1000,
      reuseExistingServer: true,
    },
  ],
});
