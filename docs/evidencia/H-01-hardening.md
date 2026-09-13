# H-01 — Hardening y matriz final de evidencia

**Rama:** `hardening/h-01`, cortada de la punta de `integracion/ola-1` (`c5be109`).
**Fecha:** 2026-09-13.

Todo sale de emuladores y fixtures efímeros. Ninguna corrida toca producción ni cuentas
reales, y no se ha ejecutado ningún `firebase deploy`.

## 1. Gates por workstream

| Gate | Comando | Resultado |
|---|---|---|
| Análisis estático | `flutter analyze` | `No issues found!`, exit 0 |
| Unitarias y de widget | `flutter test` | **1227 / 1227**, `All tests passed!` |
| Cloud Functions | `cd functions && npm test` | **276 passing**, exit 0 |
| Reglas de Firestore y Storage | `cd test_rules && npm test` | **465 / 465**, 28 suites, exit 0 |
| Build de la landing | `cd e2e && npm run build:landing` | exit 0 |
| E2E de la landing | `cd e2e && npm run test:landing` | **42 / 42**, exit 0 |
| E2E de la app | `cd e2e && npx playwright test --workers=1` | **37 / 37**, exit 0, **cero `fixme`** |
| Puertos al salir | `netstat -ano` | 0 en LISTENING |

La E2E de la app va **en serie**. En paralelo su rojo no es señal: cuatro workers arrancando
la app a la vez ahogan al emulador Java y lo que se pierde es la primera lectura del perfil.
Está documentado desde SEC-04/OPS-01 y sigue siendo cierto.

## 2. Lo que H-01 encontró

Los tres son defectos que **ninguna suite existente podía ver**, y los tres se encontraron
leyendo, no corriendo.

### 2.1 Una cita que falla al guardarse se anuncia igual en el chat

`ReservaProvider.solicitarReserva` devuelve `''` cuando la escritura falla y guarda el motivo
en `error`. `chat_screen.dart:353` **no miraba ese valor**: publicaba el mensaje `reserva_card`
igual, con `id_reserva: ''` en la metadata.

Lo que veían las dos personas del hilo: una propuesta de cita con su fecha y su hora, con el
botón «Ver detalle» **activo**, que lleva a `/reserva_detail/` sin id. Ningún error en
pantalla. El mensaje queda persistido, así que no es un parpadeo: se queda ahí.

Las guardas de `reserva_chat_card.dart` miraban `== null` en **cuatro** sitios y `''` no es
null, así que pasaba por las cuatro — incluida la que escribe el estado, que habría intentado
`cambiarEstadoReserva('')`.

Es la enfermedad de DATA-01 —un artefacto público sin su registro de respaldo— un piso más
abajo, en reservas en vez de cotizaciones.

**Cerrado** con una guarda en el emisor (no se publica la tarjeta si la reserva no existe, y
se avisa) y un normalizador `_idDeReserva()` que trata ausente y vacío como el mismo caso en
los cuatro sitios.

**Y una corrección sobre mi propio diagnóstico.** Al abrirlo escribí que un id vacío reventaba
el hilo entero, porque `collection('reservas').doc('')` no es una ruta válida. El test lo
desmintió: con `FakeFirebaseFirestore` no lanza. No he verificado que Firestore real lo haga,
así que **no lo afirmo**. El defecto probado es el botón vivo y la tarjeta fantasma, que ya
basta.

### 2.2 La séptima salida de sesión, y por qué NO se arregló

`email_verification_screen.dart:99` llama `auth.signOut()` a secas. Las otras seis salidas
—incluidas sus dos pantallas hermanas de pre-dashboard, `profile_setup` y `mechanic_pending`—
llaman antes a `clearSessionFrom`.

Lo que no lo veía: `session_reset_test.dart` prueba que `clearUserScopedProviders` hace su
trabajo, que es otra cosa. **No lee el código fuente**, así que no puede saber quién la llama.

Escribí el centinela, lo vi en rojo señalando ese archivo y ninguno más, y **añadí la llamada.
Rompió dos casos de `email_verification_screen_test.dart`**, y perseguirlo destapó por qué no
merece la pena:

- `clearSessionFrom` lee **los siete** providers con estado por usuario del contexto. Ese test
  declara en su propio comentario que reemplaza las pantallas con datos por marcadores «so
  this test never initializes live Firebase services». Meterle los siete contradice su diseño.
- Y al forzarlos, el logout moría con `[core/no-app]` **dentro del `catch (_)` de `_run`**, o
  sea en silencio: la pantalla se quedaba en el gate mostrando «no se pudo enviar el correo».

Entonces verifiqué si la limpieza hace falta ahí, en vez de suponerlo. **No hace falta:** el
redirect manda a `/verify_email` a toda sesión no verificada (`app_router.dart:246-250`) y no
la deja pasar a ninguna pantalla que cargue datos, así que los providers están vacíos cuando
se llega. Y una cuenta verificada no puede volver a no estarlo, así que no hay camino desde
una sesión con datos.

**Resultado:** el cambio de producción **está revertido**. Lo que queda es el centinela
`test/core/providers/salidas_de_sesion_test.dart`, con esa pantalla en un mapa `_exentas` que
guarda la razón —no «es incómodo de probar», sino la garantía del router— y un segundo test
que falla si una exención se queda huérfana, porque una exención sin archivo es una regla
relajada sin que nadie lo decidiera.

Las seis salidas que sí manejan datos quedan obligadas, y una séptima que nazca mañana también.

### 2.3 El registro por UI llevaba entero en `fixme`

Es la **primera fila del §8** del plan —registro válido / inválido / duplicado— y estaba sin
verificar. La aceptación de H-01 es «ningún no-verificado crítico», así que no podía quedarse.

**La razón escrita en el `fixme` era falsa a medias**, y otra vez en la dirección que manda a
reconstruir de más:

- «los rótulos que buscan estos tests ya no existen» — **falso**. `authRegisterFree`,
  `authCreateAccount` y `authRegisterButton` siguen vivos en los ARB. Lo que cambió fue el
  FINAL del recorrido: ya no hay diálogo de verificación, el router empuja a `/verify_email`.
  El test esperaba un diálogo que la app dejó de tener.
- «el proxy de input de Flutter web pierde el valor del campo al mover el foco» — **cierto,
  pero solo con `fill()`**, que escribe en el `<input>` del proxy y Flutter descarta al
  cambiar de foco. **`keyboard.type` pasa por la editing connection y es estable**: cinco
  casos, tres corridas, cero intermitencias.

Ya van **cuatro tandas seguidas** en que una anotación resulta no ser un diagnóstico.

## 3. Matriz Evidence ID → requisito → test → artefacto

**Advertencia sobre los IDs.** El plan define trece rangos (`EVID-VER-001..003`,
`EVID-SEC-010..014`, `EVID-AUTH-020..027`, `EVID-SEC-030..034`, `EVID-DB-010..015`,
`EVID-ROLE-010..018`, `EVID-QA-001..040`, `EVID-UX-010..015`, `EVID-UX-020..025`,
`EVID-FUNC-020..024`, `EVID-FUNC-030..034`, `EVID-UX-030..038`, `EVID-OPS-001..012`). En
`docs/evidencia/` solo se habían escrito **36 IDs**, y ninguno de VER, SEC, AUTH, DB ni ROLE.
Además **UX-01 usó `EVID-UX-020..023`, que es el rango asignado a UX-02**: hay colisión.

Es un defecto del registro, no de la cobertura: las tareas SÍ tienen tests, lo que faltaba era
la etiqueta. La tabla ata cada requisito a su test **verificando que el archivo existe**; los
IDs que el plan reservó y nadie escribió se marcan como tales en vez de inventarlos ahora.

| Requisito (tarea del plan) | Demostrado por | Rango del plan | IDs escritos |
|---|---|---|---|
| VER-01 — PDF de NIT alcanzable y acotado por MIME | `test_rules/storage_nit.test.js`; widget tests de `workshop_verification_screen` | `EVID-VER-001..003` | **ninguno** |
| SEC-01 — provisionamiento sin contraseña compartida | `functions/test/security_functions.test.js`, `functions/test/empleados.test.js` | `EVID-SEC-010..014` | **ninguno** |
| SEC-02 — verificación de correo obligatoria | `test/core/router/email_verification_gate_test.dart`, `test/core/router/app_router_guard_test.dart`, `test/features/auth/email_verification_screen_test.dart`, `e2e/tests/harness.spec.js`, **`e2e/tests/registro.spec.js` (H-01)** | `EVID-AUTH-020..027` | **ninguno** |
| SEC-03 — sin oráculo correo → PII | `functions/test/obtener_perfil_publico.test.js`, `functions/test/obtener_empleados_publicos_callable.test.js` | `EVID-SEC-030..034` | **ninguno** |
| DATA-01 — cotización consistente ante fallos | `test/features/chat/data/repositories/chat_repository_test.dart`, `test_rules/cotizaciones.test.js` | `EVID-DB-010..015` | **ninguno** |
| ROLE-01 — contrato canónico de roles | `test/core/utils/role_utils_test.dart`, `test_rules/roles_variantes.test.js`, `test_rules/matriz_roles_superusuario.test.js`, `functions/test/rolMigracion.test.js` | `EVID-ROLE-010..018` | **ninguno** |
| QA-01 — harness multirol y CRUD | `test_rules/ciclo_vida_crud.test.js`, `test_rules/reasignacion_campos.test.js`, `e2e/tests/roles.spec.js` | `EVID-QA-001..040` | `001..007`, `010..014`, `020..025` |
| UX-01 — contacto y CTAs reales | `e2e/tests-landing/contacto.spec.js`, `e2e/tests-landing/enlaces.spec.js`, `functions/test/solicitudes_landing.test.js`, `test_rules/solicitudes_landing.test.js` | `EVID-UX-010..015` | `010..023` (**se sale del rango y pisa el de UX-02**) |
| UX-02 — recuperación ante error y deep links | `e2e/tests/deep-links.spec.js`, `e2e/tests/sesion-persistida.spec.js` | `EVID-UX-020..025` | `020` |
| FUNC-01 — edición de reseñas con fotos | `test_rules/storage.test.js`, `functions/test/fotos_de_resenia.test.js` | `EVID-FUNC-020..024` | `020` |
| FUNC-02 — apertura única de tickets | `functions/test/apertura_unica_ticket.test.js`, `functions/test/vinculo_taller.test.js`, `test_rules/reparaciones*.test.js` | `EVID-FUNC-030..034` | `030` |
| UX-03 / UX-04 — accesibilidad y errores | `e2e/tests-landing/accesibilidad.spec.js`, `e2e/tests-landing/contraste-encabezados.spec.js`, `test/errores_sin_detalle_tecnico_test.dart` | `EVID-UX-030..038` | `030` |
| SEC-04 / OPS-01 — App Check y tareas programadas | `functions/test/app_check.test.js`, `functions/test/app_check_cobertura.test.js`, `functions/test/alertas_vencidas.test.js`, `functions/test/recordatorios_reserva.test.js`, `functions/test/exportacion_firestore.test.js` | `EVID-OPS-001..012` | `001` |
| **H-01 — QA destructivo** | `e2e/tests/registro.spec.js`, `e2e/tests/qa-destructivo.spec.js`, `test/core/providers/salidas_de_sesion_test.dart`, `test/features/chat/.../reserva_chat_card_id_vacio_test.dart` | — | ver §4 |

### 3.1 Centinelas — la cobertura que ninguna otra suite da

Estos no prueban una funcionalidad: **impiden que una clase entera de defecto vuelva en
silencio**. Todos nacieron porque algo se coló.

| Centinela | Qué clase de defecto atrapa |
|---|---|
| `test/firestore_indices_test.dart` | consultas sin índice compuesto — los emuladores las sirven, solo producción falla |
| `test/alertas_campos_test.dart` | la allowlist de `/alertas` y `AlertModel` divergiendo: un campo nuevo se denegaría solo en producción |
| `functions/test/app_check_cobertura.test.js` | un callable nuevo sin `exigirAppCheck` |
| `test/errores_sin_detalle_tecnico_test.dart` | un `Text('Error: $e')` crudo llegando a la pantalla |
| `test/features/chat/tombstone_literal_test.dart` | el literal de lápida divergiendo entre cliente y reglas |
| **`test/core/providers/salidas_de_sesion_test.dart`** (H-01) | una salida de sesión que no limpia los providers |

## 4. QA destructivo — checklist del plan

| Caso | Dónde se ejerce | Estado |
|---|---|---|
| Vacío | `registro.spec.js`, «vacio, mala forma y duplicado» | cubierto (H-01) |
| Inválido | ídem | cubierto (H-01) |
| Duplicado | ídem | cubierto (H-01) |
| Doble submit | `registro.spec.js`, «pulsar dos veces seguidas» | cubierto (H-01) |
| Refresh | `sesion-persistida.spec.js`, `deep-links.spec.js` | ya cubierto |
| Back / logout | `qa-destructivo.spec.js`, «tras cerrar sesion, ATRAS…» | cubierto (H-01) |
| Rutas protegidas | `qa-destructivo.spec.js`, seis rutas de tres familias de rol | cubierto (H-01) |
| Cross-tenant | `roles.spec.js` (15 casos) + `test_rules/ciclo_vida_crud.test.js` | ya cubierto |

Dos decisiones de método que valen más que los casos:

**Los rechazos se afirman sobre el `aria-label`, no con `getByText`.** En Flutter web el
`errorText` de un campo **no es un nodo del árbol de semántica**: se concatena al `aria-label`
del `<input>` del proxy, medido en esta misma pantalla:

```
Email / salto / name@example.com / salto / Fill in email and password.
```

`getByText` no puede encontrarlo nunca. El primer intento de estos tests falló justo por eso,
y de paso la aserción correcta es mejor: prueba que el error **se anuncia a un lector de
pantalla**.

**Y un negativo sin control positivo no prueba nada.** «No se creó cuenta» tras enviar un
correo vacío es cierto aunque se borren los validator: Firebase lo rechazaría igual. Por eso
cada rechazo afirma ADEMÁS el mensaje de validación de cliente — que es lo único que
distingue «la app cortó el envío» de «el servidor lo rechazó».

**Los tres casos de rechazo van en un solo test, a propósito.** Con cinco arranques de app en
un archivo, una de cada dos pasadas moría en `esperarAppLista` a los 120 s: cada boot cuesta
CanvasKit más persistencia offline y degrada el emulador. Agrupar bajó de 2,9 min a 54 s y
quitó la intermitencia. Es la guía que `CLAUDE.md` ya daba.

## 4 bis. La ronda de revisión de reglas, y por qué era obligatoria

Los dos arreglos de reglas que salieron de la segunda auditoría (§2 de
`docs/AUDITORIA_CREA_J_2026_v2.md`) pasaron por el gate de `firestore-rules-reviewer` antes de
darse por cerrados. **Encontró que uno de los dos no cerraba nada.**

### El arreglo de reservas solo encarecía el ataque

Atar la cita a su conversación daba por buena una relación que **el propio atacante podía
fabricarse**: el `allow create` de `/conversaciones` tenía una rama —la del propietario— que no
comprobaba nada sobre `id_mecanico`. Así que el ataque seguía siendo posible con **una escritura
más**: primero la conversación nombrando a la víctima de mecánico, después la cita.

Lo que hace esto instructivo: la rama del mecánico **sí** estaba cerrada, desde la Ronda 3. La
simétrica llevaba abierta desde entonces, y mi arreglo se apoyó justo en ella llamándola «una
relación de fiar». Lo era en la mitad que el atacante no usa.

**Cerrado de verdad:** un propietario solo puede abrir chat con un **taller aprobado**, con un
helper nuevo `esMecanicoAprobado(uid)` que mira a la contraparte y no al llamante. Cubierto por
tres casos más en `reservas_relacion_previa.test.js`, incluido el ataque completo en dos pasos,
verificados en rojo antes de tocar la regla.

Puso rojos cinco tests cuyas siembras creaban conversaciones con un `id_mecanico` que nunca se
sembraba como usuario. Su propio nombre —«inicia el chat desde el directorio»— dice que la forma
real es otra: el directorio solo lista talleres aprobados. Se corrigieron las siembras.

### Lo que el revisor vio y ninguna suite podía ver

- **`.data.id_propietario` sobre un documento al que le falte el campo no devuelve null: lanza.**
  Aquí fallaba cerrado, que es la dirección buena, pero por accidente. Ahora usa
  `.get('id_propietario', '')`, así que el motivo es «no coincide» y no un error del motor.
- **El riesgo de despliegue**, que es el más caro de todos y no es un defecto de regla:
  `esTallerAprobado` resuelve con `.get('estado', 'pendiente')`, así que **cualquier taller de
  producción sin ese campo pierde de golpe las facturas y la galería**. Ninguna suite puede
  avisarlo, porque todas siembran `estado`. Es **Pendiente 0 de `docs/RUNBOOK.md`**, bloqueante
  antes de desplegar, y explícitamente **no** un backfill ciego a `'aprobado'`: eso convertiría
  el arreglo en su contrario.

## 5. Estado de la rama

Los ocho gates de §1 están corridos y en verde sobre el árbol final. `flutter test` pasó de
1221 a **1227** y las reglas de 454 en 26 suites a **465 en 28**: los casos del id vacío de
reserva, el centinela de salidas de sesión, las dos rutas de tarea sin `extra`, el taller
suspendido y la relación previa de las citas.

**Una nota sobre cómo se leyó ese número.** La primera corrida salió `+1223 -1` y la tarea de
fondo reportó exit 0 — porque el comando terminaba en un `echo`, así que el código de salida
era el del `echo` y no el de `flutter test`. Es la misma trampa que `CLAUDE.md` ya documenta
con `tail`. **El número se lee del contenido, nunca del código de salida de una tubería.**

Pendiente: la segunda auditoría adversarial (§7 del plan) y el informe
`AUDITORIA_CREA_J_2026_v2.md`.

## 6. Gaps abiertos que H-01 deja anotados

| # | Gap | Por qué no se cierra aquí |
|---|---|---|
| 1 | **Seis formularios sin defensa contra doble envío**: recuperar contraseña y Google Auth (`auth_screen.dart:619-649`, `:569-584`), editar kilometraje (`vehicle_profile_screen.dart:953-1033`), crear y reprogramar reserva (`chat_screen.dart:273-370`, `reserva_detail_screen.dart:107-149`), responder reseña (`mechanic_reviews_screen.dart:266-319`). Inventario de un worker, **verificado a mano solo el de crear reserva** | El de reserva era el único con consecuencia demostrada (la tarjeta fantasma) y se cerró. Los otros cinco necesitan verificarse uno a uno antes de diseñar el arreglo: la lección de las cuatro tandas anteriores es que la anotación no es un diagnóstico |
| 2 | La guarda nueva de `chat_screen.dart` **no la cubre ningún test directo** | Alcanzarla exige montar la pantalla de chat y atravesar `VehiculoPicker` + `showDatePicker` + `showTimePicker`. Es alcanzable —`VehiculoPicker` lee `VehicleProvider` del contexto, o sea es inyectable— pero es trabajo propio. La consecuencia visible SÍ está cubierta, en `reserva_chat_card_id_vacio_test.dart` |
| 3 | Los cuatro anchos móviles del plan (320/375/390/414) solo se barren en la **landing**. La app prueba 320 y 375, y solo a nivel de `AppBreakpoints`, no sobre pantallas reales | 390 y 414 caen en la misma `WindowClass.compact` que 375, así que añadirlos sería cierto por construcción. Lo que falta de verdad es un barrido de overflow sobre pantallas reales, que es una tanda propia |
| 3 bis | **`_run` de `email_verification_screen.dart:30` se traga TODA excepcion** con un `catch (_)` y pinta «no se pudo enviar el correo», el mismo mensaje para cualquier fallo. Descubierto persiguiendo el §2.2: un logout que falle deja a la persona en el gate creyendo que fallo el envio del correo | Es un patron de manejo de errores, no una linea suelta: hay que mirar si hay mas `catch (_)` que conviertan fallos distintos en un mensaje unico antes de arreglar uno. Vecino de lo que cerro UX-03 |
| 4 | `chat_screen.dart:525` tiene un literal en español sin traducir (`'No se pudo eliminar el mensaje.'`) | No es una fuga de error técnico —lo que cerró UX-03— sino una cadena sin ARB. Hay que barrer si hay más antes de arreglar una sola |
| 5 | Los comentarios de `playwright.config.js:45` y `playwright.landing.config.js:38` afirman que **esperar al hub garantiza que Firestore responda**, que es justo lo contrario de lo que el proyecto aprendió | El defecto real está cerrado: la espera de verdad vive en `global-setup.js`, que espera a Firestore y a Auth directamente. Queda el comentario, que invita a «simplificar» el global-setup mañana. **Se corrige en esta misma rama** |
| 6 | La nota de `e2e/tests/helpers.js` dice que la app «no emite ni un `aria-label`» | Quedó obsoleta: los `<input>` sí los emiten, y de ahí salió la aserción del §4. **Se corrige en esta misma rama** |

| 7 | **`/reservas` no ata `id_taller`.** El `create` fija bien quién va en `id_propietario` e `id_mecanico` —la conversación los pinea—, pero el `id_taller` es libre: un cliente puede crear una cita legítima con su mecánico y apuntar ese campo a un taller de terceros. Cualquier panel o consulta que agrupe por ahí se contamina | Del gate de revisión. Ninguna suite lo mira porque el único creador de `lib/` siempre escribe el valor correcto. Cerrarlo es otro predicado en la misma regla, pero quiero ver primero qué consume ese campo antes de fijarlo |
| 8 | **Un taller vinculado y aprobado puede ESCRIBIR facturas sobre un vehículo ajeno sin ningún ticket abierto**: el vínculo basta (`storage.rules`, bloque `facturas/`) | Del gate de revisión, fuera del diff de H-01. Lectura y escritura están igualadas y no deberían: leer el histórico es razonable con el vínculo; escribir debería exigir trabajo en curso |
| 9 | `esTallerAprobado(uid)` **parece general pero su `isAuthenticated()` mira siempre al llamante**, así que invocarla con un uid ajeno daría un resultado que no significa lo que aparenta | Hoy no hay ningún call site así —los tres pasan el uid del llamante o del propio taller—, pero es una trampa esperando. O se documenta en la función o se le quita el parámetro |
| 10 | La nota de la regla de reservas afirma que «en `lib/` hay un único creador de reservas». Es cierto hoy, y **no lo vigila ningún centinela** | Es exactamente el tipo de invariante que FUNC-02 vio caducar. La seguridad de la regla NO depende de ello —la regla exige la relación venga quien venga—, así que es deuda de documentación, no de autorización |

Siguen abiertos los quince de `GAPS-04-drenaje.md` §7, sin cambios.
