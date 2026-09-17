# GAPS-08 — el F5 de `/garage` y `/alerts`, el diálogo de respuesta, y las fotos raspadas

Rama `feat/play-store`. Cierra los tres gaps que quedaban anotados de la tanda de
publicación en Google Play: el defecto de recarga que levantó la suite de capturas, el
gap 1 del §5 de GAPS-07, y la cuestión de propiedad intelectual de `vehiculos.foto_url`.

---

## 1. `/garage` y `/alerts` salían vacías con F5 o enlace directo

### Lo que pasaba

Ninguna de las dos pantallas **pedía** sus datos: las dos se limitaban a **leer**
`vehicleProvider.vehicles` y `vehicleProvider.selectedVehicle`. El único sitio de toda la
app que llamaba a `fetchVehicles` al entrar era el dashboard
(`dashboard_screen.dart:54`).

Navegando por las pestañas eso funciona, porque se pasa por el dashboard primero. Pero un
F5 —o un enlace directo, o volver desde una notificación— monta la pantalla con los
providers recién construidos:

- `/garage` pintaba «No tienes vehículos en tu garaje» con tres vehículos sembrados;
- `/alerts` se quedaba en «Selecciona un vehículo primero», **y desde ahí no hay ninguna
  forma de seleccionar nada**: el selector vive en el dashboard.

Es la misma familia que el F5 de `/task_config` que cerró H-01: el estado que la pantalla
necesita no sobrevive a una recarga, y la lectura que lo asume produce un callejón sin
salida.

Lo levantó la suite de capturas, no una suite de tests: un `goto('/garage')` en frío daba
la pantalla vacía y hubo que navegar por las pestañas para poder fotografiarla.

### El arreglo

Dos métodos idempotentes, `VehicleProvider.asegurarVehiculosCargados(uid)` y
`AlertProvider.asegurarAlertasCargadas(vehiculos)`, y un helper compartido,
`asegurarDatosDelGaraje(context)`, que las dos pantallas llaman desde
`didChangeDependencies`. El dashboard se deja como estaba: sigue refrescando en cada
entrada, que es lo que se quiere de la pantalla principal.

### Tres cosas que el propio test destapó, y que valen más que el arreglo

**1. `notifyListeners` dentro de la fase de construcción.** Llamar al helper desde
`didChangeDependencies` lo pone DENTRO del build, y `fetchVehicles` arranca con un
`notifyListeners()`. Primer intento: «setState() or markNeedsBuild() called during build».
Va en un `addPostFrameCallback`, que es el mismo patrón que el dashboard ya usaba por la
misma razón — sin que estuviera dicho en ninguna parte.

**2. Memorizar el ÉXITO en vez del INTENTO es un bucle de lecturas.** La primera versión
solo marcaba el memo cuando `_error` era null, con la idea razonable de que un fallo se
debe poder reintentar. Lo que eso significa de verdad: `fetchVehicles` termina con
`notifyListeners()` → el `context.watch` reconstruye → `didChangeDependencies` vuelve a
correr → como el fallo no está memorizado, se vuelve a pedir. **Lecturas infinitas contra
Firestore mientras el error persista**, que es justo cuando el backend menos lo aguanta.
Ahora se memoriza el intento; reintentar sigue siendo posible, pero tiene que pedirlo algo
(una entrada al dashboard, o un cambio de sesión que pase por `clearVehicles`).

**3. El memo NO puede vivir solo dentro de `fetchVehicles`.** Varios espías de los tests
sobreescriben `fetchVehicles` sin llamar a `super`; si el memo viviera solo ahí, esas
subclases dejarían el método sin memoria y recargando en cada entrada. Se marca en los dos
sitios.

### Daño colateral, y lo que enseña

Once tests se pusieron rojos, y **ninguno por el arreglo**: todos porque sus harnesses
montaban `/alerts` o el router **sin `UserProfileProvider`**, que en la app real siempre
está por encima. Eran menos parecidos a producción de lo que aparentaban — exactamente el
mismo hallazgo que la tanda anterior tuvo con los delegados de localización.

Uno merece nota propia: `task_routes_sin_extra_test.dart` fallaba porque la excepción del
provider ausente nace en un **post-frame callback**, o sea un error asíncrono que
`takeException` no recoge por mucho que se insista. No se podía arreglar desde el test
afirmando distinto; hubo que montar el árbol como la app lo monta.

---

## 2. El diálogo de respuesta a una reseña: el diagnóstico anotado era falso

GAPS-07 anotó que el diálogo **desborda ~99 000 px** y culpó al `IntrinsicWidth` de
`AlertDialog` combinado con el `SizedBox(width: double.maxFinite)` de `AppDialogContent`.
Por eso el botón «Publicar» se quedó sin test: era el único de los dieciséis controles de
aquella tanda sin cubrir.

**Medido, eso es falso.** El diálogo mide bien a 360 px y a 1200 px, y lo mide **incluso
con el código defectuoso puesto**. `AppDialogContent` no tiene nada que ver.

El defecto real era de ciclo de vida:

```dart
final texto = await showDialog<String>(...);
controller.dispose();          // ← aquí
```

`showDialog` devuelve en cuanto se llama a `Navigator.pop`, **con la ruta todavía montada
y animando su salida**. El campo vivo volvía a usar el controlador muerto:

```
A TextEditingController was used after being disposed.
```

y esa excepción se encadenaba por todo el subárbol del diálogo hasta reventar el layout
con el `RenderFlex overflowed by 99292 pixels`. **El desbordamiento era el síntoma, no la
causa** — y perseguirlo habría llevado a cambiar `AppDialogContent`, que usan veinte
diálogos, para arreglar algo que no estaba roto.

Es un defecto de PRODUCCIÓN, no solo de test: la ruta que se anima es la misma en la app.

El arreglo es que el controlador viva en su propio `State` (`_DialogoResponder`), donde lo
destruye el framework al desmontar el diálogo, que es el único momento en que se puede.
`auth_screen.dart:721` ya resolvía lo mismo con un `addPostFrameCallback` y un comentario
que lo explicaba; el diálogo de reseñas era el único sitio del repo con el patrón malo.

Con eso, el **grupo 16** de doble envío —el que GAPS-07 dejó sin test— ya se puede
escribir, y está escrito.

---

## 3. Las fotos de vehículo eran imágenes de terceros raspadas de Google

### Lo que había

`VehicleProvider.addVehicle` llamaba a `VehicleImageService`, que consultaba SearchAPI.io
(engine `google_images`) buscando una foto «estilo concesionario» de la marca y el modelo,
y guardaba **ese enlace, tal cual**, en `vehiculos.foto_url`. Cada vehículo creado desde
que existe la app lleva enlazada una imagen de un tercero, servida desde el CDN de su
dueño, y pintada como si fuera el coche de la persona.

Son **dos** problemas, y el segundo no estaba anotado:

- **Propiedad intelectual.** Catálogos de concesionario y bancos de imagen sobre los que
  AutoDoc no tiene ninguna licencia. En una ficha de Google Play, exposición a retirada.
- **Privacidad, y es un agujero ya conocido en este repo.** `foto_url` la lee todo el que
  puede ver el vehículo: el taller vinculado, **sus empleados** (la regla resuelve por
  `idTallerActor()`, no por el uid de la sesión), aquel con quien el dueño lo comparta y el
  admin. Un enlace a un servidor ajeno le entrega a ese tercero la IP y el User-Agent de
  cada uno de ellos. (No incluye a quien recibe un pase de historial, aunque lo escribí así
  al principio: `leerHistorial` proyecta una allowlist que no lleva el campo. Ver abajo.) Es
  **exactamente** el agujero que FUNC-01 cerró en `resenias.fotos` con `fotosBajoServicio`
  — y que aquí llevaba encendido por defecto desde el principio.

### El arreglo, en cuatro capas

1. **Retirado el camino entero.** `VehicleImageService` y su test, borrados; el parámetro
   `imageService` de `VehicleProvider`, retirado; `AppSecrets.vehicleImageApiKey`,
   retirada; los cinco `--dart-define=VEHICLE_IMAGE_API_KEY` de `ci.yml`, más
   `.env.example`, `app.env` y el script de secretos, limpiados. Un vehículo nace sin foto
   y `VehicleImageWidget` cae al placeholder neutro.
2. **`firestore.rules`** exige que `foto_url` esté vacía, sea null, sea la ruta del asset,
   o apunte a `vehiculos%2F{id}%2F` de **nuestro** Storage. Se valida en el `create` y, en
   el `update`, **solo si el campo cambia** — mismo motivo que
   `fotosDeReseniaValidasEnUpdate`: validar siempre dejaría INEDITABLES los vehículos con
   enlace heredado, ni el kilometraje ni la revocación de un taller, que es cambiar una
   fuga por una avería.
3. **Backfill** `functions/backfill_foto_url_ajena.js`, con dry-run por defecto, y su paso
   de runbook (Pendiente 0ter). No es bloqueante para desplegar, pero **ninguna suite
   puede avisar de que falta**: los emuladores se siembran limpios.
4. **Centinela** `test/fotos_de_vehiculo_sin_terceros_test.dart`. Una llamada nueva a un
   buscador de imágenes compila, analiza limpio y pasa cualquier test de widget; lo único
   que cambia es qué acaba en `foto_url`. El centinela cruza también que el helper de las
   reglas esté **cableado** en las dos ramas, no solo declarado — un helper declarado y sin
   cablear es el estado exacto en el que GAPS-06 encontró `avisos_pendientes`.

### Lo que encontró el gate de revisión, y por qué valió la pena

El subagente de reglas levantó **el mismo agujero por la puerta de al lado**, y yo no lo
había visto: la galería `vehiculos/{id}/fotos/{fotoId}` guarda `{url, timestamp}`, esa
`url` la elige el cliente igual que `foto_url`, y sus lectores son **exactamente los
mismos** (`puedeVerVehiculo`). Sin filtro bastaba con escribir el documento —**sin subir
nada a Storage**— para cosechar la IP de cada empleado del taller que abriera la ficha.
Cerrar `foto_url` y dejar esto abierto habría sido mover el problema, no resolverlo.

Y dos cosas más:

- **La validación estaba dentro de la rama del propietario**, así que el `|| isAdmin()`
  del final la esquivaba entera. `/resenias` ya la tenía **fuera** del paréntesis desde
  FUNC-01; la asimetría era gratuita. Hoisteada.
- **El comentario que escribí citaba un lector que no lee el campo.** Decía que `foto_url`
  la ve «quien reciba un pase de historial»; `leerHistorial` proyecta una allowlist
  explícita (`functions/src/historialCompartido.js:319-327`) que no lo incluye. La
  audiencia real ya justificaba la regla de sobra, pero la premisa falsa se hereda. Es el
  patrón que GAPS-04/05 documentan: **la anotación sirve para no perder el gap, no como
  diagnóstico** — y esta vez el que anotó mal fui yo.

Al cerrar la galería, **un test que ya existía se puso rojo**: el fixture de
`vehiculos.test.js` usaba `url: 'https://x/f.jpg'`, que es literalmente el ataque. Llevaba
ahí desde que existe la galería.

---

## Gaps que esta tanda deja abiertos

1. **Nadie puede poner la foto de su coche desde la app.** La foto la sube ahora su dueño
   —`VehiclePhotoService` ya existe y escribe en `vehiculos/{id}/fotos/`—, pero **la
   galería y `foto_url` son dos cosas separadas** y nada conecta la una con la otra.
   Mientras eso no exista, todos los vehículos se ven con la silueta. Es el precio de
   retirar el relleno automático, y es trabajo de producto, no de arreglo.
2. **La clave de SearchAPI.io sigue viva.** Ya no la usa nadie en el repo, pero hay que
   borrarla del panel de searchapi.io y de los secretos de GitHub. Está además en el `.env`
   local, que un hook impide editar.
3. **~270 literales sin traducir**, sin tocar desde GAPS-07.
4. **El segmento del bucket sigue siendo `[^/]+` en `esUrlDeStoragePropia`.** El comentario
   afirma que apuntar a otro bucket de Firebase «es contenido, no telemetría», y eso no es
   del todo cierto: los *usage logs* de Cloud Storage registran `c_ip` y `cs_user_agent`
   por objeto, así que un atacante con su propio proyecto Firebase recibe los mismos datos
   con retardo horario. El filtro encarece el ataque, no lo cierra. Es propiedad heredada
   —afecta también a `talleres.foto_url` y a `perfiles/`— y clavar el bucket rompería el
   despliegue a staging, así que se anota en vez de cambiarse a ciegas al final de una
   tanda.
