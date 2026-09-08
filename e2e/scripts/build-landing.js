#!/usr/bin/env node
'use strict';

// Compila el export estatico de la landing APUNTANDO A LOS EMULADORES.
//
// `output: "export"` incrusta las `NEXT_PUBLIC_*` en el bundle en tiempo de
// compilacion, asi que no basta con exportarlas al correr la suite: hay que
// compilar aparte. Es el mismo motivo por el que el bundle de Flutter tiene su
// propio `build-web.js`.
//
// Sin esto la suite hablaria con produccion: el POST del formulario iria a la
// Cloud Function real y la lista de talleres se leeria del Firestore real. Un
// test que solo lee de produccion tampoco esta aislado.

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const raizLanding = path.resolve(__dirname, '..', '..', 'landing-web');
const config = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'emulator-config.json'), 'utf8'),
);
const projectId = config.FIREBASE_PROJECT_ID;

const entorno = Object.assign({}, process.env, {
  // Endpoint de la Cloud Function en el emulador.
  NEXT_PUBLIC_SOLICITUDES_ENDPOINT: `http://localhost:5001/${projectId}/us-central1/recibirSolicitudLanding`,
  // REST de Firestore del emulador, para el directorio de talleres.
  NEXT_PUBLIC_FIRESTORE_REST: `http://localhost:8080/v1/projects/${projectId}/databases/(default)/documents`,
});

console.log('Compilando landing-web contra emuladores...');
console.log(`  endpoint : ${entorno.NEXT_PUBLIC_SOLICITUDES_ENDPOINT}`);
console.log(`  firestore: ${entorno.NEXT_PUBLIC_FIRESTORE_REST}`);

const npx = process.platform === 'win32' ? 'npx.cmd' : 'npx';
const r = spawnSync(npx, ['next', 'build'], {
  cwd: raizLanding,
  env: entorno,
  stdio: 'inherit',
  shell: process.platform === 'win32',
});

process.exit(r.status === null ? 1 : r.status);
