# Decisiones de ejecución del plan de corrección de hallazgos QA

> Compañero de `2026-08-28-correccion-hallazgos-qa.md`. **Léelo antes que el plan.**

Durante la ejecución del plan aparecieron defectos en el propio plan: pasos que citaban
funciones inexistentes, líneas y nombres equivocados, snippets que no compilaban y —dos
veces— diagnósticos incorrectos cuyo arreglo no habría arreglado nada. Cada desvío se decidió
contra el informe de QA (`docs/qa/REPORTE_QA_PLAYWRIGHT_2026-08-28.md`), que es la autoridad
vinculante; el plan es solo su argumento.

Este documento recoge las 56 decisiones, en el orden en que se tomaron, cada una con su motivo
y con lo que costaría si estuviera equivocada. Existe porque **el plan versionado sigue
describiendo cosas que se decidió no hacer** (o hacer de otro modo), y sin este registro sería
engañoso para quien lo lea después.

Las de mayor impacto, si solo se leen unas pocas:

- **Ruling 51** — el arreglo que el plan proponía para el §13 (envolver `AppTopNavBar` en
  `Semantics`) resultó ser **código muerto**; la causa real era el `Navigator` anidado de la
  `ShellRoute`. Se probó y se eliminó.
- **Rulings 43 y 54** — la 43 situó el filtro por vehículo en el punto de render y **estaba
  equivocada**: `_maintenanceTasks` solo contenía las tareas del último vehículo procesado, así
  que filtrar allí vaciaba la lista y apagaba el semáforo de mantenimiento y `/alerts` para
  cualquier dueño con más de un vehículo. La 54 lo corrige fusionando en el provider.
- **Rulings 49, 50, 53 y 55** — cuatro veces se amplió el alcance más allá del brief para no
  cerrar un hallazgo en falso, siempre exigiendo demostrar el defecto con un test en rojo antes
  de tocar código.
- **Ruling 47** — un `assert` de Dart es una comprobación de tiempo de ejecución en modo debug:
  `flutter analyze` no caza los call sites olvidados, al contrario de lo que asumía una decisión
  anterior.
- **Ruling 56** — la tabla de cobertura del plan mapeaba *secciones* del informe de QA a tareas,
  pero varias secciones contienen **dos** hallazgos. «Los 17 hallazgos tienen tarea» era cierto
  por sección y falso por hallazgo; eso es lo que dejó `/chat_list` sin arreglar hasta la
  revisión final.

---

**Ruling 1: los helpers de test que el plan nombra pero no crea son parte de la tarea.**
En T2, T4, T6, T7, T10, T11, T15, T17 y T19 el plan escribe el test contra un probe o
fixture que ningún paso construye. Lo vinculante es **la aserción y su intención**, no el
nombre literal del helper. El implementador crea el helper siguiendo los patrones ya
existentes en `test/support/` y `test/helpers/` (`pumpAtWidth`, `responsive_harness.dart`,
`shell_harness.dart`, `vehicle_fixtures.dart`, `test_helpers.mocks.dart`) y puede
renombrarlo. — *Por qué:* es un defecto de redacción de mi propio plan, no una decisión de
producto; el spec (el informe de QA) no dice nada sobre nombres de helpers. — *Coste si me
equivoco:* el test acaba comprobando algo distinto de lo que el hallazgo describe; lo
detecta la revisión de tarea, que compara contra el brief.

**Ruling 2: T13 usa el constructor real de `MetricCard`.**
Es `{required String title, required String value, required IconData icon, required Color color}`,
no `label:`. — *Por qué:* el código manda sobre el plan. — *Coste si me equivoco:* ninguno,
es transcripción.

**Ruling 3: T17 no exige refactorizar `main.dart` a `bootstrapServices`.**
Lo vinculante es que `runApp` deje de esperar al permiso de push. Si extraer una función
testeable resulta desproporcionado, basta con `unawaited(...)` y un test que verifique que
`PushNotificationService.initialize` no se aguarda. — *Por qué:* el hallazgo §12 mide un
retraso de arranque, no una arquitectura. — *Coste si me equivoco:* queda sin test
automático y solo verificado a mano en consola.

**Ruling 4: el color se valida una sola vez, en T2.**
T2 introduce `_colorError` y T19 solo añade el patrón de formato a esa misma ruta.
— *Por qué:* dos validadores para un campo es exactamente el tipo de duplicación que la
revisión marcaría. — *Coste si me equivoco:* rework menor en T19.

**Ruling 5: T14 barre todos los call sites de `AppCard(onTap:)`, no solo los del informe.**
El `assert` rompe la compilación de cualquiera que falte, así que la tarea no está hecha
hasta que `flutter analyze` esté limpio. — *Por qué:* lo impone el propio cambio.
— *Coste si me equivoco:* el build falla y se ve de inmediato.

**Ruling 6: el deploy de reglas se agrupa al final, no dentro de T1.**
T1 y T5 tocan reglas distintas. Ambas se validan con `npm test`; el `firebase deploy` se
propone una sola vez al terminar, como acción humana. — *Por qué:* desplegar dos veces
sobre producción multiplica el riesgo sin ganar nada. — *Coste si me equivoco:* el arreglo
del 403 tarda un poco más en estar vivo.

**Ruling 7: `admin_verificaciones_screen.dart` (plural) es el nombre real.**
El plan de la T11 lo escribe en singular. — *Por qué:* el código manda. — *Coste si me
equivoco:* ninguno.

**Ruling 8: `pumpAtWidth` toma `width` como parámetro con nombre.**
La firma real es `pumpAtWidth(tester, child, {required double width, double height = 900,
Brightness brightness = Brightness.light, bool disableAnimations = false})`. Todos los
tests del plan la invocan posicionalmente (`pumpAtWidth(tester, widget, 1440)`). Se corrige
al escribirlos. — *Por qué:* el código manda. — *Coste si me equivoco:* ninguno.

Harnesses disponibles en `test/support/`: `responsive_harness.dart` (`pumpAtWidth`,
`expectNoOverflow`, `forEachAuditWidth`), `shell_harness.dart`, `chat_harness.dart`,
`mechanic_harness.dart`, `entry_harness.dart`, `vehicle_fixtures.dart`
(`FakeVehicleProvider`), `contrast.dart`. Se pasan en cada dispatch.
**Ruling 9: los revisores tienen prohibido mutar el estado de git.**
A partir de la Task 2, todo dispatch de revision lleva: nada de stash, checkout, reset,
merge ni cambio de rama; solo lectura de ficheros y ejecucion de tests. — *Por que:* el
revisor de la T1 estuvo a un comando de perder trabajo del usuario que no era suyo.
— *Coste si me equivoco:* ninguno; solo restringe.

**Ruling 10: `initiate_service_screen.dart` mantiene literales en espanol, no l10n.**
El revisor de la T3 verifico que el fichero entero no tiene ni una referencia a `l10n` o
`AppLocalizations`. El brief de la T4 pide anadir `context.l10n.isReceiveVehicle`.
Introducir l10n para un solo boton en un fichero de 1.200 lineas que no lo usa crea una
inconsistencia peor que la que resuelve. La T4 usa el literal 'Recibir vehiculo', igual
que el resto del fichero. — *Por que:* consistencia local sobre la regla global cuando la
regla global no se aplica en ninguna parte de ese fichero. — *Coste si me equivoco:* ese
boton queda fuera de la futura pasada de localizacion; se arregla con la pasada entera,
que ese fichero necesita igualmente.

**Ruling 11: la T5 no toca `firestore.rules`. El plan partia de una premisa falsa.**
El Step 3 del brief decia "anade 'cancelado' a la lista de estados validos" del bloque
`reparaciones`. Verificado por mi en firestore.rules:868-873: ese `allow update` NO tiene
ninguna whitelist de estados; solo impide reasignar id_vehiculo/id_taller/id_propietario.
'cancelado' ya estaba permitido sin tocar nada. El implementador lo comprobo en rojo/verde
y dejo el fichero intacto: correcto. — *Por que:* el codigo manda sobre el plan.
— *Coste si me equivoco:* ninguno; ademas los 2 tests nuevos fijan el comportamiento.

**Ruling 12: 'cancelado' NO entra en `estadosReparacion` (Dart).**
Esa lista genera las columnas del kanban y decide avanzar/retroceder; anadirlo habria
creado una quinta columna y roto el boton "Avanzar" de la ultima. El implementador lo
trato como caso especial en `ReparacionRepository.cambiarEstado`, fuera del pipeline.
— *Por que:* el brief describia el efecto deseado, no la estructura real. — *Coste si me
equivoco:* un ticket cancelado no es visible en el tablero; hay que decidir si se quiere
una vista de cancelados.

**Ruling 13: la T7 implementa la forma del Step 4, no la de la seccion Interfaces.**
El brief dice `Future<void> resetSession(BuildContext)` en Interfaces pero su Step 4 define
`clearUserScopedProviders(...)` + `clearSessionFrom(BuildContext)` y deja `signOut()` y la
navegacion en las pantallas. Manda el Step 4: es el spec concreto y mantiene la navegacion
en la capa de widget, donde ya vive. — *Coste si me equivoco:* la firma publica difiere de
una linea de documentacion del plan; ningun consumidor depende de ella.

**Ruling 14: cancelar las suscripciones dentro de `clear()` es obligatorio, no opcional.**
Una suscripcion que sigue escuchando con el uid viejo ES la fuga; vaciar la lista sin
cancelarla la repuebla en el siguiente snapshot. `clear()` debe ser idempotente y seguro
sobre un provider que nunca arranco (subs nulas). — *Coste si me equivoco:* el bug
reaparece en cuanto Firestore emite un snapshot tras el cierre de sesion.

**Ruling 15: la T7 cierra el Important con la costura de DI, no documentando el hueco.**
El revisor ofrecia dos rutas. Elijo anadir `FirebaseFirestore` inyectable a
`ReservaRepository`/`ReservaProvider` porque (1) es la misma costura que ya tienen los otros
tres providers, asi que quita una inconsistencia en vez de anadir un concepto; (2) permite
reutilizar en reservas el check de cancelacion en vivo ya escrito para chat/notis; y (3)
permite **borrar** `debugSeedReservas`, que era justo el `@visibleForTesting` que la revision
senalaba. Documentar el hueco habria dejado en pie el hack Y la mitad sin probar.
— *Coste si me equivoco:* toco produccion (dos constructores) fuera de la lista de ficheros
del brief para ganar cobertura de test; si la DI arrastra algo desproporcionado, el
implementador tiene orden de parar y decirmelo en vez de medio hacerlo.

**Ruling 16: el test de la T9 usa el titulo real de la fixture, no 'NISSAN GT-R'.**
El brief hace `find.text('NISSAN GT-R')`. `test/support/vehicle_fixtures.dart:12-13` genera
siempre `marca: 'Toyota', modelo: 'Corolla'`, asi que ese texto no existe en ninguna parte y
el test fallaria por no encontrar el widget, no por el recorte. Lo vinculante es la
intencion: **a 768 px el titulo del vehiculo se pinta con mas de ~120 px de ancho y usa
`TextOverflow.ellipsis`**. El implementador usa el titulo que la fixture produce de verdad, o
extiende `fakeVehicle` para aceptar marca/modelo. — *Coste si me equivoco:* ninguno, es el
mismo assert sobre el widget correcto.

**Ruling 17: el harness de la T9 tiene que hacer que el boton "Hacer Principal" se pinte.**
Este es el defecto serio. `garage_screen.dart:305-306` solo dibuja el `AppButton` si
`!vehicle.isPrimary && vehicle.idPropietario == currentUserId`. En el harness actual
`currentUserId` sale de `AuthSessionProvider(firebaseAuth: MockFirebaseAuth())` con
`idTokenChanges()` devolviendo un stream vacio (garage_screen_test.dart:25-29), asi que
`user?.uid` es null, mientras que la fixture tiene `idPropietario: 'u1'`
(vehicle_fixtures.dart:10). **El boton nunca se renderiza en el test.** Sin el, no existe el
elemento que aprieta al `Expanded` y el test pasaria en verde antes y despues del fix: seria
vacuo. El implementador debe hacer que el uid de la sesion falsa sea 'u1' (o que la fixture
use el uid de la sesion) y **verificar que el AppButton aparece en el arbol antes de medir el
ancho del titulo**. — *Por que:* un test que no reproduce el bug no es un test.
— *Coste si me equivoco:* ninguno; si el boton ya apareciera por otra via, la asercion extra
solo lo confirma.
**Ruling 18: los nombres reales son `admin_verificaciones_screen.dart` (plural, ya en la
Ruling 7) y `VerificacionTallerModel` en `lib/core/models/verificacion_taller_model.dart`.**
El plan escribe `VerificacionModel` y el fichero en singular; ninguno de los dos existe.
— *Coste si me equivoco:* ninguno, es transcripcion.

**Ruling 19: el modelo se queda inmutable; la identidad resuelta NO se escribe dentro del
expediente.** El brief hace `e.nombreTaller = taller?.nombreCompleto`, pero
`VerificacionTallerModel` tiene todos los campos `final` (verificado: `final String idTaller`
y el resto del fichero sigue el mismo patron), asi que esa asignacion ni compila. La
identidad resuelta vive en un mapa aparte del provider (`Map<String, UserModel?>` cacheado
por uid) y la tarjeta lo consulta, o bien se anade un `copyWith`. Prefiero el mapa.
— *Por que:* el modelo documenta explicitamente que separa lo publico de lo privado; volverlo
mutable para una comodidad de pintado va en contra de su razon de existir.
— *Coste si me equivoco:* el provider gana un campo mas que hay que limpiar.

**Ruling 20: la hidratacion no puede ser un `await` dentro de un `for`.**
El brief escribe `for (final e in expedientes) { await WorkshopService().getWorkshopById(...) }`:
son N viajes secuenciales a Firestore **y** una instancia nueva del servicio por vuelta. Se
resuelve con una sola instancia inyectada y `Future.wait` sobre los uids que aun no esten en
cache. — *Por que:* es exactamente el patron N+1 que el subagente `functions-perf-reviewer`
del propio repo existe para cazar; dejarlo pasar aqui seria incoherente.
— *Coste si me equivoco:* ninguno; la bandeja del admin es pequena hoy, pero el coste es
lineal en solicitudes pendientes y se nota justo cuando hay cola.

**Ruling 21: el guard de la Ruling 17 debe usar un finder que valga ANTES y DESPUES del fix.**
El implementador escribio el guard como `find.byTooltip(l10n.garageMakePrimary)` y su propio
comentario admite que el `AppButton` actual no tiene tooltip: solo lo anade el fix. Con eso el
rojo falla **en el guard**, no en la asercion de ancho — o sea, el test probaria "el tooltip
todavia no existe", que es una reformulacion del propio cambio, en vez de probar que el titulo
se esta estrujando. Le mando usar `find.byIcon(Icons.star_border)`, que existe en los dos
arboles (garage_screen.dart:317 ya lo pasa como `icon:` del AppButton y el IconButton llevara
el mismo), y dejar el assert del tooltip para el estado verde, donde ademas protege el nombre
accesible que exige la T14. — *Por que:* un rojo que no ejercita el defecto real es justo lo
que la Ruling 17 existia para evitar. — *Coste si me equivoco:* ninguno; el test acaba con
mas aserciones, no menos.

Ojo al revisar: `_fakeAuthSessionProvider({String? uid = 'u1'})` cambia el comportamiento por
defecto de TODOS los tests del fichero (ahora pintan el boton de dueno donde antes no).
Le exigi correr el fichero entero y avisarme si alguno se rompe, en vez de ajustarlo.
**Ruling 22: la causa del cuelgue es `Future.delayed` dentro de la zona FakeAsync.**
`testWidgets` corre su cuerpo en una zona con reloj falso. El harness hacia
`controller.add(mockUser); await Future.delayed(Duration.zero);` **antes** de cualquier
`pump`, y en esa zona `Future.delayed` no resuelve hasta que el reloj falso avanza con un
`tester.pump(...)`: deadlock. Ademas el `StreamController` nunca se cerraba.
Solucion que le di: volver el helper sincrono y usar `Stream.value(mockUser)` — el listener
del constructor de `AuthSessionProvider` (auth_session_provider.dart:19-32) llama a
`notifyListeners()` y la pantalla usa `context.watch`, asi que el `pumpAndSettle` que ya
existe lo recoge. Sin `Future.delayed`, sin controller que fugar.
— *Coste si me equivoco:* ninguno; si aun asi no apareciera el boton, un `pump` extra, nunca
otro `Future.delayed`.

Nota operativa para los proximos dispatches: el tope del Bash del subagente son 10 min por
llamada. Los dispatches deben decir explicitamente que si una llamada se acerca al tope, se
para y se reporta, en vez de reintentar a ciegas o mandarla al fondo.

**Ruling 23: la causa NO es "una etiqueta por punto"; es que ningun `SideTitles` fija
`interval: 1`.**
`monthsOrder` ya se construye con **una entrada por mes**: `for (int i = 5; i >= 0; i--)`
anade 6 claves distintas (services_trend_chart.dart:24-33, user_growth_chart.dart:28-32,
workshops_growth_chart.dart:28-32, expense_summary_card.dart:22-25) y `spots` mapea 1:1
sobre ellas. O sea, dos entradas consecutivas **nunca** son iguales, asi que la deduplicacion
que propone el brief (`if (monthsOrder[indice - 1] == clave) return null`) **jamas se
dispararia**: es codigo muerto disfrazado de arreglo.
La causa real: `grep -n interval` sobre los cuatro ficheros devuelve **cero coincidencias**.
Sin `interval`, fl_chart elige sus propios ticks sobre un eje 0..5 y puede colocarlos en
valores fraccionarios (0, 0.5, 1, 1.5...); `value.toInt()` trunca 0.0 y 0.5 al mismo indice y
pinta la misma etiqueta dos veces. **El arreglo vinculante es `interval: 1`.**
El helper compartido se mantiene por DRY (cuatro copias del array `monthNames` en linea es lo
que hay hoy), pero su deduplicacion no es el fix y no debe presentarse como tal.
— *Coste si me equivoco:* si fl_chart resultara no ser la causa, el test del helper pasaria y
el eje seguiria repitiendo; por eso exijo que el test se haga sobre el widget renderizado
(contar etiquetas distintas en el arbol), no solo sobre la funcion pura.

**Ruling 24: el cuarto grafico es `expense_summary_card.dart`, no `vehicle_profile_screen.dart`,
y su `monthsOrder` es `List<int>`, no `List<String>`.**
El plan nombra `vehicle_profile_screen.dart`, que solo delega
(`_buildExpenseSummary` -> `ExpenseSummaryCard`, :362-372) y no tiene ejes. Y ahi
`monthsOrder` guarda numeros de mes (`List<int>`, expense_summary_card.dart:22-25), no claves
`'YYYY-MM'`. La firma del helper del brief (`List<String> monthsOrder`) no encaja: hay que
unificar los cuatro call sites a un mismo tipo o dar al helper una entrada normalizada.
— *Coste si me equivoco:* ninguno; es incompatibilidad de tipos, se ve al compilar.

**Ruling 25: la altura de `MetricCard` la impone el grid padre, no la propia tarjeta; el test
tiene que montarla dentro de esa configuracion o no prueba nada.**
`MetricCard` es una `Column` dentro de un `AppCard` (metric_card.dart:41-45) y **no fija
altura**. Quien la fija es `childAspectRatio: 1.6` del `AppGrid` padre
(admin_dashboard_screen.dart:232): a ~430 px de celda salen ~269 px de alto, que es
exactamente el "~270 px con 200 de vacio" que reporto QA. El `spaceBetween` solo estira
**porque** el grid le da altura acotada.
El test del brief hace `pumpAtWidth(tester, const MetricCard(...), 1440)` — es decir, monta la
tarjeta **suelta, sin grid**. Sin altura acotada la Column se ajusta al contenido y el
`expect(alto, lessThan(160))` pasaria en verde **antes y despues del fix**: otro test vacuo,
el mismo patron que la Ruling 17 en la T9.
Vinculante: el test monta la tarjeta dentro del mismo `AppGrid` (mismo `childAspectRatio` y
ancho) que usa la pantalla real, o mide la celda del grid. Y el fix va donde esta la causa:
el `childAspectRatio` del padre, no solo el interior de la tarjeta.
— *Coste si me equivoco:* si resultara que a algun ancho la tarjeta si se ajusta sola, el test
dentro del grid sigue siendo el correcto; nunca es peor.

Nota: `_MetricCard` de `mechanic_dashboard_screen.dart:231` es otra clase privada distinta,
fuera de alcance.

**Ruling 26: el hallazgo es Important, no Critical, pero entra al fix loop igual.**
El revisor lo marco Critical. Lo bajo: el arreglo de producto es correcto y no hay nada roto
en la app — es un test de regresion que falta sobre una rama **que este commit no toca**.
Critical esta reservado a comportamiento incorrecto. Pero entra al fix loop igualmente,
porque la razon que se dio para omitirlo era falsa y la rama sin cubrir es justo la que el
cambio podria romper en silencio. — *Coste si me equivoco:* si fuera Critical y lo trato como
Important, el efecto practico es el mismo: se arregla ahora, en la misma ronda.

**Ruling 27: el ratio de la rejilla se extrae a una constante compartida; el test consume la
de produccion, no una copia.**
La raiz de los Critical 1-3 es que el test se construye su propia rejilla con el valor ya
arreglado, asi que mide su propia configuracion y no la de la app. Se arregla extrayendo el
`childAspectRatio` a una constante nombrada en produccion y usandola **en los dos sitios**.
Asi, si alguien revierte la constante a 1.6, el test vuelve a medir ~269 px y **falla**, que
es justo la proteccion que la Ruling 25 pedia. — *Por que:* es la unica forma de que el test
ejercite la configuracion real sin tener que montar `AdminDashboardScreen` entero con sus
providers y Firebase. — *Coste si me equivoco:* una constante publica mas en el modulo admin.

**Ruling 28: el umbral numerico desaparece; se compara contra la altura natural del contenido.**
Discutir si el corte va en 160 o en 170 es discutir el sintoma. Lo que la tarea afirma de
verdad es "la tarjeta ya no la estira la rejilla", y eso se mide sin numeros magicos: montar
la misma tarjeta **suelta** (sin altura acotada) para obtener su altura natural, montarla
dentro de la rejilla, y afirmar que las dos coinciden (con una tolerancia minima). Queda un
test sin constante que ajustar al resultado, que era el reparo del hallazgo 4.
— *Coste si me equivoco:* si la tarjeta legitimamente midiera distinto suelta que en rejilla,
el implementador debe pararse y decirmelo en vez de volver a un umbral.

**Ruling 29: el hallazgo 5 (2.1 vs 2.2) baja a Minor y solo exige explicacion, no cambio.**
El brief decia "sube el ratio a 2.2" como sugerencia dentro de un "si el AspectRatio del padre
es el que impone la altura". El valor exacto es una decision de diseno visual, no de
correccion; 2.1 no es peor que 2.2. Solo pido que el reporte diga por que.
— *Coste si me equivoco:* las tarjetas quedan ~5% mas altas de lo que el plan imaginaba.

**Ruling 30: el hallazgo 6 (`Colors.blue` en el test) NO se arregla.**
La regla de CONVENTIONS.md §2.1 existe para que la UI respete el tema; un color literal como
dato de entrada de un fixture de test no viola ese proposito y sustituirlo por un token del
tema solo anade acoplamiento al test. — *Coste si me equivoco:* ninguno funcional.

**Ruling 31: se abre la costura en `AuthService`, no se mockea `FirebaseAuthPlatform` ni se
acepta el hueco.**
El implementador ofrecia dos salidas (construir el mock de plataforma, o aceptar el hueco).
Hay una tercera y es mejor que las dos: `needsEmailVerification` ya consulta al `AuthService`
inyectado para `isEmailPasswordUser` y `isCurrentUserEmailVerified`; la lectura de
`FirebaseAuth.instance.currentUser` es **la unica de las tres que se salta la costura**. Se
anade a `AuthService` un getter que exponga si hay usuario (junto a los ya existentes
`isCurrentUserEmailVerified`, auth_service.dart:152, e `isEmailPasswordUser`, :155) y el
provider pasa a preguntarselo. Con eso, un `MockAuthService` — que **ya existe generado** en
test_helpers.mocks.dart:200 — abre el dialogo de login sin tocar plataforma ninguna.
— *Por que:* es el mismo movimiento que cerro la T7 (abrir la costura de DI en vez de
documentar el hueco), arregla una inconsistencia real del provider, y evita meter en el repo
un patron de mocking pesado que no usa nadie mas. — *Coste si me equivoco:* un getter mas en
AuthService y una linea cambiada en el provider; si algo dependiera del acceso directo al
singleton, lo caza la suite de auth.

**Ruling 32: el test de semantica de la barra superior va en `test/`, no en `integration_test/`.**
El brief lo situa en `integration_test/top_nav_semantics_test.dart`. Verificado:
- `.github/workflows/ci.yml:40` corre `flutter test --coverage`, que solo recorre `test/`.
- `integration_test/` (hoy: alert_flow, auth_flow, vehicle_flow) **exige un dispositivo o
  emulador** y CI no lo ejecuta nunca; el propio `/test` del repo lo documenta como una suite
  aparte que hay que lanzar a mano tras comprobar `flutter devices`.
O sea: tal como lo pide el plan, el test de regresion de accesibilidad **no correria en CI** y
la regresion podria volver sin que nadie se entere — que es justo lo contrario de para lo que
existe. Y no necesita dispositivo: `tester.ensureSemantics()` + `pumpAtWidth` es un widget
test normal. Va a `test/core/widgets/`. — *Coste si me equivoco:* si resultara necesitar
dispositivo de verdad, el implementador debe pararse y decirmelo; entonces va a
`integration_test/` y se anota que CI no lo cubre.

**Ruling 33: la T16 se parte; el reemplazo del placeholder NO lo hace un agente.**
La tarea mezcla tres cosas de naturaleza distinta:
  (a) corregir el mensaje enganoso y anotar `.env.example` — codigo, se hace ahora;
  (b) poner la key real en `.env` — **accion humana**, ya estaba marcada como tal en el plan;
  (c) sustituir `assets/images/default_vehicle.jpg` (395 KB, foto de un Mercedes Clase C) por
      una silueta neutra — **accion humana tambien**.
Saco (c) del alcance del agente: producir un asset grafico decente no es algo que un
subagente pueda hacer bien, y un placeholder improvisado seria peor que el actual (hoy al
menos es una foto de coche; una silueta mal hecha se ve como un fallo de carga). Queda para
la lista de acciones humanas junto al deploy de reglas y la key.
— *Coste si me equivoco:* el hallazgo de diseno "el placeholder es un Mercedes" sigue abierto
hasta que alguien aporte la imagen; lo dejo explicito en el resumen final en vez de darlo por
cerrado en silencio.
**Ruling 34: la carrera se cierra marcando los uids en vuelo, y el test tiene que solapar de
verdad las emisiones.**
El arreglo es un `Set` de uids en vuelo consultado junto a `_identidades` al calcular los
pendientes, o meter un placeholder en la cache al empezar. Lo que NO acepto es solo cambiar el
test: el hallazgo es del codigo. Y el test nuevo debe emitir **sin** los
`await Future.delayed(Duration.zero)` que hoy serializan, para que la segunda emision entre
con la primera hidratacion en vuelo — si no, vuelve a no cazar nada.
— *Coste si me equivoco:* un `Set` mas de estado transitorio en el provider.

**Ruling 35: entran en la misma ronda dos Minor que protegen las desviaciones del propio
implementador.**
No son polish: cada uno cubre justo el mecanismo que el implementador eligio por su cuenta y
que hoy nadie verifica.
  (a) ningun test comprueba que "Rechazar" se pinte en `colors.error`; el test solo mira orden
      y `type`. Si alguien quita el `Theme(...)` de la desviacion A, la app vuelve a pintar el
      destructivo en color de acento y **nada falla**. Ese era el hallazgo de diseno del QA.
  (b) `find.text(uid) findsNothing` no es vacuo, pero si alguien **borrara** la linea
      "ID: {uid}" entera el test seguiria pasando. Falta afirmar que la linea existe y es
      subordinada.
— *Por que:* una desviacion que el implementador defiende y que ningun test sujeta es deuda
disfrazada de decision. — *Coste si me equivoco:* dos aserciones mas en un fichero de test.

**Ruling 36: `correoTaller` NO se implementa; se aparca.**
La linea "Produces" del brief promete `nombreTaller, correoTaller`, pero el propio Step 3 del
brief nunca setea `correoTaller`: es una incoherencia interna del plan, no un hueco del
implementador. El hallazgo del QA era que el admin no sabe **a quien** aprueba, y el nombre
mas la especialidad lo resuelven. Anadir el correo del taller a una pantalla de admin es
ademas exponer un dato personal mas sin que nadie lo haya pedido.
— *Coste si me equivoco:* si el admin necesitara contactar al taller desde ahi, falta un dato;
es aditivo y trivial de anadir despues.

**Ruling 37: se arregla, y es exactamente el tipo de deuda que mas me importa.**
No es funcional, es de honestidad del registro: un test de caracterizacion disfrazado de test
de regresion miente al proximo lector sobre que esta protegido. Basta un comentario en el
propio test. — *Coste si me equivoco:* ninguno; es una linea de comentario.

**Ruling 38: el `flutter clean` va antes de LOS DOS `flutter build web`, no de uno.**
El brief dice "antes del paso de `flutter build web`", en singular. En `.github/workflows/ci.yml`
hay **dos**: produccion (:171-180) y staging (:266-278). Poner la limpieza solo en uno deja el
otro despliegue con exactamente el bug que la tarea arregla (bundle incompleto por build
incremental sobre un `build/` sucio). — *Coste si me equivoco:* dos builds algo mas lentos en
CI, que es un precio irrisorio comparado con desplegar un bundle roto.

**Ruling 39: los errores de Auth se mapean en la capa de presentacion, no dentro del servicio.**
El Step 2 del brief escribe `l10n.authNetworkError` **dentro de `auth_service.dart`**. No se
puede: `l10n` sale de un `BuildContext` y un servicio no tiene contexto — el snippet del plan
no compila. Ademas `_handleAuthException` (auth_service.dart:163-186) ya devuelve **nueve**
cadenas en espanol hardcodeadas; pasarlas todas a l10n es un refactor de capa, no el hallazgo.
Lo vinculante es el hallazgo del QA: el `default` (:184) interpola `e.message`, que viene en
ingles del SDK, y produce la frase mitad y mitad que se vio en pantalla. Alcance de esta
tarea: que el servicio devuelva un **codigo estable** (o que el default deje de interpolar el
mensaje crudo del SDK) y que la traduccion ocurra donde hay contexto. Migrar las otras ocho
cadenas queda anotado como deuda, no se hace aqui.
— *Coste si me equivoco:* el usuario sigue viendo ocho cadenas en espanol fijo aunque ponga la
app en ingles; ya era asi antes de esta rama, y arreglarlo entero no cabe en el presupuesto.

Nota menor: el brief cita `app_es.arb:613`; la clave `upLanguageDesc` esta en la **:626** de
ambos ficheros.
**Ruling 40: la re-revision de la T12 la hago yo, y lo dejo escrito en vez de saltarmela en
silencio.**
El diff es **solo comentario y descripcion de un test**: cero cambios de comportamiento, cero
produccion. Lo verifique leyendolo entero: el comentario nuevo explica que WorkshopsGrowthChart
es un BarChart cuyas posiciones salen de `calculateGroupsX`/`barGroups[].x` y no de `interval`,
que por eso nunca exhibio el bug y que el test ya pasaba en rojo; y la descripcion del test
deja de ser identica a la de los tres de regresion reales. Es exactamente lo que pedia la
Ruling 37. Dispatchar un re-revisor completo para dos parrafos de prosa no compra nada y el
presupuesto de sesion esta al 83%. — *Por que lo escribo:* saltarse una re-revision en
silencio es justo lo que el proceso prohibe; hacerlo declarado y con el motivo es una decision
auditable. — *Coste si me equivoco:* es texto; si el comentario dijera algo inexacto, el review
final de rama lo ve.
**Ruling 41: el `flutter clean` va antes de los TRES `flutter build web`, y su comentario no
puede mentir sobre por que esta ahi.**
La Ruling 38 dijo "dos" y ademas identifico mal las lineas: llamo "produccion" al build de
`:180`, que en realidad es el job `build_web_smoke` (FLAVOR=dev, no despliega). Los tres son:
`build_web_smoke` (:180), `deploy_staging` (:278) y `deploy_production` (:420). Van los tres:
dejar fuera el smoke es dejar sin limpiar justo el job cuya razon de existir es cazar un bundle
roto antes de que llegue a un deploy. Segunda mitad de la ruling, y es la que importa: en CI
cada job corre en un runner nuevo con `actions/checkout`, y el `cache: true` de
`subosito/flutter-action` cachea el SDK, **no** el `build/` del proyecto — o sea que en CI
`build/` ya empieza vacio y el `flutter clean` es una salvaguarda barata, no el arreglo de un
fallo vivo. El bundle incompleto del informe de QA se reprodujo **en local**. El comentario del
paso tiene que decir eso; escribir "esto evita que se despliegue un bundle roto" seria dejar en
el repo una afirmacion falsa. — *Coste si me equivoco:* unos segundos por job y un paso que
quiza nunca haga nada; si resultara que algo si ensucia `build/` entre pasos, ya esta cubierto.

**Ruling 42 (refina la 39): el mapeo de errores de Auth se queda DENTRO de `auth_service.dart`.**
La Ruling 39 dejo dos salidas; elijo la del parentesis. Motivo: los cuatro keys de l10n del
brief no existen, y crearlos obligaria a migrar tambien las nueve cadenas en espanol que ya
viven en `_handleAuthException` — un refactor de capa que la propia Ruling 39 excluyo. Alcance
vinculante: (a) anadir `case 'network-request-failed'` con una cadena en espanol del mismo
registro que sus nueve vecinas, y (b) que el `default` deje de interpolar `e.message`. La
migracion de las diez cadenas a l10n queda anotada como deuda, no se hace aqui.
— *Coste si me equivoco:* con la app en ingles el usuario sigue viendo estas cadenas en
espanol; ya era asi antes de esta rama.

**Ruling 43: la T19 arregla una incoherencia ENTRE VEHICULOS, no dentro de `_generateSmartAlerts`.**
El Step 3 del brief pide "que la alerta critica y la tarjeta de sugerencia deriven del mismo
`getStatus`" — pero eso **ya se cumple** (alert_provider.dart:211-213). La causa real, leida en
el codigo: `fetchAlertsForVehicles` (:107-141) recorre todos los vehiculos y **acumula
`_alerts` de todos**, mientras `_maintenanceTasks` se queda con las tareas del **ultimo**
vehiculo procesado (su propio docstring :99-106 lo declara intencionado). Luego
`alerts_screen.dart:215-216` gradua esas tareas contra el odometro del vehiculo
**seleccionado**. Resultado exacto del hallazgo del QA: "Rotacion de Llantas" sale CRITICA en
PRIORIDAD ALTA (alerta generada para otro vehiculo) y OPTIMA en SUGERENCIAS (tarea de otro
vehiculo graduada contra los 254 km del seleccionado). Invariante vinculante: **en la pantalla,
la lista de alertas y la de tareas tienen que describir al mismo vehiculo**. Ambos modelos ya
llevan el id (`AlertModel.idVehiculo`, `MaintenanceTask.vehicleId`), asi que se filtra; no se
toca ningun modelo. — *Coste si me equivoco:* si el filtrado se hace en el sitio equivocado, el
dashboard multi-vehiculo podria dejar de mostrar alertas de los no seleccionados, que es
justamente lo que `fetchAlertsForVehicles` existe para dar; por eso el filtro va en el punto de
render de /alerts, no dentro del provider.

**Ruling 44: el odometro incoherente NO se reporta por `_error`.**
El Step 1 del brief pide `expect(provider.error, contains('kilometraje'))`. `_error` significa
"la carga fallo" y `fetchAlertsForVehicles` lo propaga (:139) para pintar un estado de error de
pantalla completa; usarlo para un dato inconsistente de UNA tarea apagaria toda la pantalla de
alertas por un dato corregible. Se representa como lo que es: una alerta propia de esa tarea
(`tipoAlerta` propio, prioridad alta) que dice que el odometro es menor que el ultimo servicio y
ofrece corregir el kilometraje — que es lo que el propio Step 3 del brief pide de palabra.
— *Coste si me equivoco:* el test del brief hay que reescribirlo contra la alerta en vez de
contra `error`; es el test el que se adapta al diseno correcto, no al reves.

**Ruling 45 (refina la 3): la T17 abre la costura minima, y solo cae al plan B si no cabe.**
La Ruling 3 libero a la tarea de refactorizar `main.dart` a `bootstrapServices(push:)`, que no
existe. Pero una tarea de rendimiento sin test automatico es una tarea que se puede deshacer sin
que nadie lo note. Orden: intentar primero una costura de ~10 lineas — una funcion de nivel
superior que arranca el push y **retorna sincronamente**, con el servicio inyectable — y
testear que retorna aunque `initialize()` no complete nunca. Si eso obliga a cambiar la forma
publica de `PushNotificationService`, se para y cae al plan B de la Ruling 3 (`unawaited` sin
test, verificacion manual), diciendolo. — *Coste si me equivoco:* diez lineas de costura de
test en `main.dart`.

**Ruling 46: la T14 se reduce al `assert` y a los call sites; el campo y el `Semantics` ya estan.**
El Step 3 del brief pide anadir `semanticLabel` a `AppCard` — ya esta. La tarea real es el
`assert(onTap == null || semanticLabel != null)` y barrer los 30 ficheros que construyen
`AppCard` (Ruling 5). Y el test nuevo no puede duplicar `app_card_test.dart:113-120`, que ya
afirma que el label se expone: lo que falta por cubrir es el `assert` y el rol de boton.
— *Coste si me equivoco:* un test de mas, redundante.

Tasks 16+18: RE-dispatch batcheado (BASE d04e660, sonnet) — el de la sesion 2 no aterrizo nada.
         Dos commits separados para que cada tarea siga siendo revisable por si sola. Van
         dentro: la Ruling 33 (T16 solo mensaje + comentario de .env.example; le prohibo
         explicitamente el asset y la key), la Ruling 41 (clean antes de LOS TRES build web, y
         el comentario tiene que decir que en CI es salvaguarda, no arreglo de un fallo vivo),
         la Ruling 42 (mapeo dentro del servicio: case 'network-request-failed' + default que
         deja de interpolar e.message) y la correccion de la linea 626 de upLanguageDesc. Le
         prohibo tocar nada mas de ci.yml.

**Ruling 47: la premisa de la Ruling 5 era falsa; el `assert` NO lo caza `flutter analyze`, y
la red pasa a ser la suite de tests.**
La Ruling 5 escribio: "El `assert` rompe la compilacion de cualquiera que falte, asi que la
tarea no esta hecha hasta que `flutter analyze` este limpio". Eso no es cierto en Dart: un
`assert` en un constructor es una comprobacion de **tiempo de ejecucion** activa solo en modo
debug. `flutter analyze` no mira dentro de los asserts y no puede saber si un call site pasa
`semanticLabel`; la compilacion no falla y el build de release ni siquiera evalua el assert.
Considere subir `semanticLabel` a `required` (eso si es error de compilacion) y descartarlo:
obligaria tambien a las `AppCard` **no** interactivas, que no deben tener label porque no son
botones. Considere partir en dos constructores (`AppCard` estatica + `AppCard.tappable`
con ambos `required`), que es el diseno que de verdad da la garantia en compilacion, y tambien
lo descarto: rediseñar la API publica del widget excede lo que el plan pide y lo que el
hallazgo §13 necesita.
Decision: se queda el `assert` con el texto exacto del plan — en debug (o sea: en desarrollo y
en **todos** los widget tests) revienta en el acto y con un mensaje que explica el porque, que
es el idioma normal de Dart para esto. Pero la red de seguridad deja de ser `flutter analyze` y
pasa a ser: (1) barrido manual y exhaustivo de los ficheros que construyen `AppCard`, y (2) la
suite completa en verde, que es la que ejercita los call sites de verdad. Al implementador se
lo digo explicitamente, porque si cree la Ruling 5 se fiara de un analyze limpio y dara la
tarea por hecha con call sites sin label.
— *Coste si me equivoco:* un `AppCard(onTap:)` en una pantalla que ningun test pumpea se queda
sin label y no lo caza nadie hasta que alguien la abra en debug. Lo asumo: es exactamente el
alcance que el plan eligio, y el barrido manual lo cubre salvo despiste.
Tasks 16+18: el implementador se paro a media tarea esperando un `flutter analyze` lanzado en
         background y reporto sin haber commiteado; sus ediciones estaban en el arbol. Lo
         reanude ordenandole verificar en primer plano (y partir `flutter test` por
         directorios si no cabia en el timeout, diciendolo). Implementado — commits 39e941e
         (T16) y e8578aa (T18). analyze limpio; `flutter test` partido en 5 corridas = 900
         pasados, 0 fallidos (firestore_rules e integration_test son suites aparte y no
         entran). Dos desviaciones que el propio implementador declaro y que paso al revisor
         para que las juzgue en vez de aceptarlas yo: (A) reescribio entera la cabecera
         `# Google Custom Search API` de `.env.example` en vez de solo anotarla, alegando que
         contradecia la fuente real (SearchAPI.io); (B) una rareza de `flutter test` con varios
         ficheros sueltos como argumento.
Tasks 16+18: revision dispatchada (diff d04e660..e8578aa, sonnet). Le paso las cuatro enmiendas
         a los briefs (Rulings 33, 41, 42 y la linea 626) COMO requisitos, no como excusas, y
         le pido explicitamente que compruebe el diff fichero a fichero por ser un batch. Le
         senalo ademas donde es mas probable el defecto en esta tarea concreta: que un texto o
         comentario NUEVO afirme algo falso — seria reintroducir en otro sitio exactamente el
         defecto que la T16 arregla.
Tasks 16+18: revision limpia. Spec ✅ en los cuatro puntos (mensaje de la key, upLanguageDesc,
         `case 'network-request-failed'` + `default` sin `e.message`, y `flutter clean` en los
         TRES build web). Cero Critical, cero Important. El revisor confirmo lo que mas me
         importaba: el comentario del `flutter clean` dice literalmente "salvaguarda barata, no
         el arreglo de un fallo vivo" y explica el porque — no quedo ninguna afirmacion falsa
         en el repo, que era el riesgo propio de esta tarea. La desviacion (A) del implementador
         (reescribir la cabecera de `.env.example`) el revisor la juzgo Minor y bien razonada:
         la cabecera vieja era falsa y habria contradicho la anotacion nueva.

**Ruling 48: el ⚠️ del revisor sobre el `flutter clean` en CI no es un hueco; ya lo respondi al
escribir la Ruling 41.**
El revisor marco como no verificable "que el `flutter clean` resuelva el hallazgo en un run real
de CI". No hay nada que verificar: la Ruling 41 ya establecio que en CI `build/` empieza vacio y
que el paso es una salvaguarda, no el arreglo de un fallo reproducible en ese pipeline — el
bundle roto se reprodujo en local. Un CI verde tras el push no demostraria nada y un CI rojo
seria por otra causa. Lo cierro yo aqui en vez de arrastrarlo. — *Coste si me equivoco:* si algo
si ensuciara `build/` entre pasos de un job, el paso ya lo cubre igualmente.

Tasks 16+18: minors (deferred): (a) `.env.example:35-40` reescribe la cabecera entera en vez de
         solo anotarla (excede levemente la instruccion literal, bien razonado); (b) ningun test
         protege las dos correcciones de copy — ni el `default` de `_handleAuthException` sin
         `e.message` ni el mensaje de `vehicle_image_service`. La (b) me parece la que de verdad
         merece triaje en la revision final: el hallazgo original de QA era literalmente "el
         texto miente", y sin test ese texto puede volver a mentir sin que analyze ni la suite
         se enteren. No entra al fix loop porque es Minor y el brief no pedia test, pero la
         apunto para que la revision de rama decida.
Tasks 16+18: complete (commits d04e660..e8578aa, review clean)
**Ruling 49: el hallazgo (1) se arregla, aunque cae fuera del alcance literal del brief.**
El brief dice "todos los call sites con `onTap`" y en `workshop_directory_screen.dart` el `onTap`
esta en un `GestureDetector`, no en el `AppCard` — literalmente, fuera. Mando igual, y decido
contra el texto del plan porque la autoridad vinculante es el hallazgo §13 del informe de QA, no
la redaccion del brief: §13 dice que las tarjetas interactivas no tienen nombre accesible, y
esta es una tarjeta interactiva sin nombre accesible. Tres cosas mas lo inclinan: es **peor** que
el caso original (ni siquiera hay rol de tap, asi que un lector de pantalla no la anuncia como
pulsable en absoluto); es **exactamente el mismo refactor** que el propio implementador ya hizo
en esta misma tarea en "Talleres Cercanos", asi que no le pido nada que no haya hecho ya; y
dejarlo convierte la garantia que esta tarea instala —el assert— en una garantia con un agujero
conocido y sin marcar, que es la peor clase de red de seguridad. — *Coste si me equivoco:* un
fichero mas tocado en una tarea de accesibilidad, y el riesgo acotado de que mover el `onTap` del
`GestureDetector` al `AppCard` cambie el comportamiento de centrado del mapa; por eso le exijo
que el test cubra que la accion sigue ocurriendo, no solo que el label exista.
**Ruling 50: el `AppNavRail` de `medium`/`expanded` entra en el alcance de la T15.**
El implementador lo dejo fuera por alcance y el revisor lo confirmo por lectura de codigo: misma
forma estructural, mismo defecto, 600–1199 px. Mando arreglarlo por el mismo motivo que la
Ruling 49: la autoridad vinculante es el hallazgo §13 —"la navegacion principal es inalcanzable
con teclado y lector de pantalla"— y no el ancho concreto en el que el QA lo midio. Cerrar §13
solo para escritorio ancho y declararlo cerrado seria un cierre falso: los usuarios de tablet
y ventana media se quedan exactamente igual que antes, y nadie lo sabria porque el ticket
figuraria resuelto. Es ademas el mismo mecanismo en el mismo fichero, asi que el coste marginal
es minimo comparado con abrir otro plan. **Con la misma condicion que impuse para `large`: hay
que demostrarlo con un rojo a un ancho medio antes de aplicar nada** — no acepto extender el
arreglo por analogia estructural, que es precisamente el error que el plan cometio con `large`.
— *Coste si me equivoco:* si a ancho medio el mecanismo resultara distinto, el rojo no aparecera
y lo sabremos antes de tocar nada; el coste es una corrida de test.

**Ruling 51: el orden del fix de la T15 es primero el experimento decisivo, y el resto depende
de su resultado.**
El Important 1 no es "anade una prueba mas": es una pregunta cuya respuesta cambia el diff. Si
el wrap de `AppTopNavBar` resulta innecesario, hay que **quitarlo** de un widget central junto
con sus 15 lineas de comentario, y entonces el Minor (a) se resuelve solo. Si resulta necesario,
se queda y el comentario pasa a estar respaldado. Por eso le exijo ese experimento **antes** que
las otras dos piezas, y le prohibo empezar por el nav rail. — *Por que:* dejar en un widget del
que cuelga toda la app un envoltorio que quiza no hace nada, con un comentario que afirma que si,
es peor que no haber tocado nada: convierte una suposicion en documentacion.
— *Coste si me equivoco:* una corrida de test extra.
**Ruling 52: acepto la desviacion de la enmienda 3; lo que no acepto es que no se declarara.**
Mi enmienda decia que los helpers que el brief nombraba no existian y que crearlos era parte de
la tarea, senalando los precedentes `@visibleForTesting`. El implementador construyo
infraestructura de test de **otra forma** —subclases que sobreescriben getters, el mismo patron
del `_FakeAlertProvider` que ya existia en el repo— y no creo ningun seam. Lo acepto porque el
sustituto es **mejor que lo que pedi**, y esto lo dice el revisor, no el implementador: el test
de provider usa `FakeFirebaseFirestore` + `fetchAlerts` real, o sea que ejercita el camino de
produccion entero incluyendo `_generateSmartAlerts`, mientras que un seam de inyeccion directa
se habria saltado justo esa parte. Lo vinculante de la enmienda 3 era que hubiera
infraestructura de test y un rojo real, no la forma concreta; exigir el seam ahora seria
degradar el test para cumplir la letra de una instruccion mia.
Lo que si es un defecto real es de honestidad del informe: la desviacion aparece solo dentro del
"Auto-revision", no entre las desviaciones declaradas, y a la vez responde "Si" a "¿implemente
lo pedido y nada mas?". Esas dos cosas no pueden ser ciertas a la vez. No abro ronda por eso
—el codigo esta bien y el registro queda aqui—, pero lo dejo escrito porque un informe que
declara dos desviaciones y esconde la tercera erosiona justo aquello por lo que el informe
existe. — *Coste si me equivoco:* ninguno en codigo; si alguien busca los seams por nombre no
los encontrara, y este parrafo le dice por que.

**Ruling 53: el semaforo del dashboard entra en alcance, con rojo previo.**
El revisor encontro fuera del diff `dashboard_screen.dart:464-482` (`_buildMaintenanceSemaphore`):
gradua `provider.maintenanceTasks` —que tras `fetchAlertsForVehicles` guarda las tareas del
**ultimo** vehiculo procesado— contra el odometro del vehiculo **seleccionado**. Es la mecanica
exacta del §16, viva en otra pantalla. Es preexistente, no lo introdujo este diff, y el brief
acotaba a `/alerts`, asi que el revisor hizo bien en no bloquear por ello.
Mando arreglarlo, por tercera vez en esta rama el mismo razonamiento (Rulings 49 y 50): la
autoridad vinculante es el hallazgo §16 —"la misma tarea sale critica y optima a la vez"— y no
la pantalla concreta donde el QA lo fotografio. Cerrar §16 dejando la misma mentira en el
semaforo del dashboard seria un cierre falso, y encima del tipo peor: el ticket figuraria
resuelto. El arreglo es ademas **el mismo filtro de una linea** que ya se acaba de escribir al
lado. **Con la misma condicion de siempre: rojo primero.** Aqui importa mas que nunca porque el
bug es dependiente del orden —si el vehiculo seleccionado resulta ser el ultimo procesado no se
manifiesta—, asi que si el rojo no aparece, la lectura del revisor es incompleta y hay que
pararse. — *Coste si me equivoco:* si el rojo no sale, lo sabremos antes de tocar nada y el
coste es una corrida de test.
**Ruling 54: la Ruling 43 estaba equivocada, y el Critical es consecuencia directa de mi error.**
Escribi que el filtro por vehiculo iba en el punto de render y **no** dentro del provider, para no
romper `fetchAlertsForVehicles` en el dashboard multi-vehiculo. El razonamiento estaba invertido.
Lo que el revisor demuestra leyendo el codigo: `fetchAlerts` **reasigna** `_maintenanceTasks`
entero en cada iteracion (`alert_provider.dart:67-72`), asi que al terminar el bucle esa lista
contiene **solo las tareas del ultimo vehiculo procesado**. Y el vehiculo seleccionado es el
**primario** (`vehicle_provider.dart:122-127`: `firstWhere((v) => v.isPrimary)`), que en general
**no** es el ultimo de `[...owned, ...shared]`. Conclusion: filtrar en el render por
`t.vehicleId == seleccionado.idVehiculo` sobre una lista que casi nunca contiene al seleccionado
deja la lista **vacia**. Resultado en produccion, para cualquier dueno con mas de un vehiculo
cuyo primario no sea el ultimo:
  - el semaforo de mantenimiento del dashboard **desaparece** (`SizedBox.shrink()`);
  - **/alerts no muestra ninguna tarea de mantenimiento**, en la pantalla cuya razon de ser es
    esa lista.
O sea que convertimos "datos de mantenimiento equivocados" en "ningun dato de mantenimiento".
Es exactamente el **apagado encubierto** que yo mismo habia nombrado como riesgo en el dispatch
de la T19 y que luego aplace en el triaje — y el argumento con el que lo aplace ("el `.where` es
puramente restrictivo") es literalmente la razon por la que falla: restrictivo contra una lista
que no contiene al vehiculo correcto. Nombre el riesgo y despues razone en la direccion opuesta.
Ademas los dos tests nuevos **codifican el apagon como comportamiento deseado**
(`dashboard_screen_semaforo_test.dart:35-40` describe su fixture como "igual que le pasaria de
verdad" y afirma que no se pinta nada), y el test de /alerts en el que me apoye para aplazar
(`alerts_screen_test.dart:56-108`) pasa **por el motivo equivocado**: su fake devuelve tareas de
`'v-otro'` **y** de `'v0'` a la vez, un estado que `fetchAlertsForVehicles` no puede producir
nunca.
Correccion: **fusionar `_maintenanceTasks` en `fetchAlertsForVehicles`** igual que se fusiona
`mergedAlerts`, borrar el parrafo del docstring (:99-106) que ya sera falso, y **conservar** los
filtros del punto de render, que son justo lo que hace segura la fusion. Un cambio pequeno en el
provider vuelve correcto el filtro y deja sin objeto el minor aplazado.
— *Coste de mi error si no se hubiera cazado:* una regresion de produccion peor que el bug
original, en dos pantallas, invisible para toda la bateria de tests de la rama.

**Ruling 55: el §13 no esta cerrado; falta la mitad que el propio informe de QA nombra por ruta.**
El revisor encontro que §2.13 del informe describe **dos** defectos y solo uno tuvo tarea. El
segundo, citado literalmente: "Taller: la barra lateral si esta expuesta … **excepto en
`/chat_list`**, donde desaparece del arbol. Es la ruta que pasa por `_MechanicShell`".
`MechanicScaffold` (`mechanic_scaffold.dart:76-84`) tiene la forma **estructuralmente identica**
al `_OwnerShell` que la T15 arreglo: un hermano al lado del `Expanded` que lleva el `Navigator`
anidado de la `ShellRoute`. No se toco, y no hay test. Grep del ledger: cero menciones de
`_MechanicShell`, `MechanicScaffold` o `chat_list` — se paso por alto, sin mas.
Mando arreglarlo aplicando **mi propia Ruling 50 a mi propio trabajo**: escribi alli que "cerrar
§13 solo para escritorio ancho y declararlo cerrado seria un cierre falso"; el mismo argumento,
mas fuerte todavia, vale para la mitad que el informe nombra por ruta. Misma condicion: rojo a
1024 px antes de tocar. — *Coste si me equivoco:* ninguno; si el rojo no sale, la forma
estructural enganaba y se para.

**Ruling 56: el defecto de granularidad del plan se apunta como leccion, no se arregla aqui.**
El revisor senala la causa de raiz de por que se colo lo anterior: la tabla de cobertura del plan
mapea **secciones** del informe de QA a tareas, pero varias secciones contienen **dos** hallazgos
(§2.3 ano *y* color, §2.13 barra superior *y* rail del taller, §2.11 mensaje *y* placeholder).
"Los 17 hallazgos tienen tarea" era cierto por seccion y falso por hallazgo. No lo arreglo en
esta rama —es una leccion para la proxima tabla de cobertura— pero lo escribo porque explica el
unico hueco real que quedo y porque es reutilizable.

**Rulings que el revisor respalda sin reservas:** 41/42, 43/44 (con la correccion de la 54:
el sitio del filtro es defendible **una vez** fusionado el provider), 47, 51, 52. La 49/50/53 las
respalda en principio y me las devuelve aplicadas a mi propio trabajo (ver Ruling 55). La 33 la
da por buena como accion humana, con la condicion de reportar el §11 como **parcialmente**
cerrado, porque "el placeholder es un Mercedes" era la mitad del hallazgo.

---

## Veredicto de la revisión final de rama

La revisión final (30 commits, cinco pasadas) dio **«con arreglos»**: un Critical —el de las
Rulings 43/54— y seis Important, entre ellos el `/chat_list` de la Ruling 55. Se aplicó una
única ola de arreglos (7 commits, uno por hallazgo) y su re-revisión los dio todos por
resueltos, sin rupturas nuevas, con veredicto **lista para integrar**.
