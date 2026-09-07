# PLAN MAESTRO DE CORRECCIÓN HACIA 10/10 — CREA J 2026

Quiero que utilices **todos los hallazgos, bugs, bloqueantes, deficiencias, riesgos, funcionalidades incompletas, problemas UX/UI, fallos de seguridad, problemas de roles, inconsistencias de BD y observaciones de la auditoría que acabas de realizar** para crear un **plan completo de corrección orientado a alcanzar una calificación de 10/10**.

NO quiero que vuelvas a realizar la auditoría completa desde cero.

La auditoría anterior es ahora tu **baseline**.

Tu tarea es transformar:

> HALLAZGOS → CORRECCIONES → VALIDACIÓN → IMPACTO EN RÚBRICA → PLAN HACIA 10/10

---

# 1. OBJETIVO

Construye un plan técnico y funcional que, si se implementa correctamente, lleve al proyecto desde su estado actual hasta un estado donde pueda defender razonablemente la máxima calificación de la rúbrica.

El objetivo no es solamente:

> "que el proyecto funcione mejor"

El objetivo es:

> **eliminar todas las razones objetivas por las que el profesor podría descontar puntos.**

---

# 2. FUENTE PRINCIPAL

Utiliza como fuente principal:

- la auditoría anterior;
- la matriz de evidencia;
- los bugs encontrados;
- los bloqueantes;
- las deficiencias;
- los falsos excelentes;
- las pruebas Playwright fallidas;
- los elementos NO VERIFICADOS;
- las conclusiones del Profesor Hostil;
- las conclusiones del Abogado del Diablo;
- el veredicto del Rubric Judge;
- la rúbrica CREA J 2026.

No descartes hallazgos porque parezcan pequeños.

Primero determina si afectan directa o indirectamente la posibilidad de obtener la nota máxima.

---

# 3. NO EMPIECES PROGRAMANDO

Primero crea el plan.

NO modifiques todavía el proyecto.

NO hagas refactors.

NO corrijas archivos.

Tu primera tarea es producir un:

# REMEDIATION MASTER PLAN

que podamos revisar antes de implementar.

---

# 4. RECONSTRUYE EL ESTADO ACTUAL

Resume de forma compacta:

```text
PUNTUACIÓN ACTUAL:
XX/100

AMIGABILIDAD:
XX/20

ROLES:
XX/10

SEGURIDAD:
XX/20

BD:
XX/10

FUNCIONALIDAD:
XX/20

CREATIVIDAD:
XX/20
```

Después indica:

```text
BLOQUEANTES CRÍTICOS:
X

HALLAZGOS ALTOS:
X

HALLAZGOS MEDIOS:
X

HALLAZGOS BAJOS:
X

TESTS FALLIDOS:
X

ELEMENTOS NO VERIFICADOS:
X
```

---

# 5. OBJETIVO POR CRITERIO

Para cada criterio de la rúbrica determina exactamente qué debe cambiar para llegar al máximo nivel.

Formato:

## AMIGABILIDAD — OBJETIVO 20/20

### Estado actual

### Qué impide actualmente obtener 20/20

### Qué debe corregirse

### Qué debe demostrarse con Playwright

### Evidencia necesaria para otorgar 20/20

---

Haz lo mismo con:

- Roles — 10/10
- Seguridad — 20/20
- BD — 10/10
- Funcionalidad — 20/20
- Creatividad — 20/20

---

# 6. CREA UNA MATRIZ COMPLETA DE DEFICIENCIAS

Construye:

| ID | Problema | Severidad | Criterio | Estado actual | Corrección requerida | Evidencia esperada |
|---|---|---|---|---|---|---|

No agrupes problemas diferentes de forma excesiva.

Quiero poder convertir cada fila posteriormente en una tarea de implementación.

---

# 7. IDENTIFICA BLOQUEANTES REALES

Clasifica como:

## P0 — BLOQUEANTE

Debe corregirse antes de cualquier intento de obtener 10/10.

Ejemplos:

- funcionalidades principales rotas;
- registro inseguro;
- roles vulnerables;
- acceso no autorizado;
- datos que no persisten;
- funcionalidades obligatorias inexistentes;
- errores que impiden flujos principales.

---

## P1 — ALTO IMPACTO

No necesariamente rompe el sistema, pero puede impedir alcanzar Excelente.

---

## P2 — IMPORTANTE

Mejora notablemente calidad, UX o robustez.

---

## P3 — PULIDO

Detalles secundarios necesarios para una presentación profesional.

---

# 8. PRIORIZACIÓN

No ordenes simplemente por severidad.

Utiliza conceptualmente:

```text
PRIORIDAD =
IMPACTO EN PUNTUACIÓN
×
SEVERIDAD
×
PROBABILIDAD DE QUE EL PROFESOR LO DETECTE
×
DEPENDENCIAS
÷
DIFICULTAD
```

Una corrección sencilla capaz de recuperar 5 puntos debe tener prioridad sobre una funcionalidad compleja que aporta poco.

---

# 9. DEPENDENCIAS

Construye un grafo de dependencias entre tareas.

Ejemplo:

```text
AUTH-01
Validación backend
    ↓
AUTH-02
Verificación de email
    ↓
AUTH-03
Recuperación segura
    ↓
AUTH-04
Playwright E2E
```

No propongas implementar tareas en un orden que provoque retrabajo.

---

# 10. USA GRAPHYFI SI ESTÁ DISPONIBLE

Si Graphyfi está disponible, úsalo para analizar dependencias entre:

- componentes;
- rutas;
- APIs;
- servicios;
- modelos;
- funcionalidades;
- tareas de corrección.

Construye, cuando aporte valor:

# REMEDIATION DEPENDENCY GRAPH

El objetivo es identificar qué correcciones desbloquean otras.

Si Graphyfi no está disponible, continúa mediante análisis del repositorio.

No inventes resultados.

---

# 11. USA SUPERPOWERS SI ESTÁ DISPONIBLE

Si Superpowers está disponible, utilízalo especialmente para:

- planning;
- systematic debugging;
- task decomposition;
- verification planning;
- implementation sequencing.

Pero no empieces todavía a modificar el proyecto.

En esta fase quiero:

> PLANIFICACIÓN.

---

# 12. CREA WORKSTREAMS

Agrupa las tareas en bloques lógicos.

Como mínimo considera:

## WORKSTREAM A — AUTENTICACIÓN Y SEGURIDAD

## WORKSTREAM B — ROLES Y AUTORIZACIÓN

## WORKSTREAM C — BASE DE DATOS

## WORKSTREAM D — FUNCIONALIDAD

## WORKSTREAM E — UX/UI + RESPONSIVE

## WORKSTREAM F — ESTABILIDAD Y MANEJO DE ERRORES

## WORKSTREAM G — CREATIVIDAD / INNOVACIÓN

## WORKSTREAM H — QA + PLAYWRIGHT

Adapta los workstreams al proyecto real.

---

# 13. CADA TAREA DEBE SER EJECUTABLE

No acepto tareas como:

> "Mejorar seguridad."

Eso es demasiado ambiguo.

Una tarea válida sería:

> Implementar validación backend de contraseña con longitud mínima X y reglas definidas; rechazar requests inválidos independientemente de la validación frontend.

Cada tarea debe contener:

```text
TASK ID:
NOMBRE:
PRIORIDAD:
CRITERIO DE RÚBRICA:
PROBLEMA QUE RESUELVE:
ARCHIVOS / ÁREAS PROBABLES:
CAMBIO PROPUESTO:
DEPENDENCIAS:
RIESGOS:
CRITERIOS DE ACEPTACIÓN:
TESTS NECESARIOS:
PLAYWRIGHT TEST:
EVIDENCIA PARA CERRAR:
IMPACTO ESPERADO:
```

---

# 14. CRITERIOS DE ACEPTACIÓN

Toda tarea debe tener criterios verificables.

Ejemplo incorrecto:

> "Hacer el registro más seguro."

Ejemplo correcto:

```text
[ ] contraseña rechazada si incumple política
[ ] validación existe también en backend
[ ] email duplicado rechazado
[ ] verificación de email funciona
[ ] recuperación de cuenta funciona
[ ] token de recuperación expira
[ ] Playwright confirma flujo
```

Una tarea NO se considera terminada hasta cumplir sus criterios.

---

# 15. DEFINITION OF DONE

Utiliza esta Definition of Done general:

```text
[ ] implementación completada
[ ] no existen errores de compilación
[ ] lint correcto
[ ] tests existentes continúan pasando
[ ] nuevos tests pasan
[ ] Playwright confirma comportamiento
[ ] responsive revisado cuando aplique
[ ] autorización backend comprobada cuando aplique
[ ] persistencia comprobada cuando aplique
[ ] evidencia registrada
[ ] criterio de la rúbrica reevaluado
```

---

# 16. PLAN DE TESTING DESDE EL PRINCIPIO

NO dejes Playwright para el final.

Para cada corrección importante, define:

> IMPLEMENTAR → TESTEAR → EVIDENCIAR → CERRAR

Ejemplo:

```text
TASK AUTH-04
Implementar recuperación de contraseña

↓

TEST AUTH-REC-001
Solicitud válida

↓

TEST AUTH-REC-002
Email inexistente

↓

TEST AUTH-REC-003
Token expirado

↓

EVIDENCE
EVID-AUTH-020...
```

---

# 17. REGRESSION GATE

Después de cada workstream importante, debe existir una mini regresión.

Especialmente después de modificar:

- autenticación;
- autorización;
- BD;
- navegación;
- funciones principales.

Nunca asumas que una corrección no rompió otra funcionalidad.

---

# 18. NO VERIFICADOS

Todo elemento marcado anteriormente como:

> NO VERIFICADO

debe convertirse en una de dos cosas:

### A. TAREA DE VERIFICACIÓN

si probablemente ya existe.

o

### B. TAREA DE IMPLEMENTACIÓN

si realmente falta.

No permitas que queden elementos críticos en estado NO VERIFICADO antes de la evaluación final.

---

# 19. SEGURIDAD HACIA 20/20

Dado que la máxima puntuación exige un registro realmente sólido, crea un plan específico para demostrar como mínimo, cuando aplique al proyecto:

- registro seguro;
- validación backend;
- validación correcta de correo;
- verificación real de correo;
- almacenamiento seguro/hash de contraseña;
- política de contraseña adecuada;
- recuperación de cuenta;
- tokens seguros;
- expiración;
- sesiones;
- logout;
- protección de rutas;
- protección de endpoints;
- separación correcta de roles.

No marques 20/20 futuro simplemente porque el plan incluya estas tareas.

Especifica qué evidencia deberá existir después.

---

# 20. ROLES HACIA 10/10

Para cada rol define:

```text
ROL:
PUEDE VER:
PUEDE CREAR:
PUEDE EDITAR:
PUEDE ELIMINAR:
NO PUEDE:
```

Después crea tareas para eliminar cualquier discrepancia encontrada.

Debemos demostrar autorización en:

> UI + BACKEND/API

---

# 21. BD HACIA 10/10

Crear tareas para asegurar:

- datos reales;
- persistencia;
- consistencia;
- actualización;
- precisión;
- estados vacíos;
- errores;
- CRUD;
- relaciones.

Eliminar o justificar cualquier dato hardcodeado que pueda confundirse con información proveniente de BD.

---

# 22. FUNCIONALIDAD HACIA 20/20

Para cada función actualmente:

- 🟡 parcial;
- 🔴 rota;
- ⚪ no verificable;

crea una tarea concreta.

Al terminar el plan no debería quedar ninguna función principal fuera de:

> 🟢 COMPLETA Y PROBADA

---

# 23. UX/MÓVIL HACIA 20/20

Crear tareas específicas para cualquier problema detectado en:

- 320px;
- 375px;
- 390px;
- 414px.

Considerar:

- navegación;
- formularios;
- modales;
- tablas;
- botones;
- feedback;
- loading;
- estados vacíos;
- mensajes;
- contraste;
- jerarquía.

No hacer rediseños innecesarios si no aportan a la rúbrica.

---

# 24. CREATIVIDAD HACIA 20/20

Primero corrige todos los bloqueantes.

Después evalúa si la aplicación ya puede justificar máxima puntuación en creatividad.

Si NO:

propón máximo **3 funcionalidades nuevas de alto valor**.

Para cada una calcula:

```text
VALOR PARA USUARIO
×
INNOVACIÓN
×
VISIBILIDAD EN LA PRESENTACIÓN
×
IMPACTO EN RÚBRICA
÷
COMPLEJIDAD
```

No quiero feature creep.

Es preferible una innovación excelente y perfectamente implementada que cinco funciones mediocres.

---

# 25. EVITA SOBREINGENIERÍA

NO propongas:

- microservicios innecesarios;
- reescrituras completas;
- migraciones tecnológicas sin beneficio claro;
- librerías adicionales porque sí;
- arquitectura excesivamente compleja;
- cambios estéticos masivos sin impacto.

Preserva lo que ya funciona.

Principio:

> **MENOR CAMBIO NECESARIO PARA CONSEGUIR MAYOR IMPACTO.**

---

# 26. EVITA REGRESIONES

Marca explícitamente las áreas de alto riesgo.

Ejemplo:

| Cambio | Riesgo de regresión | Qué volver a probar |
|---|---|---|
| Auth | Alto | registro/login/logout/roles |
| DB schema | Alto | CRUD + relaciones |
| navegación | Medio | rutas + responsive |

---

# 27. PLAN POR FASES

Quiero que el plan tenga aproximadamente esta secuencia:

## FASE 0 — BASELINE

Congelar el estado actual y la evidencia existente.

## FASE 1 — BLOQUEANTES

Resolver P0.

## FASE 2 — SEGURIDAD + ROLES

Eliminar riesgos de autenticación/autorización.

## FASE 3 — DATOS + FUNCIONALIDAD

Corregir persistencia y funciones parciales/rotas.

## FASE 4 — UX + MÓVIL

Eliminar razones para perder puntos de amigabilidad.

## FASE 5 — ESTABILIDAD

Errores, loading, empty states, regresiones.

## FASE 6 — INNOVACIÓN

Añadir solamente lo necesario para justificar creatividad máxima.

## FASE 7 — HARDENING

QA destructivo final.

## FASE 8 — MOCK EVALUATION

Repetir exactamente la rúbrica.

Adapta estas fases si las dependencias reales justifican otro orden.

---

# 28. SCORE GATES

Después de cada fase estima qué puntuación podría defenderse.

Ejemplo:

```text
BASELINE
72/100

DESPUÉS FASE 1
80/100

DESPUÉS FASE 2
87/100

DESPUÉS FASE 3
92/100

DESPUÉS FASE 4
96/100

DESPUÉS FASE 6
100/100 POTENCIAL
```

No inventes números optimistas.

Cada incremento debe indicar qué requisito de la rúbrica se habría resuelto.

---

# 29. 10/10 READINESS GATE

Antes de considerar el proyecto listo, debe superar:

```text
[ ] Amigabilidad máxima demostrable
[ ] Roles máximos demostrables
[ ] Seguridad máxima demostrable
[ ] BD máxima demostrable
[ ] Funcionalidad máxima demostrable
[ ] Creatividad máxima demostrable

[ ] cero bloqueantes
[ ] cero bugs críticos conocidos
[ ] cero fallos altos sin justificar
[ ] flujos principales PASS
[ ] responsive PASS
[ ] roles PASS
[ ] seguridad PASS
[ ] CRUD/persistencia PASS
[ ] recuperación de cuenta PASS si aplica al máximo nivel
[ ] verificación de correo PASS si aplica
[ ] Evidence Gate completo
```

---

# 30. SEGUNDA AUDITORÍA

El plan debe terminar obligatoriamente con una nueva auditoría completa.

NO asumas que implementar todas las tareas implica 10/10.

Después de implementar:

> ejecutar nuevamente el prompt de auditoría adversarial desde cero.

El nuevo Rubric Judge debe evaluar el estado nuevo sin confiar en la puntuación previa.

---

# 31. CONDICIÓN DE ÉXITO

El proyecto solamente puede considerarse listo para 10/10 cuando:

```text
IMPLEMENTACIÓN
+
PLAYWRIGHT
+
EVIDENCIA
+
RÚBRICA
+
ABOGADO DEL DIABLO
+
RUBRIC JUDGE
=
MÁXIMA PUNTUACIÓN DEFENDIBLE
```

---

# 32. SALIDA QUE QUIERO AHORA

NO implementes todavía.

Entrégame:

# 🎯 REMEDIATION MASTER PLAN — CAMINO A 10/10

## 1. Estado actual

Puntuación y principales razones.

## 2. Gap hacia 10/10

Qué separa exactamente el estado actual del máximo.

## 3. Bloqueantes P0

Tabla completa.

## 4. P1

Tabla completa.

## 5. P2

Tabla completa.

## 6. P3

Tabla completa.

## 7. Dependencias

Orden lógico de implementación.

## 8. Workstreams

Agrupación técnica.

## 9. Plan por fases

Secuencia exacta.

## 10. Tareas

Cada tarea con:

- ID
- prioridad
- problema
- solución
- archivos/áreas afectadas
- dependencias
- criterios de aceptación
- tests
- evidencia requerida
- impacto en rúbrica

## 11. Matriz criterio → tareas

| Criterio | Estado actual | Objetivo | Tasks necesarias |
|---|---:|---:|---|

## 12. Plan Playwright

Tests que deberán demostrar las correcciones.

## 13. Riesgos de regresión

Qué puede romper cada fase.

## 14. Innovaciones recomendadas

Solamente si son necesarias para llegar al máximo nivel.

## 15. Score gates

Puntuación potencial después de cada fase.

## 16. Checklist final 10/10

Todo lo que debe estar PASS antes de volver a evaluar.

## 17. Orden exacto de ejecución

Termina proporcionando una lista ordenada como:

```text
1. TASK-XXX
2. TASK-XXX
3. TASK-XXX
4. TASK-XXX
...
```

Esta será posteriormente nuestra cola de implementación.

---

# REGLAS FINALES

1. No implementes todavía.
2. Utiliza la auditoría anterior como baseline.
3. No ignores ningún bloqueante.
4. Convierte hallazgos en tareas ejecutables.
5. Cada tarea debe tener criterios de aceptación.
6. Cada corrección importante debe tener test.
7. Prioriza impacto sobre la rúbrica.
8. Respeta dependencias.
9. Evita sobreingeniería.
10. Evita feature creep.
11. Preserva lo que ya funciona.
12. No prometas 10/10 sin evidencia futura.
13. Elimina todos los NO VERIFICADOS importantes.
14. Incluye regresión.
15. Incluye Playwright.
16. Incluye una nueva auditoría adversarial al final.
17. El objetivo no es "mejorar mucho".
18. El objetivo es eliminar sistemáticamente todas las razones defendibles para descontar puntos.

# PRINCIPIO FINAL

> **NO QUIERO UN PLAN DE MEJORAS GENÉRICO.**

Quiero un plan que pueda convertirse directamente en una cola de trabajo:

> **PROBLEMA → TASK → IMPLEMENTACIÓN → TEST → EVIDENCIA → PUNTOS RECUPERADOS**

Construye ese plan ahora.