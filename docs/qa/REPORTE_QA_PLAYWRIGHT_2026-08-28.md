# Reporte de verificación con Playwright — AutoDoc

**Fecha:** 2026-08-28 · **Rama:** `main` (`8fec781`) · **Plataforma:** Web (Chromium 1440×900, 768×1024, 390×844)
**Backend:** Firebase **producción** `autodoc-6ef5a` (la app no tiene cableado ningún emulador)
**Cobertura:** propietario · taller pendiente · **taller aprobado** · **superadministrador**

---

## 1. Cómo se ejecutó

`flutter run -d chrome` **se cae** cuando Playwright se conecta al mismo servidor de
depuración: dos clientes sobre el mismo DDC/dwds y el tool crashea con
`WipError -32000 Cannot find context with specified id`. `-d web-server` deja la página
en blanco por la misma razón.

La verificación se hizo por tanto contra el bundle de release, que además es el artefacto
que se despliega:

```bash
flutter clean && flutter pub get
flutter build web --dart-define-from-file=.env
# servidor estático local con fallback SPA en http://127.0.0.1:5600
```

> **Nota de entorno.** El primer `flutter build web` **sin** `flutter clean` produjo un
> bundle incompleto: `assets/` vacío (0 ficheros), sin `manifest.json`, sin
> `favicon.png`, sin `firebase-messaging-sw.js`, y con `main.dart.js_*.part.js` sobrantes
> del 1 de agosto mezclados con un `main.dart.js` nuevo. La app arrancaba en blanco con
> `FormatException: Unexpected token '<'`. Tras `flutter clean` el bundle salió correcto.
> **Conviene que el CI haga `flutter clean` antes del build de hosting**, porque
> `firebase.json` publica `build/web` tal cual.

### Cuentas usadas

| Cuenta | Rol | Estado |
|---|---|---|
| `nadie@gmail.com` | Propietario | ✅ funciona |
| `taller1@taller.com` ("Taller Prueba") | Taller **aprobado** | ✅ funciona |
| `superadmin@autodocsv.com` | **Superusuario** | ✅ entra, pero ver §2.1 |
| `taller6@taller.com` | Mecánico | ❌ **credencial caducada** — sigue en `e2e/tests/mecanico.spec.js`, que por tanto falla |
| `qa.owner…`, `qa.taller…`, `qa.taller2…` | creadas en esta sesión | 🧹 ya borradas por el usuario |

### Dos aclaraciones de la primera pasada

- **El taller "auto-aprobado" no era un bug.** El registro de actividad lo confirma:
  `APROBAR TALLER · qbXBXE9t7lPM… · 28/08/26 10:59`. Lo aprobó el administrador a mano.
  El alta escribe `pendiente` correctamente. **Descartado.**
- **La placa `P999-123` "no encontrada" tampoco era un bug.** La cuenta `qa.owner…` y su
  vehículo se borraron durante la sesión; el vehículo ya no existía cuando el taller lo
  buscó. Comprobado que la búsqueda sí funciona con `P376-571` y `P859-392`. **Descartado.**

---

## 2. Hallazgos por severidad

### 2.1 🔴 El superadministrador no puede ver la evidencia que debe aprobar (403 de Storage)

En `/admin/verificaciones` la foto de la fachada —**la única evidencia obligatoria**— no
carga. La petición devuelve **403**:

```
GET https://firebasestorage.googleapis.com/v0/b/autodoc-6ef5a.firebasestorage.app
    /o/verificaciones%2FHT8HkxrUNPPdNqY9bsnFpqW3hs83%2Ffachada.png   →  403
```

**Causa raíz — las dos definiciones de `isAdmin()` se han desincronizado:**

```
firestore.rules:30   getUserData().rol in ['Administrador', 'admin', 'Superusuario']
storage.rules:14     ...data.rol in ['Administrador', 'admin']        ← falta 'Superusuario'
```

Una cuenta `Superusuario` pasa todos los checks de Firestore (por eso el panel entero
carga) y **falla todos los de Storage**. En `storage.rules` hay **12 reglas** que dependen
de `isAdmin()` (líneas 117, 121, 123, 130, 148, 172, 176, 177, 216, 232, 271, 287), así
que el agujero no se limita a esta pantalla: afecta a facturas, fotos de vehículo,
galerías y borrados administrativos.

Resultado práctico: el administrador aprueba o rechaza a ciegas. Captura
`qa-64-admin-verificacion.png`.

**Arreglo:** añadir `'Superusuario'` a la lista de `storage.rules:14` y desplegar
(`firebase deploy --only storage`). Y un test que compare ambas listas para que no
vuelvan a divergir.

---

### 2.2 🔴 Buscar una placa ya abre un ticket de reparación y notifica al dueño

En el panel del taller, *Buscar Vehículo* → escribir una placa → **BUSCAR AUTO** es una
consulta, pero además:

1. crea un ticket en **Reparaciones** (columna *Recibido*), y
2. envía una notificación push al propietario: *«Tu vehículo ya está en seguimiento»*.

Se ve en la propia pantalla de servicio: *«Vehículo recibido: ya aparece en Reparaciones»*.
Buscando dos placas para comprobar la búsqueda quedaron **dos tickets creados** sobre
vehículos de `nadie@gmail.com` y dos avisos enviados a esa persona. Capturas
`qa-58-estado-actual.png`, `qa-59-reparaciones-tras-busqueda.png`.

El taller no ha confirmado nada todavía: puede haberse equivocado de placa, o estar
comprobando el historial antes de decidir. Además **el tablero no ofrece cancelar ni
borrar un ticket**, solo *Avanzar*, así que un error de tecleo es irreversible desde la UI.

**Arreglo:** que el ticket se cree al confirmar (un botón explícito «Recibir vehículo»),
no al buscar; y añadir cancelar/archivar en el kanban.

---

### 2.3 🔴 No se puede registrar un vehículo: el año parece relleno pero está vacío

*(sin cambios respecto de la primera pasada)*

El campo **Año muestra `2024` en negrita**, con el mismo estilo que un valor elegido. No lo
está: es un literal que se pinta cuando el controlador está vacío.

```dart
// lib/features/dashboard/presentation/widgets/add_vehicle_form.dart:542-545
Text(
  _anioController.text.isEmpty
      ? '2024'                 // ← literal, no hay valor seleccionado
      : _anioController.text,
  style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
)
```

Al enviar, `int.tryParse('')` da `null` y salta un snackbar **«Año inválido»** al pie de la
pantalla ([línea 609](../../lib/features/dashboard/presentation/widgets/add_vehicle_form.dart#L609)),
apuntando a un campo que a la vista tiene un año correcto. **Color** tiene el mismo
problema (placeholder `Gris`, error por snackbar). Placa y kilometraje sí validan en línea:
dos lenguajes de error en el mismo formulario. El literal `'2024'` está además dos años
desfasado. Capturas `qa-32-snackbar.png`, `qa-33-anio-picker.png`.

---

### 2.4 🟠 En modo oscuro los mensajes recibidos no tienen burbuja

En el chat, el mensaje **recibido** se pinta como texto suelto sobre el papel tapiz: sin
fondo, sin padding y sin hora. El enviado sí tiene su burbuja turquesa con hora y checks.
Capturas `qa-53-chat-taller.png`, `qa-55-chat-enviado.png`.

**Causa raíz — dos tokens que resuelven al mismo color:**

```
chat_screen.dart:377   backgroundColor: isDark ? colors.surfaceContainer : colors.surface
chat_bubble.dart:91    fondo = isDeleted ? … : (isMe ? colors.primary : colors.surfaceContainer)
```

En oscuro el `Scaffold` del chat y la burbuja ajena son ambos `surfaceContainer`
(`#141E36`), así que la burbuja es literalmente invisible. En claro no pasa: ahí el
scaffold usa `surface` y sí contrastan. **Es un fallo solo de modo oscuro.**

**Arreglo:** dar a la burbuja ajena un token distinto del fondo del scaffold (p. ej.
`colors.surface` en oscuro).

---

### 2.5 🟠 Las alertas del usuario anterior sobreviven al cambio de cuenta

*(sin cambios)* Con cero vehículos el dashboard conserva las alertas de la sesión previa,
incluida «Tu SOAT venció hace 29 días». Tras F5 desaparecen.

**Causa raíz** — [dashboard_screen.dart:55](../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L55):

```dart
if (mounted && vehicleProvider.vehicles.isNotEmpty) {
  context.read<AlertProvider>().fetchAlertsForVehicles(vehicleProvider.vehicles);
}
```

Con la lista vacía nunca se llama, así que `AlertProvider._alerts` no se limpia. El
provider ya maneja el caso vacío ([alert_provider.dart:97](../../lib/features/dashboard/presentation/providers/alert_provider.dart#L97)):
**basta con quitar el `isNotEmpty`**. Y `_signOut`
([user_profile_screen.dart:836](../../lib/features/profile/presentation/pages/user_profile_screen.dart#L836))
no limpia ningún provider: merece un `clearAll()`.

---

### 2.6 🟠 El administrador no sabe a qué taller está aprobando

`/admin/verificaciones` identifica la solicitud **solo por el UID crudo**
(`HT8HkxrUNPPdNqY9bsnFpqW3hs83`): sin nombre, sin correo, sin especialidad. El registro de
actividad hace lo mismo (`qbXBXE9t7lPM…`). En la pantalla cuyo único trabajo es decidir si
un negocio es real, no hay forma de saber cuál es sin cruzar UIDs a mano.

Además el botón destructivo **«Rechazar» está encima de «Aprobar»**, ambos a todo el ancho
y con el mismo peso visual.

---

### 2.7 🟠 El nombre del vehículo se recorta a dos letras en el garaje

*(sin cambios)* `NI…`, `MA…`, `MI…` en `/garage`. A 768 px queda en dos letras y la placa
se parte en dos líneas.

**Causa raíz** — [garage_screen.dart:274](../../lib/features/dashboard/presentation/pages/garage_screen.dart#L274):
`Expanded(Column(nombre, placa))` a la izquierda y a la derecha un `Row` **sin restricción**
con el botón «Hacer Principal» (texto que nunca encoge) más un chevron fijo de 40 px. El
`Row` derecho toma su ancho intrínseco y el `Expanded` se queda con las sobras. Solo el
vehículo principal —sin ese botón— muestra el nombre entero.

---

### 2.8 🟠 El diálogo de verificación de correo cita un botón que no existe

*(sin cambios)* El texto manda pulsar **«Ya verifiqué»**; el diálogo solo ofrece
«Entendido» y «Reenviar correo». En [auth_screen.dart:779](../../lib/features/auth/presentation/pages/auth_screen.dart#L779)
ese botón está dentro de `if (!isRegistration)`, justo el caso contrario al del alta.

---

### 2.9 🟠 Los gráficos del panel admin repiten la etiqueta de mes por cada punto

En «Tendencia de Servicios» el eje X dibuja
`Mar Mar Mar Mar Mar Abr Abr Abr Abr Abr Abr May May May May Jun …` — una etiqueta por
punto de datos en vez de una por mes. «Crecimiento de Usuarios» la repite dos veces por
mes. Solo «Talleres Afiliados» está bien. Captura `qa-62-admin-charts.png`.

---

### 2.10 🟠 Las tarjetas de métricas del panel admin están casi vacías

Cada tarjeta de «Métricas Globales» mide ~270 px de alto con el número pegado abajo y unos
200 px de nada entre el icono y el valor. A 390 px el efecto es peor. Capturas
`qa-61-admin-dashboard.png`, `qa-70-admin-dashboard-390.png`.

---

### 2.11 🟠 Imágenes de vehículo: la key está vacía y el "placeholder" es un Mercedes

*(sin cambios)* No sale ninguna petición a `searchapi.io`. La consola dice que la app se
compiló sin `--dart-define-from-file=.env`, **pero sí se compiló con él**: lo que pasa es
que la línea 29 del `.env` es literalmente `VEHICLE_IMAGE_API_KEY=`, sin valor — la única
variable vacía del fichero. El mensaje manda a depurar el flag equivocado.

El vehículo cae en `assets/images/default_vehicle.jpg`, que **es la foto de un
Mercedes-Benz Clase C**: un Corolla aparece como un Mercedes plateado, indistinguible de un
resultado real y erróneo. Y para los vehículos que sí tienen URL, el CORS sigue rompiendo
(`hampson.goauction.co.uk` → `blocked by CORS policy`).

---

### 2.12 🟡 El arranque se bloquea cinco segundos en las notificaciones push

*(sin cambios)* Firebase listo a los 2,0 s; `runApp` a los 7,0 s, por un
`TimeoutException after 0:00:05` en `PushNotificationService.requestPermission` que en web
se agota siempre. Está en el camino crítico del arranque.

---

### 2.13 🟡 Accesibilidad: la barra superior del propietario y la lateral en `/chat_list`

Dos huecos distintos, ambos comprobados leyendo el árbol semántico:

- **Propietario, escritorio:** la barra superior completa (Inicio/Garaje/Chat/Talleres/
  Perfil, tema, idioma, campana, avatar) **no aparece**. Sobre `/dashboard` hay 34 nodos
  y todos son de contenido. Los enlaces sí están envueltos en `Semantics(button: true, …)`
  ([app_top_nav_bar.dart:255](../../lib/core/widgets/app_top_nav_bar.dart#L255)), o sea que
  es un fallo de exposición.
- **Taller:** la barra lateral **sí** está expuesta en todas sus pantallas… **excepto en
  `/chat_list`**, donde desaparece del árbol aunque se sigue viendo. Es la ruta que pasa por
  `_MechanicShell`.

Consecuencia: la navegación principal no es alcanzable con teclado ni lector de pantalla, y
los tests de `e2e/` tienen que ir por coordenadas. Extras del mismo árbol: etiquetas
duplicadas («Ayuda Ayuda», «Recordarme Recordarme»); *Ayuda/Privacidad/Términos* como
`generic` en vez de `button`; y dos tarjetas de métrica del taller expuestas como `button`
**sin nombre accesible**.

---

### 2.14 🟡 La URL no acompaña a la navegación en cuatro pantallas

La ruta del navegador se queda atrás al abrir una conversación de chat (sigue en
`/chat_list`), la pantalla de iniciar servicio (sigue en `/mechanic_search`), la
verificación del taller (sigue en `/mechanic_pending`) y el formulario de registro (sigue
en `/login`). Un F5 devuelve al usuario a la pantalla anterior y esas vistas no se pueden
enlazar.

---

### 2.15 🟡 Rol `Usuario` en datos reales, sin filtro que lo cubra

En `/admin/usuarios` hay cuentas con la insignia **USUARIO** (p. ej. *Norberto Colorado*,
*Jacobo*), pero los filtros son Propietario / Mecanico / Administrador / Superusuario. Ese
valor no está en ninguno, así que esas cuentas no salen en ningún filtro por rol. Es la
divergencia de vocabulario de roles que ya avisaba §1.3 del plan de estabilización, ahora
visible en producción. Captura `qa-64-admin-usuarios.png`.

---

### 2.16 🟡 Texto recortado en el login

*(sin cambios)* El separador dice `O CONTINUAR CON` en el árbol semántico pero se pinta
**«O CONTINUA…»** en las tres anchuras. El placeholder del correo se corta
(`nombre@ejemplo.com o usua…`) y la cabecera del selector de fecha también
(`Fecha de nacim…`).

---

### 2.17 🟡 App Check no consigue token

*(sin cambios)* `appCheck/recaptcha-error` en cada llamada a Auth. El login funciona, o sea
que App Check **no está enforced**. Puede ser solo que `127.0.0.1` no esté en los dominios
autorizados; conviene confirmarlo contra `autodoc-6ef5a.web.app` **antes** de activar el
enforcement.

---

### 2.18 🟡 Etiqueta de idioma que dice lo contrario del estado real

*(sin cambios)* «Idioma / Language — `EN (Activado) / ES (Desactivado)`» con el interruptor
apagado y la app en español. Literal fijo en `app_es.arb:613`.

---

### 2.19 🟡 Detalles sueltos

| Detalle | Dónde |
|---|---|
| *Buscar Vehículo* sugiere `Ej: ABC123`, pero la app exige `P123-456` | Taller |
| En **Reparaciones** el contador de cada columna queda pegado al título de la **siguiente** | Taller |
| «Avanzar a Esperando Re…» se recorta | Taller |
| «Solicitudes formales **(colección Talleres)**» expone el nombre de la colección Firestore al admin | Admin |
| Los tres desplegables de filtro de `/admin/talleres` dicen «Todos» sin etiqueta que diga qué filtran | Admin |
| *Crear Usuario* dice que asigna «una contraseña temporal genérica» pero nunca la muestra: el admin no puede comunicársela | Admin |
| «Dashboard Admi…» se recorta a 390 px | Admin |
| `findVehicleByPlate` traga las excepciones y devuelve `null`: un `permission-denied` y un «no existe» se ven idénticos | Taller |
| Al escribir en **contraseña** aparece el error en el campo **correo**, aún sin tocar | Login |
| «Entrar con Google» mantiene el verbo «Entrar» en modo registro | Alta |
| Botones a todo el ancho de 1440 px sobre tarjetas de 560 px | Setup, Perfil |
| Bajo TOYOTA aparecen **Scion xA / tC / xB** —marca distinta— y por delante del Corolla | Alta vehículo |
| En oscuro «Cerrar Sesión» y el FAB son morados; el resto del acento es turquesa | Perfil |
| `Permission.locationWhenInUse … not supported on web`: los talleres cercanos no se ordenan por distancia | Consola |
| `google.maps.Marker` deprecado; migrar a `AdvancedMarkerElement`. Maps se carga sin `loading=async` | Consola |
| Excepción sin mensaje al desmontar el mapa del directorio | Consola |
| Ventana de `permission-denied` justo tras el alta, antes de que exista `usuarios/{uid}` | Consola |
| El bundle no compila a **WASM**: `geolocator_web` usa `dart:html` | Build |

---

## 3. Lo que sí funciona (verificado en vivo)

### Propietario
Onboarding y *Saltar* · login válido e inválido con mensajes claros · validación del
formulario vacío en línea · alta completa (registro → `profile_setup` → `/dashboard`) ·
selector de fecha con suelo de 18 años · validación de placa salvadoreña · alta de vehículo
(una vez elegido el año) con pantalla de confirmación · estado vacío del garaje · tema
claro/oscuro (**§3.1 del plan**) · responsive 1440/768/390 con top-nav → rail → bottom-nav ·
cierre de sesión · deep links en frío.

### Taller (aprobado)
Login → `/mechanic_dashboard` · **las diez secciones del panel cargan**: Dashboard, Buscar
Vehículo, Mis Servicios, Reparaciones, Mis Reseñas, Mensajes, Empleados, Catálogo, Fotos
del taller, Configuración · búsqueda por placa (`P376-571`, `P859-392` encontradas vía la
callable `buscarVehiculoPorPlaca`) · pantalla de iniciar servicio con datos del vehículo,
kilometraje, alertas y materiales · **kanban de reparaciones y avance de estado** ·
**envío de mensajes en el chat** (llega con doble check) · **notificaciones push en primer
plano** (*«Nuevo mensaje de Taller Prueba»*, *«Tu vehículo ya está en seguimiento»*) ·
Configuración con datos reales (especialidad, departamento, municipio, coordenadas GPS
registradas) · estados vacíos correctos en Empleados, Catálogo y Reseñas.

### Taller (pendiente)
**§1.1 del plan:** el alta ya no entra en bucle, cae en `/mechanic_pending` con
`estado: 'pendiente'` · **los guards de rol funcionan**: `/dashboard`,
`/mechanic_dashboard`, `/admin/dashboard` y `/workshop_verification` redirigen todos a
`/mechanic_pending` · la pantalla de verificación con checklist y subidas se abre desde
«Completar verificación».

### Administrador
Login → `/admin/dashboard` · métricas globales (45 usuarios, 4 talleres, 48 vehículos, 15
servicios, 2 reseñas) · las tres gráficas renderizan · acciones rápidas · actividad
reciente · **Gestión de Usuarios** con búsqueda, filtros por rol, insignias de estado y
menú por fila · **Gestión de Talleres** con búsqueda, filtros y la sección de solicitudes
formales · **§1.2 del plan: el semáforo de estados es correcto** («taller prueba 3» sale
*Pendiente* en ámbar, los activos en verde) · **Moderación de Reseñas** con estrellas,
taller, cliente y borrado · **Registro de Actividad** con tipo, descripción, colección y
fecha · diálogo *Crear Usuario* · responsive a 390 px.

---

## 4. Lo que sigue sin cubrir

- **Subida de ficheros** (foto de fachada, galería del taller, foto de perfil, factura de
  servicio): Playwright puede hacerlo, pero cada subida deja un objeto en el Storage de
  producción. Es lo que falta para cerrar §1.5 y §6.2 del plan.
- **Cerrar un servicio completo** (*FINALIZAR SERVICIO* con materiales y mano de obra):
  habría escrito en el historial real de un vehículo ajeno.
- **§1.4 servicio manual del propietario**: necesita una cuenta de propietario de usar y
  tirar, y las creadas se borraron.
- **Cotizaciones y reservas** desde el chat.
- **Aprobar/Rechazar** una verificación real: no se pulsó por ser irreversible sobre un
  taller de verdad.

---

## 5. Rastro dejado en producción

Al comprobar la búsqueda por placa se crearon, sin intención, **dos tickets de reparación**
en el taller «Taller Prueba» sobre vehículos de `nadie@gmail.com`:

- `P376-571` — avanzado a *En Revisión* (probando el kanban)
- `P859-392` — en *Recibido*

Y un mensaje de chat: *«Mensaje de prueba QA 28/08»* en la conversación con `usuario`.
El propietario recibió además dos push de *«Tu vehículo ya está en seguimiento»*. Conviene
borrarlos; ver §2.2, que es justo lo que hace que esto sea tan fácil de provocar.

---

## 6. Orden sugerido

1. **§2.1** — `'Superusuario'` en `storage.rules:14` y desplegar. El admin aprueba a ciegas.
2. **§2.3** — el año del alta de vehículo: bloquea al usuario nuevo en su primera acción.
3. **§2.2** — que buscar una placa no cree ticket ni notifique; añadir cancelar en el kanban.
4. **§2.4** — burbuja del mensaje recibido en modo oscuro.
5. **§2.5** — alertas que sobreviven al cambio de cuenta.
6. **§2.6** — mostrar nombre y correo del taller en la pantalla de verificación.
7. **§2.8** — el botón «Ya verifiqué» que no existe.
8. **§2.7** — nombre del vehículo recortado.
9. **§2.9 / §2.10** — ejes de las gráficas y tarjetas de métricas del admin.
10. **§2.11** — rellenar `VEHICLE_IMAGE_API_KEY` y sustituir el Mercedes por un placeholder neutro.
11. **§2.12** — sacar el push del arranque.
12. **§2.17** — confirmar App Check en el dominio real antes de tocar el enforcement.
13. **§2.13** — exponer la barra superior y la lateral de `/chat_list`.
14. Resto: **§2.14 · §2.15 · §2.16 · §2.18 · §2.19**.
---

## 7. Tercera pasada — subidas, servicio completo, servicio manual y cotizaciones

Ejecutada con datos ficticios y autorización expresa para escribir en producción.
La segunda mitad se hizo **contra el sitio real** `https://autodoc-6ef5a.web.app`, que
es el artefacto que usan los usuarios.

### 7.1 ⚠️ Correcciones importantes a la segunda pasada

**Retracto tres hallazgos.** Al final de la sesión larga en localhost la página dejó de
responder por completo: primero los campos de texto perdían los primeros caracteres tras
enfocarlos, luego los clics dejaron de registrarse, y al final ni el propio login
reaccionaba. Llegué a documentar como fallos «las tarjetas del garaje no abren el
vehículo», «el perfil del vehículo no hace scroll» y «hay ~1 s de ventana muerta al
escribir». **En una pestaña nueva los tres funcionan perfectamente**, comprobado en
producción: la tarjeta abre el perfil, el perfil hace scroll con la rueda y los campos
aceptan el texto completo desde el primer carácter.

Una recarga completa en la misma pestaña **no** recuperaba el estado; solo una pestaña
nueva. Eso apunta al proceso de la pestaña/renderer, no al estado de Flutter, así que lo
más probable es que sea un artefacto de la automatización con sesiones largas y no algo
que sufran los usuarios. Merece una comprobación manual: dejar la app abierta 30–40
minutos y probar a pulsar.

**También corrijo el hallazgo de App Check.** En `https://autodoc-6ef5a.web.app`, con
almacenamiento limpio, el login funciona a la primera. El `appCheck/recaptcha-error` y el
fallo de login tras borrar IndexedDB **solo ocurren en `127.0.0.1`**, porque ese origen no
está en los dominios autorizados de la clave reCAPTCHA Enterprise. En producción no hay
problema; queda como una fricción de desarrollo local, no como riesgo de despliegue.

### 7.2 🔴 Un taller no puede cerrar un servicio si el vehículo no tiene tareas configuradas

Recorrido completo como `taller1@taller.com`: buscar placa → añadir material («Filtro de
aceite (QA)», 2 × $12.50) → mano de obra $35 → **el total se autocalcula a $60.00** →
observaciones → adjuntar factura. Todo correcto. Y al pulsar **FINALIZAR SERVICIO**:

> «Selecciona al menos una tarea realizada»

Pero la sección *TAREAS A REALIZAR* de esa misma pantalla dice **«No hay tareas
configuradas para este vehículo»**. No hay ninguna casilla que marcar.

**Causa raíz:**

- [`initiate_service_screen.dart:1154`](../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L1154)
  — con `provider.maintenanceTasks` vacío solo se pinta ese texto, sin ninguna casilla.
- [`initiate_service_screen.dart:317`](../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L317)
  — el guard exige `_completedTaskIds.isNotEmpty` sin excepción.

Callejón sin salida: el taller rellena todo el parte y no puede guardarlo. Las tareas las
configura el **propietario**, y nada en la pantalla lo dice ni ofrece crear una.

*(Comprobado que la factura no se sube hasta guardar, así que un intento fallido no deja
ficheros huérfanos en Storage.)*

Capturas `qa-78-material-agregado.png`, `qa-81-factura-adjunta.png`, `qa-82-confirmar-finalizar.png`.

### 7.3 🟠 Alertas contradictorias y kilometraje incoherente

En `/alerts` del propietario, **«Rotación de Llantas» aparece dos veces a la vez**: en
*PRIORIDAD ALTA* como «¡CRÍTICO! Límite de Rotación de Llantas superado» y en
*SUGERENCIAS* como **ÓPTIMO**, «Próximo servicio en 64367 km aprox.».

Además los números no cuadran: «Kilometraje actual: **254 km**» frente a «Último:
**54,621 km**». El odómetro del vehículo está muy por debajo del último servicio
registrado, lo que hace que los cálculos de «próximo servicio» salgan disparatados.
Captura `qa-127-alertas.png`.

### 7.4 🟠 El bug de ejes de las gráficas también está en el perfil del vehículo

El mismo defecto de §2.9 (una etiqueta por punto en vez de una por mes) aparece en
«Resumen de Gastos» del perfil del vehículo:
`Mar Mar Mar Mar Mar Abr Abr Abr Abr Abr Abr May May May May Jun …`. Es el componente de
gráfica compartido, así que arreglarlo cierra los dos sitios de una vez.
Captura `qa-123-prod-perfil-scroll.png`.

### 7.5 🟡 Otros detalles de esta pasada

| Detalle | Dónde |
|---|---|
| Un vehículo tiene el color guardado como **`Gris13`**: el campo es texto libre sin validación | Perfil del vehículo |
| El error de Auth se muestra **sin traducir**: «Ocurrió un error inesperado: A network AuthError (such as timeout, interrupted connection or unreachable host) has occurred.» | Login |
| En la cotización recibida, **«Rechazar» se pinta con el color de acento** y «Aceptar» en morado: la acción destructiva no se lee como tal | Chat, propietario |
| Al aceptar la cotización **no aparece ninguna tarjeta de reserva** ni se navega a `/reserva_detail`; el estado de la cotización sí pasa a EN PROCESO. No pude confirmar que la reserva se cree | Chat |

---

## 8. Resultado de los cuatro flujos que faltaban

| Flujo | Resultado |
|---|---|
| **Subida de ficheros** | ✅ **Funciona.** Logo y foto del local del taller: `POST` a Storage 200 y relectura pública 200 (`talleres_fotos/{uid}/logo.png`, `/local-1.png`). Evidencia del servicio manual del propietario: subida y adjuntada. **§6.2 del plan cerrado.** |
| **Cerrar un servicio completo** | ❌ **Bloqueado** por §7.2. Todo el formulario funciona (materiales, autocálculo del total, observaciones, factura); solo falla el guardado. |
| **Servicio manual del propietario (§1.4)** | ✅ **Funciona end-to-end**: costo, notas, evidencia obligatoria y «Servicio validado y registrado en historial ✓». La tarea se actualizó a «Último: 254 km». |
| **Cotizaciones** | ✅ **Funciona end-to-end**: el taller la crea con fecha, hora, renglones y total; el propietario la recibe y al aceptar pasa de **PENDIENTE** a **EN PROCESO**. |
| **Reservas** | ⚠️ **Sin confirmar** (ver §7.5). |

Capturas `qa-73`, `qa-74` (subidas), `qa-114`–`qa-118` (cotización), `qa-125`, `qa-126`
(aceptación), `qa-128`–`qa-130` (servicio manual).

---


## 9. Anexos

- `docs/qa/capturas/` — 144 capturas, numeradas en orden de recorrido.
- `docs/qa/qa-consola-completa.log` — volcado de consola del navegador.
- `docs/qa/reporte-qa-playwright-2026-08-28.html` — este informe como página autocontenida.
