# Pruebas de uso real contra PRODUCCION — 2026-09-22

Campana de E2E conducida con Playwright contra la app **desplegada**
(`https://autodoc-6ef5a.web.app`), no contra emuladores, porque las cuentas
facilitadas son de produccion:

- Mecanico: `taller3@taller.com` — uid `HT8HkxrUNPPdNqY9bsnFpqW3hs83`, rol
  `Mecanico`, estado `activo`, ficha publica «taller prueba 3».
- Propietario: `hinasoh475@kingdais.com` — uid `laMMnrSlj4NgXsQTy165adLzCGy1`,
  rol `Propietario`, «prueba 1».

Las dos cuentas empezaron **vacias**: 0 vehiculos, 0 tickets, 0 cotizaciones,
0 conversaciones. Todo lo de abajo se construyo desde cero por la UI.

> **Estado: los cuatro estan arreglados** en la rama
> `fix/pruebas-produccion-2026-09-22`. Lo que sigue es el informe de la
> campana tal y como se escribio, con dos correcciones marcadas: al
> implementar, **dos de las soluciones que aqui se proponen resultaron ser
> incorrectas**. Ver §8.

Los specs viven en `e2e/tests-prod/` con `e2e/playwright.prod.config.js`.
**No son la suite del repo** y no deben fusionarse tal cual: escriben en
produccion.

---

## 0. Lo que SI funciona (ciclo completo verificado)

| Paso | Evidencia en Firestore |
|---|---|
| Login por formulario | redirige a `/dashboard`, uid correcto |
| Alta de vehiculo | `vehiculos/ee223f89-…` placa `P900-111` |
| Directorio (16 talleres) + busqueda + perfil | consulta `estado in [aprobado,activo]` + `orderBy calificacion_promedio` OK |
| «Contactar» | `conversaciones/thEYBMu8xky7DMAr7HgF` |
| Mensaje del propietario | subcoleccion `mensajes`, `tipo: texto` |
| Cita desde el chat | `reservas/72fNtqSeuWvEGPiBuNpg`, `id_proponente` = propietario |
| «Cotizar y Aceptar» del mecanico | la pantalla trae el coche (`P900-111 • 2018 • 85000 KM`) |
| Cotizacion enviada | `cotizaciones/sHLeEQP4V8SspQhgnDQd`, total 410, `mano_de_obra` 25 |
| Propietario acepta | cotizacion `aceptada` + `reparaciones/cot_sHLeEQP4V8SspQhgnDQd` en `pendiente_recepcion` + cita CONFIRMADA |
| 4 transiciones del tablero | `recibido` → `en_revision` → `esperando_repuestos` → `listo_para_entrega` |
| Guarda de «entregar sin cobrar» | avisa cuando no hay servicio; **deja de avisar** cuando lo hay |
| Cierre del servicio | `servicios/3E1wr35D`, costo 410 |
| Entrega | ticket `entregado`, `abierto: false`, tablero vacio |
| Historial del propietario | «Total gastado $410.00 · Servicios 1» |
| Resena | «Tu servicio con taller prueba 3 termino. ¿Como te fue?» + «Calificar servicio» |

**Tres defectos que el repo documentaba como arreglados lo estan de verdad en
produccion:** la cotizacion que nacia sin coche, la cita que se quedaba en
«pendiente» tras cotizar, y la entrega sin cobro previo.

---

## 1. P0 — El asistente de IA esta caido al 100%, en sus dos accesos

### Sintoma

En `/alerts` (propietario, boton «Preguntar al asistente») y en la barra lateral
del panel de taller (mismo boton), la pantalla abre bien, acepta la pregunta y
responde:

```
No pudimos cargar esta informacion
El asistente no esta configurado todavia. Estamos en ello.
```

### Como se encontro

Conduciendo las dos entradas por UI. La consola mostraba
`Failed to load resource: 400`. Llamando al callable a pelo con el token del
usuario:

```
POST /asistenteAutoDoc
{"error":{"message":"El asistente no esta disponible ahora mismo.",
          "status":"FAILED_PRECONDITION"}}
```

Identico para los dos roles. Los logs de la funcion dan la frase interna:

```
asistente: el proveedor rechazo el esquema del clasificador. Se reintenta sin el...
asistenteAutoDoc [failed-precondition]: El proveedor rechazo la peticion (400):
  revisa GEMINI_API_KEY y el modelo.
```

Ese mensaje apunta a la clave o al modelo, y **las dos pistas son falsas**:

- `firebase functions:secrets:get GEMINI_API_KEY --project production` → 5
  versiones ENABLED; el audit log de la funcion confirma que esta enlazada
  (`secretEnvironmentVariables: GEMINI_API_KEY v5`).
- `node functions/spike_gemini.js --probar` con esa misma clave: el modelo por
  defecto `gemini-3.5-flash-lite` **SIRVE**, en `v1beta` y en `v1`.
- `node functions/spike_gemini.js` (clasificar + redactar) pasa entero.

El spike pasa porque **no ejercita el camino que usa produccion**: sus dos
llamadas (`spike_gemini.js:266` y `:292`) no pasan `enumeracion` ni
`sinRazonar`. Aislando las cuatro combinaciones contra la API real con la clave
de produccion:

```
[400] enum + sinRazonar  (lo que manda produccion)   INVALID_ARGUMENT
[200] solo enum
[400] solo sinRazonar
[200] pelado
```

### Causa raiz

`functions/src/modeloGemini.js:177`

```js
if (peticion.sinRazonar) {
  generationConfig.thinkingConfig = { thinkingBudget: 0 };
}
```

El comentario de encima dice «un modelo que no soporta `thinkingConfig` lo
ignora». **No lo ignora: lo rechaza con 400.** `gemini-3.5-flash-lite` devuelve
`INVALID_ARGUMENT` en cuanto aparece ese campo, con esquema o sin el.

Y la caida blanda de `functions/src/asistente.js:669` solo desactiva **el
esquema**:

```js
if (!e || e.code !== 'failed-precondition' || esquemaRechazado) throw e;
esquemaRechazado = true;
bruto = await pedirEtiqueta(cliente, pregunta, false);   // sigue con sinRazonar
```

Como `sinRazonar` no se toca, el reintento manda el mismo campo venenoso y falla
igual. Por eso **ninguna** peticion puede completarse: no es intermitente, es
total.

### Reproduccion

1. Iniciar sesion con cualquiera de las dos cuentas.
2. Propietario: `/alerts` → «Preguntar al asistente». Taller:
   `/mechanic_dashboard` → «Preguntar al asistente».
3. Escribir cualquier pregunta → «Preguntar».
4. Sale el mensaje de «no configurado»; la red muestra 400 en
   `/asistenteAutoDoc`.

Sin UI, con la clave de produccion en el entorno:

```bash
curl -s -X POST \
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent' \
  -H "x-goog-api-key: $GEMINI_API_KEY" -H 'Content-Type: application/json' \
  -d '{"contents":[{"role":"user","parts":[{"text":"hola"}]}],
       "generationConfig":{"maxOutputTokens":8,"thinkingConfig":{"thinkingBudget":0}}}'
```

Devuelve 400 `INVALID_ARGUMENT`. Quitando `thinkingConfig`, la misma llamada da
200.

### Solucion

`thinkingConfig` es una optimizacion, no un requisito: existe para que los
tokens de pensamiento no se coman `maxOutputTokens` en el clasificador. El
arreglo correcto es **no dejar que una optimizacion tumbe la funcionalidad**.

1. **Degradar `sinRazonar` igual que el esquema.** Anadir una segunda bandera
   recordada por instancia y un tercer intento:

   ```js
   let esquemaRechazado = false;
   let razonamientoRechazado = false;   // nuevo
   // 1er intento: esquema + sinRazonar
   // 2o  intento: sin esquema, con sinRazonar   (esquemaRechazado = true)
   // 3er intento: sin esquema, sin sinRazonar   (razonamientoRechazado = true)
   ```

   Asi un campo no soportado degrada la calidad, no la disponibilidad.

2. **Compensar el presupuesto al degradar.** Sin `thinkingBudget: 0` el modelo
   puede gastar presupuesto pensando y devolver vacio — que es justo el defecto
   que `sinRazonar` vino a cerrar. Al caer al tercer intento hay que subir
   `maxOutputTokens` del clasificador para que la etiqueta quepa despues de
   los tokens de pensamiento. **(Correccion: `MAX_TOKENS_ETIQUETA` ya vale
   64, no ~8 como decia el borrador. Y al medirlo resulto que con el enum
   puesto y el razonamiento encendido 64 basta: 4/4 aciertos. Ver §8.)**

3. **Arreglar el mensaje de diagnostico.** `modeloGemini.js:276` dice «revisa
   GEMINI_API_KEY y el modelo» ante cualquier 400, y aqui las dos cosas estaban
   bien — esa frase costo el primer tramo de la investigacion. Debe incluir el
   `error.message` que devuelve Gemini, que es lo unico que identifica el campo
   rechazado.

4. **Cerrar el hueco de cobertura que lo dejo pasar.** `spike_gemini.js` es la
   unica prueba que habla con el proveedor de verdad, y no manda `enumeracion`
   ni `sinRazonar`. Debe llamar exactamente como `asistente.js`.

### Verificacion

- Repetir la matriz de cuatro combinaciones: o dan 200, o la funcion responde
  igual por el camino degradado.
- `npm test` en `functions/`.
- Por UI, una pregunta real de cada rol devuelve prosa.

### Nota de impacto

En los logs de produccion aparece un tercer uid
(`6cLFo1XvaQV6z0iRvWIUDFjJ6I22`) chocando con el mismo 400 el 2026-09-22 a las
21:12 UTC. **Hay usuarios reales afectados**, no solo las cuentas de prueba.

---

## 2. P0 — El selector de vehiculos del chat nunca carga por si solo

### Sintoma

Propietario → chat con un taller → «Adjuntar» → «Nueva Reserva». El dialogo
«Selecciona un Vehiculo» dice:

```
No tienes vehiculos registrados.
Agrega un vehiculo desde tu garaje para poder seleccionarlo aqui.
```

con dos vehiculos perfectamente existentes en `vehiculos`. **No es lentitud:**
se esperaron 180 s y el texto no cambia.

Consecuencia: sin cita no hay «Cotizar y Aceptar», sin cotizacion no hay ticket.
**La cadena propietario↔mecanico entera queda bloqueada** para quien entre al
chat desde una notificacion, un enlace directo o un F5.

### Como se encontro

Primero parecio lentitud, porque en una corrida anterior el selector **si** habia
cargado. La diferencia entre las dos corridas era que en la buena se habia
visitado `/garage` antes. Se convirtio en hipotesis y se probo A/B en la misma
sesion de navegador:

```
A) SIN pasar por el garaje  -> «No tienes vehiculos registrados.»
B) tras abrir /garage y volver al chat
   -> button: Toyota Corolla, placa P900-111
      button: Toyota Corolla, placa P900-333
```

### Causa raiz

`lib/features/chat/presentation/widgets/vehiculo_picker.dart`

```dart
class VehiculoPicker extends StatelessWidget {                      // :9
  ...
  child: Consumer<VehicleProvider>(                                 // :57
    builder: (context, vehicleProvider, child) {
      final vehicles = vehicleProvider.vehicles;
      if (vehicleProvider.isLoading && vehicles.isEmpty) { ... }     // :61
      if (vehicles.isEmpty) { /* «No tienes vehiculos registrados» */ }  // :65
```

El picker **lee** el provider pero nunca dispara la carga. Es un
`StatelessWidget`, asi que no tiene `initState` donde hacerlo. Si nadie poblo
`VehicleProvider` antes, `vehicles` esta vacio y `isLoading` es `false`, de modo
que cae directo en el estado vacio — que ademas **afirma un hecho falso**.

Quien lo poblaba era el dashboard (`dashboard_screen.dart:55`), de ahi que
navegando por las pestanas todo funcione.

### Lo que hace este defecto especialmente barato de arreglar

**El repo ya resolvio esta misma clase de bug** y dejo la herramienta hecha:
`lib/features/dashboard/presentation/utils/asegurar_datos_del_garaje.dart`,
cuyo propio comentario describe el sintoma palabra por palabra:

> «Lo que no funcionaba era entrar SIN pasar por el: un F5 sobre `/garage` o
> `/alerts`, o un enlace directo... El garaje pintaba "No tienes vehiculos" con
> tres sembrados».

Se aplico a `garage_screen.dart:53` y a `alerts_screen.dart:45`. **Al chat no.**

### Reproduccion

1. Iniciar sesion como propietario con al menos un vehiculo.
2. Ir **directo** a `/chat/<idConversacion>` (recarga completa, sin pasar por
   `/dashboard` ni `/garage`).
3. «Adjuntar» → «Nueva Reserva».
4. Sale «No tienes vehiculos registrados» y ahi se queda.
5. Ir a `/garage`, volver al chat y repetir: ahora si aparecen.

### Solucion

1. **Llamar al helper que ya existe** desde `_ChatScreenState.initState`
   (`chat_screen.dart:189`), igual que el garaje y las alertas:

   ```dart
   asegurarDatosDelGaraje(context);
   ```

   Es idempotente (`VehicleProvider.asegurarVehiculosCargados`,
   `vehicle_provider.dart:138`, memoriza la carga en curso), asi que no
   multiplica lecturas de Firestore.

   Alternativa mas local, si no se quiere cargar alertas desde el chat: llamar
   solo a `asegurarVehiculosCargados(uid)` justo antes de abrir el picker
   (`chat_screen.dart:375`).

2. **Arreglar el estado vacio mentiroso.** Aunque se dispare la carga, la
   condicion de `:61` solo muestra el cargando si `isLoading` **ya** es `true`.
   Queda una ventana en la que se afirma «no tienes vehiculos» sin haber
   preguntado. El estado vacio debe exigir que la carga haya terminado al menos
   una vez, no solo que no este en curso.

### Verificacion

- Test de widget: montar `ChatScreen` con un `VehicleProvider` recien construido
  (sin `fetchVehicles` previo) y un repositorio con 2 vehiculos; abrir el picker
  y afirmar que aparecen los dos. Debe estar **rojo antes** del arreglo.
- E2E: el A/B de arriba, con el paso A pasando a verde.

---

## 3. P1 — El alta de vehiculo canta victoria antes de escribir nada

### Sintoma

Al terminar el formulario, la pantalla dice:

```
¡Vehiculo Registrado!
Tu Toyota Corolla ya esta en el garaje.
```

y en ese momento **el vehiculo no existe en Firestore**. Solo se escribe si
ademas se pulsa «Ir al Dashboard». Quien cierre el dialogo en la pantalla de
exito pierde el alta creyendo que la guardo.

Ademas ese boton **ni cierra el dialogo ni navega**: escribe y deja al usuario
en la misma pantalla de exito, con la URL en `/garage`.

### Como se encontro

El primer intento del flujo E2E terminaba con la pantalla de exito delante y la
consulta a `vehiculos` devolviendo `[]`. Se descarto que fueran las reglas
escribiendo el mismo documento con el SDK desde la misma sesion: **persistio sin
problema**. Luego se leyo el codigo. Se reverifico despues con un vehiculo
distinto (Toyota Prius `P900-444`):

```
A) en la pantalla «¡Vehiculo Registrado!»: ["P900-111","P900-333"]   <- falta P900-444
B) tras «Ir al Dashboard»:                 ["P900-444","P900-111","P900-333"]
B) URL tras «Ir al Dashboard»: .../garage          <- no navega
B) ¿sigue abierto el dialogo? true                 <- no cierra
```

### Causa raiz

`lib/features/dashboard/presentation/widgets/add_vehicle_form.dart`

- El boton «Finalizar Registro» (`:806`) valida y termina en `_nextStep()`
  (`:874`). `_nextStep` solo avanza el `PageView` a `_buildSuccessStep()`
  (`:885`). **No escribe.**
- La escritura cuelga del `onPressed` de «Ir al Dashboard» (`:943`), que llama a
  `widget.onFinish(vehicle)` → `VehicleProvider` → `VehicleService.addVehicle`
  (`vehicle_service.dart:30`).
- El `catch` de esa escritura (`:966`) solo hace
  `setState(() => _isFinishing = false)`. Si falla, el spinner se apaga y **no
  se dice nada**: ni SnackBar, ni texto de error, ni log.

### Reproduccion

1. Propietario → `/garage` → «Anadir vehiculo».
2. Completar los cuatro pasos y pulsar «Finalizar Registro».
3. Con «¡Vehiculo Registrado!» en pantalla, consultar `vehiculos` filtrando por
   `id_propietario` (o cerrar el dialogo y recargar `/garage`): el vehiculo
   **no esta**.
4. Pulsar «Ir al Dashboard»: aparece, pero el dialogo sigue abierto y la URL no
   cambia.

### Solucion

1. **Escribir en «Finalizar Registro», no despues.** Ese boton debe hacer
   `await widget.onFinish(vehicle)` y solo avanzar a `_buildSuccessStep()` si la
   escritura resolvio. La pantalla de exito pasa a ser lo que dice ser: la
   confirmacion de un hecho consumado.
2. **«Ir al Dashboard» queda como pura navegacion:** `Navigator.pop` del dialogo
   + `context.go('/dashboard')`. Hoy no hace ninguna de las dos.
3. **Que el fallo se vea.** En el `catch`, ademas de `_isFinishing = false`,
   mostrar el error mapeado (`mensajeDeError`, de UX-04) y dejar el boton
   reintentable. Un `catch` que solo apaga un spinner es indistinguible del exito
   para el usuario.
4. Menor: «Color» presenta `Gris` como *placeholder* y es obligatorio; se lee
   como valor por defecto y el formulario rebota con «El color es obligatorio».
   O se prellena de verdad, o el hint no debe parecer un valor.

### Verificacion

- Test de widget con un `VehicleService` doble: pulsar «Finalizar Registro» y
  afirmar que **ya** se llamo a `addVehicle`, y que la pantalla de exito solo
  aparece despues; con el doble lanzando, afirmar que se muestra el error y que
  NO se avanza.
- E2E: el A/B de arriba, con A conteniendo ya la placa nueva.

---

## 4. P2 — Los 16 talleres del directorio dicen «Ubicacion no especificada»

### Sintoma

Todas las tarjetas del directorio, sin excepcion, muestran «Ubicacion no
especificada» — incluidas las de talleres con `municipio` y `ubicacion`
(GeoPoint) bien puestos. El **perfil** del mismo taller si la muestra: «San
Salvador Este, San Salvador».

### Como se encontro

Volcado del arbol de accesibilidad del directorio (16 tarjetas, 16 veces el mismo
texto) contrastado con la lectura directa de la coleccion `talleres`, que trae
`municipio: "San Salvador Este"` en 14 de los 17 documentos.

### Causa raiz

`lib/features/dashboard/presentation/pages/workshop_directory_screen.dart:1005`

```dart
final location =
    data['ubicacion_municipio'] ?? context.l10n.wdLocationNotSpecified;
```

`UserModel` tiene **dos** campos distintos y los serializa por separado
(`user_model.dart:170` y `:175`): `ubicacion_municipio` y `municipio`. Los
documentos de `talleres` que publica `publishTallerProfile` llevan `municipio`.
La tarjeta lee el otro, que nunca esta, y cae siempre al literal.

### Reproduccion

Propietario → `/talleres`, esperar a que cargue la lista (tarda; ver §5). Todas
las tarjetas dicen «Ubicacion no especificada». Abrir «Ver perfil» de cualquiera:
la ubicacion aparece.

### Solucion

```dart
final location = data['ubicacion_municipio'] ??
    data['municipio'] ??
    context.l10n.wdLocationNotSpecified;
```

Lo de fondo es que `UserModel` arrastra dos nombres para el mismo dato. Conviene
anotar cual es el canonico para la proyeccion publica y dejar el otro solo como
retrocompatibilidad, igual que se hizo con `estado`/`aprobado`.

### Verificacion

Test de widget sobre la tarjeta con un mapa que solo trae `municipio`: debe
pintar el municipio, no el literal.

---

## 5. Menores, con su evidencia

- **El importe no se prellena al cerrar el servicio.** `/initiate_service/<id>`
  dice «El cliente aprobo una cotizacion por $410.00. El desglose ya esta
  registrado» y el campo «Costo del servicio» llega **vacio** (`inputValue()`
  = `''`). El taller reteclea, y nada obliga a que el importe cobrado coincida
  con el aprobado. Es el residual que FUNC-02 ya anoto; sigue vivo.
- **`context.push` no mueve la URL.** Confirmado en produccion en dos sitios: el
  perfil publico del taller (la pantalla abre entera y la URL sigue en
  `/workshop_directory`) y el asistente (sigue en `/alerts` o
  `/mechanic_dashboard`). Un F5 devuelve a la pantalla anterior. Es la «causa B»
  que `url_sigue_a_la_navegacion_test.dart` ya documenta.
- **Lentitud generalizada.** El directorio tarda entre 13 s y 25 s en pintar las
  tarjetas; el filtro por texto, mas de 6 s; el picker de vehiculos, mas de 10 s
  cuando carga. Mientras tanto no hay texto accesible (esqueletos sin rotulo),
  asi que un lector de pantalla no anuncia nada.
- **Rotulo del asistente en el panel de taller:** dice «Preguntame por los
  vencimientos, las citas y los mantenimientos de **tus vehiculos**», redaccion
  de propietario en una pantalla de taller.
- **«Recibir vehiculo» en `/initiate_service`** aparece con el vehiculo ya
  recibido (ticket en `listo_para_entrega`).

---

## 6. Falsos positivos descartados (y por que importan)

Tres conclusiones intermedias fueron **del arnes de pruebas, no de la app**. Se
anotan porque la proxima campana puede repetirlas:

1. **«El chat no abre».** El helper hacia `page.mouse.click(10, 10)` para forzar
   el arbol de semantica de Flutter. En las pantallas con `AppBar` eso cae sobre
   **«Volver»**, asi que cada volcado salia de la pantalla anterior. La app ya
   llama a `ensureSemantics()` en `main.dart`: `flt-semantics-host` existe desde
   el arranque. **No hace falta ningun clic.**
2. **«El directorio esta vacio»** y **«"Finalizar servicio" no hace nada»**: las
   dos eran esperas cortas. Con esperas explicitas (`expect.poll` sobre el
   locator, no `waitForTimeout`) ambas pasan.
3. El **`x11`** de la cotizacion (`Pastillas de freno delanteras x11`, $385) no
   es un defecto: el campo «Cantidad» viene con `1` y el tecleo se anadio detras.

---

## 7. Datos creados en PRODUCCION por esta campana

Pendientes de borrar si se decide limpiarlos:

- `vehiculos/ee223f89-eb95-412a-943b-01cbae17199b` — `P900-111`
- `vehiculos/qa-diag-1790113553945` — `P900-333` (lo creo el diagnostico por SDK)
- `vehiculos/…` — `P900-444` (Toyota Prius, de la reverificacion del §3)
- `conversaciones/thEYBMu8xky7DMAr7HgF` + 1 mensaje
- `reservas/72fNtqSeuWvEGPiBuNpg`
- `cotizaciones/sHLeEQP4V8SspQhgnDQd`
- `reparaciones/cot_sHLeEQP4V8SspQhgnDQd` (estado `entregado`)
- `servicios/3E1wr35D` ($410)

---

## 8. Lo que cambio al implementar (rama `fix/pruebas-produccion-2026-09-22`)

Dos de las soluciones propuestas arriba **eran incorrectas**, y las dos las
destapo el reconocimiento delegado antes de escribir una linea. Se anotan aqui
porque el informe de arriba se conserva tal cual se escribio.

### 8.1 El arreglo del §3 habria dejado una pantalla muerta

El informe propone mover la escritura de «Ir al Dashboard» a «Finalizar
Registro». **No se puede:** los dos llamadores (`dashboard_screen.dart:719-748`
y `garage_screen.dart:407-436`) hacen `Navigator.pop` en cuanto la escritura
sale bien, asi que con la escritura en el primer boton la pantalla de exito
nunca llegaria a verse. Se habria cambiado una pantalla que miente por una
pantalla inalcanzable.

Lo implementado: **el paso deja de afirmar lo que todavia no ha pasado.**
«¡Vehiculo Registrado! / ya esta en el garaje» pasa a «Todo listo para guardar
/ Revisa tu {marca} {modelo} y guardalo en el garaje», y el CTA pasa de «Ir al
Dashboard» a «Guardar vehiculo». Quien cierre ahi ya no cree haber guardado
nada. Mas los dos defectos de estado que la revision del diff levanto: el
`catch` mudo ahora avisa **traducido** (`mensajeDeError`, no
`mensajeSeguroDeError`, que devuelve castellano fijo), y un `finally` devuelve
el boton a su sitio — sin el, el camino de fallo normal (`addVehicle` devuelve
`false` y el llamador solo pinta un aviso) dejaba un spinner eterno sin forma
de reintentar.

### 8.2 El arreglo del §1 era mas complicado de lo necesario

El informe propone un tercer escalon que ademas renuncie al esquema. Midiendo
las cuatro combinaciones contra la API real con la clave de produccion:

```
[400] enum + sinRazonar   <- lo que mandaba produccion
[200] solo enum           <- basta con esto
[400] solo sinRazonar
[200] pelado
```

O sea que lo rechazado es `thinkingConfig`, y el enum —la mitad valiosa, la que
OBLIGA en vez de PEDIR— se puede conservar. La escalera implementada degrada
**primero el razonamiento** y solo despues el esquema. Verificado contra la API
real con el prompt y el presupuesto de produccion:

```
--- escalon 1 (enum + sinRazonar) ---  400 INVALID_ARGUMENT x4
--- escalon 2 (enum, razonando)   ---  4/4 aciertos
```

`MAX_TOKENS_ETIQUETA` no valia ~8 sino 64, y con el razonamiento encendido 64
ya bastaba (4/4, cero vacias). El presupuesto del camino degradado se queda en
2x y no en 8x: `maxOutputTokens` es un techo, pero Gemini factura los tokens de
pensamiento como salida, asi que un techo alto es el limite de un descontrol,
no holgura gratis.

### 8.3 Lo que los dos gates anadieron

- **`clearTimeout` corria antes de leer el cuerpo.** `fetch` resuelve al llegar
  las CABECERAS, asi que el `await respuesta.json()` del camino de error —que
  este cambio introduce— quedaba sin ninguna cota de tiempo. Reestructurado
  para que el reloj cubra tambien las lecturas de cuerpo, lo que ademas cierra
  el mismo hueco preexistente en el camino de exito. Y el cuerpo solo se lee en
  400/401/403, que son los unicos estados que lo aprovechan.
- **Centinelas de fuga.** El rescate de `error.status` no lo afirmaba ningun
  test: tres casos nuevos en `modelo_gemini.test.js` fijan que el `status` viaja,
  que el `message` NO (lleva la pregunta del usuario), y que un 500 ni siquiera
  bufferiza el cuerpo.
- **Tope estructural** en la escalera (`for (let intento = 0; intento < 3; ...)`)
  mas una guarda si el bucle se agotara: sin ella, un tercer eje anadido sin
  `throw` haria que la pregunta cayera a `fuera_de_alcance` en silencio.
- **El §4 estaba en tres sitios, no en uno.** Ademas de las dos tarjetas del
  directorio, `workshop_model.dart` —que alimenta el panel de administracion,
  sus filtros y su exportacion— leia tambien solo `ubicacion_municipio`. La
  eleccion de campo vive ahora en `lib/core/utils/municipio_publicado.dart`,
  porque duplicarla es justo lo que produjo el fallo.
- **El spike medi­a el camino equivocado.** Llevaba copias congeladas del enum
  (cinco etiquetas frente a las tres de produccion), del prompt y del
  presupuesto, y no pasaba `enumeracion` ni `sinRazonar`. Ahora importa las de
  verdad y recorre **los dos escalones**, asi que reproduce el incidente y
  ademas comprueba el camino que atiende el trafico.

### 8.4 Un cargo de la revision que NO era cierto

La revision independiente senalo que `razonamientoRechazado` y
`esquemaRechazado`, al ser estado de modulo, podrian marcarse mal con dos
peticiones concurrentes. **No aplica:** la funcion esta desplegada como
callable v1 con `maxInstanceRequestConcurrency: 1` (visible en el audit log de
`CreateFunction`), asi que no hay dos peticiones a la vez en la misma
instancia. Se anota porque la cita era plausible y comprobarla costo un
minuto.

### 8.5 Cifras

`flutter analyze` limpio, `flutter test` **1524/1524**, Functions **603/603**.
Reglas y Storage sin tocar. Queda pendiente el despliegue.
