# Corrección de los hallazgos del recorrido QA — Plan de implementación

> **Para trabajadores agénticos:** SUB-SKILL REQUERIDA: usa `superpowers:subagent-driven-development`
> (recomendado) o `superpowers:executing-plans` para implementar este plan tarea a tarea.
> Los pasos usan sintaxis de casilla (`- [ ]`) para el seguimiento.

**Goal:** Cerrar los 17 hallazgos del recorrido QA del 2026-08-28 — cuatro bloqueantes incluidos —
sin romper ninguno de los 689 tests existentes.

**Architecture:** Cada bloque es independiente y termina en algo desplegable. El Bloque A toca
reglas de Storage y exige un `firebase deploy`; el resto es solo cliente Flutter y se valida con
`flutter test`. Las tareas siguen TDD: test que falla → implementación mínima → test que pasa →
commit.

**Tech Stack:** Flutter 3.41 / Dart 3.11 · Firebase (Auth, Firestore, Storage, Functions) ·
Provider · GoRouter · fl_chart · Jest + `@firebase/rules-unit-testing` para reglas.

**Spec:** `docs/qa/REPORTE_QA_PLAYWRIGHT_2026-08-28.md` (informe de QA con capturas y causa raíz
de cada hallazgo). Las referencias `§N` de este plan son sus secciones.

## Restricciones globales

- **Idioma de la UI**: todo texto visible va en `lib/l10n/app_es.arb` **y** `app_en.arb`. Nunca
  literales en pantalla salvo que ya existan en ese archivo.
- **Colores**: prohibido `Colors.*` en widgets. Siempre `context.appColors` / `Theme.of(context)`
  (ver `CONVENTIONS.md` §2.1).
- **Estado**: la lógica vive en providers; las páginas no llaman a Firebase (`CONVENTIONS.md` §1).
- **Estados de cuenta**: cualquier comparación de `estado` pasa por `AppEstadoCuenta`
  (`lib/core/theme/app_estado_cuenta.dart`). No repetir literales `'aprobado'` / `'activo'`.
- **Verificación por tarea**: `flutter analyze` limpio y `flutter test` en verde antes de commit.
- **Reglas**: `cd test_rules && npm test` antes de cualquier `firebase deploy`.

## Mapa de ficheros

| Fichero | Responsabilidad | Bloque |
|---|---|---|
| `storage.rules` | `isAdmin()` acepta `Superusuario` | A |
| `test_rules/storage.test.js` | Regresión de A | A |
| `lib/features/dashboard/presentation/widgets/add_vehicle_form.dart` | Año/color con estado visible | B1 |
| `lib/features/mechanic/presentation/pages/initiate_service_screen.dart` | Guard de tareas + ticket bajo confirmación | B2, B3 |
| `lib/features/dashboard/presentation/pages/dashboard_screen.dart` | Refresco de alertas con garaje vacío | C1 |
| `lib/core/providers/session_reset.dart` *(nuevo)* | Limpieza de providers al cerrar sesión | C2 |
| `lib/features/chat/presentation/widgets/chat_bubble.dart` | Burbuja ajena con contraste | D1 |
| `lib/features/dashboard/presentation/pages/garage_screen.dart` | Nombre del vehículo sin recortar | D2 |
| `lib/features/auth/presentation/pages/auth_screen.dart` | Copy del diálogo de verificación | D3 |
| `lib/features/admin/presentation/pages/admin_verificacion_screen.dart` | Identidad del taller | D4 |
| `lib/core/widgets/charts/month_axis.dart` *(nuevo)* | Eje de meses compartido | D5 |
| `lib/core/widgets/app_card.dart` + call sites | `semanticLabel` obligatorio | E1 |
| `.env`, `lib/core/services/vehicle_image_service.dart`, `assets/images/` | Imágenes de vehículo | F1 |
| `lib/main.dart` | Push fuera del arranque | F2 |
| `.github/workflows/ci.yml` | `flutter clean` antes del build web | F3 |

---

## Bloque A — Reglas de Storage (requiere deploy)

### Task 1: `isAdmin()` de Storage acepta `Superusuario`

**Files:**
- Modify: `storage.rules:11-15`
- Test: `test_rules/storage.test.js`

**Interfaces:**
- Produces: `isAdmin()` en Storage devuelve `true` para `rol == 'Superusuario'`, igual que
  `firestore.rules:30`.

- [ ] **Step 1: Escribe el test que falla**

Añade al final de `test_rules/storage.test.js`:

```javascript
describe('storage: isAdmin acepta Superusuario', () => {
  test('un Superusuario puede leer la evidencia de verificacion de un taller', async () => {
    await seedUsuario(UIDS.taller1, 'Mecanico');
    await seed(env, async (db) => {
      await db.collection('usuarios').doc(UIDS.admin).set({
        id_usuario: UIDS.admin, rol: 'Superusuario', estado: 'activo',
      });
    });
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage().ref(`verificaciones/${UIDS.taller1}/fachada.jpg`)
        .put(imagen(50), META_JPEG);
    });
    const st = env.authenticatedContext(UIDS.admin).storage();
    await assertSucceeds(
      st.ref(`verificaciones/${UIDS.taller1}/fachada.jpg`).getDownloadURL(),
    );
  });

  test('un Administrador tambien puede leerla', async () => {
    await seedUsuario(UIDS.taller1, 'Mecanico');
    await seedUsuario(UIDS.admin, 'Administrador');
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage().ref(`verificaciones/${UIDS.taller1}/fachada.jpg`)
        .put(imagen(50), META_JPEG);
    });
    const st = env.authenticatedContext(UIDS.admin).storage();
    await assertSucceeds(
      st.ref(`verificaciones/${UIDS.taller1}/fachada.jpg`).getDownloadURL(),
    );
  });

  test('un propietario cualquiera sigue sin poder leerla', async () => {
    await seedUsuario(UIDS.taller1, 'Mecanico');
    await seedUsuario(UIDS.owner2, 'Propietario');
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage().ref(`verificaciones/${UIDS.taller1}/fachada.jpg`)
        .put(imagen(50), META_JPEG);
    });
    const st = env.authenticatedContext(UIDS.owner2).storage();
    await assertFails(
      st.ref(`verificaciones/${UIDS.taller1}/fachada.jpg`).getDownloadURL(),
    );
  });
});
```

- [ ] **Step 2: Ejecuta el test y comprueba que falla**

Run: `cd test_rules && npx jest storage.test.js -t "Superusuario" --runInBand`
Expected: FAIL — el caso de `Superusuario` da `PERMISSION_DENIED`.

- [ ] **Step 3: Corrige la regla**

En `storage.rules`, sustituye la función:

```
    function isAdmin() {
      return isAuthenticated() &&
        firestore.exists(/databases/(default)/documents/usuarios/$(request.auth.uid)) &&
        firestore.get(/databases/(default)/documents/usuarios/$(request.auth.uid)).data.rol
          in ['Administrador', 'admin', 'Superusuario'];
    }
```

Añade encima este comentario, para que la próxima persona no vuelva a separarlas:

```
    // ESTA LISTA DEBE COINCIDIR CON isAdmin() DE firestore.rules:30.
    // Estuvieron desincronizadas hasta 2026-08-28: aqui faltaba
    // 'Superusuario', asi que el superadmin pasaba todos los checks de
    // Firestore y fallaba TODOS los de Storage — incluida la foto de
    // fachada de /admin/verificaciones, la unica evidencia obligatoria
    // para aprobar un taller. Hay 12 reglas en este archivo que dependen
    // de isAdmin(); el agujero las afectaba a todas.
```

- [ ] **Step 4: Ejecuta la suite completa de reglas**

Run: `cd test_rules && npm test`
Expected: PASS — 175 tests previos + los 3 nuevos.

- [ ] **Step 5: Commit**

```bash
git add storage.rules test_rules/storage.test.js
git commit -m "fix(storage): isAdmin acepta Superusuario, que no podia ver la evidencia de verificacion"
```

- [ ] **Step 6: Despliega (acción humana)**

Run: `firebase deploy --only storage --project autodoc-6ef5a`
Verifica después en `/admin/verificaciones` que la foto de fachada carga (antes daba 403).

---

## Bloque B — Bloqueantes de flujo

### Task 2: El año del alta de vehículo deja de mentir

**Files:**
- Modify: `lib/features/dashboard/presentation/widgets/add_vehicle_form.dart:536-550`, `:609-631`
- Test: `test/features/dashboard/presentation/widgets/add_vehicle_form_anio_test.dart` (crear)

**Interfaces:**
- Produces: cuando `_anioController.text` está vacío, el campo Año muestra un *placeholder*
  con `colors.textSecondary`; el submit señala el error **en el campo**, no en un snackbar.

- [ ] **Step 1: Escribe el test que falla**

Crea `test/features/dashboard/presentation/widgets/add_vehicle_form_anio_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';

import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets(
    'el placeholder de Ano se pinta con textSecondary, no como un valor elegido',
    (tester) async {
      await pumpAtWidth(tester, const _AnioProbe(), 1440);
      await tester.pumpAndSettle();

      final texto = tester.widget<Text>(find.text('Selecciona el ano'));
      final contexto = tester.element(find.text('Selecciona el ano'));
      expect(
        texto.style!.color,
        AppTheme.lightTheme.extension<AppColors>()!.textSecondary,
        reason: 'un placeholder no puede tener el mismo peso visual que un valor real',
      );
      expect(texto.style!.fontWeight, isNot(FontWeight.bold));
      expect(contexto, isNotNull);
    },
  );
}
```

> El `_AnioProbe` monta solo el bloque del campo Año extraído a
> `_buildAnioField(BuildContext, AppColors)`; extraerlo es parte del Step 3.

- [ ] **Step 2: Ejecuta el test y comprueba que falla**

Run: `flutter test test/features/dashboard/presentation/widgets/add_vehicle_form_anio_test.dart`
Expected: FAIL — hoy el literal `'2024'` se pinta en `textPrimary` y `FontWeight.bold`.

- [ ] **Step 3: Corrige el render del campo**

En `add_vehicle_form.dart`, sustituye el bloque de las líneas 542-550:

```dart
                              Text(
                                _anioController.text.isEmpty
                                    ? context.l10n.addVehicleYearHint
                                    : _anioController.text,
                                style: TextStyle(
                                  // Un placeholder NO puede parecer un valor
                                  // elegido: hasta 2026-08-28 aqui se pintaba
                                  // el literal '2024' en bold/textPrimary, y el
                                  // usuario no tenia forma de saber que el
                                  // campo seguia vacio. Al enviar saltaba
                                  // "Ano invalido" senalando un campo que a la
                                  // vista tenia un ano correcto.
                                  fontWeight: _anioController.text.isEmpty
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  color: _anioController.text.isEmpty
                                      ? colors.textSecondary
                                      : colors.textPrimary,
                                ),
                              ),
```

Añade a `lib/l10n/app_es.arb`:

```json
  "addVehicleYearHint": "Selecciona el año",
```

y a `lib/l10n/app_en.arb`:

```json
  "addVehicleYearHint": "Select the year",
```

Luego `flutter gen-l10n`.

- [ ] **Step 4: Mueve el error del año al campo**

En el `onPressed` de `addVehicleFinish` (línea ~604), sustituye el bloque del snackbar por
un estado de error del formulario:

```dart
                  final anio = int.tryParse(_anioController.text);
                  final currentYear = DateTime.now().year;
                  if (anio == null || anio < 1900 || anio > currentYear) {
                    setState(() => _anioError = context.l10n.addVehicleYearInvalid);
                    return;
                  }
                  setState(() => _anioError = null);

                  if (_colorController.text.trim().isEmpty) {
                    setState(() => _colorError = context.l10n.addVehicleColorRequired);
                    return;
                  }
                  setState(() => _colorError = null);
```

Declara los dos campos junto a los controladores (línea ~113):

```dart
  String? _anioError;
  String? _colorError;
```

y píntalos bajo cada campo, con el mismo patrón que ya usa la placa:

```dart
                              if (_anioError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _anioError!,
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: colors.error),
                                  ),
                                ),
```

- [ ] **Step 5: Ejecuta los tests**

Run: `flutter test test/features/dashboard/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dashboard/presentation/widgets/add_vehicle_form.dart lib/l10n/ test/
git commit -m "fix(vehiculos): el ano dejaba de parecer relleno estando vacio y el error va al campo"
```

---

### Task 3: Se puede cerrar un servicio aunque el vehículo no tenga tareas

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/initiate_service_screen.dart:317-324`, `:1151-1160`
- Test: `test/features/mechanic/presentation/pages/initiate_service_tareas_test.dart` (crear)

**Interfaces:**
- Produces: `FINALIZAR SERVICIO` solo exige una tarea marcada **si hay tareas que marcar**.

- [ ] **Step 1: Escribe el test que falla**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';

void main() {
  test(
    'sin tareas configuradas el guard no exige seleccionar ninguna',
    () {
      expect(
        requiereTareaSeleccionada(tareasDisponibles: 0, tareasMarcadas: 0),
        isFalse,
        reason: 'no se puede exigir marcar una casilla que la pantalla no dibuja',
      );
    },
  );

  test('con tareas disponibles sigue exigiendo al menos una', () {
    expect(
      requiereTareaSeleccionada(tareasDisponibles: 3, tareasMarcadas: 0),
      isTrue,
    );
    expect(
      requiereTareaSeleccionada(tareasDisponibles: 3, tareasMarcadas: 1),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Ejecuta el test y comprueba que falla**

Run: `flutter test test/features/mechanic/presentation/pages/initiate_service_tareas_test.dart`
Expected: FAIL — `requiereTareaSeleccionada` no existe.

- [ ] **Step 3: Extrae el guard a una función pura y úsala**

Al final de `initiate_service_screen.dart`, fuera de la clase:

```dart
/// Decide si hay que exigir al mecanico marcar una tarea antes de cerrar el
/// servicio.
///
/// Hasta 2026-08-28 el guard era `_completedTaskIds.isEmpty` a secas, sin
/// mirar si habia tareas que marcar. Cuando el vehiculo no tenia ninguna
/// configurada, la pantalla pintaba "No hay tareas configuradas para este
/// vehiculo" (sin casillas) y el submit respondia "Selecciona al menos una
/// tarea realizada": un callejon sin salida con el parte entero relleno.
bool requiereTareaSeleccionada({
  required int tareasDisponibles,
  required int tareasMarcadas,
}) {
  if (tareasDisponibles == 0) return false;
  return tareasMarcadas == 0;
}
```

Sustituye el bloque de la línea 317:

```dart
    final tareasDisponibles = context.read<AlertProvider>().maintenanceTasks.length;
    if (requiereTareaSeleccionada(
      tareasDisponibles: tareasDisponibles,
      tareasMarcadas: _completedTaskIds.length,
    )) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(
        context,
        'Selecciona al menos una tarea realizada',
      );
      return;
    }
```

- [ ] **Step 4: Explica el vacío en la propia pantalla**

En `_buildMaintenanceTasks` (línea 1154), sustituye el texto suelto por un aviso accionable:

```dart
    if (provider.maintenanceTasks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Este vehiculo no tiene tareas de mantenimiento configuradas.',
            style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Las configura el propietario desde Alertas. Puedes cerrar el '
            'servicio igualmente: quedara registrado en el historial.',
            style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ],
      );
    }
```

- [ ] **Step 5: Ejecuta los tests**

Run: `flutter test test/features/mechanic/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/mechanic/presentation/pages/initiate_service_screen.dart test/
git commit -m "fix(taller): permitir cerrar un servicio cuando el vehiculo no tiene tareas configuradas"
```

---

### Task 4: Buscar una placa deja de abrir un ticket y de notificar al dueño

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/initiate_service_screen.dart:213`, `:760-790`
- Test: `test/features/mechanic/presentation/pages/initiate_service_ticket_test.dart` (crear)

**Interfaces:**
- Produces: `_iniciarTicketReparacion` deja de llamarse desde `_onVehiculoListo`; se dispara solo
  desde el botón **Recibir vehículo**.

- [ ] **Step 1: Escribe el test que falla**

```dart
testWidgets(
  'abrir la pantalla de servicio NO crea el ticket de reparacion',
  (tester) async {
    final repo = _SpyReparacionRepository();
    await pumpInitiateService(tester, repo: repo, vehiculo: vehiculoFixture);
    await tester.pumpAndSettle();

    expect(
      repo.llamadasIniciar,
      0,
      reason: 'buscar una placa es una consulta: no puede escribir un ticket '
          'ni notificar al propietario sin que el taller confirme',
    );

    await tester.tap(find.text('Recibir vehiculo'));
    await tester.pumpAndSettle();
    expect(repo.llamadasIniciar, 1);
  },
);
```

- [ ] **Step 2: Ejecuta el test y comprueba que falla**

Run: `flutter test test/features/mechanic/presentation/pages/initiate_service_ticket_test.dart`
Expected: FAIL — `llamadasIniciar` vale 1 nada más montar.

- [ ] **Step 3: Quita la creación automática**

En `_onVehiculoListo`, borra la línea 213 (`await _iniciarTicketReparacion(vehiculo);`) y
deja este comentario en su lugar:

```dart
    // NO se crea el ticket aqui. Hasta 2026-08-28 se creaba al montar la
    // pantalla, asi que teclear una placa en "Buscar Vehiculo" ya metia el
    // coche en el kanban Y mandaba un push al propietario ("Tu vehiculo ya
    // esta en seguimiento") antes de que el taller confirmase nada. Un error
    // de tecleo era ademas irreversible: el tablero solo ofrece "Avanzar".
    // Ahora lo dispara el boton "Recibir vehiculo".
```

- [ ] **Step 4: Añade el botón de confirmación**

En el bloque de estado de reparación (línea ~785), cuando `_idReparacion == null` y no hay error:

```dart
    if (_idReparacion == null) {
      return AppButton(
        text: context.l10n.isReceiveVehicle,
        type: AppButtonType.secondary,
        icon: const Icon(Icons.garage_outlined),
        onPressed: _recibiendo ? null : () => _iniciarTicketReparacion(_vehiculo!),
      );
    }
```

l10n:

```json
  "isReceiveVehicle": "Recibir vehículo"
```
```json
  "isReceiveVehicle": "Receive vehicle"
```

- [ ] **Step 5: Ejecuta los tests**

Run: `flutter test test/features/mechanic/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/mechanic/presentation/pages/initiate_service_screen.dart lib/l10n/ test/
git commit -m "fix(taller): el ticket de reparacion se crea al confirmar, no al buscar la placa"
```

---

### Task 5: Cancelar un ticket desde el tablero

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart`
- Modify: `lib/features/mechanic/presentation/providers/reparacion_provider.dart`
- Modify: `firestore.rules` (bloque `reparaciones`), `test_rules/reparaciones.test.js`

**Interfaces:**
- Consumes: `requiereTareaSeleccionada` no; independiente de Task 3.
- Produces: `ReparacionProvider.cancelar(String idReparacion)` → `Future<bool>`.

- [ ] **Step 1: Test de reglas que falla**

En `test_rules/reparaciones.test.js`:

```javascript
test('el taller dueno del ticket puede cancelarlo', async () => {
  const db = await withRole(env, UIDS.taller1, 'Mecanico');
  await seed(env, async (admin) => {
    await admin.collection('reparaciones').doc('rep-1').set({
      id_taller: UIDS.taller1, id_vehiculo: 'veh-1', estado: 'recibido',
    });
  });
  await assertSucceeds(
    db.collection('reparaciones').doc('rep-1').update({ estado: 'cancelado' }),
  );
});

test('otro taller no puede cancelarlo', async () => {
  const db = await withRole(env, UIDS.taller2, 'Mecanico');
  await seed(env, async (admin) => {
    await admin.collection('reparaciones').doc('rep-1').set({
      id_taller: UIDS.taller1, id_vehiculo: 'veh-1', estado: 'recibido',
    });
  });
  await assertFails(
    db.collection('reparaciones').doc('rep-1').update({ estado: 'cancelado' }),
  );
});
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `cd test_rules && npx jest reparaciones.test.js --runInBand`

- [ ] **Step 3: Permite `cancelado` en las reglas y añade el método**

En `firestore.rules`, dentro del `allow update` de `reparaciones`, añade `'cancelado'` a la
lista de estados válidos. En `ReparacionProvider`:

```dart
  /// Cancela un ticket. Existe porque el tablero solo ofrecia "Avanzar": un
  /// ticket abierto por error (p. ej. una placa mal tecleada) no habia forma
  /// de retirarlo desde la interfaz.
  Future<bool> cancelar(String idReparacion) async {
    try {
      await _repository.cambiarEstado(idReparacion, 'cancelado');
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
```

- [ ] **Step 4: Añade la acción a la tarjeta del kanban**

En cada tarjeta, junto a *Avanzar*, un `AppButton` de tipo `text` con
`context.l10n.repCancel` que abra un `AppDialogContent` de confirmación antes de llamar a
`cancelar`.

- [ ] **Step 5: Ejecuta ambas suites**

Run: `cd test_rules && npm test` y `flutter test test/features/mechanic/`

- [ ] **Step 6: Commit**

```bash
git add firestore.rules test_rules/ lib/features/mechanic/ lib/l10n/
git commit -m "feat(taller): cancelar un ticket de reparacion desde el tablero"
```

---

## Bloque C — Estado entre sesiones

### Task 6: Las alertas dejan de sobrevivir al cambio de cuenta

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/dashboard_screen.dart:50-61`
- Test: `test/features/dashboard/presentation/pages/dashboard_screen_vehicle_fetch_test.dart`

- [ ] **Step 1: Escribe el test que falla**

```dart
testWidgets(
  'con el garaje vacio se piden alertas igualmente, para limpiar las del usuario anterior',
  (tester) async {
    final alertProvider = _SpyAlertProvider()..alerts = [alertaFixture];
    await pumpDashboard(tester, vehicles: const [], alertProvider: alertProvider);
    await tester.pumpAndSettle();

    expect(
      alertProvider.fetchLlamadoCon,
      isEmpty,
      reason: 'fetchAlertsForVehicles([]) vacia la lista; no llamarlo deja '
          'las alertas del usuario anterior en pantalla',
    );
    expect(alertProvider.alerts, isEmpty);
  },
);
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test test/features/dashboard/presentation/pages/dashboard_screen_vehicle_fetch_test.dart`
Expected: FAIL — hoy `fetchAlertsForVehicles` no se llama y `alerts` sigue con 1 elemento.

- [ ] **Step 3: Quita el guard**

```dart
          vehicleProvider.fetchVehicles(userSession.userData!.idUsuario).then((
            _,
          ) {
            if (!mounted) return;
            // Se llama SIEMPRE, tambien con la lista vacia: el provider ya
            // trata ese caso vaciando `_alerts` (alert_provider.dart:97).
            // Con el `isNotEmpty` que habia aqui, un usuario recien creado
            // veia las alertas del usuario de la sesion anterior — incluido
            // "Tu SOAT vencio hace 29 dias" de un coche que no es suyo.
            context.read<AlertProvider>().fetchAlertsForVehicles(
              vehicleProvider.vehicles,
            );
          });
```

- [ ] **Step 4: Ejecuta los tests**

Run: `flutter test test/features/dashboard/`

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/presentation/pages/dashboard_screen.dart test/
git commit -m "fix(dashboard): refrescar alertas tambien con el garaje vacio"
```

---

### Task 7: Cerrar sesión limpia todos los providers

**Files:**
- Create: `lib/core/providers/session_reset.dart`
- Modify: `lib/features/dashboard/presentation/providers/alert_provider.dart`,
  `lib/features/chat/presentation/providers/chat_provider.dart`,
  `lib/features/chat/presentation/providers/reserva_provider.dart`,
  `lib/core/providers/notification_center_provider.dart`
- Modify: `lib/features/profile/presentation/pages/user_profile_screen.dart:836-841`,
  `lib/features/mechanic/presentation/pages/mechanic_pending_screen.dart:64-67`
- Test: `test/core/providers/session_reset_test.dart` (crear)

**Interfaces:**
- Produces: `Future<void> resetSession(BuildContext context)` — cierra sesión en Firebase y
  vacía todo el estado por usuario. Cada provider expone `void clear()`.

- [ ] **Step 1: Escribe el test que falla**

```dart
test('resetSession vacia todos los providers con estado por usuario', () async {
  final alertas = AlertProvider()..debugSeed([alertaFixture]);
  final chat = ChatProvider()..debugSeed([conversacionFixture]);
  final reservas = ReservaProvider()..debugSeed([reservaFixture]);
  final notis = NotificationCenterProvider()..debugSeed([notificacionFixture]);

  clearUserScopedProviders(
    alertas: alertas, chat: chat, reservas: reservas, notificaciones: notis,
  );

  expect(alertas.alerts, isEmpty);
  expect(chat.conversaciones, isEmpty);
  expect(reservas.reservas, isEmpty);
  expect(notis.notifications, isEmpty);
});
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test test/core/providers/session_reset_test.dart`
Expected: FAIL — `clearUserScopedProviders` no existe.

- [ ] **Step 3: Añade `clear()` a cada provider**

`AlertProvider`:

```dart
  /// Vacia el estado por usuario. Se llama al cerrar sesion: sin esto, el
  /// siguiente usuario que entre sin recargar la pagina ve las alertas del
  /// anterior.
  void clear() {
    _alerts = [];
    _maintenanceTasks = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
```

`ChatProvider` (cancela también las suscripciones, que siguen escuchando con el uid viejo):

```dart
  void clear() {
    _conversacionesSub?.cancel();
    _mensajesSub?.cancel();
    _conversacionesSub = null;
    _mensajesSub = null;
    _conversaciones = [];
    _mensajesActuales = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
```

`ReservaProvider` y `NotificationCenterProvider`: mismo patrón con `_reservasSub` /
`_subscription` y sus listas.

- [ ] **Step 4: Crea el orquestador y úsalo en los dos cierres de sesión**

`lib/core/providers/session_reset.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

/// Vacia todo el estado que pertenece a **un** usuario.
///
/// Hasta 2026-08-28 `_signOut` solo llamaba a `AuthProvider.signOut()` y
/// navegaba: los providers seguian en memoria con los datos del usuario
/// saliente hasta la siguiente recarga completa de la pagina.
void clearUserScopedProviders({
  required AlertProvider alertas,
  required ChatProvider chat,
  required ReservaProvider reservas,
  required NotificationCenterProvider notificaciones,
  VehicleProvider? vehiculos,
  UserProfileProvider? perfil,
}) {
  alertas.clear();
  chat.clear();
  reservas.clear();
  notificaciones.clear();
  vehiculos?.clearVehicles();
  perfil?.clearUserData();
}

/// Azucar para llamarlo desde una pantalla.
void clearSessionFrom(BuildContext context) {
  clearUserScopedProviders(
    alertas: context.read<AlertProvider>(),
    chat: context.read<ChatProvider>(),
    reservas: context.read<ReservaProvider>(),
    notificaciones: context.read<NotificationCenterProvider>(),
    vehiculos: context.read<VehicleProvider>(),
    perfil: context.read<UserProfileProvider>(),
  );
}
```

En `user_profile_screen.dart:836`:

```dart
  Future<void> _signOut(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final router = GoRouter.of(context);
    clearSessionFrom(context);
    await authProvider.signOut();
    router.go('/login');
  }
```

Aplica lo mismo en `mechanic_pending_screen.dart:_signOut`.

- [ ] **Step 5: Ejecuta la suite completa**

Run: `flutter test`
Expected: PASS (689 + los nuevos).

- [ ] **Step 6: Commit**

```bash
git add lib/core/providers/session_reset.dart lib/features/ test/
git commit -m "fix(sesion): limpiar todos los providers por usuario al cerrar sesion"
```

---

## Bloque D — UI y contenido

### Task 8: La burbuja del mensaje recibido se ve en modo oscuro

**Files:**
- Modify: `lib/features/chat/presentation/widgets/chat_bubble.dart:89-91`
- Test: `test/features/chat/presentation/widgets/chat_bubble_contraste_test.dart` (crear)

- [ ] **Step 1: Escribe el test que falla**

```dart
testWidgets(
  'en oscuro la burbuja ajena contrasta con el fondo del chat',
  (tester) async {
    await pumpAtWidth(
      tester,
      const ChatBubble(isMe: false, child: Text('hola')),
      1440,
      brightness: Brightness.dark,
    );
    final contenedor = tester.widget<Container>(
      find.byKey(const ValueKey('chat-bubble-surface')),
    );
    final fondoBurbuja = (contenedor.decoration as BoxDecoration).color;
    final fondoChat = AppTheme.darkTheme
        .extension<AppColors>()!
        .surfaceContainer;

    expect(
      fondoBurbuja,
      isNot(fondoChat),
      reason: 'chat_screen.dart:377 pinta el Scaffold con surfaceContainer; '
          'si la burbuja usa el mismo token es invisible',
    );
  },
);
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test test/features/chat/presentation/widgets/chat_bubble_contraste_test.dart`
Expected: FAIL — ambos son `#141E36`.

- [ ] **Step 3: Da a la burbuja ajena su propio token**

```dart
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // El Scaffold del chat usa surfaceContainer en oscuro
    // (chat_screen.dart:377). Si la burbuja ajena usara ese mismo token —
    // como hasta 2026-08-28 — el mensaje recibido se leia como texto suelto
    // sobre el papel tapiz: sin fondo, sin padding visible y sin hora.
    final fondoAjeno = isDark ? colors.surface : colors.surfaceContainer;

    final fondo = isDeleted
        ? colors.surfaceVariant
        : (isMe ? colors.primary : fondoAjeno);
```

- [ ] **Step 4: Ejecuta los tests**

Run: `flutter test test/features/chat/`

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/presentation/widgets/chat_bubble.dart test/
git commit -m "fix(chat): la burbuja del mensaje recibido era invisible en modo oscuro"
```

---

### Task 9: El nombre del vehículo deja de recortarse en el garaje

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/garage_screen.dart:274-330`
- Test: `test/features/dashboard/presentation/pages/garage_screen_test.dart`

- [ ] **Step 1: Escribe el test que falla**

```dart
testWidgets('a 768 px el nombre del vehiculo no se recorta', (tester) async {
  await pumpScreen(tester, 768, vehicleCount: 4);
  await tester.pumpAndSettle();

  final titulo = tester.widget<Text>(find.text('NISSAN GT-R'));
  final render = tester.renderObject<RenderBox>(find.text('NISSAN GT-R'));
  final pintado = (render as dynamic).size.width as double;

  expect(
    pintado,
    greaterThan(120),
    reason: 'con "Hacer Principal" sin restriccion el Expanded se queda con '
        'las sobras y el titulo cae a dos letras ("NI...")',
  );
  expect(titulo.overflow, TextOverflow.ellipsis);
});
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test test/features/dashboard/presentation/pages/garage_screen_test.dart`

- [ ] **Step 3: Convierte «Hacer Principal» en un icono**

Sustituye el `AppButton` de la línea 305 por:

```dart
                      if (!vehicle.isPrimary &&
                          vehicle.idPropietario == currentUserId)
                        // Icono y no boton con texto: "Hacer Principal" mide
                        // ~150 px y, junto al chevron de 40, no dejaba sitio
                        // al Expanded del nombre. A 768 px el titulo caia a
                        // dos letras.
                        IconButton(
                          tooltip: context.l10n.garageMakePrimary,
                          icon: const Icon(Icons.star_border),
                          color: colors.primary,
                          onPressed: provider.isLoading
                              ? null
                              : () => _setVehicleAsPrimary(
                                  context,
                                  vehicle,
                                  provider,
                                ),
                        ),
```

- [ ] **Step 4: Ejecuta los tests**

Run: `flutter test test/features/dashboard/`

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/presentation/pages/garage_screen.dart test/
git commit -m "fix(garaje): el nombre del vehiculo se recortaba a dos letras"
```

---

### Task 10: El diálogo de verificación deja de citar un botón inexistente

**Files:**
- Modify: `lib/features/auth/presentation/pages/auth_screen.dart:738-746`
- Modify: `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/auth/auth_screen_verify_dialog_test.dart` (crear)

- [ ] **Step 1: Escribe el test que falla**

```dart
testWidgets(
  'en el alta el texto no menciona un boton que el dialogo no dibuja',
  (tester) async {
    await pumpVerifyDialog(tester, isRegistration: true);
    await tester.pumpAndSettle();

    expect(find.textContaining('Ya verifiqué'), findsNothing);
    expect(find.text('Entendido'), findsOneWidget);
  },
);
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test test/features/auth/auth_screen_verify_dialog_test.dart`
Expected: FAIL — el texto `authOpenLinkThenVerify` menciona «Ya verifiqué».

- [ ] **Step 3: Usa un texto distinto según el modo**

```dart
                Text(
                  isRegistration
                      ? context.l10n.authOpenLinkOnRegister
                      : context.l10n.authOpenLinkThenVerify,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
```

`app_es.arb`:

```json
  "authOpenLinkOnRegister": "Abre el enlace del correo para activar tu cuenta. Puedes continuar mientras tanto."
```

`app_en.arb`:

```json
  "authOpenLinkOnRegister": "Open the link in the email to activate your account. You can continue in the meantime."
```

- [ ] **Step 4: Ejecuta los tests**

Run: `flutter test test/features/auth/`

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/pages/auth_screen.dart lib/l10n/ test/
git commit -m "fix(auth): el dialogo de verificacion citaba un boton que no existe en el alta"
```

---

### Task 11: La pantalla de verificación identifica al taller

**Files:**
- Modify: `lib/features/admin/presentation/pages/admin_verificacion_screen.dart`
- Modify: `lib/features/admin/presentation/providers/admin_verificacion_provider.dart`
- Test: `test/features/admin/admin_verificacion_identidad_test.dart` (crear)

**Interfaces:**
- Consumes: `talleres/{uid}` (lectura pública) para `nombre`, `especialidad`, `departamento`.
- Produces: cada expediente expone `nombreTaller`, `correoTaller`.

- [ ] **Step 1: Escribe el test que falla**

```dart
testWidgets('la tarjeta muestra el nombre del taller, no solo su uid', (tester) async {
  await pumpVerificaciones(tester, expedientes: [
    expedienteFixture(uid: 'HT8Hkxr...', nombre: 'Taller Los Pinos'),
  ]);
  await tester.pumpAndSettle();

  expect(find.text('Taller Los Pinos'), findsOneWidget);
  expect(
    find.text('HT8Hkxr...'),
    findsNothing,
    reason: 'el uid crudo no le dice al admin a quien esta aprobando',
  );
});
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test test/features/admin/admin_verificacion_identidad_test.dart`

- [ ] **Step 3: Enriquece el expediente y pinta la identidad**

En el provider, tras cargar los expedientes, resuelve el perfil público:

```dart
  /// El expediente de `verificaciones/{uid}` solo trae la evidencia. El
  /// nombre y la especialidad viven en `talleres/{uid}`, de lectura publica,
  /// asi que se resuelven aqui: hasta 2026-08-28 la pantalla identificaba la
  /// solicitud unicamente por el uid crudo y el administrador decidia a
  /// ciegas.
  Future<void> _hidratarIdentidades(List<VerificacionModel> expedientes) async {
    for (final e in expedientes) {
      final taller = await WorkshopService().getWorkshopById(e.idTaller);
      e.nombreTaller = taller?.nombreCompleto;
      e.especialidad = taller?.especialidad;
    }
    notifyListeners();
  }
```

En la tarjeta, sustituye el `Text(uid)` por nombre + especialidad + uid en pequeño y monoespaciado.

- [ ] **Step 4: Invierte el orden de los botones**

«Aprobar» primero (primario), «Rechazar» debajo como `AppButtonType.text` en `colors.error`,
con `AppDialogContent` de confirmación. La destructiva no puede ser la más prominente.

- [ ] **Step 5: Ejecuta los tests**

Run: `flutter test test/features/admin/`

- [ ] **Step 6: Commit**

```bash
git add lib/features/admin/ test/
git commit -m "feat(admin): mostrar identidad del taller en la pantalla de verificacion"
```

---

### Task 12: Un solo eje de meses para todas las gráficas

**Files:**
- Create: `lib/core/widgets/charts/month_axis.dart`
- Modify: `lib/features/admin/presentation/widgets/services_trend_chart.dart:62-96`,
  `user_growth_chart.dart`, `workshops_growth_chart.dart`,
  `lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart` (Resumen de Gastos)
- Test: `test/core/widgets/charts/month_axis_test.dart` (crear)

**Interfaces:**
- Produces: `SideTitles monthSideTitles({required List<String> monthsOrder, required AppColors colors})`
  — dibuja **una etiqueta por mes**, no una por punto.

- [ ] **Step 1: Escribe el test que falla**

```dart
test('solo dibuja la etiqueta en el primer punto de cada mes', () {
  final orden = ['2026-03', '2026-03', '2026-03', '2026-04', '2026-04', '2026-08'];
  expect(etiquetaParaIndice(orden, 0), 'Mar');
  expect(etiquetaParaIndice(orden, 1), isNull);
  expect(etiquetaParaIndice(orden, 2), isNull);
  expect(etiquetaParaIndice(orden, 3), 'Abr');
  expect(etiquetaParaIndice(orden, 4), isNull);
  expect(etiquetaParaIndice(orden, 5), 'Ago');
});
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test test/core/widgets/charts/month_axis_test.dart`

- [ ] **Step 3: Implementa el eje compartido**

```dart
const _nombresMes = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

/// Devuelve la etiqueta del mes **solo** en su primer punto.
///
/// Cada grafica dibujaba una etiqueta por punto de datos, asi que el eje X
/// salia como "Mar Mar Mar Mar Mar Abr Abr Abr Abr Abr Abr May ...".
String? etiquetaParaIndice(List<String> monthsOrder, int indice) {
  if (indice < 0 || indice >= monthsOrder.length) return null;
  final clave = monthsOrder[indice];
  if (indice > 0 && monthsOrder[indice - 1] == clave) return null;
  return _nombresMes[int.parse(clave.split('-')[1]) - 1];
}

SideTitles monthSideTitles({
  required List<String> monthsOrder,
  required AppColors colors,
}) {
  return SideTitles(
    showTitles: true,
    reservedSize: 30,
    getTitlesWidget: (value, meta) {
      final etiqueta = etiquetaParaIndice(monthsOrder, value.toInt());
      if (etiqueta == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Text(
          etiqueta,
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
      );
    },
  );
}
```

- [ ] **Step 4: Sustituye los cuatro `getTitlesWidget`**

En cada gráfica: `bottomTitles: AxisTitles(sideTitles: monthSideTitles(monthsOrder: monthsOrder, colors: colors))`.

- [ ] **Step 5: Ejecuta los tests**

Run: `flutter test test/`

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/charts/ lib/features/ test/
git commit -m "fix(graficas): una etiqueta por mes en el eje X, no una por punto"
```

---

### Task 13: Tarjetas de métricas sin 200 px de vacío

**Files:**
- Modify: `lib/features/admin/presentation/widgets/metric_card.dart`
- Modify: `lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart` (tarjetas Año/Color/Km/Marca)
- Test: `test/features/admin/metric_card_altura_test.dart` (crear)

- [ ] **Step 1: Escribe el test que falla**

```dart
testWidgets('la tarjeta de metrica se ajusta a su contenido', (tester) async {
  await pumpAtWidth(
    tester,
    const MetricCard(icon: Icons.people, value: '45', label: 'Usuarios'),
    1440,
  );
  await tester.pumpAndSettle();

  final alto = tester.getSize(find.byType(MetricCard)).height;
  expect(
    alto,
    lessThan(160),
    reason: 'hoy mide ~270 px con el numero pegado abajo y 200 px de nada',
  );
});
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test test/features/admin/metric_card_altura_test.dart`

- [ ] **Step 3: Quita el estirado**

Sustituye el `Spacer()` / `Expanded` interno por `mainAxisSize: MainAxisSize.min` y un
`SizedBox(height: AppSpacing.md)` entre icono y valor. Si el `AspectRatio` del `AppGrid`
padre es el que impone la altura, súbelo a `childAspectRatio: 2.2`.

- [ ] **Step 4: Comprueba a 390 px también**

Run: `flutter test test/features/admin/`

- [ ] **Step 5: Commit**

```bash
git add lib/features/admin/presentation/widgets/metric_card.dart lib/features/dashboard/ test/
git commit -m "fix(admin): las tarjetas de metricas tenian 200 px de vacio"
```

---

## Bloque E — Accesibilidad

### Task 14: `AppCard` interactiva exige `semanticLabel`

**Files:**
- Modify: `lib/core/widgets/app_card.dart:28-35`, `:82-88`
- Modify: todos los call sites con `onTap` (garaje, dashboard, acciones rápidas, talleres cercanos)
- Test: `test/core/widgets/app_card_semantics_test.dart` (crear)

**Interfaces:**
- Produces: `AppCard` con `onTap != null` **requiere** `semanticLabel` (assert en debug).

- [ ] **Step 1: Escribe el test que falla**

```dart
testWidgets('una AppCard pulsable expone un nombre accesible', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(
    _wrap(AppCard(
      onTap: () {},
      semanticLabel: 'Volkswagen Jetta, placa P376-571',
      child: const Text('VOLKSWAGEN Jetta'),
    )),
  );

  expect(
    tester.getSemantics(find.byType(AppCard)),
    matchesSemantics(label: 'Volkswagen Jetta, placa P376-571', isButton: true),
  );
  handle.dispose();
});
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test test/core/widgets/app_card_semantics_test.dart`

- [ ] **Step 3: Haz obligatorio el label**

```dart
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    this.onTap,
    this.semanticLabel,
  }) : assert(
         onTap == null || semanticLabel != null,
         'Una AppCard pulsable necesita semanticLabel: excludeSemantics borra '
         'el texto de los hijos, asi que sin label queda un boton sin nombre. '
         'En el garaje se anunciaban cinco "boton" seguidos, sin decir cual '
         'es cual.',
       );
```

- [ ] **Step 4: Rellena los call sites**

En `garage_screen.dart:158`:

```dart
    return AppCard(
      semanticLabel:
          '${vehicle.marca ?? ''} ${vehicle.modelo ?? ''}, placa ${vehicle.placa}',
      onTap: () => context.push(...),
```

Repite en la tarjeta del vehículo principal del dashboard, en los ítems de «Talleres
Cercanos» (`'${taller.nombre}, ${taller.especialidad}'`) y en las tres acciones rápidas del
perfil del vehículo.

- [ ] **Step 5: Ejecuta la suite completa**

Run: `flutter analyze && flutter test`
Expected: PASS; el `assert` fuerza a rellenar cualquier call site olvidado.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/app_card.dart lib/features/ test/
git commit -m "fix(a11y): AppCard pulsable exige semanticLabel; habia botones sin nombre"
```

---

### Task 15: La barra superior aparece en el árbol de accesibilidad

**Files:**
- Modify: `lib/core/widgets/app_top_nav_bar.dart`
- Modify: `lib/core/widgets/main_scaffold.dart:75-83` (rama `WindowClass.large`)
- Test: `integration_test/top_nav_semantics_test.dart` (crear)

**Interfaces:**
- Produces: cada destino de `AppNavDestinations.owner` es un nodo semántico con rol botón y
  su `semanticLabel`.

- [ ] **Step 1: Escribe el test que falla**

```dart
testWidgets('los cinco destinos de la barra superior estan en el arbol', (tester) async {
  final handle = tester.ensureSemantics();
  await pumpAtWidth(tester, const _ShellProbe(), 1440);
  await tester.pumpAndSettle();

  for (final d in AppNavDestinations.owner) {
    expect(
      find.bySemanticsLabel(d.semanticLabel),
      findsOneWidget,
      reason: 'sobre /dashboard a 1440 px no habia NINGUN nodo de la barra '
          'superior: ni los enlaces, ni tema, ni idioma, ni campana',
    );
  }
  handle.dispose();
});
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test integration_test/top_nav_semantics_test.dart`

- [ ] **Step 3: Envuelve la barra en un contenedor semántico explícito**

En `main_scaffold.dart`, rama `WindowClass.large`:

```dart
      WindowClass.large => Scaffold(
        body: Column(
          children: [
            // `Semantics(container: true, explicitChildNodes: true)` fuerza a
            // que la barra genere su propio subarbol. Sin esto, a 1440 px el
            // arbol de /dashboard tenia 34 nodos y todos eran de contenido:
            // la navegacion principal era inalcanzable con teclado y con
            // lector de pantalla, y los tests E2E tenian que ir por
            // coordenadas.
            const Semantics(
              container: true,
              explicitChildNodes: true,
              child: AppTopNavBar(),
            ),
            Expanded(child: child),
          ],
        ),
      ),
```

Añade además `tooltip` + `Semantics(label:)` a la campana, el avatar y el selector de idioma.

- [ ] **Step 4: Ejecuta el test**

Run: `flutter test integration_test/top_nav_semantics_test.dart`
Expected: PASS.

- [ ] **Step 5: Verifica en el navegador**

Compila y comprueba con Playwright que `document.querySelectorAll('[id^=flt-semantic-node-]')`
incluye nodos con `aria-label` «Garaje», «Talleres» y «Perfil».

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/ integration_test/
git commit -m "fix(a11y): exponer la barra de navegacion superior en el arbol semantico"
```

---

## Bloque F — Configuración, copy y CI

### Task 16: Imágenes de vehículo — key, mensaje y placeholder

**Files:**
- Modify: `.env` (acción humana), `.env.example`
- Modify: `lib/core/services/vehicle_image_service.dart:137-145`
- Replace: `assets/images/default_vehicle.jpg`
- Test: `test/core/services/vehicle_image_service_test.dart`

- [ ] **Step 1: Corrige el mensaje engañoso**

```dart
    if (_apiKey.isEmpty) {
      debugPrint(
        '[SearchAPI.io] VEHICLE_IMAGE_API_KEY llega vacia. Revisa que la '
        'variable tenga VALOR en el .env con el que se compilo (no solo que '
        'exista la linea) y que el build use --dart-define-from-file. '
        'No se buscara imagen.',
      );
```

> El mensaje anterior afirmaba que la app se había compilado sin
> `--dart-define-from-file=.env`, lo cual era falso: el flag estaba y la línea 29 del `.env`
> era `VEHICLE_IMAGE_API_KEY=` sin valor. Mandaba a depurar el sitio equivocado.

- [ ] **Step 2: Sustituye el placeholder**

`assets/images/default_vehicle.jpg` es la foto de un Mercedes-Benz Clase C: un Corolla sin
imagen aparece como un Mercedes, indistinguible de un resultado real y erróneo. Sustitúyelo
por una silueta neutra (SVG rasterizado o ilustración plana) sin marca reconocible.

- [ ] **Step 3: Rellena la key (acción humana)**

En `.env`, línea 29, pon la key real de searchapi.io. Añade a `.env.example` el comentario
`# obligatoria: sin valor, todos los vehiculos nuevos caen al placeholder`.

- [ ] **Step 4: Verifica**

Run: `flutter test test/core/services/vehicle_image_service_test.dart`
Y a mano: crea un vehículo y comprueba que sale una petición a `searchapi.io`.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/vehicle_image_service.dart assets/images/ .env.example test/
git commit -m "fix(imagenes): mensaje correcto con la key vacia y placeholder sin marca"
```

---

### Task 17: El push sale del camino crítico del arranque

**Files:**
- Modify: `lib/main.dart` (bloque `PushNotificationService`)
- Test: `test/main_bootstrap_test.dart` (crear)

- [ ] **Step 1: Escribe el test que falla**

```dart
test('el arranque no espera al permiso de notificaciones', () async {
  final reloj = Stopwatch()..start();
  await bootstrapServices(
    push: _PushQueNuncaResuelve(),
  );
  reloj.stop();

  expect(
    reloj.elapsed,
    lessThan(const Duration(seconds: 1)),
    reason: 'requestPermission tarda 5 s en expirar en web y estaba en el '
        'camino critico: Firebase quedaba listo a los 2,0 s y runApp no se '
        'lanzaba hasta los 7,0 s',
  );
});
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test test/main_bootstrap_test.dart`

- [ ] **Step 3: Lanza el push sin `await`**

```dart
  // Sin await: en web el permiso de notificaciones no se resuelve hasta que
  // el usuario decide, asi que el timeout de 5 s se agotaba SIEMPRE y
  // retrasaba runApp de 2,0 s a 7,0 s. El servicio se inicializa en segundo
  // plano y notifica por su cuenta cuando termina.
  unawaited(
    PushNotificationService().initialize().catchError((e) {
      debugPrint('=== [AutoDoc Init] PushNotificationService fallo: $e ===');
    }),
  );
```

- [ ] **Step 4: Ejecuta y mide en el navegador**

Run: `flutter test` y luego compila y comprueba en consola que
`Inicializacion completa. Lanzando runApp` sale antes de los 2,5 s.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/
git commit -m "perf(arranque): sacar el permiso de push del camino critico (5 s menos)"
```

---

### Task 18: Copy suelto y CI

**Files:**
- Modify: `lib/l10n/app_es.arb:613`, `app_en.arb:613`
- Modify: `lib/features/auth/data/services/auth_service.dart` (mapeo de errores)
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Etiqueta de idioma que no miente**

`upLanguageDesc` es un literal fijo `EN (Activado) / ES (Desactivado)` que se muestra igual
con el interruptor apagado y la app en español. Sustitúyelo por una descripción del control:

```json
  "upLanguageDesc": "Activa el interruptor para usar la app en inglés"
```
```json
  "upLanguageDesc": "Turn the switch on to use the app in English"
```

- [ ] **Step 2: Traduce los errores de Auth**

En `auth_service.dart`, mapea los códigos de `FirebaseAuthException` a textos de `l10n`.
Hoy se ve tal cual: «Ocurrió un error inesperado: A network AuthError (such as timeout,
interrupted connection or unreachable host) has occurred.» — mitad español, mitad interno
del SDK.

```dart
  String mensajeParaError(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'network-request-failed' => l10n.authNetworkError,
        'wrong-password' || 'invalid-credential' => l10n.authInvalidCredentials,
        'too-many-requests' => l10n.authTooManyRequests,
        _ => l10n.authUnexpectedError,
      };
    }
    return l10n.authUnexpectedError;
  }
```

- [ ] **Step 3: `flutter clean` en el CI antes del build web**

En `.github/workflows/ci.yml`, antes del paso de `flutter build web`:

```yaml
      - name: Limpiar artefactos previos
        # Un build incremental sobre un build/ sucio puede emitir un bundle
        # incompleto: assets/ vacio, sin manifest.json, sin favicon y sin
        # firebase-messaging-sw.js, con part.js de builds viejos mezclados.
        # firebase.json publica build/web tal cual, asi que ese bundle se
        # desplegaria roto.
        run: flutter clean
```

- [ ] **Step 4: Verifica**

Run: `flutter gen-l10n && flutter analyze && flutter test`

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/ lib/features/auth/ .github/workflows/ci.yml
git commit -m "fix(copy,ci): etiqueta de idioma, errores de Auth traducidos y flutter clean en CI"
```

---

### Task 19: Coherencia de datos de mantenimiento

**Files:**
- Modify: `lib/features/dashboard/presentation/providers/alert_provider.dart` (§5 de `_generateSmartAlerts`)
- Modify: `lib/features/dashboard/presentation/widgets/add_vehicle_form.dart` (validación de color)
- Test: `test/features/dashboard/presentation/providers/alert_provider_coherencia_test.dart` (crear)

- [ ] **Step 1: Escribe el test que falla**

```dart
test('una tarea no puede salir CRITICA y OPTIMA a la vez', () {
  final provider = AlertProvider()
    ..debugSeedTasks([tareaRotacionLlantas(intervalo: 10000, ultimo: 54621)]);

  provider.debugGenerarAlertas(vehiculoConKm(254));

  final criticas = provider.alerts.where((a) => a.titulo == 'Rotación de Llantas');
  final optimas = provider.maintenanceTasks.where(
    (t) => t.nombre == 'Rotación de Llantas' &&
        t.getStatus(254) == MaintenanceStatus.optimal,
  );

  expect(
    criticas.isEmpty || optimas.isEmpty,
    isTrue,
    reason: 'en /alerts la misma tarea aparecia en PRIORIDAD ALTA como '
        '"¡CRITICO!" y en SUGERENCIAS como "OPTIMO"',
  );
});

test('un odometro por debajo del ultimo servicio no genera alertas absurdas', () {
  final provider = AlertProvider()
    ..debugSeedTasks([tareaFiltroAceite(intervalo: 5000, ultimo: 54621)]);

  provider.debugGenerarAlertas(vehiculoConKm(254));

  expect(provider.error, contains('kilometraje'));
});
```

- [ ] **Step 2: Ejecuta y comprueba que falla**

Run: `flutter test test/features/dashboard/presentation/providers/alert_provider_coherencia_test.dart`

- [ ] **Step 3: Una sola fuente de verdad para el estado de la tarea**

En `_generateSmartAlerts`, la alerta crítica y la tarjeta de sugerencia deben derivar del
**mismo** `task.getStatus(km)`. Si el estado es `optimal`, no se emite alerta; si es
`critical`, la tarjeta de sugerencia se pinta también en crítico.

Y valida el odómetro: si `vehicle.kilometrajeActual < task.ultimoKm`, no calcules
«próximo servicio» — marca la tarea como *dato inconsistente* y ofrece corregir el
kilometraje, que es lo que realmente pasa.

- [ ] **Step 4: Valida el color en el alta**

`Gris13` está guardado en producción porque el campo es texto libre. Añade a
`add_vehicle_form.dart` un validador `^[A-Za-zÁÉÍÓÚáéíóúÑñ ]{3,30}$` con el mensaje
«Solo letras y espacios».

- [ ] **Step 5: Ejecuta los tests**

Run: `flutter test test/features/dashboard/`

- [ ] **Step 6: Commit**

```bash
git add lib/features/dashboard/ test/
git commit -m "fix(alertas): una tarea no puede ser critica y optima a la vez; validar color"
```

---

## Limpieza posterior (acción humana)

Datos ficticios creados durante el QA, en producción:

- Dos tickets de reparación en «Taller Prueba»: `P376-571` (En Revisión) y `P859-392` (Recibido).
- Cotización de $45 aceptada en el chat de «Taller Prueba» con `usuario`.
- Servicio manual de $38.50 en el VW Jetta (`P376-571`).
- Logo y «Foto 1» de «Taller Prueba» en `talleres_fotos/Go9O443o8sed9K6ExRrCLUkLAOb2/`.
- Mensaje «Mensaje de prueba QA 28/08».

Y una credencial caducada: `taller6@taller.com` sigue codificada en
`e2e/tests/mecanico.spec.js`, que por tanto falla. Sustitúyela por `taller1@taller.com`.

---

## Autorrevisión

**Cobertura del informe.** Los 17 hallazgos tienen tarea: §1→T1, §2→T4+T5, §2b→T3, §3→T2,
§4→T8, §5→T6+T7, §6→T11, §7→T9, §8→T10, §9→T12, §10→T13, §11→T16, §12→T17, §13→T14+T15,
§14 (URL desincronizada) → **sin tarea, ver abajo**, §15 (rol `Usuario`) → **sin tarea, ver
abajo**, §16 → T18+T19.

**Dos huecos deliberados**, ambos por necesitar una decisión de producto antes de tocar código:

- **§14 — la URL no acompaña a la navegación** en chat, iniciar servicio, verificación y
  registro. Arreglarlo es cambiar `context.push` por rutas con URL propia, lo que toca el
  `ShellRoute` y arriesga el bug de `HeroControllerScope` que ya documenta
  `vehicle_profile_screen.dart:862`. Merece su propio plan.
- **§15 — rol `Usuario` en datos reales.** Hay cuentas en producción con ese valor y ningún
  filtro las cubre. Antes de migrar hay que decidir si `Usuario` es sinónimo de `Propietario`
  (y entonces migrar los documentos) o un rol distinto (y entonces añadirlo a
  `role_utils.dart`, a los filtros del admin y a las reglas).

**Consistencia de tipos.** `requiereTareaSeleccionada` (T3), `clearUserScopedProviders` (T7),
`etiquetaParaIndice` / `monthSideTitles` (T12) y `ReparacionProvider.cancelar` (T5) se
declaran con la misma firma en el punto donde se definen y donde se usan.
