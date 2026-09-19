# AutoDoc — Guía para Claude Code

## ⚠️ Trabajo actual — plan de remediación CREA J 2026

El trabajo se dirige desde `docs/superpowers/plans/2026-09-06-remediation-master-plan-crea-j-10-10.md`
(baseline 64/100 → objetivo 10/10). Su **§12 fija el orden**, y la Definition of Done del final
manda sobre cualquier atajo. Para orquestarlo, usa la skill `ejecutar-plan-remediacion`.

Evidencia base: `docs/AUDITORIA_CREA_J_2026_CODEX.md` y `docs/AUDITORIA_CREA_J_2026_CLAUDE.md`
(dos auditorías independientes, ambas 64/100 por rutas distintas). **No repitas la auditoría
antes de implementar**; el plan lo prohíbe.

**Estado a 2026-09-13 — 18 tareas cerradas y verificadas:** SEC-01, SEC-02, SEC-03, DATA-01,
VER-01, ROLE-01, QA-02, QA-01, UX-01, UX-02, FUNC-01, FUNC-02, UX-03 / UX-04,
**SEC-04 / OPS-01**, **H-01** e **INNO-01**.
**Solo queda FINAL-01** (la evaluación simulada final). Las tandas de drenaje de gaps están
cerradas: `fix/gaps-02` (residuales de FUNC-02), `fix/gaps-03` (accesibilidad de la landing que
dejó UX-03) y **`fix/gaps-04`** (lo que quedaba abierto antes de H-01, cerrada el 2026-09-13).

### Observaciones de uso real del 2026-09-18 (rama `fix/observaciones-2026-09-18`)

Segunda ronda del PDF de chele moskar / chele alonzo + el Inge. Las páginas 1–2 eran el
backlog ya cerrado el 2026-09-04/05 (plan `2026-09-04-observaciones-colaboradores.md`); lo
nuevo eran las capturas 3–6 y los puntos que ese plan dejó fuera. Lo que hay que saber:

- **La cotización del chat nacía sin coche** (capturas 4–5): "Cotizar y Aceptar" tomaba
  `id_vehiculo` de la CONVERSACIÓN, vacía cuando el chat se abrió desde el directorio. El
  coche sale ahora de la cita; `onCotizacionAceptada` lo recupera de `id_reserva` si falta
  (misma pareja propietario/taller) y lo escribe de vuelta. **Paso de despliegue:**
  `firebase deploy --only functions:onCotizacionAceptada --project production`, y después
  `node backfill_tickets_cotizaciones_aceptadas.js` (dry-run, luego `--apply`) para abrir los
  tickets de las cotizaciones ya atascadas. **Hecho el 2026-09-18:** la función ya está
  desplegada en producción, y una simulación fiel (la misma `abrirTicketDeReparacion` con las
  escrituras interceptadas) dio **0 tickets recuperables** de 26: 19 sin coche ni cita, 10 con
  el coche ya borrado —5 de ellas con la cita borrada también, incluida la de la captura— y 1
  que ya tenía ticket abierto. **El dry-run del script engaña:** solo mira si existe
  `cot_<id>` y dice "abriría" de todo lo demás. No se corrió `--apply`: no habría abierto nada
  y solo habría reescrito el aviso rojo en cotizaciones viejas.
- **Una sola pantalla de cotización** (`NuevaCotizacionScreen`, captura 6) para chat, cita y
  Buscar Vehículo: dos columnas, catálogo, mano de obra y día/hora. `CotizacionModel.total`
  incluye `mano_de_obra`. La cita guarda `vehiculo_resumen` porque el taller no puede leer
  `vehiculos/{id}` hasta recibir el coche.
- **Buscar Vehículo cotiza si hay cita vigente** del propietario con el taller; sin cita, solo
  la ficha pública. Recibir sigue exigiendo la cotización ACEPTADA.
- **Checks automáticos:** `ChatProvider.abrirConversacion` marca vistos los mensajes que llegan
  con el chat abierto (pausado en segundo plano). **Aviso en pantalla** de mensajes nuevos
  (`AvisoMensajesNuevos`, en el `builder` de `MaterialApp.router`: está sobre el `Navigator`,
  sin `Overlay` — nada de `Tooltip` ahí) e insignia de no leídos en la navegación.
- **Tres puntos, responder y reenviar** en cada mensaje (`respuesta_a`, `reenviado`; el
  adapter de Hive se tocó a mano: campos 11 y 12). **Logo del taller** como avatar.
- Sin cambios en `firestore.rules`, `storage.rules` ni índices.

### La tanda GAPS-07 esta cerrada (2026-09-15, `fix/gaps-07a`) — el doble envio

Cierra el gap 1 del §4 de GAPS-06: **los 15 grupos de doble envio, los 15**. Evidencia en
`docs/evidencia/GAPS-07-doble-envio.md`. Lo que hay que saber sin leerla:

- **Los dos mecanismos no son alternativas.** `onPressed: null` (y `AppButton(isLoading: true)`)
  **solo surte efecto en el frame siguiente**, asi que dos taps en el MISMO frame pasan los dos.
  En tres grupos lo que atrapo el segundo tap fue el guard de reentrada, no la deshabilitacion.
  Todo control lleva las dos capas.
- **El defecto casi nunca es "dos taps en el mismo boton".** En OCHO de los quince el envio esta
  detras de un dialogo de confirmacion o de pickers, y el dialogo **se cierra al confirmar**: el
  segundo envio viene de **reabrirlo**. Los tests afirman que el dialogo NO se reabre, que es mas
  fuerte que un contador en uno. El caso extremo es la cita nueva del chat, con cuatro pasos.
- **Anadir una bandera destapo tres cosas construidas dentro de `build`,** y esto es lo mas
  transferible: un `setState` recrea lo que se construye en `build`. El stream de fotos de la
  galeria, el stream de resenias del panel de mecanico (que **ya volvia la lista a `waiting` al
  cambiar el orden**, antes de esta tanda) y el `Future` del resumen de gastos del perfil de
  vehiculo. **Un arreglo de doble envio que no mire eso cambia un defecto por otro peor.**
- **Un veredicto del anexo era falso:** "aceptar invitacion" de la fila 10 NO es vulnerable — el
  boton hace `Navigator.pop` inmediato y el segundo tap no se lleva la ruta de debajo. El test
  escrito para demostrarlo pasa sin arreglo alguno. Sexta ronda seguida.
- **`AppButton(isLoading: true)` envenena `pumpAndSettle`:** su spinner no deja de animar nunca.
  Donde hace falta, se usa el efecto secundario — que el rotulo desaparezca ES la prueba.
- **Una reversion que falla en silencio miente igual que un verde por el motivo equivocado.** Al
  comprobar el rojo-antes de un guard la reversion no se aplico (el formateo habia cambiado el
  texto buscado) y el test paso. **Verifica que el rojo-antes revirtio algo de verdad.**
- **Codex se quedo sin cuota a mitad y los tres workers murieron sin escribir su informe.** Lo que
  dejaron: 11 ficheros de test que compilaban y reproducian el defecto (17 casos en
  `Expected 1 / Actual 2`) y **cero implementacion util**. El reconocimiento rinde delegado; la
  implementacion con TDD no, si la cuota puede cortarse.

**Cifras:** `flutter analyze` limpio, `flutter test` **1301/1301** (base 1278). Functions y reglas
no se relanzaron: cero cambios en `functions/`, `firestore.rules` y `storage.rules`.

**Tres gaps nuevos** en el §5 de esa evidencia. El de mas peso y probablemente un defecto de
PRODUCCION: **el dialogo de respuesta a una resenia desborda ~99 000 px** porque `AlertDialog`
envuelve su contenido en `IntrinsicWidth` y el `SizedBox(width: double.maxFinite)` de
`AppDialogContent` vuelve absurdo el ancho intrinseco. Es el unico control de los 16 sin test.
**Y los literales sin traducir siguen sin empezar**: el worker que tenia que remedir los 274
murio con la cuota y no dejo nada.

### La tanda GAPS-06 esta cerrada (2026-09-14, `fix/gaps-05`) — segundo drenaje

Drena los 15 gaps que GAPS-05 dejo abiertos. **Cerrados 5** (1, 3, 5, 6 y la mitad
accionable del 4); **2 se quedaron fuera por agotarse la cuota de Codex** (7 y 8), con su
reconocimiento hecho y guardado en `docs/evidencia/anexos/`. Evidencia en
`docs/evidencia/GAPS-06-drenaje.md`. Lo que hay que saber sin leerla:

- **El gate tumbo mi propio arreglo, y esta vez el defecto lo meti yo.** GAPS-05 anoto que
  las 499 invocaciones que pierden la carrera de `aggregateRatings` «descartan su delta».
  Es al reves: un trigger de Firestore se dispara **despues** del commit, asi que cuando el
  ganador recuenta, la escritura del perdedor **ya esta en la coleccion**. Sumarla encima la
  cuenta dos veces —dos resenias de 5 y 3 daban **3 resenias y 11 estrellas**— y no se
  autocura, porque con `suma_estrellas` definido nadie vuelve a recontar. Lo que si era real
  y **no estaba anotado**: la siembra no era transaccional.
- **`/alertas` NO TIENE CREADOR EN NINGUNA PARTE.** Ni `lib/` ni `functions/`;
  `AlertModel.toMap()` no tiene un solo llamador. Las alertas que ve el usuario son
  **sinteticas, calculadas en el cliente y nunca persistidas** (de ahi los prefijos `soat_`,
  `task_`). Lo que el barrido lee en produccion es **dato heredado**. No invalida el
  arreglo, pero lo reencuadra: no es una cola que crece, es una que no se vacia.
- **Un marcador de posicion que se vuelve real deja tests verdes por el motivo
  equivocado.** `alertas_allowlist.test.js` usaba `avisos_pendientes` para modelar «un campo
  de servidor que todavia no existe». Al existir, tres tests seguian VERDES pero por otra
  regla en vez de por el `hasOnly` que dicen cubrir.
- **De los «cuatro streams sin cota» del panel del mecanico, son TRES** —el de servicios
  recientes ya llevaba `limit(5)`— y solo la grafica de tendencia se puede acotar sin
  cambiar lo que significa. Dibujaba seis meses descargando la historia entera del taller y
  tirando el resto **en memoria**, asi que el test no puede afirmar sobre la grafica: sale
  igual con cota y sin ella. Afirma sobre los documentos que cruzan el cable.
- **El backfill del gap 1 se ensayo gratis:** al anadir el filtro, **once tests del barrido
  se pusieron rojos de golpe**. Es lo que le pasaria a produccion sin correrlo — la consulta
  daria cero documentos y **todas las alertas dejarian de avisar**, sin error ni log.
  **`node backfill_avisos_pendientes.js --apply` es paso de runbook BLOQUEANTE**, despues de
  `backfill_ultimo_aviso.js`. No hace falta desplegar indices: son dos igualdades.
- **Una alerta heredada no se podia completar**, y lo levanto el gate. El guard
  `fecha_limite is timestamp` mira el documento RESULTANTE, asi que un
  `update({estado:'Completada'})` sobre una alerta con `fecha_limite` en cadena moria con
  `permission-denied`: su dueno no podia cerrarla, solo borrarla, mientras el barrido le
  seguia mandando cada escalon.

**Cifras:** `flutter analyze` limpio, `flutter test` **1278/1278**, Functions **389**,
reglas **511/511** en 31 suites.

**Quedan 11 gaps abiertos**, en el §4 de esa evidencia. Los dos de mas valor y mas baratos
son los que la cuota dejo fuera, y **su reconocimiento ya esta pagado**: los quince grupos
de doble envio (el gap decia cinco) y los literales sin traducir (el gap decia 64 en 24
ficheros; el barrido da **274 en 58**, y medir bien esa diferencia ES el primer trabajo).

### La tanda GAPS-05 está cerrada (2026-09-14, `fix/gaps-05`) — drenaje previo a FINAL-01

Drena los gaps abiertos de **cuatro** fuentes a la vez (INNO-01 §7, H-01 §6, GAPS-04 §7 y los
hallazgos del §4 de la auditoría final). Deduplicados son **~25 reales**, no 31: varios estaban
contados dos veces. **Cerrados 14.** Evidencia en `docs/evidencia/GAPS-05-drenaje.md`. Lo que hay
que saber sin leerla:

- **Los dos P1 de la auditoría estaban mal descritos, y comprobarlo ERA el trabajo.** Cuarta ronda
  seguida. El de `reservas.id_taller` era cierto, pero la anotación no decía lo que decide cómo
  arreglarlo: el único creador escribe **siempre** el mismo valor que `id_mecanico` — el
  `idTallerEfectivo` es de las **cotizaciones**, otra colección—, así que atarlo a
  `id_taller_efectivo` (la lectura natural del enunciado) habría roto el flujo entero. Y el de
  facturas describe el significado que `talleres_vinculados` tenía **antes de la ronda 5**: hoy el
  vínculo **es** posesión del coche, o sea ya es el «trabajo vigente» que el cargo pedía.
- **Pero al lado había un agujero real:** `allow write` cubre create, update **y** delete, así que
  el bloque denegaba borrar una factura y a la vez dejaba **sobrescribirla** a cualquiera con
  vínculo — que es borrarla con pasos extra.
- **La condición que separa «subir» de «reemplazar» NO es el verbo.** Storage clasifica una
  resubida como `create`, no como `update`; medido: con `allow create` a secas los dos casos de
  sobrescritura seguían pasando. El guard es `resource == null`. Esto contradice la documentación
  de Firebase, así que la regla está escrita para ser correcta bajo las dos semánticas.
- **`env.clearStorage()` NO limpia nada, y en silencio** (el endpoint REST del emulador responde
  501). Nadie podía verlo porque todas las reglas de Storage permitían sobrescribir: subir encima
  de lo que dejó el test anterior daba el mismo verde. Apareció al mirar `resource == null`, y
  destapó que **tres tests llevaban tiempo siendo dependientes del orden**. Usa `limpiarStorage()`
  de `test_rules/helpers.js`.
- **El gate de revisión encontró un defecto de cliente que nadie había visto: la confirmación de
  citas estaba invertida.** `ReservaModel` resuelve `idProponente ?? idPropietario` y
  `chat_screen.dart` no lo pasaba, así que una cita propuesta por el **mecánico** nacía con el uid
  del propietario. Como confirmar exige `uid != id_proponente`, **el propietario no podía
  confirmar la cita que le proponían y el mecánico sí podía confirmar la suya.**
- **Reutilizar el pase de historial vivo cierra dos gaps de INNO-01 con un solo cambio:** no nace
  un documento por visita a la pantalla (ritmo) y volver a ella vuelve a poner el botón de revocar
  delante (antes, salir dejaba el pase vivo y sin ninguna vía para anularlo).
- **El barrido de literales sin traducir dio 76 en 28 ficheros**, repartidos por toda la app y no
  solo en admin. Se localizaron 12; quedan 64 medidos. No es teórico: la app **se renderiza en
  inglés** cuando el navegador lo está.

**Quedan 15 gaps abiertos**, en el §5 de esa evidencia. Los de más peso son los mismos que GAPS-04
ya dimensionó como tanda propia: la denormalización de `avisos_pendientes`, el N+1 de los
barridos, los siete triggers sin test y los cuatro streams sin cota del panel del mecánico —este
último **deliberadamente no tocado**, porque los dos KPI de por vida no se pueden acotar sin
cambiar lo que significan y el ahorro de compartir stream **no se puede medir** (`FakeFirebaseFirestore`
no cuenta lecturas).

### INNO-01 está cerrada (2026-09-13) — el pase de historial ya es un flujo, no solo un backend

El commit `67c1a3a` dejó los tres callables, las reglas y el cliente Dart; el juez de
`docs/AUDITORIA_CREA_J_2026_FINAL.md` dio **18/20** en creatividad con una razón literal: «no
hay pantalla de emisión/lectura, integración con el escáner ni prueba Playwright». Esta tanda
cierra eso. Evidencia en `docs/evidencia/INNO-01-pase-de-historial.md`. Lo que hay que saber
sin leerla:

- **La demo E2E encontró tres defectos que ninguna suite de widgets podía ver.** El peor:
  **`context.push` no mueve la URL** en go_router 17 (`RouteMatchList.push()` conserva el `uri`
  anterior — la «causa B» que `url_sigue_a_la_navegacion_test.dart` ya tenía documentada), así
  que el pase no sobrevivía a un F5. Los otros dos: un `SelectableText` que Flutter web expone
  como `textbox [disabled]` —o sea, un lector de pantalla lo anuncia como campo de formulario
  deshabilitado en vez de como texto— y unos tokens de fixture que **no eran hexadecimales**
  (`'b2caduca'`, `'c3revoca'`: `u` y `v`), con lo que el servidor los rechazaba por la forma
  antes de mirar la caducidad y parecía que la pantalla mapeaba mal los errores.
- **LA APP DEL BUNDLE E2E SE RENDERIZA EN INGLÉS, y no estaba anotado en ninguna parte.**
  Chromium arranca con el locale del sistema y Flutter resuelve `AppLocalizations` con
  `navigator.language`. Lo que esconde la trampa es que los rótulos que NO pasan por el ARB
  —«Garaje», «Talleres», «Fechas»— siguen en español, y son justo los que usan los specs
  viejos. Síntoma: «no encuentro el botón» con el botón delante. El `error-context.md` de
  Playwright trae el snapshot de accesibilidad y ahí se lee el rótulo real.
- **La suite E2E arranca ahora también el emulador de Functions** (`auth,firestore,storage,
  functions`) y `global-setup.js` espera a su puerto: es el más lento de los cuatro, y sin esa
  espera el primer canje fallaría con `internal` y se leería como un defecto de la pantalla.
  `firebase_emulators.dart` cablea `useFunctionsEmulator` bajo los mismos dos candados.
- **El mapeo de errores de UX-04 NO sirve para el pase, y usarlo habría mentido:**
  `mensajeDeError` manda `deadline-exceeded` a «revisa tu conexión» y `permission-denied` a
  «vuelve a iniciar sesión», cuando significan *caducó* y *el propietario lo revocó*. Hay un
  mapeo propio (`mensajeDePaseHistorial`) y `paseMereceReintento`, que **retira el botón de
  reintentar** donde no puede funcionar nunca.
- **El reloj de la pantalla de emisión es inyectable porque si no, ningún test ve el
  vencimiento:** `tester.pump(Duration)` avanza el reloj FALSO del binding y `DateTime.now()`
  lee el de verdad, así que una pantalla que se negara a retirar un QR muerto pasaría cualquier
  suite. Y con la cuenta atrás viva **`pumpAndSettle` no se puede usar**: un `Timer.periodic`
  nunca deja de haber trabajo pendiente.
- **La distinción de lo auto-declarado es la funcionalidad.** `firestore.rules:728-729` deja al
  propietario registrar servicios con `id_taller == 'Manual (Propietario)'`, así que un vendedor
  puede escribirse el historial entero. Se pinta con icono, texto y color distintos —no solo
  color— y con un aviso de que AutoDoc no los verifica.

**Cifras al día del árbol (2026-09-13, con INNO-01):** `flutter analyze` limpio, `flutter test`
**1267 / 1267**, Functions **296**, reglas **476 / 476** en 29 suites, E2E de la app **41 / 41**
en serie y cero `fixme`, puertos libres al salir. La E2E de la landing sigue en **42 / 42**; no
se relanzó porque esta tanda no toca `landing-web/`.

**Quedan seis gaps anotados** en el §7 de esa evidencia. El de más peso: **un pase deja de ser
revocable en cuanto se sale de la pantalla** — `revocarPaseHistorial` funciona, pero la única
vía para llegar a él es el botón de la pantalla que emitió *ese* pase, y listar «mis pases
vivos» exige un callable nuevo porque `tokens_historial` está cerrada a todo cliente. Le sigue
que `crearPaseHistorial` no tiene límite por usuario y la pantalla emite al abrirse.

### Incidente de despliegue del 2026-09-13 — el bundle de E2E llego a produccion

Se desplego a hosting el artefacto de `e2e/scripts/build-web.js`. Es **el mismo defecto que
`firebase_emulators.dart` documenta como imposible**, llegando por el lado que sus candados no
cubren:

- Los dos candados son `_flagEmuladores && !kReleaseMode`. El build de E2E es **`--profile`**,
  donde `kReleaseMode` es `false`, asi que **los dos se abren**. La app publicada llamo a
  `useAuthEmulator()` y el SDK pinto «Running in emulator mode. Do not use with production
  credentials» a todo visitante, con Auth/Firestore/Storage apuntando al `localhost` **del
  visitante**.
- **No hubo fuga de datos** — no se puede leer produccion desde ahi, las claves del shim son
  falsas y el shim ni se ejecuta (se autodesactiva por hostname). Fue una **caida total de
  disponibilidad** de la web, no una brecha.
- **Ninguna suite podia verlo, y esa es la leccion.** `analyze`, `flutter test`, reglas y las dos
  suites de Playwright miran el **codigo fuente**, y el codigo fuente estaba bien. El defecto
  vivia en el **artefacto** (`build/web`, no versionado) y en que `firebase deploy --only hosting`
  publica ese directorio **sin mirarlo**. Un artefacto contaminado era indistinguible de uno
  limpio para todas las puertas que el repo tenia.
- **Cerrado con una guarda `predeploy`** en `firebase.json` (objetivo `app`):
  `scripts/verificar_bundle_web.js`. Comprueba la condicion peligrosa y no un sintoma — que
  `main.dart.js` **no** contenga el rastro de `firebase_emulators.dart`, que en un build
  `--release` desaparece entero por tree-shaking. Verificada en los dos sentidos: aborta sobre el
  bundle que se desplego y pasa sobre uno limpio.
- **Centinela nuevo** `test/despliegue_web_protegido_test.dart`: rompe si alguien quita el
  `predeploy` o lo apunta a otro sitio.
- **`flutter clean` no es opcional** antes de un build de produccion: sin el, el `index.html`
  inyectado por el pipeline de E2E sobrevive al siguiente build.

**Y un detalle de configuracion que muerde:** `.firebaserc` tiene `"default": "autodoc-staging"`,
asi que **todo `firebase deploy` sin `--project` va a staging**. Usa siempre `--project production`
(alias de `autodoc-6ef5a`) o `--project staging`, nunca el implicito.

**Pendiente 0 del runbook, resuelto el 2026-09-13:** `functions/contar_talleres_sin_estado.js`
(nuevo) conto **cero** usuarios con rol `Mecanico`/`Taller` sin `estado` valido, asi que las
reglas de H-01 no dejan a nadie fuera. El script no tiene `--apply` a proposito, y **`src/aprobarTodosTalleres.js` y `src/backfillEstadoMecanicos.js` NO son la respuesta**: escriben
`estado: 'aprobado'` a todos y anularian justo el agujero que H-01 cierra.

### H-01 está cerrada (2026-09-13, `hardening/h-01`)

Hardening, QA destructivo, matriz de evidencia y **segunda auditoría adversarial desde cero**.
Evidencia en `docs/evidencia/H-01-hardening.md` y `docs/AUDITORIA_CREA_J_2026_v2.md`.
**Veredicto del juez independiente: 85/100, sin P0.** Lo que hay que saber sin leerlas:

- **⚠️ RUNBOOK, Pendiente 0, BLOQUEANTE antes de desplegar reglas.** Las reglas nuevas resuelven
  el estado del taller con `.get('estado','pendiente')`, así que **un taller de producción sin
  ese campo pierde de golpe las facturas y la galería**. Hay que contarlos antes de desplegar, y
  **no** hacer un backfill ciego a `'aprobado'`: eso convertiría el arreglo en su contrario.
  Ninguna suite puede avisar — todas siembran `estado`.
- **El registro por UI ya no está en `fixme`**, y su razón documentada era falsa a medias: los
  rótulos seguían vivos en el ARB; lo que cambió fue el final del recorrido. La otra mitad sí era
  cierta y tiene arreglo: **en Flutter web `fill()` no sirve y `keyboard.type` sí** — el primero
  escribe en el `<input>` del proxy y Flutter lo descarta al cambiar de foco.
- **El `errorText` de un campo NO es un nodo del árbol de semántica en Flutter web**: viaja
  pegado al `aria-label` del `<input>`. `getByText` no puede verlo nunca. Afirmarlo ahí prueba
  además que el error se anuncia a un lector de pantalla.
- **Dos auditores independientes encontraron conjuntos DISTINTOS.** El agujero de Storage lo vio
  solo el abogado del diablo; el juez, que puntuó Seguridad 16/20, no lo detectó. Y **uno de los
  cinco cargos era falso**, con cita de `ruta:línea` igual que los verdaderos: la cita hace el
  cargo comprobable, no cierto.
- **El gate de revisión tumbó mi propio arreglo.** Atar la cita a su conversación no cerraba
  nada: el `create` de `/conversaciones` dejaba fabricarse esa conversación nombrando de mecánico
  a la víctima. La rama del mecánico se cerró en la Ronda 3; la del propietario seguía abierta
  desde entonces.
- **Recargar la página en `/task_config` o `/task_complete` reventaba la app** — `state.extra` no
  sobrevive a un refresh y el cast era incondicional. No hace falta teclear la URL: basta F5.
- **Refutar un cargo dio un defecto que nadie pidió**: el chat no duplica mensajes, pero el envío
  es fire-and-forget y el texto ya se borró, así que si falla la persona lo pierde sin ver error.
- **Centinela nuevo** `test/core/providers/salidas_de_sesion_test.dart`: obliga a que toda
  pantalla que cierre sesión limpie los providers, con un mapa de exenciones razonadas y un
  segundo test que rompe si una exención se queda huérfana.

**Cifras:** `flutter analyze` limpio, `flutter test` **1227/1227**, Functions **276**, reglas
**465/465** en 28 suites, E2E de la app **37/37 en serie y cero `fixme`**, E2E de la landing
**42/42**, puertos libres al salir.

**Quedan diez gaps anotados** en el §6 de la evidencia de H-01, más los quince de GAPS-04. Los de
más peso: App Check en `monitor` por defecto (deliberado, es paso de runbook), seis formularios
sin defensa contra doble envío —solo uno verificado a mano— y las lecturas sin cota del panel del
mecánico y del barrido de alertas.

### La tanda GAPS-04 está cerrada (2026-09-13, `fix/gaps-04`, fusionada)

Drenaje de los gaps que quedaban abiertos antes de H-01. Evidencia en
`docs/evidencia/GAPS-04-drenaje.md`. Lo que hay que saber sin leerla:

- **Remitir un gap a una tarea futura NO lo cierra.** Dos gaps se habían «remitido a
  OPS-01», OPS-01 cerró sin recogerlos y ahí se quedaron. Son justo los dos de más valor de
  la tanda. Si mandas un gap a una tarea, esa tarea tiene que recogerlo explícitamente en su
  evidencia o volver a quedar anotado.
- **Otra vez dos descripciones de gap estaban mal, y la peor tranquilizaba.** El gap 9.6
  decía que nadie recogía `vinculo_revocacion_pendiente`; en realidad el barrido sí la
  recoge, pero **a los 30 días** — o sea que un fallo de revocación regalaba un mes de
  acceso a la ficha de un coche ya devuelto. Ya van tres rondas seguidas: **la anotación
  sirve para no perder el gap, no como diagnóstico.**
- **`/alertas` pasa de denylist a allowlist.** Una denylist cubre los campos de servidor que
  existían el día que se escribió y deja nacer escribible cualquiera posterior — por ahí
  llegó el hallazgo de SEC-04. Hay un centinela nuevo, `test/alertas_campos_test.dart`, que
  cruza `camposDeAlerta()` de las reglas con `AlertModel.toMap()` **en las dos direcciones**:
  sin él, un campo nuevo del modelo se denegaría **solo en producción**, porque los
  emuladores obedecen la regla igual de bien que Firestore.
- **Trigger nuevo `borrarFotosAlEliminarResenia`.** Al eliminar una reseña sus fotos se
  quedaban en Storage. Son **dos** caminos y el segundo no estaba anotado: el borrado de
  cuenta barre reseñas en lotes de 500 sin pasar por la app.
- **Retirado `streamReservasUsuario` y toda su rama** (cero consumidores en `lib/`,
  sostenida por tres tests — el patrón de FUNC-02). **Y el centinela de índices paró un
  defecto real**: con sus dos índices se iba también un tercero de `reservas` que usa el
  recordatorio de citas, que es del **servidor**. Vaciar `lib/` de consultas a una colección
  no significa que la colección se quede sin consultas.
- **Los dos revisores encontraron siete defectos que las suites propias no veían**, y el peor
  era mío repitiendo el gap 9.1: **en un `whereIn` el `limit` se aplica por subconsulta**, así
  que un `limit(50)` con 30 vehículos lee hasta 1500 documentos. Es la tercera tanda seguida
  en que los gates pagan su coste.
- **Runbook nuevo:** `firebase deploy --only firestore:indexes` antes que la app — crea uno
  (`servicios (id_vehiculo, id_taller, fecha DESC)`) y retira dos de `reservas`.

**Cifras al día:** `flutter analyze` limpio, `flutter test` **1221 / 1221**, Functions
**276**, reglas **454 / 454** en 26 suites, puertos libres al salir.

**Quedan quince gaps anotados** en el §7 de esa evidencia, con su razón. Los de más peso: la
denormalización de `avisos_pendientes` (el barrido de alertas relee cada día todo lo ya
avisado), el N+1 de los barridos, los siete triggers de notificación sin test, y el panel del
mecánico con cuatro streams sin tope.

### SEC-04 / OPS-01 — enforcement de App Check y tareas programadas

Rama `fix/sec04-ops01`. Evidencia en
`docs/evidencia/SEC-04-OPS-01-enforcement-y-tareas-programadas.md`. Lo que hay que saber
sin leerla:

- **App Check estaba a medias, y faltaba la mitad que protege.** El cliente firma desde
  `lib/main.dart:183` y **ningún servidor comprobaba la firma**. Y la trampa: este repo usa
  Cloud Functions **v1**, donde el enforcement **no tiene interruptor de consola**. Activar
  App Check en la consola habría mostrado el producto «protegido» mientras los doce
  callables aceptaban cualquier llamada. Ahora los 12 llaman a `exigirAppCheck`, con un
  centinela que corta el entrypoint por bloques `exports.` — **no cuenta ocurrencias**,
  porque contar `onCall` y contar `exigirAppCheck` daría el mismo número aunque uno llevara
  dos y otro ninguna.
- **El modo por defecto es `monitor`, no `enforce`, y es deliberado.** Con `enforce` la
  suite E2E entera dejaría de pasar: el emulador de Functions no emite tokens. Encenderlo
  es un paso de runbook, y un valor no reconocido cae a `monitor` (caer a `off` sería
  inseguro en silencio; caer a `enforce` por una errata tiraría la app entera).
- **El barrido de alertas mandaba el mismo push cada día, para siempre.** Nada marcaba la
  alerta como avisada y `estado` solo lo cambia el usuario a mano. Ahora hay dos escalones
  y dos notificaciones en toda la vida de una alerta. `ultimo_aviso` queda cerrado al
  cliente en las reglas, por `affectedKeys()` y **también en el `create`** — sin eso se
  podía nacer la alerta ya silenciada, y de forma irreversible.
- **El recordatorio de citas leía todas las reservas confirmadas de la historia, cada día**,
  y calculaba «mañana» en UTC: Colombia es UTC-5, así que las citas de tarde salían
  descolocadas. Ahora la cota va en el servidor, con índice `reservas (estado,
  fecha_hora_propuesta)`.
- **El respaldo no fallaba sin `projectId`: exportaba a `gs://undefined-backups`.** Es la
  única copia de seguridad del proyecto y podía llevar meses sin hacerse.
- **Los dos revisores encontraron tres defectos que los tests propios no veían**, y uno
  grave: el `update` de contabilidad estaba fuera del `try`, así que **borrar una alerta a
  media pasada abortaba el barrido del día entero** — denegación de servicio con una
  operación que las reglas autorizan. También que `startAfter` era un no-op en los dos
  dobles, por lo que la paginación no la ejercía ningún test.
- **Cuatro pasos de runbook nuevos** en `docs/RUNBOOK.md`: desplegar índices y correr
  `node backfill_ultimo_aviso.js --apply` **antes** que las funciones (sin el backfill, la
  primera corrida notifica de golpe todo el histórico); cómo llega `APP_CHECK_ENFORCEMENT`
  a las funciones desplegadas (archivos `.env` por proyecto, no un ajuste de consola); y
  los prerrequisitos del respaldo (bucket, rol IAM y política de ciclo de vida).

### Los gaps de accesibilidad de UX-03 están cerrados (`fix/gaps-03`)

Evidencia en `docs/evidencia/GAPS-03-accesibilidad-de-la-landing.md`. Dos cosas que valen:

- **Las cifras de contraste heredadas eran aproximadas.** Venían de los hex de Tailwind 3 y
  la landing usa Tailwind **4**, que computa en OKLCH: medido de verdad, `amber-600` seguía
  fallando (3.058:1) y hubo que subir a `amber-700`.
- **La anotación no decía el tema, y no todos fallaban en el mismo.** El pie fallaba en
  oscuro y pasaba en claro; la calificación, al revés. Arreglar «el contraste del pie» sin
  medir habría tocado el lado que ya cumplía.
- Las cuatro imágenes de fondo por CSS **son decorativas** y por tanto no necesitan
  alternativa textual: quedan con un comentario para que la próxima auditoría no las
  levante otra vez.

**La E2E de la app en paralelo no es reproducible, y su rojo no es senal.** El emulador Java
de Firestore no da abasto cuando cuatro workers arrancan la app a la vez, y lo que se pierde
es la primera lectura del perfil: el router ve `userData == null` y manda a `/profile_setup`.
UX-03/04 anoto que la corrida siguiente salia 32/32; en SEC-04/OPS-01 **no se curo sola** —dos
corridas paralelas seguidas fallaron, la segunda peor que la primera— y solo
`npm test -- --workers=1` la saca entera en verde. **Toma el numero de gate de esta suite en
serie**; en paralelo cada rojo cuesta una investigacion.

**Cifras al día del árbol combinado:** `flutter analyze` limpio, `flutter test`
**1216/1216**, Functions **263**, reglas **446/446** en 25 suites, E2E de la landing
**42/42**.

UX-03 / UX-04 ya estan cerradas y fusionadas (`fix/ux03-ux04`). Evidencia en
`docs/evidencia/UX-03-UX-04-accesibilidad-y-errores.md`. Lo que hay que saber sin leerla:

- **No habia un menu movil inaccesible: no habia menu.** La navegacion de la landing es
  `hidden md:flex`, asi que por debajo de 768 px los tres enlaces de seccion desaparecian, y
  «Iniciar Sesion» (`hidden sm:block`) tambien: a 320 px solo quedaba «Probar Gratis».
- **Quitar las animaciones bajo `prefers-reduced-motion` deja la landing PEOR que antes.** Es
  un export estatico: framer-motion hornea el valor de `initial` como estilo inline en el HTML
  y en el servidor `useReducedMotion()` no sabe nada. Sin nadie que anime esos estilos, el
  elemento se queda congelado donde lo dejo el servidor — **invisible para siempre**. Medido:
  con `{}` y tambien con solo `{initial: false}`, el titulo de talleres seguia en `opacity: 0`
  a los 2,5 s. Hace falta un destino explicito (`animate: REPOSO`) que PISE el estilo inline.
- **`test.use({ reducedMotion })` NO surte efecto en Playwright 1.62.1.** `matchMedia(...)`
  dentro de la pagina seguia dando `false` y los casos fallaban con el arreglo ya puesto. Usa
  `page.emulateMedia()`, y antes del `goto`.
- **El `Error: ${snapshot.error}` del enunciado era uno de cuarenta, y el patron estaba una
  capa mas abajo:** quince providers guardaban `_error = e.toString()` (77 sitios) y las
  pantallas pintan ese campo tal cual. Consecuencia que nadie habia visto: donde la pantalla
  hace `provider.error ?? context.l10n.loQueSea`, **la cadena traducida no se veia nunca** —
  el error crudo no es null cuando algo falla. Habia ARB traducido al ingles inalcanzable.
- **Ocho tests existentes se pusieron rojos y los ocho probaban de mentira.** Lanzaban una
  CADENA suelta (`thenThrow('email-already-in-use')`) y afirmaban que `provider.error` la
  contenia: con `_error = e.toString()` eso pasaba por construccion, sin ejercer una linea del
  manejo real de errores de Firebase. Ahora lanzan `FirebaseAuthException`.
- **Los codigos de Auth no caen en el mensaje generico, a proposito:** son los unicos errores
  de la app que la persona puede resolver sola. Taparlos habria sido cambiar un defecto por
  otro.
- **Centinela nuevo: `test/errores_sin_detalle_tecnico_test.dart`.** Ninguna otra suite ve
  este defecto — un `Text('Error: $e')` compila, analiza limpio y pasa cualquier test de
  widget. Destapo cinco fugas mas. Mira solo presentacion y providers; `data/` queda fuera
  adrede.
- **El hook de pre-commit daba un falso positivo:** `dart format .` no falla, MUERE recorriendo
  `landing-web/node_modules` tras un `pnpm install` en el worktree (rutas de pnpm mas largas de
  lo que Windows admite). Decia «hay Dart sin formatear» sin listar un archivo. Ya lo
  distingue.
- **La E2E de la app dio 2 rojos en la primera corrida y 0 en la segunda.** Es la contencion ya
  conocida, no una regresion: los dos specs solos dan 9/9.

Cifras del arbol con UX-03/UX-04: `flutter analyze` limpio, `flutter test` **1216/1216**,
E2E de la landing **40/40**, E2E de la app **32 pasan y 2 `fixme`**.

Gaps anotados en el §Gaps de esa evidencia: contraste por debajo de 4.5:1 en seis sitios de la
landing (cifras de un worker, **sin verificar a mano**), jerarquia de encabezados con saltos,
cuatro imagenes de fondo por CSS sin alternativa textual, el fundido de `FeaturesGrid` bajo
movimiento reducido (deliberado) y una clave de ARB que no hace falta todavia.

QA-01 ya esta fusionada en `integracion/ola-1` (`c17fead`), sin conflictos. Evidencia completa
en `docs/evidencia/QA-01-matriz.md`. Lo que hay que saber sin leerla:

- **Construir la matriz destapo cinco huecos de autorizacion reales**, todos de la misma forma:
  una regla que autoriza mirando `resource.data` —el documento VIEJO— y luego no mira lo que el
  write deja escrito. Los peores: el propietario podia **regalar su vehiculo** reescribiendo
  `id_propietario`, y podia vaciar `talleres_conocidos` para devolver el coche al estado walk-in,
  que lo abre a **cualquier** mecanico (el agujero de la ronda 6, reabierto desde el otro lado).
- **La suite E2E corria contra PRODUCCION** y `registro.spec.js` creaba usuarios reales en cada
  corrida. Ya no: la app tiene cableado a emuladores (`lib/core/config/firebase_emulators.dart`)
  tras un doble candado (`--dart-define` **y** `!kReleaseMode`).
- **Queda abierto:** los dos flujos de registro por UI estan en `fixme`; sin cobertura E2E de
  Storage ni callables.

UX-01 ya esta fusionada en `integracion/ola-1` (`ed2e8e1`). Evidencia en
`docs/evidencia/UX-01-contacto-y-ctas.md`. Lo esencial:

- **Eran DOS los formularios que fingian enviar, no uno.** El de contacto era `<form action="#">`.
  El de afiliacion de talleres —que no estaba en el enunciado del plan y era el peor— POSTeaba
  **sin autenticar a la REST API de Firestore de PRODUCCION** contra `/talleres`, cuya regla es
  `allow create: if isAdmin()`: se denegaba siempre, con un estado de exito implementado que
  nadie podia alcanzar. Ademas los legales del pie apuntaban fuera del sitio, las anclas del menu
  morian fuera de la home, y la pagina de contacto **no la enlazaba nadie**.
- **El contrato ahora es la Cloud Function `recibirSolicitudLanding`** (la landing es un export
  estatico y no tiene servidor): valida, honeypot, cupo por IP con contador transaccional, y
  escribe con Admin SDK en `solicitudes_landing`, cerrada a los clientes por los dos lados.
- **Sin dos pasos de runbook el endpoint NO debe desplegarse:** definir `SOLICITUDES_LANDING_SALT`
  (sin ella la funcion se niega a arrancar, a proposito: con la sal versionada el hash de IP era
  reversible) y crear la politica TTL de `solicitudes_landing_control`, que no se configura desde
  `firestore.indexes.json`.
- **Suite nueva con config propia:** `cd e2e && npm run build:landing && npm run test:landing`
  (20 casos tras `fix/landing-crash`). No necesita el bundle de Flutter ni el emulador de Auth.

**El bundle E2E de la app se compila con `--profile`, no con el release por defecto.**
`flutter build web` compila en release, donde `kReleaseMode` desactiva el cableado a emuladores y
Auth sale al endpoint REAL con las claves falsas, muriendo en `auth/api-key-not-valid`.

**Playwright esperaba a la pieza equivocada, en las dos suites.** La config espera al puerto del
**hub** (4400), que abre antes que Firestore y mucho antes de que Functions cargue los triggers:
los dos primeros tests fallaban en 53 ms con ECONNREFUSED contra 8080 y el tercero pasaba tras
8 s — que parece el emulador muriendose a media suite y es justo lo contrario. Ambas esperan ya a
Firestore de verdad. Y **el navegador leyendo Firestore por REST desestabiliza el emulador**
(Chromium aborta las conexiones al navegar, netty acumula "Connection reset"): en la suite de la
landing esa lectura se intercepta.

### Ramas — nada está fusionado a `main`

`main` sigue en `1265d23`. **Las 12 tareas cerradas viven en `integracion/ola-1`**: ola 1
(SEC-01/02/03, DATA-01), las tres de ola 2 (QA-02, VER-01, ROLE-01),
QA-01, UX-01 y **UX-02** (fusionada el 2026-09-09, `d5c707a`, sin conflictos). Encima va
`fix/landing-crash` (`564fdf0`), que **no es una tarea del plan** pero sí trabajo real sobre
la landing ya integrada: normaliza las calificaciones que llegan por la REST de Firestore
—de ahí salía el crash— y retira Vercel Analytics, que en Firebase Hosting no tiene backend
al que hablar.

**Ya no queda ninguna rama `fix/*` pendiente de fusionar.** `fix/gaps-02` (la tanda de
drenaje) entro el 2026-09-11 en `integracion/ola-1` (`3130550`), fast-forward y sin
conflictos.

#### Árbol combinado, verificado entero el 2026-09-09

| Gate | Resultado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | **1167 / 1167**, exit 0 |
| `functions` (Mocha) | **170 passing** |
| `test_rules` (Jest + emuladores) | **426 / 426**, 24 suites |
| E2E de la app (Playwright) | **32 pasan, 2 `fixme`**, exit 0 |
| E2E de la landing | **20 / 20**, exit 0 |
| Puertos al salir | 0 en `LISTENING` |

UX-02 cerró dos callejones sin salida en la app y, en un segundo commit, el defecto del
harness que ella misma había destapado. Evidencia en
`docs/evidencia/UX-02-errores-y-deep-links.md`. Lo que hay que saber sin leerla:

- **El rewrite SPA ya existia** en `firebase.json` para el target `app`. El hueco era de
  evidencia: **ningun spec de la suite de la app navegaba a otra cosa que `/`**. El README si
  desinformaba, documentando `python -m http.server` (que no reescribe rutas) y presentando su
  404 como una limitacion a sortear. Ahora apunta al emulador de Hosting.
- **RESUELTO — el cableado a emuladores no se puede hacer desde Dart.**
  `Firebase.initializeApp()` en web no retorna hasta que `firebase_auth_web` termina su
  `ensurePluginInitialized`, que espera al primer `onAuthStateChanged`. Con sesion persistida
  ese evento exige refrescar el token guardado: una peticion de red que sale **dentro** del
  `initializeApp`, contra PRODUCCION, y que deja el Auth ya usado — asi que el
  `conectarEmuladoresFirebase()` de `main.dart` llega tarde por construccion y
  `emulatorConfig` se queda en null para siempre. No es un bug de la app: en produccion
  restaurar la sesion contra el backend real es lo correcto.
  El arreglo es `e2e/scripts/shim-emuladores.js`, que `build-web.js` inyecta en
  `build/web/index.html` **despues** de compilar (nunca en `web/index.html`, que es lo que se
  despliega): crea la app de JS y conecta el emulador antes de cargar `flutter_bootstrap.js`,
  y flutterfire reutiliza esa app. Tiene que usar **`initializeAuth` con las mismas opciones
  que flutterfire**, no `getAuth`, o el arranque muere con `auth/already-initialized`.
- **`esperarAppLista` ya no implica lo que implicaba.** Esperar a `auth.emulatorConfig`
  significaba que Firestore y Storage tambien estaban cableados, porque `main.dart` los conecta
  en las tres lineas siguientes. Con el shim, Auth queda cableado desde el arranque y hay ~1 s
  en el que `getFirestore()` apunta a **produccion**: `roles.spec.js` fallaba en 2 de 3
  corridas por eso. El helper espera ahora a las tres piezas: `<flutter-view>` montado, Auth en
  su emulador y Firestore en el suyo.
- **Ese arreglo produjo un falso verde de manual, y merece recordarse.** El primer intento
  dejaba el SDK de JS perfecto mientras Flutter caia a la pantalla de error de arranque: todas
  las afirmaciones miraban el SDK, la capa equivocada. **Un test de E2E sobre Firebase tiene
  que afirmar tambien que la app de Flutter arranco** — que no hay `ERROR al inicializar
  Firebase` en consola y que hay arbol montado.
- **La siembra corria antes de que Auth estuviera arriba** (`global-setup.js` esperaba solo a
  Firestore, pero sembrar tambien crea usuarios). Arreglado; reproducible al revertirlo.
- **Cada arranque de la app en un test cuesta caro** (CanvasKit + persistencia offline de
  Firestore) y degrada el emulador Java: un test de mas tumbaba specs ajenas por timeout.
  Agrupa `goto` y `reload` en el mismo test en vez de partirlos.

Ojo con el nombre: `fix/ux1` (sin el cero) es de un intento anterior y **no tiene ni un commit
propio** — es ancestro de `integracion/ola-1`. La buena es `fix/ux01`.

Las ramas `fix/*` ya integradas: **no trabajes sobre ellas**, parte de `integracion/ola-1`.

Antes de empezar una tarea, mira qué ramas `fix/*` existen ya para no duplicar.

### La tanda de drenaje `fix/gaps-02` está cerrada (2026-09-11)

Cierra los gaps **9.1, 9.2, 9.3 y 9.4** del §9 de `GAPS-FUNC-02-cierre-de-residuales.md`.
Evidencia en `docs/evidencia/GAPS-02-drenaje.md`. Lo que hay que saber sin leerla:

- **La trampa que el plan mandaba comprobar antes de tocar la bandeja de chat NO existía.**
  Ninguna conversación puede nacer sin `ultimo_mensaje_ts` (campo obligatorio del modelo,
  único creador en `lib/`, las Functions solo leen esa colección, y el modelo nació con el
  campo). Ni backfill ni paso de runbook. Comprobarlo ahorró una migración inventada — y es
  el contrapunto del lote C, donde la misma trampa sí era real.
- **Denormalizar `abierto` puso rojos diez tests de golpe**, todos por siembras que no
  escribían el campo: una igualdad sobre un campo ausente no devuelve NADA. Es exactamente
  lo que le pasaría a producción sin correr el backfill, ensayado gratis.
- **Los dos revisores encontraron cuatro cosas mal, dos graves.** (1) `abierto` se podía
  **borrar** con `FieldValue.delete()` y la regla lo dejaba pasar —`.get(campo, derivado)`
  degenera en una tautología sobre un campo ausente—, así que un taller escondía un ticket
  vivo de su propio tablero con el vínculo al coche intacto. (2) El backfill estampaba el
  centinela `migracion_ronda6` en TODOS los tickets, y ese centinela es **pegajoso**: cada
  ticket vivo el día de la migración habría dejado de notificar sus transiciones y de
  revocar el vínculo al entregarse, para siempre. Los dos cerrados, con sus tests.
- **`ReservaProvider.inicializarReservasUsuario` no tiene ningún llamador en `lib/`**: lo
  sostienen sus tests, como los `iniciar*` de FUNC-02. Se acotó igual; anotado como gap.
- **El runbook creció:** el backfill tiene ahora una pasada 4 (`abierto`) y **sin ella el
  tablero de todos los talleres sale vacío**; el despliegue de índices **retira seis** de
  producción; y las reglas van DESPUÉS del backfill y JUNTO a la app, nunca antes.

Cifras de la rama: `flutter analyze` limpio, Functions **218**, reglas **435 / 435** en 25
suites.

### Lo siguiente: UX-03 / UX-04

**"Accesibilidad y errores de datos"** (§7 del plan, P2). Áreas que señala:
`landing-web/src`, `service_history_screen.dart`, componentes de error/empty state, ARB y
pruebas. Dos frentes distintos: la landing (Next.js, `prefers-reduced-motion`, menú móvil
accesible, `Link > button` anidado) y la app (`Error: ${snapshot.error}` crudo → estado
localizado con reintento). Se pueden inventariar en paralelo.

**El gap 7.1 ya está cerrado** (rama `fix/marcar-leidos`, fusionada el 2026-09-11): el
batch de `marcarComoLeidos` reventaba con hilos de más de 499 mensajes del otro
participante y dejaba el contador de no leídos sin resetear para siempre. Era el único de
los seis que rompía; el resto del §7 de `GAPS-02-drenaje.md` son descubrimientos y
decisiones documentadas, y **quedan por decidir antes de UX-03/UX-04** — la regla del
2026-09-10 sigue siendo permanente: un gap documentado no está cerrado.

Del cierre de 7.1 vale la pena recordar dos cosas: **`FakeFirebaseFirestore` SÍ aplica el
límite de 500 por batch**, así que ese defecto se reproduce con el doble tal cual; y lo que
el doble no ve —cuántos lotes se commitean y de qué tamaño— hay que envolverlo para
afirmarlo, o «se marcaron todos» da igual de verde leyendo el hilo entero de una vez.

Corta la rama de la punta de `integracion/ola-1`, nunca de una `fix/*`.

Tres cosas que ahorran una hora:

- **Un worktree nuevo no tiene dependencias instaladas, y el fallo no lo dice.** El build de
  la landing murió con `Cannot find module 'next-intl/plugin'`, que suena a bug del código y
  solo significaba que faltaba `pnpm install` en `landing-web/`. Por worktree hay que sembrar
  `flutter pub get`, `functions/npm ci`, `test_rules/npm ci`, `e2e/npm ci` y
  `landing-web/pnpm install`.
- **No encadenes corridas de Playwright sin esperar a que se liberen los puertos.** Dos de
  tres fallaron en `global-setup` con «El emulador de Auth no respondio en 90 s», que parece
  un emulador roto y es solo la corrida anterior soltando los puertos. Comprueba 8080, 9099,
  9199, 4400, 5555 antes de relanzar.
- **El script `test` de `test_rules/` no acepta argumentos.** Es un `firebase emulators:exec`,
  así que `npm test -- storage.test.js` muere con «Too many arguments». Para correr una sola
  suite: `npx firebase emulators:exec --only firestore,storage --project autodoc-rules-test
  "npx jest --runInBand storage.test.js"`.
- **Cifras al día tras cerrar los residuales:** `flutter test` **1180**, reglas **426**
  en 24 suites, Functions **197**, E2E de la app **32**.

### Los nueve residuales de FUNC-02 están cerrados (rama `fix/gaps-func02`)

No es una tarea del plan: es el drenaje del §7 de la evidencia de FUNC-02. Evidencia en
`docs/evidencia/GAPS-FUNC-02-cierre-de-residuales.md`. Lo que hay que saber sin leerla:

- **Dos de los nueve estaban mal descritos, y en la dirección peligrosa.** El «índice muerto
  `Servicios`» no estaba muerto: era `servicios` **con la S mayúscula**, o sea el índice VIVO
  mal escrito, y el historial de servicios del propietario moría con `failed-precondition` en
  producción por su culpa. Y la «consulta que falla en silencio» no daba un mensaje
  equivocado: dejaba a la pantalla pintando el **formulario manual**, así que el mecánico
  re-tecleaba a mano el importe que el cliente ya había aprobado y era ese el que se guardaba
  en `servicios`.
- **Hay un centinela nuevo de índices: `test/firestore_indices_test.dart`.** Los emuladores
  sirven cualquier consulta sin mirar `firestore.indexes.json`, así que una consulta sin
  índice **no la detecta ninguna suite** — solo un usuario en producción. Cruza el inventario
  con los índices en las dos direcciones y cuenta los `.orderBy(` de `lib/` y los `.where(` de
  `functions/` como disparador. Destapó **seis consultas más sin índice** (reservas ×2,
  servicios, cotizaciones, conversaciones) y **cuatro índices huérfanos**.
- **Todos los tests de `InitiateServiceScreen` corrían contra un Firestore roto.** La pantalla
  usaba `FirebaseFirestore.instance` (su propio test lo llamaba «no inyectable»); al
  inyectarlo, trece se pusieron rojos de golpe. Llevaban ejerciendo el camino de fallo sin
  saberlo, porque el `.then` sin `catchError` se lo tragaba.
- **Dos dobles de prueba no podían ver el defecto que cubrían.** Uno tenía `limit()` como
  no-op; el otro devolvía el documento **vivo** desde `get()` en vez de una copia, y un
  snapshot de Firestore es inmutable — con eso, el primer test de la carrera del historial dio
  **falso verde**. Los dos modelan ahora esas propiedades.
- **La recepción pasa de `batch` a `runTransaction`** y la autorización viaja dentro, lo que
  retira además la segunda lectura del ticket. **El vínculo caduca solo** a los 30 días sin
  actividad (`caducarVinculosDeTalleresInactivos`): caduca el ACCESO, no el ticket, y el
  reintento que ya existe lo recupera mientras el ticket siga abierto.
- **Dos pasos de runbook nuevos, y uno no es negociable:** `node backfill_entregado.js --apply`
  ANTES de desplegar la app web (el tablero pasa a ordenar por `fecha_actualizacion`, y un
  `orderBy` excluye los documentos sin el campo, igual que el `whereIn` de la ronda 6), y
  `firebase deploy --only firestore:indexes` antes que la app.
- **Quedan nueve gaps NUEVOS anotados** en el §9 de esa evidencia, casi todos destapados por
  el gate de revisión. El que más vale: **el tope del tablero acota documentos, no lecturas** —
  un `whereIn` de 5 estados con `limit(200)` aplica el límite a cada subconsulta, así que lee
  hasta 1000 para devolver 200. Sigue siendo mejor que el stream sin tope de antes, pero no
  es lo que parece.

FUNC-02 retiró los caminos muertos de reparación y, al inventariarlos, destapó que el peor
seguía **vivo en el servidor**. Evidencia en
`docs/evidencia/FUNC-02-apertura-unica-de-tickets.md`. Lo esencial:

- **Lo que sostenía vivo a `iniciarReparacion` no era la app: eran sus tests.** Los cuatro
  métodos `@Deprecated` de `ReparacionProvider` y los dos del repositorio tenían **cero**
  consumidores en `lib/`; solo la siembra de 19 tests. Esa siembra vive ahora en
  `test/support/sembrar_reparacion.dart`, donde no compila dentro de la app.
- **El callable `iniciarReparacionPorVehiculo` seguía desplegado e invocable sin tener
  llamador.** Abría el ticket directamente en `'recibido'` —saltándose la recepción física—
  y se otorgaba `vehiculos.talleres_vinculados`. Su única compuerta era «existe una
  cotización aceptada para este vehículo+taller», y **una cotización se queda en `aceptada`
  para siempre**: con una visita YA ENTREGADA bastaba para recuperar el acceso al coche que
  `revocarVinculoAlCerrarTicket` acababa de revocar. El `allow create: if false` de
  `firestore.rules` no lo alcanzaba — los callables corren con Admin SDK.
- **`firebase functions:delete iniciarReparacionPorVehiculo` es paso de runbook.** Borrar el
  export NO retira el endpoint desplegado: mientras siga vivo en el proyecto de Firebase, el
  replay sigue disponible en producción. Va en el mismo cajón que `SOLICITUDES_LANDING_SALT`.
- **Quedan tres escritores server-side sobre `/reparaciones` y ninguno más**:
  `onCotizacionAceptada` (crea, en `pendiente_recepcion`), `recibirVehiculoDelTicket`
  (transiciona) y el barrido de `onVehicleDelete` (cierra). Lo vigila un centinela que
  cuenta los accesos **por archivo** — la primera versión miraba solo el cuerpo de cada
  `exports.` y pasaba por casualidad, porque la escritura real vive en `src/vinculoTaller.js`.
- **Nueve gaps quedan abiertos y anotados** en el §7 de esa evidencia, con su razón. Los dos
  que más valen: el **dedup de tickets puede fallar por volumen** (`.limit(20)` sin filtro de
  estado ni orden en `aceptarCotizacion.js:247`) y una **consulta sin índice que falla en
  silencio** (`initiate_service_screen.dart:269`, `.then` sin `catchError`, y la pantalla
  acaba diciendo «no hay cotización aceptada» por un `failed-precondition`).

FUNC-01 cerró el defecto de las fotos y, de camino, un agujero de reglas que no estaba en el
enunciado. Evidencia en `docs/evidencia/FUNC-01-fotos-de-resenias.md`. Lo esencial:

- **El enunciado del plan describe mal el bug.** «La edición descarta fotos» no era cierto: el
  sheet escondía el selector en modo edición precisamente para que no se descartara nada. El
  defecto real era que **`updateReview` no mencionaba `fotos`**, así que tras publicar no había
  forma de tocarlas, y que **`storage.rules` no dejaba al autor borrar las suyas**
  (`allow delete: if isAdmin()`): sin ese segundo cambio la tarea no se podía cerrar, porque
  limpiar un huérfano moría en `permission-denied`.
- **`resenias` es de lectura ANÓNIMA y `fotos` aceptaba cualquier URL.** Era teórico mientras
  el cliente no escribía `fotos` en un update; FUNC-01 es justo lo que lo vuelve alcanzable. Un
  propietario con una reseña legítima podía apuntar a un servidor propio y cosechar IP y
  User-Agent de todo el que abriera la ficha del taller. Cerrado con `fotosBajoServicio`,
  hermano de `esUrlDeStoragePropia`. **En un update valida solo si `fotos` cambia**:
  `request.resource.data` es el documento *resultante*, así que validar siempre dejaría
  ineditables las reseñas con URLs heredadas, ni siquiera para corregir el texto.
- **Queda residual y anotado:** el «vehículo fantasma» (`vehiculos` admite `create` con ID
  elegido por el cliente, y `onVehicleDelete` es asíncrono), cuyo endurecimiento limpio —atar
  el nombre del objeto al uid— es una migración, no un ajuste; y que **nadie borra las fotos
  al ELIMINAR una reseña**, que es trabajo de un trigger `onDelete` con Admin SDK y encaja en
  OPS-01.

Sigue **abierto y sin dueño**: el rojo intermitente de `flutter test` (`1139 +1 -1`) que no
se ha llegado a identificar — ver «Rarezas» más abajo — y el emulador Java de Firestore
muriéndose ~1 de cada 6 corridas en Windows.

### La trampa a vigilar: los dobles de prueba no aplican las reglas

Hay tests de autorización escritos contra `FakeFirebaseFirestore` y
`fake_firebase_security_rules`, que **no aplican las reglas reales**. El motor falso solo
conoce `read, write, update, delete, list` — **no existe `create` ni `get`** —, `write` ya
incluye `update` y `delete`, y `isAllowed` hace OR de todos los `allow` que casen. Un verde ahí
no prueba autorización; eso solo lo prueba `test_rules/` contra los emuladores.

Ese patrón ya produjo **dos** falsos verdes reales, y ambos son la misma enfermedad — un test
que ejercita una puerta distinta de la que dice probar:

1. **VER-01 (cerrada):** el test del PDF del NIT inyectaba un `XFile` que el picker real nunca
   podía producir, sobre una pantalla que usaba `ImagePicker` y por tanto jamás admitía un PDF.
   Verde sobre un flujo inalcanzable en producción. Hoy la pantalla usa `FilePicker` y el test
   sustituye `FilePickerPlatform.instance`, o sea recorre la ruta de selección de verdad.
   Al escribir los negativos apareció además un agujero de MIME spoofing (`nit.jpg` declarando
   `application/pdf`) que se cerró emparejando nombre y content-type en `storage.rules`.
2. **ROLE-01 (cerrada):** el test de variantes de rol apuntaba a
   `talleres/{id}/catalogo_servicios`, cuya regla es `actuaPorTaller()` — **propiedad pura, sin
   mirar el rol**. Habría pasado con cualquier cadena. Se repuntó a la lectura de `vehiculos`
   vinculados (`firestore.rules:516`), que sí pasa por `isMecanico()`.

**Antes de dar por bueno un test de autorización, abre la regla que dice cubrir y comprueba que
el predicado que te importa es el que decide.**

### Rarezas

- **Resuelta — el fallo de la primera corrida de Mocha tras `npm ci`.** No era intermitente:
  el hook `before()` de `functions/test/empleados.test.js` termina con un `require` *síncrono*
  de `index.js`, que arrastra firebase-admin y firebase-functions. En frío ese require tarda
  ~4 s leyendo de disco y bloquea el event loop, así que el timeout por defecto de Mocha
  (2000 ms) vencía y la suite daba 147/1. En caliente la suite entera corre en 294 ms, de ahí
  la apariencia de azar. Arreglado con `--timeout 20000` en el script `test` de
  `functions/package.json`, verificado borrando `node_modules` y reinstalando (150/150 en frío).
- **Abierta — un rojo de `flutter test` que no se ha podido identificar.** El 2026-09-08
  aparecio dos veces `1139 +1 -1` (en `fix/ux01` y en el arbol fusionado) contra cuatro corridas
  de 1140/1140, incluida una repitiendo `analyze` justo antes para forzar la hipotesis obvia. Las
  dos rojas tenian en comun que la salida pasaba por `tail`, que **se comio el nombre del test y
  ademas falseo el codigo de salida a 0** (el del pipe es el de `tail`). Si vuelve a salir:
  **captura la salida entera a un archivo, nunca por `tail`**, y apunta aqui el nombre. Puede ser
  una dependencia de orden o de temporizacion; hoy no hay evidencia para afirmar ni descartar.
- **Abierta:** el emulador Java de Firestore muere a media suite en Windows
  (`Connection reset`) ~1 de cada 6 corridas.

El plan `docs/superpowers/plans/2026-09-02-hallazgos-uso-real.md` (anexo S2–S6, Bloques B–G)
sigue pendiente y se retoma cuando el plan de remediación cierre.

## Flujo de trabajo obligatorio para cada petición

1. **Contexto del proyecto**: usa **graphify** (`/graphify`, o las skills `graphify` instaladas) como fuente principal de contexto del código — grafo de conocimiento ya construido en `graphify-out/graph.json` (9457 nodos, 14617 edges, 493 comunidades; reindexado el 2026-09-16). Si el grafo no responde lo suficiente, complementa buscando directamente en el código (Grep/Glob/Read).
2. **Superpowers**: usa las skills de `superpowers` (brainstorming, TDD, debugging sistemático, subagent-driven development, code review) según corresponda al tipo de tarea.
3. **find-skills**: antes de improvisar una solución, usa `find-skills` para revisar si ya existe una skill relevante instalada o disponible en las marketplaces configuradas.

Ver también `CONVENTIONS.md` para arquitectura (Clean Architecture + Provider), reglas de Firestore/roles, y estilo de código.

## Cómo se corren las suites (detalles que cuestan una hora si se ignoran)

- `test_rules/` va **siempre por `npm test`**, que envuelve todo en `firebase emulators:exec`.
  Invocar `npx jest` a pelo da ECONNREFUSED porque no hay emulador levantado.
- **No cambies los puertos de emulador** de `firebase.json` ni de `test_rules/helpers.js` para
  esquivar una colisión local: son canónicos y compartidos. Si el puerto está ocupado, mata el
  proceso que lo tiene — normalmente es una corrida tuya anterior que sigue viva.
- Un hook de pre-commit rechaza el commit si queda Dart sin formatear: `dart format` antes.
- **Dos suites de Playwright, cada una con su config.** La de la app va contra emuladores
  desde QA-01; la de la landing (`e2e/tests-landing/`, UX-01) se lanza con
  `npm run build:landing && npm run test:landing` y no necesita ni el bundle de Flutter ni el
  emulador de Auth. **Ninguna de las dos espera al puerto del hub para dar por listos los
  emuladores**: el hub abre antes que Firestore, y eso hacia fallar los primeros tests con
  ECONNREFUSED como si el emulador se hubiera muerto.
- **`e2e/` (Playwright) va contra emuladores desde QA-01.** Primero `cd e2e && npm run build:web`
  (compila el bundle en `--profile`, tarda varios minutos, incluye un `flutter clean` que no es
  opcional), luego `npm test`. La config levanta los emuladores y siembra los fixtures sola.
  Tres cosas que cuestan una tarde si se ignoran:
  - **`getByLabel` no puede funcionar**: la app no emite ni un `aria-label`. Flutter web expone la
    semántica como `<flt-semantics role="button">` con el rótulo como texto — usa `getByRole`. Y
    hace falta un clic (`page.mouse.click(10,10)`) para que Flutter construya ese árbol; sin él
    ningún selector encuentra nada.
  - **No importes el SDK de gstatic dentro de `page.evaluate`**: crea su propio registro de apps
    (`getApps()` vacío) y, peor, no hereda el `useAuthEmulator` — hablaría con producción desde
    dentro de una suite que se cree aislada. Usa los globales `window.firebase_core` /
    `firebase_auth` / `firebase_firestore`, que son la instancia real.
  - **Usa `esperarAppLista()` de `e2e/tests/helpers.js`; no improvises la espera.** Comprueba
    tres cosas, y las tres hacen falta: `<flutter-view>` montado, Auth en su emulador y
    **Firestore en el suyo**. Desde el shim de emuladores (UX-02), Auth queda cableado antes
    de que arranque Flutter, así que `auth.emulatorConfig` por sí solo dejó de implicar que
    Firestore lo esté: hay ~1 s en el que `getFirestore()` apunta a producción.

## Skills/plugins instalados (scope: user)

- `claude-code-setup@claude-plugins-official` — recomendador de automatizaciones.
- `superpowers@claude-plugins-official` — brainstorming, TDD, debugging, code review, subagentes.
- `andrej-karpathy-skills@karpathy-skills` — guías de comportamiento (pensar antes de codear, simplicidad, cambios quirúrgicos, criterios de éxito claros).
- `find-skills@easier-life-skills` — descubrimiento de skills relevantes para el repo activo.
- `graphify` (CLI vía `uv tool install graphifyy` + skill en `~/.claude/skills/graphify/`) — grafo de conocimiento del código, `/graphify` para re-indexar.

## Automatizaciones locales del proyecto (`.claude/`)

- Hooks: bloqueo de edición de `.env`/credenciales, auto-`dart format` post-edición.
- Subagentes: `firestore-rules-reviewer`, `functions-perf-reviewer`. Son **gate obligatorio**,
  no opinión opcional: pásalos después de implementar y antes de cerrar cualquier tarea que
  toque `firestore.rules` o `functions/index.js`.
- Slash commands: `/test [unit|rules|integration|all]`, `/delegate-to-codex`.
- Skills: `firebase-deploy-check`, `ejecutar-plan-remediacion`.
- `AGENTS.md` (raíz) repite el estado del plan para los workers de Codex, que arrancan en frío.
  **Si cierras una tarea del plan, actualiza los dos archivos.**
