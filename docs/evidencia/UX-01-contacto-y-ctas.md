# UX-01 — Contacto y CTAs reales

**Rama:** `fix/ux01`, cortada de `integracion/ola-1` (`c17fead`, ya con QA-01 fusionada).
**Fecha:** 2026-09-08.

Ninguna corrida toca produccion: los formularios se ejercen contra el emulador de Functions y el
de Firestore, con el export de la landing compilado apuntando a ellos.

## 1. El estado de partida era peor que "un formulario decorativo"

El plan describe UX-01 como "contacto y CTA App Store rotos". Al abrirlo aparecieron **dos**
formularios que prometen un flujo y no lo terminan, y el segundo no estaba en el enunciado:

| ID | Donde | Que pasaba |
|---|---|---|
| `EVID-UX-010` | `app/[locale]/contact/page.tsx` | `<form action="#">`. Pulsar "Enviar Mensaje" recargaba la pagina y no enviaba nada. Sin estado de carga, de exito ni de error, porque no habia envio. |
| `EVID-UX-011` | `components/ui/WorkshopsSection.tsx` | El formulario de afiliacion hacia un **POST sin autenticar a la REST API de Firestore de produccion** contra `/talleres`. La regla de esa coleccion es `allow create: if isAdmin()`: **siempre 403**. Tenia implementados `submitting`, `submitted` y el mensaje de exito — estados inalcanzables. Y si la regla hubiera dejado pasar el POST habria sido peor: alta anonima directa en el directorio publico. |
| `EVID-UX-012` | `HeroSection.tsx`, `Footer.tsx` | `https://apps.apple.com/app/id123456789` — id de ejemplo, en los dos sitios. |
| `EVID-UX-013` | `Footer.tsx` | Los legales apuntaban a `autodoc.app/privacidad` y `/terminos`, rutas que el hosting no sirve, mientras la landing tiene sus propias `/es/privacy` y `/es/terms`. |
| `EVID-UX-014` | `Header.tsx`, `Footer.tsx` | Anclas `href="#features"`: desde `/es/contact` no van a ninguna parte, porque esas secciones viven en la home. |
| `EVID-UX-015` | toda la pagina de contacto | Hardcodeada en espanol pese a vivir bajo `[locale]`, y **no la enlazaba nadie**: existia y era inalcanzable navegando. |

## 2. El contrato elegido

El plan admite endpoint validado o `mailto:` etiquetado. Se eligio **endpoint**, porque hacen falta
dos destinos (contacto y afiliacion) y porque el `mailto:` no arregla el segundo formulario.

La landing es un export estatico (`output: "export"`), o sea que no tiene servidor propio: el
destino es una Cloud Function, `recibirSolicitudLanding` (`functions/src/solicitudesLanding.js`).

| Evidence ID | Que hace | Artefacto |
|---|---|---|
| `EVID-UX-016` | valida por tipo, recorta, normaliza el correo y **copia campo declarado a campo declarado** (un POST con `rol: 'Superusuario'` no arrastra nada) | `validarSolicitud` |
| `EVID-UX-017` | honeypot: al bot se le responde exito y no se guarda nada, para no ensenarle cual es el campo trampa | `HONEYPOT`, `ContactForm.tsx` |
| `EVID-UX-018` | cupo por IP con contador transaccional (una lectura y una escritura, sin indice ni lecturas O(n)), contado **antes** de validar | `dentroDelCupo` |
| `EVID-UX-019` | respuesta no reveladora: un unico `datos_invalidos` para todos los motivos, en vez de un oraculo campo a campo | manejador HTTP |
| `EVID-UX-020` | el buzon `solicitudes_landing` esta cerrado a los clientes por los dos lados; el administrador solo puede cambiar `estado`, dentro de una lista cerrada | `firestore.rules` |

## 3. Lo que cambio tras los gates obligatorios

Los dos revisores (`firestore-rules-reviewer` y `functions-perf-reviewer`) corrieron sobre la
implementacion terminada. **Coincidieron por separado en el hallazgo grave**, que era mio:

| Severidad | Hallazgo | Cierre |
|---|---|---|
| **Alta** | `ipDe()` tomaba el **primer** elemento de `X-Forwarded-For`, que es justo el trozo que escribe quien llama: `curl -H 'X-Forwarded-For: 10.0.$i.$j'` caia en un cubo distinto en cada peticion y el cupo no se tocaba nunca. El limitador era decorativo. | se toma la penultima entrada (la IP real cuando hay proxy delante) y la unica si la cadena trae un solo elemento; test dedicado |
| Alta | sin `try/catch`: un fallo de Firestore escapaba como *unhandled rejection*, y el runtime **mata la instancia** y escribe su error sobre la respuesta de la ultima peticion vista por el proceso — que puede ser la de otra persona— y sin cabeceras CORS | `try/catch` -> 503 con CORS ya puestas; test que falsea el fallo de Firestore |
| Media | la sal del hash de IP era una cadena versionada. Con la sal a la vista, invertir `ip_hash` sobre 2^32 direcciones es un barrido de minutos: el hash no anonimizaba nada | `SOLICITUDES_LANDING_SALT` obligatoria fuera del emulador; la funcion se niega a arrancar sin ella |
| Media | `solicitudes_landing_control` crecia un documento por IP y no caducaba nunca | campo `expira_en` (Timestamp) para una politica TTL — ver §6 |
| Media | endpoint anonimo sin tope de instancias: un bucle escala sin techo y la factura la paga el proyecto | `runWith({ maxInstances: 10, memory: '128MB', timeoutSeconds: 20 })` |
| Baja | `request.resource.data.estado` revienta la evaluacion si el update **borra** el campo, en vez de denegar limpio | `.get('estado', '')`, y un test que primero comprueba que el centinela de borrado es real |
| Baja | `@google-cloud/firestore` se cargaba a nivel de modulo para una funcion que corre una vez al dia: lo pagaba el arranque en frio de las ~30 funciones | `require` movido dentro de `scheduledFirestoreExport` |
| Baja | `mensaje` (2000 caracteres) se indexaba en ambos sentidos sin que nadie consulte por el | exencion en `fieldOverrides` |

Ademas se anadieron los casos que faltaban y que los revisores pidieron: update combinado
`{estado, mensaje}` (el bypass canonico del patron), update que anade una clave nueva, update que
borra `estado`, `list` anonimo y `create` en la coleccion del contador.

**Discrepancia resuelta a favor de lo observado:** el revisor de performance sostuvo que
`admin.firestore.FieldValue` funciona bajo el emulador y que el problema era solo la copia
duplicada del modulo. No es asi: el emulador dio primero `Cannot read properties of undefined
(reading 'serverTimestamp')` —o sea `admin.firestore.FieldValue` ausente— y solo despues, al usar
el modulo `@google-cloud/firestore`, el error de centinela ajeno. Son dos fallos distintos, ambos
reproducidos; el comentario del codigo describe los dos.

## 4. Cobertura

| Evidence ID | Suite | Resultado |
|---|---|---|
| `EVID-UX-021` | `functions/test/solicitudes_landing.test.js` | 23 casos (validacion, CORS, metodo, honeypot, cupo, IP falsificada, fallo de Firestore) |
| `EVID-UX-022` | `test_rules/solicitudes_landing.test.js` | 20 casos contra emulador |
| `EVID-UX-023` | `e2e/tests-landing/` (Playwright, config propia) | **18 casos, todos verdes, dos corridas seguidas** |

| Suite | Antes | Despues |
|---|---|---|
| Reglas | 395 / 395, 23 suites | **415 / 415, 24 suites**, exit 0 |
| Functions (Mocha) | 150 / 150 | **173 / 173** |
| E2E landing | no existia | **18 / 18**, exit 0 |
| E2E app (Flutter) | 27 + 2 fixme | sin cambios (no se toco `lib/`) |
| Flutter (`flutter test`) | 1140 / 1140 | **1140 / 1140** (ver nota abajo) |
| Puertos al salir | — | **0 en LISTENING** |

**Nota sobre la primera corrida de Flutter:** dio 1139 y un fallo, en una corrida lanzada en
paralelo con las suites de reglas y de functions. La corrida limpia y secuencial da 1140/1140. No
se pudo identificar el test porque la salida iba por `tail`; UX-01 no toca ni un archivo Dart, asi
que el cambio no puede explicarlo, pero queda dicho que hubo un rojo y que no se llego a ver cual.

Los defectos siguieron TDD: el endpoint se escribio contra 20 tests en rojo, y los cinco arreglos
de los gates traen cada uno su caso.

## 5. Dos trampas del harness que costaron corridas

1. **Playwright esperaba a la pieza equivocada.** La config espera al puerto del **hub** (4400),
   que abre bastante antes que Firestore y mucho antes de que el emulador de Functions termine de
   cargar los triggers. Sintoma: los dos primeros tests fallaban en **53 ms** con ECONNREFUSED
   contra 8080 y el tercero pasaba tras 8 s — que parece el emulador muriendose a media suite (la
   rareza de Windows ya documentada) y era exactamente lo contrario. Cerrado con
   `scripts/global-setup-landing.js`, que espera a Firestore y al preflight de la funcion. **El
   mismo error latente estaba en la suite de la app**: su `global-setup.js` sembraba sin esperar a
   Firestore; tambien se corrigio.
2. **El navegador hablando REST con el emulador de Firestore lo desestabiliza.** El directorio de
   talleres se lee con un GET desde la pagina; Chromium aborta esas conexiones al navegar y el
   emulador (Java/netty) acumula "Connection reset". En la suite se intercepta esa lectura
   (`stubDirectorio`). Por eso la comprobacion de que una solicitud **no** publica un taller se
   hace con el Admin SDK contra `talleres`, y no mirando la pantalla: con la lectura interceptada,
   "no aparece en la pagina" no probaria nada.

## 6. Lo que queda abierto, y por que

- **La politica TTL de `solicitudes_landing_control` no esta en el repo.** El campo `expira_en` ya
  se escribe, pero Firestore no configura TTL desde `firestore.indexes.json`: va por consola o
  `gcloud firestore fields ttls update`. Queda como paso del runbook de despliegue, junto con
  definir `SOLICITUDES_LANDING_SALT`. **Sin esas dos cosas el endpoint no debe desplegarse**: sin
  la sal ni arranca, y sin el TTL la coleccion del limitador no se purga nunca.
- **La forma exacta de `X-Forwarded-For` en este proyecto no se ha podido verificar contra el
  entorno real**, porque no se autoriza desplegar. La implementacion cubre las tres formas
  posibles (cadena con proxy, cadena de un elemento, sin cabecera) y evita `req.ip` a proposito:
  si el framework no tuviera `trust proxy`, `req.ip` seria la IP interna del proxy y **todo el
  trafico caeria en un unico cubo**, convirtiendo el limitador en un tope global de diez envios
  por hora para el mundo entero. Conviene confirmarlo en el primer despliegue.
- **No hay pantalla de administracion del buzon.** `allow read`/`allow update` estan concedidos y
  hoy no los usa ningun cliente. Cambiar `estado` tampoco deja rastro en `admin_logs`
  (`CONVENTIONS.md` solo lo exige para cambios de rol).
- **El cupo es por IP publica**, asi que una oficina tras NAT lo comparte. Es el precio de limitar
  sin identificar a nadie; por eso el cupo es de diez y no de tres.
- **El badge de Google Play no se ha podido validar**: el id coincide con el `applicationId` real
  (`com.autodoc.app`), pero que la ficha este publicada no se comprueba desde aqui. El de iOS,
  que era un id de ejemplo, esta oculto tras una constante unica (`lib/enlaces.ts`).

## 7. Estado de la Definition of Done

| Punto de la DoD | Estado |
|---|---|
| implementacion minima y localizada | cumplido |
| prueba nueva falla antes y pasa despues | cumplido: el endpoint nacio de 20 tests en rojo y cada hallazgo de los gates trae su caso |
| pruebas existentes relevantes pasan | reglas 415/415, functions 173/173, landing E2E 18/18 |
| Playwright/emulador donde cruza UI, autorizacion o persistencia | cumplido: 18 casos contra el export real y los emuladores |
| responsive y localizacion | localizacion cumplida (ES/EN, con el envio probado en los dos); **los cuatro viewports siguen siendo de UX-03** |
| Evidence ID, resultado y artefacto registrados | este documento |
| regresion del workstream ejecutada | cumplida |
| reevaluacion del criterio CREA afectado | Amigabilidad: los dos formularios informan del resultado real y ningun CTA promete lo que no existe. Funcionalidad: la solicitud de afiliacion, que nunca llegaba a ningun sitio, ahora tiene destino y buzon |
