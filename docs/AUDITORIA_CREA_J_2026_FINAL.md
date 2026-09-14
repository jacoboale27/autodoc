# Auditoría CREA J 2026 — evaluación final reproducible

**Fecha:** 2026-09-13  
**Commit auditado:** `67c1a3a` (`main`)  
**Alcance:** evaluación nueva del árbol actual; la nota 64/100 del informe base y la nota
85/100 de la segunda ronda se usaron únicamente como historial, no como punto de partida
matemático.

## 1. Veredicto ejecutivo

**Resultado defendible: 89/100.** AutoDoc ya demuestra con emuladores los recorridos
multirol, la persistencia, los rechazos de autorización y los flujos públicos que faltaban en
la auditoría base. No quedan P0 demostrados. La distancia hasta una nota máxima no está en la
cantidad de funcionalidad ni en la estabilidad de las suites, sino en cuatro límites
concretos: dos permisos todavía demasiado amplios, App Check sin evidencia de `enforce` en un
proyecto desplegado, deuda de capacidad y una innovación cuyo backend existe pero cuya UI y
demo siguen pendientes.

| Criterio | Máximo | Nota | Fundamento |
|---|---:|---:|---|
| Amigabilidad móvil | 20 | **18** | Landing accesible en 320/375/390/414, teclado y reduced motion; app autenticada recorrida en navegador. Falta barrido equivalente de pantallas Flutter reales en los cuatro anchos y queda copy/error residual. |
| Roles establecidos | 10 | **9** | Matriz real de propietario, taller, admin y superusuario pasa contra emuladores. `/reservas` aún permite que un participante escriba un `id_taller` no anclado a la conversación. |
| Seguridad de registro | 20 | **16** | Verificación de correo, invitaciones privilegiadas, no enumeración de PII, reglas y callables tienen pruebas negativas. App Check queda en `monitor` por defecto y Storage permite subir factura con vínculo histórico sin exigir ticket abierto. |
| Información mediante BD | 10 | **9** | CRUD, refresh, reglas, índices centinela y relaciones están demostrados. Persisten lecturas sin cota y barridos N+1/relectura diaria. |
| Funcionalidad completa | 20 | **19** | Gates completos y 37 E2E autenticados; quedan triggers sin prueba integrada y el envío fallido de chat puede perder texto. |
| Creatividad y tecnologías | 20 | **18** | QR, mapas, PDF, chat, alertas, paneles y pase temporal de historial tienen diseño sólido. INNO-01 está terminado del lado servidor, pero no tiene pantallas, integración del escáner ni demo Playwright. |
| **TOTAL** | **100** | **89/100** | |

## 2. Evidencia fresca de esta ejecución

| Gate | Comando efectivo | Resultado |
|---|---|---|
| Análisis estático | Flutter tools `analyze --no-pub` | **0 issues**, exit 0, 188,4 s |
| Unitarias/widget | Flutter tools `test --no-pub` | **1229/1229**, exit 0 |
| Cloud Functions | `functions/npm.cmd test` | **296 passing**, exit 0 |
| Firestore/Storage rules | Firebase CLI efímera + `jest --runInBand` | **476/476**, 29 suites, exit 0 |
| Build landing | `e2e/npm.cmd run build:landing` | **15 páginas estáticas**, exit 0 |
| E2E landing | Playwright local, config landing | **42/42**, exit 0 |
| Build app E2E | `e2e/npm.cmd run build:web` | `flutter clean` + build `--profile`, shim de emuladores inyectado, exit 0 |
| E2E app | Playwright local `--workers=1` | **37/37**, exit 0, cero `fixme` |
| Teardown | `netstat` en 8080/9199/9099/5001/4400 | **cinco puertos libres** |

Todas las pruebas con datos usaron los proyectos de emulador y fixtures efímeros. No se
desplegó nada ni se usaron cuentas reales.

## 3. Qué quedó cerrado respecto del informe base

- La credencial privilegiada compartida fue sustituida por invitaciones rotables y no se
  devuelve una contraseña.
- El correo no verificado ya no cruza el gate de navegación; el registro UI real se prueba.
- La búsqueda por correo ya no funciona como oráculo de PII y exige consentimiento.
- La cotización pública y su margen privado tienen contrato atómico/reparable probado.
- El PDF del NIT atraviesa el selector real y las reglas de Storage.
- Hay matriz multirol y CRUD/refresco contra emuladores, no solo FakeFirestore.
- Contacto y afiliación de landing escriben por Function; CTAs y deep links son verificables.
- App Check se exige en todos los callables; un centinela impide añadir uno sin el gate.
- La estabilidad y el teardown de emuladores están demostrados en la misma corrida.

## 4. Hallazgos abiertos verificados

### P1 — integridad de `reservas.id_taller`

`firestore.rules:1198-1225` ancla propietario, mecánico y conversación, pero no exige que
`request.resource.data.id_taller` pertenezca al mecánico/taller de esa conversación. Un actor
legítimo puede contaminar agrupaciones por taller con un identificador de terceros. Las reglas
impiden reescribirlo después, pero no impiden crearlo mal.

### P1 — escritura de facturas con vínculo histórico

`storage.rules:135-145` usa el mismo predicado para lectura y escritura. Un taller aprobado
que conserve vínculo con el vehículo puede subir una factura aunque no haya un ticket abierto.
Leer el historial con el vínculo es razonable; crear evidencia financiera debería exigir
trabajo vigente o una autorización equivalente.

### P1 operativo — App Check todavía depende del runbook

Los 15 callables actuales invocan `exigirAppCheck` y las pruebas negativas pasan, pero el modo
por defecto sigue siendo `monitor`. El repo prohíbe desplegar durante QA, por lo que esta
auditoría no puede aportar evidencia de `APP_CHECK_ENFORCEMENT=enforce` en staging/producción.
No es un defecto oculto: es una acción operativa pendiente.

### P2 — capacidad y resiliencia

- `mechanic_dashboard_screen.dart:165,175,304,492` y
  `mechanic_service_history_screen.dart:99` abren streams sin límite sobre servicios.
- `alertasVencidas` pagina, pero vuelve a leer cada día alertas ya avisadas y conserva N+1 de
  vehículos/usuarios.
- Siete triggers de notificación siguen sin prueba integrada de su acceso a Firestore/FCM.
- Si falla el envío de chat, el texto ya fue limpiado y la persona no recibe un error.

### P2 — INNO-01 no es todavía un flujo demostrable

El commit `67c1a3a` añade tres callables, reglas cerradas, TTL documentado, límite de canjes,
proyección sin datos económicos y un cliente Dart. Sin embargo, la única referencia a
`PaseHistorialService` está en su propia declaración
(`lib/features/dashboard/data/services/pase_historial_service.dart:23`): no hay pantalla de
emisión/lectura, integración con el escáner ni prueba Playwright. El backend es real; la
experiencia prometida aún no lo es.

## 5. Riesgos de despliegue que no deben confundirse con verde local

1. Ejecutar primero el inventario de talleres sin `estado`; no hacer backfill ciego a
   `aprobado`.
2. Desplegar índices y ejecutar los backfills indicados por `docs/RUNBOOK.md` antes de la app.
3. Crear las políticas TTL de `solicitudes_landing_control` y `tokens_historial`.
4. Configurar `APP_CHECK_ENFORCEMENT=enforce` solo después de verificar clientes reales.
5. Ejecutar `flutter clean` antes del build productivo y conservar la guarda `predeploy`.

## 6. Limitaciones de esta auditoría

- **Graphify no pudo reindexarse.** `graphify.exe` y
  `graphify-out/.graphify_python` apuntan a un Python 3.11 eliminado; no hay otro Python/uv
  instalado. Se conserva como referencia el grafo del 2026-09-06 (7.802 nodos, 12.106 aristas,
  424 comunidades), pero no se usa como evidencia de cambios posteriores.
- No se desplegó, por restricción expresa del proyecto; por ello App Check, TTL, Scheduler,
  IAM y backfills quedan como evidencia de runbook, no de entorno remoto.
- No hubo un segundo evaluador independiente en esta ejecución. La nota se deriva de evidencia
  reproducible y hallazgos inspeccionables, no de consenso entre agentes.

## 7. Orden mínimo para subir de 89 a 95+

1. Cerrar y probar en emulador los dos permisos P1 (`reservas.id_taller` y escritura de
   facturas).
2. Completar INNO-01 en UI, diferenciar servicios auto-declarados y añadir demo Playwright.
3. Acotar/paginar los streams del panel mecánico y denormalizar alertas pendientes.
4. Extraer y probar los siete triggers de notificación.
5. Ejecutar el runbook en staging y adjuntar evidencia de App Check, TTL, Scheduler y
   migraciones.

## 8. Veredicto final

> **Si evaluara hoy el commit `67c1a3a` siguiendo estrictamente la rúbrica CREA J 2026,
> otorgaría 89/100.**

La app ya es demostrable y no arrastra los bloqueantes de la auditoría de 64/100. Todavía no
es defendible como 100/100 porque dos fronteras de autorización siguen siendo más amplias que
el contrato de negocio y la innovación añadida no llega aún a una experiencia de usuario.
