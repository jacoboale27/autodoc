#!/usr/bin/env node
'use strict';

// Sirve build/web con fallback SPA, que es lo que Firebase Hosting hace en
// produccion (`rewrites` a /index.html en firebase.json).
//
// Un `python -m http.server` NO sirve: no reescribe rutas, asi que recargar
// cualquier ruta profunda da 404 y la suite mediria un 404 del servidor de
// pruebas en vez del comportamiento de la app. Ese es justo el fallo que UX-02
// tiene que poder distinguir.
//
// Escucha en `localhost` y no en `127.0.0.1` a proposito: la clave de
// reCAPTCHA Enterprise de App Check no admite una IP, y cuando no resuelve su
// token Firebase Auth se cuelga SIN emitir una sola peticion de red — el login
// no hace nada y la consola no dice nada. En modo emulador App Check esta
// desactivado, pero el mismo servidor se usa para probar builds que si lo
// llevan, y el modo de fallo es demasiado silencioso como para dejarlo al azar.

const http = require('http');
const path = require('path');
const fs = require('fs');

const raiz = path.resolve(__dirname, '..', '..', 'build', 'web');
const puerto = Number(process.env.E2E_PORT || 5555);

const tipos = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.map': 'application/json; charset=utf-8',
};

if (!fs.existsSync(path.join(raiz, 'index.html'))) {
  console.error(
    `No hay bundle en ${raiz}. Corre antes: node e2e/scripts/build-web.js`,
  );
  process.exit(1);
}

function enviar(res, archivo, codigo = 200) {
  const ext = path.extname(archivo).toLowerCase();
  res.writeHead(codigo, {
    'Content-Type': tipos[ext] || 'application/octet-stream',
    // El bundle se recompila entre corridas; una respuesta cacheada haria que
    // la suite probara el build anterior, que es un falso verde perfecto.
    'Cache-Control': 'no-store',
  });
  fs.createReadStream(archivo).pipe(res);
}

const servidor = http.createServer((req, res) => {
  const ruta = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);

  // Normalizar y confinar a la raiz: sin esto, un `..` en la URL sirve
  // cualquier archivo de la maquina.
  const destino = path.normalize(path.join(raiz, ruta));
  if (!destino.startsWith(raiz)) {
    res.writeHead(403).end('Forbidden');
    return;
  }

  if (fs.existsSync(destino) && fs.statSync(destino).isFile()) {
    enviar(res, destino);
    return;
  }

  // Fallback SPA: cualquier ruta que no sea un archivo real la resuelve el
  // router de la app, igual que en Hosting.
  enviar(res, path.join(raiz, 'index.html'));
});

servidor.listen(puerto, 'localhost', () => {
  console.log(`build/web servido en http://localhost:${puerto} (fallback SPA)`);
});
