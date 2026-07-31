const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  timeout: 60000,
  retries: 0,
  reporter: [['json', { outputFile: 'results/test-results.json' }], ['html']],
  use: {
    baseURL: 'http://localhost:5555',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure'
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } }
  ],
  webServer: {
    command: 'cd .. && flutter run -d web-server --web-port=5555',
    port: 5555,
    timeout: 120 * 1000,
    reuseExistingServer: true
  }
});
