---
description: Corre las suites de test del proyecto AutoDoc (unit/widget, reglas de Firestore, e integración) en el orden correcto.
argument-hint: [unit|rules|integration|all]
allowed-tools: Bash
---

Objetivo: correr las suites de test de AutoDoc. Argumento recibido: `$ARGUMENTS` (si está vacío, tratar como `all` mode, excluyendo `integration`).

Suites disponibles:

1. **unit** — tests unit/widget de Flutter:
   ```
   flutter analyze --no-fatal-infos
   dart format --output=none --set-exit-if-changed .
   flutter test --coverage
   ```
   (mismos pasos que `.github/workflows/ci.yml`, job `analyze_and_test`).

2. **rules** — tests de `firestore.rules` (proyecto Node separado en `test/firestore_rules`):
   ```
   cd test/firestore_rules
   pnpm install --frozen-lockfile
   pnpm test
   ```

3. **integration** — flujos end-to-end en `integration_test/` (`alert_flow_test.dart`, `auth_flow_test.dart`, `vehicle_flow_test.dart`). Requiere un dispositivo/emulador conectado — antes de correrlos, verifica con `flutter devices` que haya uno disponible y avisa al usuario si no lo hay en vez de fallar en silencio:
   ```
   flutter test integration_test
   ```

4. **all** — corre `unit` y `rules` en secuencia (no incluye `integration` por el requisito de dispositivo; menciónalo al usuario al final).

Ejecuta la(s) suite(s) correspondiente(s) al argumento con la herramienta Bash, reporta resultados de forma resumida (pass/fail por suite, no pegues el output completo salvo que algo falle), y si algo falla muestra el fragmento relevante del error.
