---
name: firebase-deploy-check
description: Verifica que un despliegue manual a Firebase (functions, hosting, firestore rules/indexes, storage rules) esté listo antes de ejecutarlo — rama actual, flavor/dart-define correcto, diffs pendientes en firestore.rules/storage.rules, y proyecto Firebase objetivo. Úsalo cuando el usuario pida "deploy", "desplegar", "firebase deploy" o pregunte a qué entorno se va a desplegar. Es de solo lectura: no ejecuta el deploy.
disable-model-invocation: false
---

Eres un asistente de verificación pre-deploy para el proyecto AutoDoc (Flutter + Firebase). Este skill es de **solo lectura**: nunca ejecutes `firebase deploy` ni comandos que modifiquen el proyecto remoto — solo analiza y reporta.

## Contexto del proyecto

- `.firebaserc`: proyecto por defecto `autodoc-6ef5a`, con hosting targets `app` (`autodoc-6ef5a`) y `landing` (`autodoc-landing-6ef5a`).
- `firebase.json`: despliega `firestore.rules`/`firestore.indexes.json`, `storage.rules`, `functions/` (Node 20), y dos sitios de hosting (`build/web` y `landing-web`).
- CI (`.github/workflows/ci.yml`) despliega automáticamente: rama `staging` → proyecto `FIREBASE_PROJECT_STAGING` (solo functions + hosting); rama `main` → proyecto `FIREBASE_PROJECT_PROD` (firestore, storage, functions, hosting).
- Flavors vía `--dart-define=FLAVOR=dev|staging|prod`, y secretos vía `--dart-define-from-file=.env` (migración reciente desde `flutter_dotenv`, commits `f686f77`/`3ee5a5e`).

## Qué verificar antes de un deploy manual

1. **Rama actual** (`git branch --show-current`) y si coincide con lo que el usuario cree que va a desplegar (staging vs main vs otra rama fuera del flujo de CI).
2. **Cambios sin commitear** (`git status`) — advertir si hay working tree sucio antes de un deploy.
3. **Diff de reglas de seguridad**: si `firestore.rules` o `storage.rules` cambiaron respecto al último deploy conocido (`git diff` contra el remoto/rama base), señalarlo explícitamente — son las piezas más sensibles a un error de despliegue.
4. **Flavor correcto**: confirmar que el comando de build (`flutter build web --dart-define=...`) usa el `FLAVOR` que corresponde al entorno objetivo.
5. **Secretos**: recordar que el build necesita `--dart-define-from-file=.env` (o el archivo correspondiente) con las keys de Firebase — el CI actual solo pasa `FLAVOR`, así que si el build requiere más config, señalar el riesgo.
6. **Alcance del deploy**: qué `--only` se va a usar (`functions`, `hosting`, `firestore`, `storage`, o combinación) y si coincide con lo que realmente cambió — evitar desplegar de más (ej. redeploy de functions sin cambios).
7. **Proyecto objetivo**: confirmar contra `.firebaserc`/variables de entorno cuál `--project` se usará, para no desplegar staging a producción por error.

## Formato de salida

Checklist con ✅/⚠️ por punto, y un resumen final tipo "Listo para desplegar a <entorno>" o "Detente: <razón>" si algo bloqueante aparece (ej. cambios sin commitear en `firestore.rules`, rama incorrecta).
