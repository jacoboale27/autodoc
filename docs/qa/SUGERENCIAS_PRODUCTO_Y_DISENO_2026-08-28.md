# Sugerencias de producto y diseño — AutoDoc

**Fecha:** 2026-08-28 · Escritas después de recorrer la app entera con los cuatro roles
(propietario, taller pendiente, taller aprobado, superadministrador) y ejecutar los flujos
reales: alta, garaje, chat, cotización, servicio y panel de administración.

No son ideas en abstracto: cada una nace de algo que me pasó usando la app.

---

## 1. Producto — huecos que se notan al usarla

### 1.1 🔴 Nadie puede crear una tarea de mantenimiento desde donde hace falta

Es el hueco más caro de todos. El taller **no puede cerrar un servicio** si el vehículo no
tiene tareas configuradas, y no tiene forma de crearlas: las configura el propietario, desde
otra pantalla, en otra sesión. En la práctica el taller queda bloqueado esperando que el
cliente entre a la app.

**Propuesta:** un catálogo de **plantillas de mantenimiento por marca/modelo/año**. Al
registrar un vehículo se aplican las tareas estándar (aceite cada 5.000 km, filtro de aire
cada 15.000, rotación cada 10.000, frenos cada 20.000). El propietario ajusta intervalos si
quiere; el taller siempre encuentra algo que marcar. Cierra el bloqueante *y* elimina el
estado vacío de "No hay tareas configuradas", que hoy aparece en el 100 % de los vehículos
nuevos.

### 1.2 🔴 El propietario no ve en qué estado está su carro

El taller tiene un kanban precioso —Recibido / En Revisión / Esperando Repuestos / Listo para
Entregar— y el propietario **no ve nada de eso**. Solo recibe un push suelto («Tu vehículo ya
está en seguimiento») y luego silencio hasta que el servicio se cierra.

**Propuesta:** una tarjeta de *seguimiento en vivo* en el dashboard del propietario, con los
mismos cuatro estados y la hora del último cambio. Es dato que ya existe en `reparaciones`; solo
falta exponerlo del lado del cliente. Es la funcionalidad que convierte la app en algo que se
abre a diario, no solo cuando toca revisión.

### 1.3 🟠 Las reseñas no se piden nunca

45 usuarios, 15 servicios registrados y **2 reseñas** en toda la plataforma. Los cuatro talleres
del directorio salen con **0.0★**, lo que hace que el directorio no sirva para elegir: todos
parecen iguales.

**Propuesta:** pedir la reseña **en el momento**, con un push y una tarjeta en el chat cuando el
servicio pasa a *Listo para Entregar*, no un formulario escondido. Y mientras un taller no tenga
reseñas, mostrar «Sin reseñas todavía» en vez de `0.0★`, que se lee como *malo* y no como
*desconocido*.

### 1.4 🟠 El historial de servicios no sale de la app

`pubspec.yaml` ya incluye `printing`, pero no hay forma de exportar nada. Para vender un carro,
reclamar una garantía o justificar un gasto, el historial hay que enseñarlo desde el móvil.

**Propuesta:** botón *Exportar historial (PDF)* en el perfil del vehículo, con las facturas ya
adjuntas de cada servicio. Es la función que convierte «llevo el mantenimiento en la app» en
«el carro vale más porque tengo el historial». Diferenciador real frente a una libreta.

### 1.5 🟠 El taller no puede deshacer nada

El tablero solo ofrece *Avanzar*. Un ticket abierto por error —y con el bug actual basta con
teclear mal una placa— se queda ahí para siempre, y el propietario ya recibió el aviso.

**Propuesta:** *Cancelar* con motivo (ya planificado como Task 5), y que el estado cancelado
mande su propia notificación al propietario. Sin deshacer, cualquier error operativo se
convierte en una llamada de teléfono.

### 1.6 🟡 La verificación del taller es opcional de facto

Un taller aprobado a mano entra al directorio público sin haber subido nunca la foto de fachada.
El expediente de verificación existe, es bueno, y no bloquea nada.

**Propuesta:** que el sello de *verificado* sea visible en el directorio y que los talleres sin
expediente aparezcan más abajo. Convierte la verificación en algo que el taller quiere hacer, en
vez de un trámite que puede saltarse.

### 1.7 🟡 Los empleados no tienen permisos distintos del dueño

`crearEmpleadoTaller` crea sub-cuentas con **los mismos permisos operativos** que el dueño. Un
mecánico de mostrador puede cambiar la ficha pública, la ubicación y el catálogo de precios.

**Propuesta:** dos roles dentro del taller — *operario* (buscar vehículo, mover el kanban, cerrar
servicios) y *administrador del taller* (además: ficha pública, precios, empleados, fotos). El
campo `id_taller_propietario` ya distingue las sub-cuentas; falta el nivel.

### 1.8 🟡 Ordenar talleres por cercanía no funciona en web

`Permission.locationWhenInUse` no está soportado en web, así que «Talleres Cercanos» no está
ordenado por nada. La configuración del taller sí guarda coordenadas GPS.

**Propuesta:** usar la Geolocation API del navegador en web (`geolocator_web` ya está, aunque
bloquea el build WASM) o, más simple, dejar que el propietario fije su municipio en el perfil y
ordenar por eso. Un desplegable resuelve el 90 % del valor sin pedir permisos.

### 1.9 🟡 Búsquedas recientes que nunca se llenan

La pantalla *Buscar Vehículo* tiene una sección «Búsquedas Recientes» con un estado vacío muy
cuidado… que sigue vacío después de buscar. Solo se puebla al abrir el vehículo, y hoy eso crea
un ticket. Al arreglar Task 4, conviene poblar el historial **en la búsqueda**, que es cuando el
usuario espera verlo.

---

## 2. Diseño — lo que se ve al usarla en escritorio

### 2.1 La app es móvil estirada, no una app de escritorio

Es el patrón que más se repite. A 1440 px:

- El botón **Finalizar Configuración** ocupa los 1440 px completos bajo una tarjeta de 560.
- **Cerrar Sesión** y **Eliminar cuenta** hacen lo mismo en el perfil.
- El *hero* del perfil del vehículo mide **620 px de alto**: media pantalla antes del primer dato.
- Las tarjetas de métricas del admin miden ~270 px con el número pegado abajo y 200 px de nada.

**Propuesta:** un `maxWidth` para los contenedores de acción (480-560 px, alineados con la tarjeta
que acompañan) y alturas que se ajusten al contenido en vez de estirarse. La regla simple: *si un
botón es más ancho que la tarjeta a la que pertenece, está mal*.

### 2.2 Dos acentos compitiendo en modo oscuro

En oscuro el acento es turquesa —nav activo, botones primarios, iconos— pero **Cerrar Sesión** y
el **FAB** salen morados, y en el chat las burbujas propias también. El morado es el color de
marca en claro; en oscuro se cuela a medias.

**Propuesta:** decidir si el morado es el primario en ambos temas o solo en claro, y aplicarlo en
`AppColors` de una vez. Ahora mismo la pantalla de perfil tiene tres acentos a la vez.

### 2.3 Texto que se corta en sitios donde sobra espacio

`O CONTINUAR CON` se pinta **«O CONTINUA…»** en las tres anchuras que probé, con la tarjeta medio
vacía a los lados. Igual el placeholder del correo (`nombre@ejemplo.com o usua…`), la cabecera del
datepicker (`Fecha de nacim…`) y la acción del kanban (`Avanzar a Esperando Re…`).

**Propuesta:** son `Row` sin `Flexible` alrededor del texto. Una pasada por los separadores y las
acciones con etiqueta larga lo cierra. Un texto recortado con espacio libre alrededor es lo que
más barato se arregla y más caro se ve.

### 2.4 El destructivo no parece destructivo

Dos sitios, dos maneras distintas y ambas al revés:

- En `/admin/verificaciones`, **Rechazar** está *encima* de **Aprobar**, ambos a todo el ancho y
  con el mismo peso. El botón que más pesa visualmente es el irreversible.
- En la cotización recibida, **Rechazar** se pinta con el color de acento y **Aceptar** en morado.

**Propuesta:** una regla única — la acción constructiva es primaria y va primero; la destructiva
es `text` en `colors.error` y pide confirmación. Ya existe `AppDialogContent`.

### 2.5 El contador del kanban se lee de la columna equivocada

En *Reparaciones*, el número de cada columna está alineado a su derecha, a 24 px del título de la
**siguiente**. Se lee `Recibido … 2 | En Revisión` y parece que el 2 es de «En Revisión».

**Propuesta:** el contador pegado al título, como *chip* (`Recibido (2)`), o separadores verticales
entre columnas.

### 2.6 Detalles de contenido que delatan el interior

- «Solicitudes formales **(colección Talleres)**» enseña el nombre de la colección Firestore al
  administrador.
- Los tres desplegables de filtro de `/admin/talleres` dicen los tres «Todos», sin decir qué filtran.
- Las solicitudes de verificación y el registro de actividad identifican al taller por su **UID**.
- `assets/images/default_vehicle.jpg` es la foto de un **Mercedes-Benz Clase C**: cualquier
  vehículo sin imagen aparece como un Mercedes plateado, indistinguible de un resultado real y
  equivocado.
- El error de Auth aparece a medio traducir: «Ocurrió un error inesperado: A network AuthError
  (such as timeout, interrupted connection or unreachable host) has occurred.»

### 2.7 Lo que ya está muy bien y conviene no tocar

Para calibrar: el **panel del taller** es la mejor parte de la app. La barra lateral es clara, los
estados vacíos están cuidados uno a uno («Aún no tienes empleados», «Aún no tienes ítems en tu
catálogo», «Los servicios que registres desde Buscar Vehículo aparecerán aquí»), el kanban se
entiende sin explicación y la pantalla de iniciar servicio tiene una jerarquía de dos columnas que
funciona. El formulario de cotización, con su autocálculo del total y el campo *Beneficio ($) — solo
tú lo ves*, está mejor pensado que la media del sector. El onboarding, el semáforo de estados del
admin y la validación de placa salvadoreña también están bien resueltos.

El problema de diseño no es la calidad; es la **consistencia entre pantallas** y el salto a
escritorio.

---

## 3. Skills que aportan valor a este plan

Ejecuté `/find-skills` sobre el repositorio. De los cuatro marketplaces registrados
(claude-plugins-official, easier-life-skills, karpathy-skills, ui-ux-pro-max-skill) estas son las
que valen para lo que viene:

| # | Skill · marketplace | Relevancia | Por qué encaja aquí |
|---|---|---|---|
| 1 | **firebase** · claude-plugins-official | **Alta** | La Task 1 exige `firebase deploy --only storage` y verificar reglas; la limpieza posterior exige borrar tickets, cotizaciones y ficheros de Storage creados en el QA. Durante el recorrido tuve que deducir `usuarios/{uid}.estado` por la API REST pública porque no podía leer Firestore directamente — con este MCP eso es una consulta. |
| 2 | **site-audit** · easier-life-skills | **Alta** | Es la versión sistematizada de lo que hice a mano: crawlea con Playwright MCP y audita UX, accesibilidad y bugs. Habría encontrado sola los botones sin nombre del garaje y la barra superior ausente del árbol semántico. Úsala como regresión después de las Tasks 14 y 15. |
| 3 | **brainstorm** · easier-life-skills | **Alta** | «Sugiere las 5 mejoras más valiosas para un proyecto». Es exactamente la sección 1 de este documento, y conviene volver a pasarla cuando el plan esté ejecutado y el mapa haya cambiado. |
| 4 | **security-review** · easier-life-skills | **Media-alta** | El hallazgo §1 fue una divergencia entre dos definiciones de `isAdmin()` que nadie detectó en revisión. Un escaneo de OWASP + secretos sobre `firestore.rules`, `storage.rules` y `functions/` buscaría el resto de esa familia. Ojo también con `functions/src/aprobarTodosTalleres.js`, un script que marca `estado: 'aprobado'` a **todos** los usuarios y vive dentro de `functions/`. |
| 5 | **dependency-audit** · easier-life-skills | **Media** | Hay dos señales concretas: `geolocator_web` usa `dart:html` y bloquea el build WASM, y `google.maps.Marker` está deprecado desde 2024-02-21. Este skill las agrupa con el resto del árbol de dependencias. |
| 6 | **frontend-design** · claude-plugins-official | **Media** | Para la sección 2: el problema no es la calidad de cada pantalla sino la consistencia entre ellas y el salto a escritorio. Es el tipo de trabajo que este skill hace bien. |
| 7 | **code-audit** · easier-life-skills | **Media** | Encuentra código muerto y audita la calidad del logging. La consola de la app escupe mucho `debugPrint` en producción (todo el bloque `[AutoDoc Init]`, `Got object store box…`), que además es ruido donde luego hay que buscar errores reales. |

**Ya instaladas y en uso:** `playwright` (el recorrido entero), `superpowers` (este plan sale de
`writing-plans`), `ui-ux-pro-max`, `andrej-karpathy-skills`, `find-skills`.

**Revisadas y descartadas:** `docs` (el repo ya tiene `README`, `CONVENTIONS.md`, `RUNBOOK.md` y
`docs/` completos), `task-agent` y `auto-board-task` (no hay tablero de GitHub Projects en el
repo), `cost-tracker` (no resuelve nada de este plan), `superdesign` (solapa con
`frontend-design`, que encaja mejor por leer el código existente), `scaffold` y `workflow` (no hay
plugins propios que crear).

**Instalación:**

```
/plugin marketplace add dan323/easier-life-skills
/plugin install easier-life-skills/site-audit
/plugin install easier-life-skills/brainstorm
/plugin install easier-life-skills/security-review
/plugin install easier-life-skills/dependency-audit
/plugin install easier-life-skills/code-audit
/plugin install claude-plugins-official/firebase
/plugin install claude-plugins-official/frontend-design
```

---

## 4. Por dónde empezar

Si solo hay tiempo para tres cosas antes de la demo:

1. **Task 1** — `'Superusuario'` en `storage.rules` y desplegar. Sin esto el administrador aprueba
   talleres a ciegas, y son 12 reglas afectadas.
2. **Task 2 + Task 3** — el año fantasma del alta y el servicio que no se puede cerrar. Son los dos
   callejones sin salida: uno bloquea al usuario nuevo en su primera acción, el otro al taller con
   el parte entero relleno.
3. **Task 4** — que buscar una placa no cree un ticket ni notifique al propietario. Es el que puede
   dejar en evidencia durante la demo, porque basta con teclear mal una placa.

Y del lado de producto, la apuesta con más retorno por esfuerzo es **1.1 (plantillas de
mantenimiento)**: cierra un bloqueante, elimina un estado vacío universal y hace que las alertas
del propietario tengan sentido desde el primer día.
