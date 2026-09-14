# INNO-01 — pase temporal de historial por QR (cierre: pantallas, escáner y demo)

**Tarea:** INNO-01 del plan maestro (§7 y §10), última del orden §12 antes de FINAL-01.
**Rama:** trabajo sobre `main` (el plan ya está fusionado ahí).
**Estado previo:** el commit `67c1a3a` dejó el **backend completo** —tres callables, reglas,
TTL, límite de canjes, proyección sin datos económicos y un cliente Dart— y anotó como
pendiente lo que cierra este documento: pantallas, integración del escáner y demo Playwright.

## 1. Por qué esta tarea existía (y por qué no bastaba con el backend)

El plan condiciona INNO-01 a que el mock judge no conceda 20/20 en creatividad. El juez de
`docs/AUDITORIA_CREA_J_2026_FINAL.md` dio **18/20**, y su motivo es literal:

> «La única referencia a `PaseHistorialService` está en su propia declaración
> (`lib/features/dashboard/data/services/pase_historial_service.dart:23`): no hay pantalla de
> emisión/lectura, integración con el escáner ni prueba Playwright. El backend es real; la
> experiencia prometida aún no lo es.»

Ese diagnóstico es el enunciado de esta tanda. **Un callable desplegado que ninguna pantalla
invoca no es una funcionalidad**, y además es el peor de los dos estados posibles: la
superficie de ataque ya está publicada y el valor todavía no existe.

## 2. Qué se implementó

| Pieza | Archivo | Qué hace |
|---|---|---|
| Pantalla de emisión | `lib/features/dashboard/presentation/pages/compartir_historial_screen.dart` | Emite el pase al abrirse, pinta el QR, la cuenta atrás y el código en texto, y permite revocar |
| Pantalla del lector | `lib/features/dashboard/presentation/pages/historial_compartido_screen.dart` | Canjea el pase y pinta el vehículo y sus servicios, distinguiendo lo auto-declarado |
| Decisión del escáner | `pase_historial_service.dart` → `rutaDeEscaneoQr()` | Separa un pase de una placa |
| Integración | `vehicle_search_screen.dart` | El escáner existente bifurca en vez de buscar la placa |
| Rutas | `app_router.dart` | `/compartir_historial/:vehiculoId` (propietario) y `/historial_compartido/:token` (cualquier sesión) |
| Entrada | `service_history_screen.dart` | Acción «Compartir historial» en el historial de servicios |
| Rótulos | `lib/l10n/app_es.arb`, `app_en.arb` | 23 claves nuevas, ES y EN |
| Emuladores | `firebase_emulators.dart`, `e2e/playwright.config.js`, `e2e/scripts/global-setup.js` | Functions cableado y esperado en la suite E2E |
| Fixtures | `e2e/scripts/seed-emulators.js` | Dos servicios sobre el vehículo de A: uno de taller y uno auto-declarado |

## 3. Las cinco decisiones que conviene no deshacer

### 3.1 La distinción de lo auto-declarado es la funcionalidad, no un adorno

`firestore.rules:728-729` autoriza al propietario a registrar servicios sobre su propio
vehículo con el centinela `id_taller == 'Manual (Propietario)'`. Es una regla correcta —nadie
puede prohibir el mantenimiento propio—, pero significa que **un vendedor puede escribirse
diez mantenimientos inventados y enseñar el QR**. El servidor ya mandaba la bandera
`auto_declarado` (la puso el gate de revisión de reglas del commit anterior); el defecto que
quedaba por cometer era pintarlos igual en la pantalla.

Se pintan con **icono, texto y color distintos** —no solo color, que sería invisible para
quien no los distingue— y con un aviso explícito de que AutoDoc no puede verificarlos. El
widget test `historial_compartido_screen_test.dart` lo afirma, y la demo E2E lo vuelve a
afirmar sobre datos reales de los emuladores.

### 3.2 El mapeo de errores de UX-04 **no sirve** aquí, y usarlo habría mentido

`mensajeDeError()` manda `deadline-exceeded` al mensaje de conexión («revisa tu conexión») y
`permission-denied` a «vuelve a iniciar sesión». Para un pase los dos son **falsos**: el
primero significa que el pase caducó y el segundo que el propietario lo revocó. Los dos
dejarían a la persona peleándose con su wifi o con su sesión por algo que solo puede arreglar
el propietario emitiendo otro pase.

`mensajeDePaseHistorial()` traduce los cinco códigos que `historialCompartido.js` elige uno a
uno, y `paseMereceReintento()` **retira el botón de reintentar** donde no puede funcionar
nunca. Los cinco casos tienen su test.

### 3.3 El reloj de la pantalla es inyectable porque si no, ningún test ve el vencimiento

`tester.pump(Duration)` avanza el reloj **falso** del binding; `DateTime.now()` lee el de
verdad. Con la hora real, un pase de dos segundos sigue «vivo» dentro del test para siempre:
una pantalla que se negara a retirar un QR muerto pasaría cualquier suite en verde. La
inyección no es un gancho de conveniencia — es la única forma de probar la mitad de esta
pantalla.

Y el corolario para quien escriba tests aquí: **`pumpAndSettle` no se puede usar** con la
cuenta atrás viva. Un `Timer.periodic` nunca deja de haber trabajo pendiente, así que
`pumpAndSettle` expira a los diez minutos de reloj virtual en vez de fallar por lo que se esté
probando.

### 3.4 La decisión del escáner vive fuera del `onDetect`

`vehicle_search_screen.dart` interpretaba **todo** lo que leyera como una placa. Sin bifurcar,
escanear un pase buscaría el vehículo de placa `autodoc://historial/a3f9...`, no lo
encontraría y diría «vehículo no encontrado»: **el diagnóstico equivocado**, porque parece que
falta el coche y lo que pasa es que el código era otra cosa.

La decisión se extrajo a `rutaDeEscaneoQr()`, una función pura, porque dentro del callback de
`MobileScanner` **no la puede ejercer ningún test**: no hay cámara en una suite de widgets. El
token se escapa con `Uri.encodeComponent` aunque un token legítimo sea 64 hex — lo que entra
ahí es lo que alguien haya impreso en un QR, y una barra sin escapar parte la ruta en dos
segmentos y deja una pantalla desconocida en vez del mensaje «ese código no es un pase».

### 3.5 El token viaja en el path, no en `state.extra`

Es la cicatriz de H-01: recargar `/task_config` reventaba la app porque `state.extra` no
sobrevive a un F5. Un pase que muriera al recargar no serviría para lo único que sirve —
enseñárselo a alguien delante del coche.

Y la ruta del lector **no está en ningún conjunto por rol**, a propósito: quien escanea el QR
puede ser un comprador (propietario de otro coche), un taller o cualquiera. Lo que acota el
riesgo es el token —opaco de 256 bits, caducable, revocable— y no el rol de quien lo canjea.
`test/core/router/pase_historial_rutas_test.dart` fija las dos guardas en las dos direcciones.

## 4. La suite E2E necesitaba el emulador de Functions, y no lo tenía

La configuración de Playwright arrancaba `auth,firestore,storage`. El pase vive **entero** en
tres callables, así que la demo no podía existir sin Functions. Se añadió al arranque y —esto
es lo que importa— **a la espera de `global-setup.js`**: es el emulador más lento de los
cuatro (carga `functions/index.js` con todos sus triggers), y si la suite arrancara sin él, el
primer canje fallaría con `internal` y se leería como un defecto de la pantalla, no como un
emulador que aún no estaba.

También se cableó `FirebaseFunctions.instance.useFunctionsEmulator` en
`firebase_emulators.dart`, bajo los mismos dos candados que el resto. Sin ese cableado la
suite hablaría con las funciones de **producción** desde dentro de una corrida que se cree
aislada.

## 5. Lo que la demo E2E afirma, y por qué cada afirmación

`e2e/tests/pase-historial.spec.js`, cuatro casos:

1. **El propietario emite desde su historial.** Se comprueba que el pase existe **del lado
   servidor** (`tokens_historial` por la API del emulador) con su vehículo, su emisor, su
   caducidad en el futuro y `revocado: false`, **y que el token que el servidor generó es el
   que la pantalla enseña**. Afirmar solo lo que se ve dejaría pasar una pantalla que pinta un
   QR de cualquier cosa — el falso verde exacto que este repo ya se comió en UX-02.
2. **Quien escanea ve el historial y distingue lo auto-declarado.** Lo canjea el **taller**,
   que es el caso realista de quien no tiene relación con el vehículo. Y se afirma que el
   importe **no cruza**: el fixture del taller lleva `costo: 250000` justamente para poder
   comprobar que ese número no aparece en ninguna parte.
3. **Un pase caducado lo dice y no ofrece reintentar**, y no filtra el historial.
4. **El propietario revoca desde la app y el pase deja de servir.** Se emite por la UI, se
   revoca por la UI, se comprueba en Firestore que `revocado` quedó en `true` —que el QR
   desaparezca de la pantalla no prueba que se haya anulado para quien ya lo fotografió— y se
   vuelve a canjear para ver el mensaje de revocado.

Los pases de los casos 2 y 3 se siembran por la API del emulador en vez de emitirse por la UI:
cada arranque de la app en un test cuesta CanvasKit más la persistencia offline de Firestore y
degrada el emulador Java, y encadenar tests por un token que produjo el anterior los vuelve
dependientes del orden.

### 5.1 La app del bundle E2E se renderiza **en inglés**, y eso no estaba anotado en ninguna parte

Chromium arranca con el locale del sistema (`en-US`) y Flutter resuelve `AppLocalizations` con
`navigator.language`: **todo el copy que pasa por el ARB sale en inglés**, aunque el repo se
escriba en español. El primer intento de esta demo afirmaba los rótulos en español y falló
diciendo «no encuentro el botón» con el botón delante; el snapshot de accesibilidad de
Playwright lo enseñaba como `button "Share history"`.

Lo que hace que la trampa no salte a la vista es que **los rótulos que NO pasan por el ARB
siguen en español** — «Garaje», «Talleres», «Fechas» —, así que la pantalla parece española
hasta que se toca una cadena localizada. Los specs anteriores nunca lo notaron porque
apuntaban justo a esos rótulos sin traducir.

De regalo, la demo comprueba la localización inglesa de INNO-01 de punta a punta, que es más
de lo que pedía la Definition of Done.

### 5.2 La demo encontró tres defectos que ninguna suite de widgets podía ver

Esta es la parte que justifica el coste de la demo. Los tres salieron en la primera corrida
contra emuladores, con todos los tests de widget en verde:

1. **`context.push` no mueve la URL, así que el pase no sobrevivía a un F5.** El botón del
   historial navegaba con `push`; en go_router 17 `RouteMatchList.push()` copia la lista de
   pantallas y **conserva el `uri` anterior** (es la «causa B» que
   `test/core/router/url_sigue_a_la_navegacion_test.dart` ya documentó para otras pantallas).
   La barra se quedaba en `/service_history` y recargar devolvía al historial perdiendo el
   pase — exactamente lo que el comentario de mi propia ruta decía estar evitando al meter el
   token en el path. Corregido a `context.go` en las dos entradas (el botón y el escáner), con
   `canPop()` en el botón de volver, que con `go` puede no tener nada que desapilar.
2. **El código en texto se anunciaba como un campo de formulario deshabilitado.** Era un
   `SelectableText`, y Flutter web lo expone como `textbox [disabled]`: un lector de pantalla
   no lo lee como texto, y `getByText` no puede encontrarlo. Sustituido por `Text` más un botón
   de copiar — mejor en los tres ejes: se anuncia bien, se puede probar, y en un móvil pulsar
   un botón bate a seleccionar 64 caracteres a dedo.
3. **Los tokens de fixture no eran hexadecimales.** `'b2caduca'` y `'c3revoca'` se leen como
   hex y no lo son (`u` y `v`). El servidor los rechazaba por la forma **antes de mirar la
   caducidad**, así que el test del pase caducado veía «ese código no es un pase» y parecía que
   la pantalla mapeaba mal los errores. El defecto estaba en el fixture; `tokenDePrueba()`
   ahora se niega a construir una semilla no hexadecimal, con el motivo escrito.

Y un cuarto que era del test, no del producto: esperar **4 segundos fijos** tras pulsar
«Revocar» y leer Firestore acusaba a `revocarPaseHistorial` de no escribir, cuando el callable
seguía en vuelo — el snapshot lo delataba, con el botón aún en `[disabled]`. Ahora se espera a
la condición (el mensaje de revocado) y después se lee el servidor. Es la misma lección que
`propietario.spec.js` ya tenía escrita: esperar a la condición, no al reloj.

**Otro detalle que muerde:** la API del emulador devuelve los documentos ordenados **por su id**,
y el id de un pase es un token hexadecimal aleatorio. Coger el último del array parece lo mismo
que coger el más reciente y da el pase equivocado en cuanto hay más de uno. Se elige por
`creado_en`.

## 6. Gates

| Gate | Resultado |
|---|---|
| `flutter analyze` | `No issues found!`, exit 0 |
| `flutter test` | **1267 / 1267**, exit 0 |
| Functions (Mocha) | **296 passing**, exit 0 |
| Reglas (Jest + emuladores) | **476 / 476** en 29 suites, exit 0 |
| E2E de la app (Playwright, `--workers=1`) | **41 / 41**, exit 0 |
| Puertos al salir | 0 en `LISTENING` |

La E2E de la landing no se relanzó: esta tanda no toca `landing-web/`. Functions y reglas
tampoco cambiaron (el backend del pase entró en `67c1a3a`); se corrieron igualmente para que la
cifra de cierre sea de este árbol y no heredada.

**Tests nuevos de esta tanda:** 9 de `rutaDeEscaneoQr` / `tokenDesdePayloadQr`, 7 de la pantalla
de emisión, 9 de la del lector, 8 de guardas de ruta y 5 responsive (ocho anchos, dos temas y
un paso en inglés), más los 4 casos de la demo E2E.

## 7. Gaps que quedan anotados

La regla del 2026-09-10 sigue en pie: **un gap documentado no está cerrado**, y la anotación
sirve para no perderlo, no como diagnóstico firme. Van ordenados por lo que valen.

1. **Un pase emitido deja de ser revocable en cuanto se sale de la pantalla.**
   `revocarPaseHistorial` existe y funciona, pero la única forma de llegar a él es el botón de
   la pantalla que emitió *ese* pase. Si la persona cierra la app, el pase sigue vivo hasta que
   caduque y **ya no hay ninguna UI que lo anule**. No se puede arreglar solo en el cliente:
   `tokens_historial` está cerrada a todo cliente en las reglas, así que listar «mis pases
   vivos» exige un callable nuevo. Mitigado por los 15 minutos de vigencia, que es corto a
   propósito — pero quince minutos son quince minutos.
2. **`crearPaseHistorial` no tiene límite por usuario y la pantalla emite al abrirse.** Cada
   visita a `/compartir_historial` escribe un documento. Entrar y salir en bucle crea pases sin
   tope; el TTL los purga (caducidad + 48 h) pero nada acota el ritmo. El arreglo limpio es
   reutilizar un pase vivo del mismo vehículo en vez de acuñar otro, o un contador
   transaccional como el de `solicitudes_landing_control` (UX-01).
3. **`MAX_CANJES` es por pase, no por persona.** Veinte canjes en total: si tres personas miran
   el mismo QR y alguna recarga, se agota antes de lo que la cifra sugiere. La alternativa
   —contar por uid— cuesta una escritura por canjeador y no está claro que compense.
4. **La cámara no la ejerce ninguna prueba.** `rutaDeEscaneoQr` está probada como función pura
   y `vehicle_search_screen` la llama, pero que `MobileScanner` entregue el `rawValue` esperado
   no lo comprueba nada automatizado: no hay cámara en una suite. Es el mismo tipo de hueco que
   VER-01 documentó para el picker, y la mitigación es la misma — que la decisión viva fuera
   del callback.
5. **Quien escanea no ve cuánto le queda al pase.** El servidor devuelve `expira_en` en el
   canje y la pantalla del lector lo ignora. No rompe nada (el servidor vuelve a comprobar),
   pero deja a quien mira sin saber si le da tiempo a repasar el historial.
6. **La política TTL de `tokens_historial` sigue siendo un paso de runbook.** Ya está en
   `docs/RUNBOOK.md` desde el commit del backend; no se puede configurar desde
   `firestore.indexes.json` y ninguna suite puede ver si se creó.
