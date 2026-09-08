#!/usr/bin/env node
'use strict';

// Sirve el export estatico de la landing (`landing-web/out`) imitando lo que
// hace Firebase Hosting con el target `landing` en firebase.json:
//
//   - `cleanUrls: true`  ->  /es/contact sirve out/es/contact.html
//   - redirect 302 de `/` a `/es`
//
// Imitarlo importa: si aqui se sirviera con reglas distintas, la suite mediria
// este servidor y no el sitio que se despliega. El caso concreto es
// `cleanUrls`: sin el, /es/contact da 404 y el test de contacto no llega ni a
// ver el formulario.

const http = require('http');
const path = require('path');
const fs = require('fs');

const raiz = path.resolve(__dirname, '..', '..', 'landing-web', 'out');
const puerto = Number(process.env.E2E_LANDING_PORT || 5556);

const tipos = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

// El export de Next escribe /es como 'es.html' (cleanUrls), no como
// 'es/index.html': la comprobacion de que hay build tiene que mirar ese
// archivo o rechaza un export perfectamente valido.
if (!fs.existsSync(path.join(raiz, 'es.html'))) {
  console.error(
    `No hay export en ${raiz}. Corre antes: node e2e/scripts/build-landing.js`,
  );
  process.exit(1);
}

function enviar(res, archivo, codigo = 200) {
  const ext = path.extname(archivo).toLowerCase();
  res.writeHead(codigo, {
    'Content-Type': tipos[ext] || 'application/octet-stream',
    // El export se rehace entre corridas; una respuesta cacheada haria que la
    // suite probara el build anterior.
    'Cache-Control': 'no-store',
  });
  fs.createReadStream(archivo).pipe(res);
}

const servidor = http.createServer((req, res) => {
  const ruta = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);

  if (ruta === '/') {
    res.writeHead(302, { Location: '/es' }).end();
    return;
  }

  // Normalizar y confinar a la raiz: sin esto, un `..` en la URL sirve
  // cualquier archivo de la maquina.
  const destino = path.normalize(path.join(raiz, ruta));
  if (!destino.startsWith(raiz)) {
    res.writeHead(403).end('Forbidden');
    return;
  }

  const candidatos = [
    destino,
    destino + '.html', // cleanUrls
    path.join(destino, 'index.html'),
  ];
  for (const c of candidatos) {
    if (fs.existsSync(c) && fs.statSync(c).isFile()) {
      enviar(res, c);
      return;
    }
  }

  // Un sitio estatico devuelve 404 de verdad: no hay router de cliente que
  // recoja la ruta. Que la suite vea el 404 es justo lo que hace falta para
  // poder afirmar que un enlace llega o no llega a su destino.
  const propio = path.join(raiz, '404.html');
  if (fs.existsSync(propio)) {
    enviar(res, propio, 404);
    return;
  }
  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }).end('404');
});

servidor.listen(puerto, 'localhost', () => {
  console.log(`landing-web/out servido en http://localhost:${puerto} (cleanUrls)`);
});
