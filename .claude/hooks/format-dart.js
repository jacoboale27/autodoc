#!/usr/bin/env node
// PostToolUse hook (Edit|Write): auto-runs `dart format` on edited .dart files,
// matching the format check enforced in .github/workflows/flutter_ci.yml.

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
