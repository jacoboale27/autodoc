#!/usr/bin/env node
// PostToolUse hook (Edit|Write): auto-runs `dart format` on edited .dart files,
// matching the format check enforced in .github/workflows/ci.yml (step
// "Check formatting").
//
// Alcance limitado, a proposito: este hook solo ve `tool_input.file_path`, que
// unicamente existe en Edit|Write. Un archivo escrito desde Bash (sed, heredoc)
// pasa de largo. La red que si cubre todos los casos es .githooks/pre-commit;
// actívala con `git config core.hooksPath .githooks` (ver CONVENTIONS.md 4.1).

const { execFileSync } = require('child_process');

let input = '';
process.stdin.on('data', (d) => (input += d));
process.stdin.on('end', () => {
  let data;
  try {
    data = JSON.parse(input);
  } catch {
    process.exit(0);
  }

  const filePath = data.tool_input && data.tool_input.file_path;
  if (!filePath || !filePath.endsWith('.dart')) process.exit(0);

  try {
    execFileSync('dart', ['format', filePath], {
      stdio: 'pipe',
      shell: process.platform === 'win32',
    });
  } catch (err) {
    // Non-blocking: formatting failure shouldn't stop the agent loop.
    console.error(`dart format falló en ${filePath}: ${err.message}`);
  }

  process.exit(0);
});
