# UX-03 / UX-04 — Accesibilidad y errores de datos

Rama `fix/ux03-ux04`, cortada de `integracion/ola-1` (`dc7b011`).
Evidencia `EVID-UX-030..038`.

Dos frentes que no se tocan entre si: la landing (Next.js) y la app (Flutter).
Se hicieron en ese orden y van en dos commits separados, `d2cf0d9` y `b35bebe`.

---

## Lo que hay que saber sin leer el resto

1. **No habia un menu movil inaccesible que arreglar: no habia menu.** El
   enunciado del plan dice «anadir menu movil accesible», como si existiera uno
   defectuoso. La navegacion de `Header.tsx` es `hidden md:flex`: por debajo de
   768 px los tres enlaces de seccion **desaparecian**, y «Iniciar Sesion» es
   `hidden sm:block`, asi que a 320 px lo unico que quedaba en pantalla era
   «Probar Gratis». No es una molestia de accesibilidad; es navegacion que no
   existe en el tamano por el que entra la mayor parte del trafico.

2. **El `Error: ${snapshot.error}` del enunciado era uno de cuarenta, y ni
   siquiera el peor.** El patron de verdad estaba una capa mas abajo: quince
   providers guardaban `_error = e.toString()` —setenta y siete sitios— y las
   pantallas pintan ese campo tal cual. Por eso seguian filtrando **hasta los
   mensajes que ya estaban traducidos**.

3. **Y ahi habia una consecuencia que nadie habia visto:** donde la pantalla
   hace `provider.error ?? context.l10n.loQueSea`, la cadena traducida **no se
   veia nunca**. El error crudo no es null cuando algo falla, asi que el `??`
   jamas caia del lado del ARB. Habia texto localizado, revisado y traducido al
   ingles que era inalcanzable.

4. **Ocho tests existentes se pusieron rojos y los ocho probaban de mentira.**
   Lanzaban una cadena suelta (`thenThrow('email-already-in-use')`) y afirmaban
   que `provider.error` la contenia. Con `_error = e.toString()` eso pasaba por
   construccion: no ejercian ni una linea del manejo real de errores de
   Firebase. Es la misma enfermedad que ya tiene dos cicatrices en este repo
   (VER-01 y ROLE-01) — un test que ejercita una puerta distinta de la que dice
   probar.

---

## UX-03 — la landing (`d2cf0d9`)

### Menu movil

`Header.tsx` tiene ahora un boton hamburguesa con `aria-expanded` y
`aria-controls`, el foco entra al panel al abrirlo, `Escape` cierra y devuelve
el foco al boton, y cada enlace cierra al pulsarse.

El panel **se desmonta** al cerrar en vez de esconderse con `hidden`: un panel
oculto por CSS sigue siendo tabulable si alguien olvida el `inert`, y entonces
el teclado se pierde en enlaces invisibles.

A esos anchos el panel recoge ademas lo que la barra no puede mostrar —login y
los controles de idioma y tema—, porque a 320 px no caben junto al CTA y la
hamburguesa. El CTA principal se queda en la barra: es la accion de la pagina.

Los controles de idioma y tema se anunciaban en ingles
(`aria-label="Toggle language"`) en un sitio que existe en dos idiomas. Ahora
salen del ARB y el de tema dice **que va a hacer**, no como se llama.

### Movimiento reducido

29 elementos animados con framer-motion y **cero** guardas en todo el proyecto:
ni `useReducedMotion`, ni `MotionConfig`, ni una `@media` en `globals.css`. Lo
peor no era la entrada de la cabecera sino los dos mockups del hero, que
flotaban con `repeat: Infinity` — movimiento continuo e indefinido es
exactamente el disparador vestibular que la preferencia existe para evitar.

Se cierra por tres capas, y las tres hacen falta:

| Capa | Cubre | Por que no basta sola |
|---|---|---|
| `@media (prefers-reduced-motion)` en `globals.css` | `transition-*`, `animate-spin`, `scroll-behavior` | No alcanza a framer-motion, que anima por rAF con estilo inline |
| `<MotionConfig reducedMotion="user">` | transform y layout de cualquier `motion.*` | **Deja viva la opacidad a proposito** (un fundido no marea), y ahi esta el problema real de esta landing |
| `aparicion()` en cada componente | el revelado por scroll | — |

La segunda fila es la que importa: las secciones de abajo arrancan en
`opacity: 0` y solo se revelan con `whileInView`. Con `MotionConfig` solo, quien
pide movimiento reducido se queda mirando huecos en blanco hasta que hace
scroll.

### La trampa que costo dos vueltas

**Retirar las props de animacion deja la landing PEOR que antes.** Es un export
estatico: framer-motion hornea el valor de `initial` como estilo inline dentro
del HTML generado, para que no haya parpadeo, y en el servidor
`useReducedMotion()` no puede saber nada. Si al hidratar te limitas a quitar las
props, **no queda nadie que anime esos estilos** y el elemento se queda
congelado donde lo dejo el servidor: invisible para siempre, justo para la
persona que pidio que las cosas se movieran menos.

Se midio en el navegador, no se dedujo:

| `aparicion()` devuelve | `header` | titulo de talleres |
|---|---|---|
| `{}` | `matrix(1, 0, 0, 1, 0, -100)` | `opacity: 0` |
| `{initial: false}` | `matrix(1, 0, 0, 1, 0, -100)` | `opacity: 0` |
| `{initial: false, animate: REPOSO}` | `none` | `opacity: 1` |

`initial: false` significa «no animes desde el principio», no «borra lo que ya
hay escrito». Hace falta un **destino explicito** que pise el estilo heredado.

### HTML valido

`<Link><button>` en **dos** sitios, no uno: la cabecera y el CTA del hero. Un
boton dentro de un ancla lo prohibe el modelo de contenido de `<a>`; el
navegador lo tolera pero deja un nodo con dos roles, y un lector de pantalla
anuncia «enlace, boton».

### Pruebas

`e2e/tests-landing/accesibilidad.spec.js`, 20 casos a 320/375/390/414 px, con
teclado y con la preferencia emulada.

Dos cosas de la suite que conviene no volver a descubrir:

- **`test.use({ reducedMotion: 'reduce' })` no surte efecto en Playwright
  1.62.1.** Dentro de la pagina, `matchMedia('(prefers-reduced-motion:
  reduce)').matches` seguia dando `false`, y los tres casos fallaban **con el
  arreglo ya puesto** — que es la forma mas cara de perder una tarde. Hay que
  usar `page.emulateMedia()`, y antes del `goto`: framer lee la preferencia al
  montar.
- **Hay un caso de control sin la preferencia** que exige que el revelado siga
  existiendo. Sin el, «arreglarlo» borrando todas las animaciones pasaria la
  suite entera.

Como se afirma el movimiento sin carreras contra el reloj: las secciones de
abajo, sin la preferencia, se quedan invisibles **para siempre** si nadie hace
scroll. Ese «para siempre» es lo que vuelve deterministas las comprobaciones.

---

## UX-04 — la app (`b35bebe`)

### Tres funciones, y la diferencia entre ellas importa

| Funcion | Donde | Por que |
|---|---|---|
| `mensajeDeError(l10n, e)` | pantallas con contexto que pintan un estado | Traduce de verdad; es lo que usa el historial de servicios |
| `mensajeSeguroDeError(e, accion:)` | providers y avisos por SnackBar | Un provider no tiene `BuildContext`, y darselo para esto seria peor que el problema |
| `mensajeDeReglaDeNegocio(e)` | donde ESTE codigo lanza `StateError` adrede | Ahi el `StateError` es un mensaje redactado; en cualquier otro sitio es un fallo de programacion («Bad state: No element») |

Lo que habia en el tercer caso era
`e.toString().replaceFirst('StateError: ', '')`: se lee como si distinguiera y
no distingue nada — a un `FirebaseException` le dejaba pasar el
`[cloud_firestore/...]` entero.

El texto de `mensajeSeguroDeError` va en espanol y sin pasar por el ARB, que es
exactamente lo que ya hacian los dos unicos providers que trataban esto bien
(`galeria_provider`, `verificacion_provider`).

### Dos decisiones de contenido

- **Red y permisos dicen cosas distintas.** Colapsar todo en «algo fallo» deja
  sin saber si reintentar sirve de algo. Reintentar arregla un `unavailable`;
  ante un `permission-denied` no va a arreglar nada nunca.
- **`failed-precondition` cae en el generico a proposito.** En esta app
  significa casi siempre una consulta sin indice compuesto — un fallo nuestro,
  que la persona no puede resolver ni entender. Lo unico honesto que se le
  puede decir es que lo intente mas tarde. Y su mensaje trae la consulta entera
  y un enlace a la consola del proyecto.
- **Los codigos de Auth NO caen en el generico.** Son los unicos errores de la
  app que la persona puede resolver sola. Taparlos con «algo fallo» habria sido
  cambiar un defecto por otro. Antes se veian, pero crudos y en ingles.

### Reintentar: un `setState` no basta

El `StreamBuilder` vive dentro de `build`, asi que un `setState` lo reconstruye
pero le entrega **el mismo objeto Stream**. Flutter compara
`oldWidget.stream == widget.stream` y no se resuscribe: reintentar repintaria
el error que ya estaba. Va con `key: ValueKey(_intento)`.

El test lo afirma **contando suscripciones**, no mirando si el texto cambio —
que es lo que habria dado verde sin arreglar nada.

### El centinela

`test/errores_sin_detalle_tecnico_test.dart`. Existe por la misma razon que el
de indices: **ninguna otra suite puede ver este defecto**. Un `Text('Error:
$e')` compila, analiza limpio y pasa cualquier test de widget; el fallo solo
aparece cuando a alguien, en produccion, le revienta una consulta. Y volver a
meterlo cuesta una linea en cualquier `catch` nuevo.

Destapo **cinco fugas mas** que el inventario se habia dejado
(`add_vehicle_form` ×2, `initiate_service_screen:690`,
`mechanic_reviews_screen:321`, `reserva_detail_screen:79`).

Mira solo presentacion y providers. `data/` queda fuera adrede: un servicio que
hace `throw 'Error al obtener vehiculo: $e'` esta bien, eso no se pinta, se
propaga, y el provider que lo recoge ya lo sanea. Incluirlo solo llenaria la
lista de excepciones justificadas hasta vaciar el centinela de sentido.

Lleva autochequeo propio y dos excepciones justificadas **por escrito**: el
codigo de Firebase en `galeria_provider` y `verificacion_provider`, que va en el
mensaje a proposito y ya estaba razonado en su sitio (sin el, un fallo de
configuracion del bucket es indistinguible de un corte de red).

---

## Gates

| Gate | Resultado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | **1216 / 1216** |
| `tsc --noEmit` (landing) | limpio |
| `eslint` (landing) | sin errores nuevos |
| E2E de la landing | **40 / 40** (20 nuevos + los 20 de UX-01) |
| E2E de la app | **32 pasan, 2 `fixme`**, exit 0 |

La primera corrida completa de la E2E de la app dio **2 rojos** —`propietario`
y `mecanico`, los dos aterrizando en `/profile_setup` en vez de `/dashboard`—
y no eran del cambio: corridos los dos specs solos dieron 9/9, y la corrida
completa siguiente, 32/32. Es la contencion ya documentada (cuatro workers,
cada arranque de la app cuesta CanvasKit mas la persistencia offline de
Firestore, y el emulador Java se resiente). Se deja escrito para no volver a
investigarlo como si fuera una regresion.

Los revisores `firestore-rules-reviewer` y `functions-perf-reviewer` **no
aplican**: ninguno de los dos commits toca `firestore.rules`,
`firestore.indexes.json` ni `functions/`.

### De paso: el hook de pre-commit

`dart format .` no falla sino que **muere** recorriendo
`landing-web/node_modules` en cuanto se hace `pnpm install` en un worktree
(pnpm anida rutas mas largas de lo que Windows admite y salta una
`PathNotFoundException`). El hook leia ese exit distinto de cero como «hay Dart
sin formatear» y detenia el commit con un mensaje falso que ademas no listaba
ni un archivo. En el CI no pasa porque el checkout es limpio, asi que solo se ve
en local. Ahora distingue ese caso y reintenta sobre las tres raices de Dart.

---

## Gaps abiertos

Ninguno rompe nada hoy; los dos primeros vienen del inventario de la landing y
quedan **fuera del alcance que fija el enunciado** (que nombra movimiento, menu
movil y HTML anidado).

| # | Que | Por que se deja |
|---|---|---|
| 1 | **Contraste por debajo de 4.5:1** en seis sitios de la landing: `FeaturesGrid` (`text-slate-500` sobre `#111827`, ~3.7:1; alerta `#FC8181` sobre blanco, ~2.4:1), `WorkshopsSection` (rating ambar sobre `slate-50`, ~2.05:1), `Footer` (copyright, ~4.0:1). | Es una decision de marca, no un bug: tocar la paleta cambia el aspecto del sitio y merece verse antes de aplicarse. Las cifras son de un worker en frio y **no estan verificadas a mano**. |
| 2 | **Jerarquia de encabezados con saltos**: `FeaturesGrid` no tiene `h2` y empieza en `h3`; `TestimonialsSection` pasa de `h2` a `h4`; el pie usa `h4` sin contenedor. | Mecanico pero toca la estructura de cinco componentes; sin test que lo fije se vuelve a romper al primer cambio de maquetado. Iria con un centinela, como el de errores. |
| 3 | **Cuatro imagenes de fondo por CSS** (`backgroundImage` en `ValuePropSection` y `FeaturesGrid`) sin alternativa textual. | Las de `next/image` si tienen `alt`; estas requieren decidir si son decorativas o informativas, y eso es criterio de producto. |
| 4 | **`FeaturesGrid` sigue animando la entrada del panel bajo movimiento reducido**, via `MotionConfig`, que mantiene la opacidad. | Deliberado: un fundido no provoca mareo, y la pauta de la WCAG apunta a transform y parallax. Se anota para que conste que es una eleccion y no un olvido. |
| 5 | **`errorDatosNoEncontrado` no existe**: `not-found` cae en el generico de `mensajeDeError` aunque `mensajeSeguroDeError` si lo distingue. | Ninguna pantalla de las cambiadas llega a ese codigo hoy. Anadir una clave de ARB que nadie usa es deuda, no cobertura. |
