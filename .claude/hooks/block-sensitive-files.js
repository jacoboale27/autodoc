#!/usr/bin/env node
// PreToolUse hook (Edit|Write): blocks edits to secrets/credentials files.
// Motivated by the API key leak fixed in commit 3ee5a5e.

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
  if (!filePath) process.exit(0);

  const normalized = filePath.replace(/\\/g, '/');
  const base = normalized.split('/').pop();

  const isEnvFile =
    base === '.env' ||
    base === 'app.env' ||
    (/^\.env\..+/.test(base) && base !== '.env.example');

  const isCredentialFile =
    /service[-_]?account.*\.json$/i.test(base) ||
    /firebase-adminsdk.*\.json$/i.test(base) ||
    base === 'google-services.json' ||
    base === 'GoogleService-Info.plist' ||
    /\.(pem|p12|key)$/i.test(base);

  if (isEnvFile || isCredentialFile) {
    console.error(
      `Bloqueado: "${filePath}" es un archivo de secretos/credenciales. ` +
        `Este hook (block-sensitive-files) impide que se edite desde Claude Code ` +
        `para evitar leaks de API keys. Edita el archivo manualmente si es intencional.`
    );
    process.exit(2);
  }

  process.exit(0);
});
