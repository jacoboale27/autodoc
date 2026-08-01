const fs = require('fs');

function generateReport() {
  const resultPath = './results/test-results.json';
  if (!fs.existsSync(resultPath)) {
    console.log('No test results found. Run `npm test` first.');
    return;
  }
  
  const data = JSON.parse(fs.readFileSync(resultPath, 'utf8'));
  let markdown = '# Reporte de Revisión Playwright - AutoDoc\n\n';
  
  markdown += '## Resumen de Ejecución\n';
  markdown += `- Total de Suites: ${data.suites ? data.suites.length : 0}\n\n`;
  
  markdown += '## Flujos Probados\n';
  if (data.suites) {
    function processSuite(suite) {
      if (suite.specs && suite.specs.length > 0) {
        markdown += `### ${suite.title}\n`;
        suite.specs.forEach(spec => {
          const status = (spec.tests && spec.tests[0] && spec.tests[0].results && spec.tests[0].results[0]) 
            ? spec.tests[0].results[0].status 
            : 'unexpected';
          const ok = status === 'expected' ? '✅' : '❌';
          markdown += `- ${ok} ${spec.title}\n`;
        });
      }
      if (suite.suites && suite.suites.length > 0) {
        suite.suites.forEach(subSuite => processSuite(subSuite));
      }
    }
    
    data.suites.forEach(suite => processSuite(suite));
  }
  
  fs.writeFileSync('./reporte_playwright.md', markdown);
  console.log('Reporte generado en e2e/reporte_playwright.md');
}

generateReport();
