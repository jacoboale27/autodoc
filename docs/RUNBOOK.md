# AutoDoc — Runbook de Producción

> **Versión:** 1.0 | **Última actualización:** 2026-07 | **Propietario:** Equipo AutoDoc

Este documento cubre los procedimientos operacionales para mantener AutoDoc en producción.

---

## 1. Acceso a herramientas de operación

| Herramienta | URL / Comando |
|-------------|---------------|
| Firebase Console | https://console.firebase.google.com/project/[PROJECT_ID] |
| Google Cloud Console | https://console.cloud.google.com/project/[PROJECT_ID] |
| Crashlytics Dashboard | Firebase Console → Crashlytics |
| Cloud Functions Logs | `firebase functions:log --project [PROJECT_ID]` |
| GitHub Actions CI | https://github.com/[ORG]/autodoc/actions |

> **Nota:** Reemplaza `[PROJECT_ID]` y `[ORG]` con los valores reales del proyecto.

---

## 2. Rotación de credenciales admin

### 2.1 Cambiar contraseña de admin
1. Ir a Firebase Console → Authentication → Users
2. Buscar el usuario admin por email
3. Hacer click en los 3 puntos → "Reset password"
4. El admin recibe email con link para cambiar contraseña

### 2.2 Rotar service account (CI/CD)
```bash
# 1. Crear nuevo service account key
gcloud iam service-accounts keys create new-key.json \
  --iam-account firebase-adminsdk@[PROJECT_ID].iam.gserviceaccount.com

# 2. Actualizar secret en GitHub
gh secret set FIREBASE_TOKEN --body "$(cat new-key.json)"

# 3. Eliminar key antigua del IAM Console
# Firebase Console → Project Settings → Service accounts → Manage service account permissions
```

### 2.3 Rotar FCM API Key
1. Firebase Console → Project Settings → Cloud Messaging
2. Generar nueva Server Key
3. Actualizar variable de entorno en Cloud Functions (si aplica)

---

## 3. Suspender usuario

### Via panel admin (recomendado)
1. Login como Administrador en la app
2. Ir a Admin → Usuarios
3. Encontrar el usuario → "Suspender" → ingresar motivo
4. El sistema registra en `admin_logs` y actualiza `estado: suspendido`

### Via Firebase Console (emergencia)
```bash
# Deshabilitar cuenta en Firebase Auth
firebase auth:export users.json --project [PROJECT_ID]
# Luego en Firebase Console → Authentication → Users → Disable user
```

---

## 4. Suspender taller

### Via panel admin
1. Admin → Talleres
2. Encontrar el taller → "Suspender"
3. Esto actualiza el campo `estado` en la colección `usuarios` del mecánico
4. El mecánico ve la pantalla `MechanicPendingScreen` al intentar acceder

### Efecto en producción
- El mecánico es redirigido a `/mechanic_pending` por el router
- No puede iniciar servicios ni acceder al dashboard
- Los clientes no ven el taller en el directorio si `estado != 'activo'`

---

## 5. Respuesta a incidente de seguridad

### Nivel P0 — Brecha de datos activa

**Tiempo de respuesta objetivo: < 30 minutos**

```
1. AISLAR
   - Firebase Console → Authentication → "Disable all new user registrations" (Settings)
   - Si hay function comprometida: firebase functions:delete [functionName]
   
2. IDENTIFICAR
   - Revisar admin_logs en Firestore para actividad sospechosa
   - Revisar Cloud Functions logs: firebase functions:log
   - Revisar Firebase Auth activity log en Google Cloud Console
   
3. CONTENER  
   - Cambiar service account keys (ver §2.2)
   - Revocar todos los tokens FCM si es necesario
   - Actualizar reglas Firestore a modo restrictivo temporal:
     match /{doc=**} { allow read, write: if false; }
   
4. RECUPERAR
   - Restaurar reglas normales desde firestore.rules en git
   - firebase deploy --only firestore --project [PROD_PROJECT]
   - Habilitar registros nuevamente
   
5. DOCUMENTAR
   - Crear issue post-mortem en GitHub
   - Notificar a usuarios afectados si aplica (GDPR/privacidad)
```

### Nivel P1 — Servicio degradado

```
1. Verificar Crashlytics para errores masivos
2. Revisar Cloud Functions logs para errores 500
3. Verificar Firestore usage en Firebase Console
4. Considerar rollback (ver §6)
```

---

## 6. Rollback de deploy

### Rollback de Cloud Functions

```bash
# Ver versiones desplegadas
gcloud functions list --project [PROJECT_ID]

# Rollback a versión anterior del código
git checkout [PREVIOUS_COMMIT_HASH] -- functions/
firebase deploy --only functions --project [PROJECT_ID]

# Volver a la versión actual
git checkout main -- functions/
```

### Rollback de Flutter Web (Firebase Hosting)

```bash
# Ver historial de releases
firebase hosting:releases:list --project [PROJECT_ID]

# Rollback al release anterior (usa el ID del release)
firebase hosting:rollback [RELEASE_ID] --project [PROJECT_ID]
```

### Rollback de Firestore Rules

```bash
# Restaurar reglas de producción conocidas-buenas desde git
git checkout [SAFE_COMMIT] -- firestore.rules
firebase deploy --only firestore:rules --project [PROJECT_ID]
```

---

## 7. Procedimientos de monitoreo

### 7.1 Verificación diaria (cron interno)
- [ ] Crashlytics: sin nuevos crash groups críticos
- [ ] Cloud Functions: tasa de error < 1%
- [ ] Firestore: sin alertas de usage
- [ ] Auth: sin picos de registros sospechosos

### 7.2 Alertas configuradas (Cloud Monitoring)
- Functions falla 3+ veces en 1h → alerta email a equipo
- Firestore reads > umbral → alerta de costo

### 7.3 Ver logs de functions en tiempo real
```bash
firebase functions:log --project [PROJECT_ID] --follow
```

---

## 8. Índices Firestore requeridos

Los siguientes índices compuestos deben estar activos en producción:

| Colección | Campos | Dirección |
|-----------|--------|-----------|
| `alertas` | `id_vehiculo` ASC, `estado` ASC | Compuesto |
| `alertas` | `id_vehiculo` ASC, `fecha_limite` ASC | Compuesto |
| `conversaciones` | `id_propietario` ASC, `ultimoMensajeTs` DESC | Compuesto |
| `conversaciones` | `id_mecanico` ASC, `ultimoMensajeTs` DESC | Compuesto |
| `servicios` | `id_vehiculo` ASC, `fecha` DESC | Compuesto |
| `reservas` | `id_propietario` ASC, `estado` ASC | Compuesto |
| `reservas` | `id_mecanico` ASC, `estado` ASC | Compuesto |

Para crear manualmente: Firebase Console → Firestore → Indexes → Create Index

---

## 9. Backup de Firestore

### Backup manual (emergencia pre-deploy)
```bash
gcloud firestore export gs://[PROJECT_ID]-backups/manual-$(date +%Y%m%d) \
  --project [PROJECT_ID]
```

### Backup automático (scheduled export)
Configurar en Cloud Scheduler (Cloud Console):
- Frecuencia: `0 2 * * *` (2am diario)
- Target: `gs://[PROJECT_ID]-backups/daily`
- Comando: Cloud Functions → `scheduledFirestoreExport`

### Restaurar backup
```bash
gcloud firestore import gs://[PROJECT_ID]-backups/[BACKUP_ID] \
  --project [PROJECT_ID]
```

---

## 10. Escalación y contactos

| Rol | Responsabilidad | Contacto |
|-----|----------------|---------|
| Tech Lead | Incidentes P0, arquitectura | [EMAIL] |
| Backend Dev | Functions, Firestore, reglas | [EMAIL] |
| Flutter Dev | App crashes, bugs UI | [EMAIL] |
| DevOps | CI/CD, hosting, Firebase | [EMAIL] |
| Legal | Privacidad, cumplimiento | [EMAIL] |

### SLAs internos
- **P0** (app caída / brecha): < 30 min respuesta, < 2h resolución
- **P1** (funcionalidad crítica degradada): < 2h respuesta, < 8h resolución  
- **P2** (bug no crítico): < 24h respuesta, próximo sprint

---

## 11. Checklist pre-lanzamiento (Soft Launch)

- [ ] Reglas Firestore desplegadas y testeadas con emulador
- [ ] Reglas Storage desplegadas
- [ ] Cloud Functions desplegadas y testeadas
- [ ] Firebase App Check activo (Play Integrity en Android, DeviceCheck en iOS)
- [ ] Crashlytics recibiendo eventos de prueba
- [ ] Push notifications: Android ✅ iOS ✅ Web ✅
- [ ] Deep links verificados: chat, reserva, alerta
- [ ] Landing page en dominio final con SSL
- [ ] Privacy Policy publicada y enlazada desde app
- [ ] Terms of Service publicados y enlazados
- [ ] Índices Firestore activos (sin "Building")
- [ ] Staging sign-off completo por QA
- [ ] Backup inicial de Firestore creado
- [ ] Runbook distribuido al equipo

---

## App Check — activación

App Check debe desplegarse en **dos fases** para no dejar fuera a usuarios con
clientes antiguos en caché:

1. **Monitorización** (semana 1): registrar las apps en la consola de Firebase
   → App Check, con enforcement **desactivado**. Revisar en las métricas el
   porcentaje de peticiones con token válido.
2. **Enforcement** (semana 2, si el porcentaje supera el 98 %): activar el
   enforcement en Firestore, Storage y Functions, uno a uno, verificando entre
   cada paso.

Requisito previo: la Tarea 1 de este plan (cabeceras de caché) debe estar en
producción, porque de lo contrario los clientes antiguos sin App Check quedan
atrapados en caché y el enforcement los expulsaría de forma permanente.

**Nota sobre CI/CD:** los workflows actuales (`.github/workflows/ci.yml` y
`flutter_ci.yml`) no pasan `--dart-define=RECAPTCHA_SITE_KEY=...` en ningún
paso de `flutter build web`, a diferencia de `GOOGLE_SIGNIN_CLIENT_ID_WEB`, que
sí se inyecta vía `sed` en `web/index.html`. Mientras esto no se corrija, todos
los builds de web (dev/staging/prod) activan App Check con una site key vacía;
el modo tolerante a fallos evita que esto bloquee el arranque, pero el cliente
web no emitirá tokens válidos hasta que se añada el secreto
`RECAPTCHA_SITE_KEY` a los workflows y se pase como `--dart-define` en el paso
`flutter build web`. Este ajuste queda fuera del alcance de esta tarea.

---

*Documento mantenido en `docs/RUNBOOK.md`. Actualizar con cada cambio operacional significativo.*
