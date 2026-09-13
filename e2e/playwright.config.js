const { defineConfig, devices } = require('@playwright/test');

// La suite corre contra EMULADORES, no contra produccion.
//
// La version anterior de este archivo arrancaba
// `flutter run -d web-server --dart-define-from-file=.env`, es decir: el
// Firebase real con las credenciales reales. Los specs iniciaban sesion con
// dos cuentas fijas y el de registro creaba usuarios nuevos en produccion en
// cada corrida. Ademas `--dart-define-from-file` no funciona en este repo
// —compila sin quejarse y deja el bundle con las claves vacias—, y el modo
// debug de Flutter web solo admite un cliente de depuracion, asi que abrir la
// pagina con Playwright mientras dwds esta conectado la deja en blanco.
//
// El arranque tiene tres piezas y el orden importa:
//   1. emuladores (Auth, Firestore, Storage) — el backend;
//   2. el bundle compilado, servido con fallback SPA — la app;
//   3. globalSetup siembra los fixtures cuando 1 ya responde.
// El bundle se compila aparte (`npm run build:web`) porque tarda varios
// minutos y no tiene sentido rehacerlo en cada corrida.

module.exports = defineConfig({
  testDir: './tests',
  timeout: 180000,
  retries: 0,
  globalSetup: require.resolve('./scripts/global-setup.js'),
  reporter: [['json', { outputFile: 'results/test-results.json' }], ['html']],
  use: {
    // `localhost`, nunca `127.0.0.1`: la clave de reCAPTCHA Enterprise de App
    // Check no admite una IP, y cuando su token no resuelve Firebase Auth se
    // cuelga sin emitir una sola peticion de red. En modo emulador App Check
    // esta desactivado, pero el modo de fallo es demasiado silencioso como
    // para dejar la eleccion al azar.
    baseURL: 'http://localhost:5555',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: [
    {
      // `emulators:start` y no `exec`: los emuladores tienen que seguir vivos
      // durante toda la suite, no envolver un unico comando.
      command:
        'npx firebase emulators:start --only auth,firestore,storage --project autodoc-e2e',
      cwd: '..',
      // El hub de emuladores. Playwright espera a este puerto solo para no
      // seguir adelante con el proceso muerto: el hub abre ANTES que Firestore
      // y mucho antes de que Functions cargue los triggers, asi que llegar
      // aqui NO significa que los emuladores respondan.
      //
      // La espera que de verdad cuenta esta en scripts/global-setup.js, que
      // pregunta a Firestore (8080) y a Auth (9099) directamente. No la
      // sustituyas por esta: los dos primeros tests caian con ECONNREFUSED en
      // 53 ms mientras el tercero pasaba tras 8 s, que parece el emulador
      // muriendose a media suite y es justo lo contrario.
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
