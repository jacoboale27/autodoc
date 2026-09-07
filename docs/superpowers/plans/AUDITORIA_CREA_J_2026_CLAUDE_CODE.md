````markdown
# 🔴 AUDITORÍA ADVERSARIAL CREA J 2026
## Claude Code + Playwright MCP + Subagentes + Graphyfi + Superpowers

> **Objetivo:** realizar una auditoría extremadamente estricta, minuciosa, reproducible y basada en evidencia de mi aplicación antes de presentarla al evaluador de CREA J 2026.

---

# 1. MISIÓN

Actúa como un **equipo profesional de auditoría de software extremadamente estricto** encargado de evaluar mi aplicación.

Tu objetivo NO es confirmar que el proyecto está bien.

Tu objetivo es:

> **ENCONTRAR TODO LO QUE PUEDA HACERME PERDER PUNTOS ANTES DE QUE LO ENCUENTRE EL EVALUADOR.**

Debes adoptar una actitud:

- adversarial;
- escéptica;
- minuciosa;
- sistemática;
- basada en evidencia;
- técnicamente rigurosa.

No seas destructivo ni injusto.

No inventes problemas para reducir artificialmente la nota.

La regla es:

> **HOSTIL CON EL PROYECTO, PERO OBJETIVO CON LA EVIDENCIA.**

Debes combinar:

- inspección del código;
- ejecución real de la aplicación;
- MCP de Playwright;
- pruebas funcionales;
- pruebas responsive;
- análisis UX/UI;
- análisis de seguridad;
- análisis de arquitectura;
- análisis de base de datos;
- análisis de roles y permisos;
- análisis de funcionalidades;
- Graphyfi, si está disponible;
- Superpowers, si está disponible;
- subagentes especializados;
- revisión adversarial;
- juez independiente final.

---

# 2. FUENTE DE VERDAD: RÚBRICA CREA J 2026

La aplicación debe evaluarse usando estos seis criterios.

| Criterio | Peso |
|---|---:|
| Amigabilidad de la aplicación móvil | 20% |
| Identificación de roles establecidos | 10% |
| Seguridad en el registro mediante correo electrónico | 20% |
| Presentación de información registrada mediante BD | 10% |
| Funcionalidad completa de la plataforma | 20% |
| Creatividad y uso de nuevas tecnologías | 20% |
| **TOTAL** | **100%** |

---

# 3. NIVELES DE LA RÚBRICA

## 3.1 Amigabilidad — 20 puntos

### Excelente — 20
La interfaz es intuitiva, clara y muy atractiva para el usuario.

### Muy Bueno — 15
Interfaz entendible, con pocos detalles de confusión y buena experiencia de uso.

### Bueno — 10
Funcional, pero presenta dificultad en la navegación.

### Regular — 5
Interfaz poco organizada que complica la interacción.

### Necesita Mejorar — 1
Interfaz confusa y nada amigable, limita la experiencia del usuario.

---

## 3.2 Roles — 10 puntos

### Excelente — 10
Roles claramente definidos, bien implementados y diferenciados en funciones.

### Muy Bueno — 7
Roles bien establecidos, con mínimas limitaciones.

### Bueno — 5
Existen roles, pero no están diferenciados con claridad.

### Regular — 3
Roles confusos o con errores en permisos.

### Necesita Mejorar — 1
No hay definición ni correcta implementación de roles.

---

## 3.3 Seguridad en registro — 20 puntos

### Excelente — 20
Registro seguro con validación por correo, cifrado y recuperación de cuenta.

### Muy Bueno — 15
Registro seguro con validación básica de correo.

### Bueno — 10
Registro funcional con mínima validación de seguridad.

### Regular — 5
Registro débil con fallos en validación.

### Necesita Mejorar — 1
Registro sin medidas de seguridad ni validación.

---

## 3.4 Información mediante BD — 10 puntos

### Excelente — 10
Información clara, organizada, precisa y actualizada en tiempo real.

### Muy Bueno — 7
Información ordenada con pocos errores de actualización.

### Bueno — 5
Información presentada, pero con inconsistencias menores.

### Regular — 3
Información incompleta o con errores frecuentes.

### Necesita Mejorar — 1
La información no se presenta o no se conecta a la BD.

---

## 3.5 Funcionalidad completa — 20 puntos

### Excelente — 20
Todas las funciones operan correctamente y sin errores.

### Muy Bueno — 15
Casi todas las funciones implementadas con errores menores.

### Bueno — 10
Varias funciones operan, pero otras están incompletas.

### Regular — 5
La mayoría de funciones no operan correctamente.

### Necesita Mejorar — 1
La plataforma no es funcional ni integra las funciones básicas.

---

## 3.6 Creatividad y nuevas tecnologías — 20 puntos

### Excelente — 20
Uso de tecnologías modernas con innovaciones que enriquecen la App.

### Muy Bueno — 15
Tecnologías actuales con algunos elementos innovadores.

### Bueno — 10
Uso de tecnologías básicas con limitados aportes creativos.

### Regular — 5
Creatividad mínima y tecnologías poco actuales.

### Necesita Mejorar — 1
No hay innovación ni uso adecuado de tecnologías modernas.

---

# 4. REGLA ABSOLUTA: EVIDENCE FIRST

Ningún punto debe otorgarse solamente porque una funcionalidad aparentemente existe.

El hecho de encontrar:

- un componente;
- una función;
- una ruta;
- un botón;
- un endpoint;
- una API;
- un modelo;
- una tabla;
- una validación;
- un comentario;
- documentación;
- una dependencia instalada;

NO demuestra que la funcionalidad realmente funcione.

Debes distinguir cinco tipos de evidencia.

### CODE EVIDENCE

Lo que existe en el código.

### RUNTIME EVIDENCE

Lo que realmente funciona al ejecutar la aplicación.

### PLAYWRIGHT EVIDENCE

Lo que fue comprobado mediante interacción real con Playwright.

### DATABASE EVIDENCE

Lo que puede demostrarse que persiste o proviene realmente de la BD.

### SECURITY EVIDENCE

Lo que puede demostrarse sobre autenticación, autorización, validación y protección de datos.

---

# 5. REGLA: NO EVIDENCE = NO EXCELENTE

Utiliza este proceso:

```text
¿Existe en código?
        |
        ├── NO
        │    ↓
        │  NO CUMPLE
        │
        └── SÍ
             |
             ↓
        ¿Funciona realmente?
             |
             ├── NO
             │    ↓
             │  NO CUMPLE
             │
             └── SÍ
                  |
                  ↓
          ¿Existe evidencia?
                  |
                  ├── NO
                  │    ↓
                  │  NO DAR MÁXIMO NIVEL
                  │
                  └── SÍ
                       |
                       ↓
          ¿Cumple completamente
           el nivel de la rúbrica?
                       |
                       ├── NO
                       │    ↓
                       │  BAJAR NIVEL
                       │
                       └── SÍ
                            ↓
                     PUEDE OBTENER
                     ESE NIVEL
````

---

# 6. PRINCIPIO DE CONTRADICCIÓN

Cuando exista contradicción entre código y ejecución:

> **LA EJECUCIÓN TIENE PRIORIDAD.**

Ejemplo:

El código aparentemente implementa recuperación de contraseña.

Pero Playwright demuestra que el botón genera error.

Resultado:

> La recuperación NO debe considerarse completamente funcional.

Otro ejemplo:

El frontend oculta el panel administrativo a usuarios normales.

Pero el endpoint administrativo acepta solicitudes de usuarios normales.

Resultado:

> Existe un fallo real de autorización.

---

# 7. PIPELINE DE AUDITORÍA

NO hagas una única revisión gigante.

Divide la auditoría en fases.

```text
FASE 0
Reconocimiento
        ↓
FASE 1
Mapa de aplicación
        ↓
FASE 2
Auditorías especializadas
        ↓
FASE 3
Playwright
        ↓
FASE 4
Correlación código/runtime
        ↓
FASE 5
Abogado del Diablo
        ↓
FASE 6
Juez independiente
        ↓
FASE 7
Puntuación
        ↓
FASE 8
Roadmap de mejoras
```

---

# 8. CONTROL DEL CONSUMO DE TOKENS / CUOTA

Esta auditoría debe ser exhaustiva pero también eficiente.

NO envíes todos los subagentes a analizar absolutamente todo el repositorio.

Cada subagente debe recibir únicamente el contexto necesario para su responsabilidad.

Evita:

* análisis duplicados;
* volver a leer archivos sin necesidad;
* lanzar múltiples agentes para responder la misma pregunta;
* generar explicaciones extensas durante la exploración;
* repetir información conocida;
* utilizar modelos costosos para tareas mecánicas.

Prioriza:

> **COBERTURA + EVIDENCIA > TEXTO GENERADO**

Los agentes deben devolver resultados compactos y estructurados.

---

# 9. USO DE SUBAGENTES

Cuando Claude Code permita utilizar subagentes, utilízalos.

Cada subagente debe tener:

* misión;
* alcance;
* archivos relevantes;
* herramientas permitidas;
* evidencia requerida;
* formato de salida.

Los subagentes NO deben modificar el proyecto.

Su misión es:

> **AUDITAR, NO PROGRAMAR.**

---

# 10. SUBAGENTE 0 — ORQUESTADOR

## Personalidad

Director de auditoría.

## Responsabilidades

Primero inspecciona:

* estructura del repositorio;
* README;
* package.json;
* archivos de configuración;
* frontend;
* backend;
* BD;
* ORM;
* autenticación;
* autorización;
* APIs;
* servicios externos;
* variables de entorno;
* comandos disponibles.

Determina:

```text
Frontend:
Backend:
Framework:
Lenguaje:
BD:
ORM:
Autenticación:
Autorización:
Servicios externos:
APIs:
Sistema de correo:
Tecnologías relevantes:
```

Después identifica las áreas que cada subagente debe investigar.

---

# 11. SUBAGENTE 1 — PROFESOR HOSTIL

## Personalidad

Profesor extremadamente exigente.

Mentalidad:

> "Quiero encontrar cualquier razón OBJETIVA para no darle Excelente."

Debe analizar exclusivamente desde la rúbrica.

Para cada criterio:

1. ¿Qué exige literalmente?
2. ¿Qué demuestra el proyecto?
3. ¿Qué NO demuestra?
4. ¿Qué puede cuestionar el profesor?
5. ¿Qué impediría otorgar Excelente?
6. ¿Existe evidencia suficiente?

No aceptar:

> "Está implementado."

Exigir:

> "Demuéstrame que funciona."

---

# 12. SUBAGENTE 2 — QA DESTRUCTIVO

## Personalidad

Tester obsesionado con romper aplicaciones.

Intentar:

* campos vacíos;
* datos inválidos;
* valores extremos;
* caracteres especiales;
* datos duplicados;
* doble submit;
* refresh;
* navegación atrás;
* navegación adelante;
* logout;
* volver atrás después del logout;
* rutas inexistentes;
* rutas protegidas;
* acciones repetidas;
* estados vacíos;
* errores;
* formularios incompletos.

Cada problema debe ser reproducible.

---

# 13. SUBAGENTE 3 — UX/UI

Analizar:

* navegación;
* intuitividad;
* claridad;
* jerarquía;
* consistencia;
* colores;
* tipografía;
* contraste;
* formularios;
* feedback;
* errores;
* estados vacíos;
* estados de carga;
* accesibilidad;
* responsive;
* experiencia móvil.

Pregunta fundamental:

> ¿Puede una persona utilizar esta aplicación sin recibir instrucciones?

---

# 14. SUBAGENTE 4 — SEGURIDAD

Debe actuar con mentalidad paranoica.

Analizar:

## Registro

* email;
* contraseña;
* validación;
* duplicados;
* verificación;
* recuperación.

## Autenticación

* sesiones;
* tokens;
* cookies;
* almacenamiento;
* expiración;
* logout.

## Autorización

* roles;
* permisos;
* endpoints;
* rutas protegidas.

Cuando sea relevante, investigar de forma segura:

* IDOR;
* XSS;
* inyección;
* secretos expuestos;
* datos sensibles;
* validación únicamente frontend;
* errores demasiado descriptivos;
* endpoints sin autorización.

NO realizar acciones destructivas.

NO atacar infraestructura externa.

---

# 15. SUBAGENTE 5 — BASE DE DATOS

Verificar:

```text
UI
 ↓
API
 ↓
BACKEND
 ↓
BD
 ↓
BACKEND
 ↓
API
 ↓
UI
```

Para CRUD:

```text
CREATE
↓
REFRESH
↓
VERIFY
```

```text
UPDATE
↓
REFRESH
↓
VERIFY
```

```text
DELETE
↓
REFRESH
↓
VERIFY
```

Buscar:

* datos hardcodeados;
* datos falsos;
* información que no persiste;
* relaciones incorrectas;
* registros duplicados;
* inconsistencias;
* problemas de sincronización;
* información obsoleta.

---

# 16. SUBAGENTE 6 — FUNCIONALIDAD

Crear un inventario completo:

| Funcionalidad | Existe | Funciona | Probada | Evidencia | Estado |
| ------------- | ------ | -------- | ------- | --------- | ------ |

Estados:

* 🟢 Funciona
* 🟡 Parcial
* 🔴 Rota
* ⚪ No verificable

Buscar especialmente:

* funciones incompletas;
* botones decorativos;
* páginas placeholder;
* TODO;
* mocks;
* datos falsos;
* funciones sin backend;
* funciones sin UI;
* endpoints sin consumidor.

---

# 17. SUBAGENTE 7 — CREATIVIDAD Y TECNOLOGÍA

Analizar:

* tecnologías modernas;
* APIs;
* IA;
* automatizaciones;
* integraciones;
* funciones originales;
* innovación;
* valor diferencial.

NO premiar simplemente utilizar:

* React;
* Next;
* Node;
* Firebase;
* Supabase;
* APIs;
* IA;
* muchas dependencias.

Pregunta:

> ¿Esta tecnología realmente mejora la experiencia o capacidad de la aplicación?

---

# 18. SUBAGENTE 8 — USUARIO NOVATO

Este agente NO debe leer el código.

Solo puede utilizar la aplicación.

Debe intentar entenderla como usuario nuevo.

Registrar:

* confusión;
* acciones poco claras;
* navegación problemática;
* botones difíciles de encontrar;
* mensajes ambiguos;
* pasos innecesarios;
* errores.

---

# 19. GRAPHYFI

Antes de utilizar Graphyfi:

> COMPRUEBA SI REALMENTE ESTÁ DISPONIBLE.

Si está disponible, utilízalo para construir relaciones entre:

* rutas;
* pantallas;
* componentes;
* APIs;
* entidades;
* modelos;
* roles;
* funcionalidades;
* servicios;
* flujos.

Crear un:

# APPLICATION GRAPH

Ejemplo:

```text
USER
 |
 ├── REGISTER
 │      |
 │      ├── EMAIL
 │      └── DATABASE
 |
 ├── LOGIN
 │      |
 │      └── AUTH
 |
 └── DASHBOARD
        |
        ├── FEATURE A
        │      |
        │      └── API
        │             |
        │             └── DATABASE
        |
        └── PROFILE
```

Utilizar este mapa para detectar:

* componentes aislados;
* rutas sin interfaz;
* UI sin backend;
* endpoints sin consumidor;
* modelos aparentemente sin uso;
* funciones desconectadas;
* inconsistencias arquitectónicas.

Si Graphyfi NO está disponible:

```text
Graphyfi no disponible.
Application Map construido mediante inspección del repositorio.
```

NO inventes resultados provenientes de Graphyfi.

---

# 20. SUPERPOWERS

Primero comprueba si Superpowers está disponible.

Si existe, utiliza sus capacidades/skills cuando aporten valor para:

* planificación;
* análisis;
* debugging;
* investigación sistemática;
* verificación;
* revisión.

NO utilices Superpowers artificialmente simplemente para afirmar que fue utilizado.

Principio:

> Calidad de auditoría > cantidad de herramientas utilizadas.

Si no está disponible:

```text
Superpowers no disponible.
Continuando auditoría mediante herramientas disponibles.
```

---

# 21. PLAYWRIGHT MCP ES OBLIGATORIO

Playwright debe utilizarse como fuente primaria de evidencia de ejecución.

NO basta con inspeccionar código.

Debes abrir la aplicación y probarla.

---

# 22. PROTOCOLO DE EVIDENCIA PLAYWRIGHT

Cada prueba relevante debe generar:

```text
TEST ID:
CRITERIO:
OBJETIVO:
PRECONDICIONES:
VIEWPORT:
URL:
ACCIONES:
RESULTADO ESPERADO:
RESULTADO REAL:
PASS/FAIL:
SEVERIDAD:
EVIDENCIA:
```

Ejemplo:

```text
TEST ID: AUTH-REG-003
CRITERIO: Seguridad
OBJETIVO: Validación de correo inválido
PRECONDICIONES: Usuario no autenticado
URL: /register

ACCIONES:
1. Abrir registro
2. Introducir "abc"
3. Completar demás campos
4. Enviar

RESULTADO ESPERADO:
El formulario debe rechazar el correo.

RESULTADO REAL:
Mensaje "Correo inválido".

PASS

EVIDENCIA:
Comportamiento observado mediante Playwright.
```

---

# 23. EVIDENCE ID

Asigna identificadores a evidencia importante.

Ejemplo:

```text
EVID-AUTH-001
EVID-AUTH-002
EVID-ROLE-001
EVID-DB-001
EVID-FUNC-001
EVID-UX-001
```

Las conclusiones del informe final deben poder referenciar estos IDs.

Ejemplo:

```text
Seguridad de registro: Muy Bueno — 15/20

Evidencia:
EVID-AUTH-001
EVID-AUTH-002
EVID-AUTH-005
```

---

# 24. MATRIZ DE PLAYWRIGHT

Como mínimo:

| ID       | Área          | Prueba                        |
| -------- | ------------- | ----------------------------- |
| AUTH-001 | Registro      | Email válido                  |
| AUTH-002 | Registro      | Email inválido                |
| AUTH-003 | Registro      | Password débil                |
| AUTH-004 | Registro      | Campos vacíos                 |
| AUTH-005 | Registro      | Usuario duplicado             |
| AUTH-006 | Login         | Credenciales válidas          |
| AUTH-007 | Login         | Credenciales inválidas        |
| AUTH-008 | Login         | Campos vacíos                 |
| AUTH-009 | Sesión        | Logout                        |
| AUTH-010 | Sesión        | Ruta protegida después logout |
| ROLE-001 | Roles         | Usuario normal                |
| ROLE-002 | Roles         | Admin                         |
| ROLE-003 | Roles         | Acceso no autorizado          |
| DB-001   | BD            | Crear                         |
| DB-002   | BD            | Persistencia                  |
| DB-003   | BD            | Actualizar                    |
| DB-004   | BD            | Eliminar                      |
| FUNC-001 | Funcionalidad | Flujo principal               |
| UX-001   | Mobile        | 320px                         |
| UX-002   | Mobile        | 375px                         |
| UX-003   | Mobile        | 390px                         |
| UX-004   | Mobile        | 414px                         |

Amplía automáticamente esta matriz según las funcionalidades descubiertas.

---

# 25. REGISTRO

Probar:

1. Datos correctos.
2. Email inválido.
3. Email vacío.
4. Password vacío.
5. Password débil.
6. Campos vacíos.
7. Datos duplicados.
8. Caracteres especiales.
9. Envíos repetidos.
10. Feedback.
11. Resultado posterior al registro.
12. Persistencia.

Además investigar:

* verificación de correo;
* hashing/cifrado;
* recuperación de cuenta;
* validación backend.

IMPORTANTE:

No confundir:

> Validación de formato de correo

con:

> Verificación real de propiedad del correo.

---

# 26. LOGIN

Probar:

* credenciales válidas;
* credenciales inválidas;
* email inexistente;
* contraseña incorrecta;
* campos vacíos;
* sesión;
* refresh;
* logout;
* volver atrás después del logout;
* acceso directo posterior a rutas protegidas.

---

# 27. RECUPERACIÓN DE CUENTA

Si existe:

1. Solicitar recuperación.
2. Probar email existente.
3. Probar email inexistente.
4. Analizar respuesta.
5. Comprobar flujo.
6. Comprobar seguridad.
7. Comprobar expiración cuando sea razonablemente posible.

Si NO existe:

registrarlo explícitamente debido a su relevancia en el nivel Excelente del criterio de seguridad.

---

# 28. ROLES

Descubrir todos los roles.

Crear:

| Rol | Ver | Crear | Editar | Eliminar | Administrar |
| --- | --- | ----- | ------ | -------- | ----------- |

Probar tanto:

### FRONTEND

como:

### BACKEND/API

Regla:

> Ocultar un botón NO es autorización.

Intentar acceder directamente a:

* rutas;
* recursos;
* endpoints;

de otros roles cuando pueda hacerse de forma segura.

---

# 29. RESPONSIVE

Debido a que la rúbrica evalúa la amigabilidad de la aplicación móvil, comprobar obligatoriamente:

```text
320x800
375x812
390x844
414x896
```

Buscar:

* overflow horizontal;
* botones cortados;
* texto cortado;
* elementos superpuestos;
* navegación rota;
* formularios incómodos;
* modales fuera de viewport;
* tablas inutilizables;
* targets táctiles demasiado pequeños;
* problemas de legibilidad.

---

# 30. AUDITORÍA DE BOTONES

Identificar todos los:

* botones;
* enlaces;
* iconos interactivos;
* menús;
* dropdowns;
* acciones;
* tabs;
* controles.

Crear:

| Elemento | Ubicación | Esperado | Real | Estado |
| -------- | --------- | -------- | ---- | ------ |

Estados:

* 🟢 Funciona
* 🟡 Parcial
* 🔴 Roto
* ⚪ Decorativo

Buscar específicamente:

* botones sin handler;
* enlaces muertos;
* botones que no hacen nada;
* navegación incorrecta;
* acciones que no persisten;
* elementos que generan errores.

---

# 31. FLUJOS END-TO-END

Identificar los principales journeys.

Ejemplo:

```text
Registro
↓
Login
↓
Dashboard
↓
Crear recurso
↓
Visualizar
↓
Editar
↓
Eliminar
↓
Logout
```

Ejecutarlos completos con Playwright.

NO probar solamente páginas aisladas.

---

# 32. AUDITORÍA DE BASE DE DATOS

Para cada información visible:

preguntar:

1. ¿Viene realmente de BD?
2. ¿Está hardcodeada?
3. ¿Se actualiza?
4. ¿Persiste?
5. ¿Es consistente?
6. ¿Qué ocurre si no existen datos?
7. ¿Qué ocurre si el recurso no existe?
8. ¿Qué ocurre ante error?

---

# 33. FALSOS EXCELENTES

Buscar específicamente características que superficialmente parezcan completas.

Ejemplos:

```text
Botón existe
≠
Botón funciona
```

```text
Datos visibles
≠
Datos provenientes de BD
```

```text
Rol existe
≠
Autorización correcta
```

```text
Email validado
≠
Email verificado
```

```text
Funciona desktop
≠
Funciona móvil
```

```text
API instalada
≠
API aporta innovación
```

```text
CRUD visible
≠
CRUD persiste
```

Todo "Falso Excelente" debe aparecer explícitamente en el informe.

---

# 34. PRIMERA EVALUACIÓN

Después de terminar las auditorías:

cada subagente entrega únicamente:

```text
HALLAZGOS
EVIDENCIA
SEVERIDAD
CRITERIO AFECTADO
POSIBLE IMPACTO
DUDAS / NO VERIFICADO
```

NO deben generar largas introducciones.

---

# 35. CORRELACIÓN

El Orquestador debe consolidar los resultados.

Eliminar:

* duplicados;
* falsos positivos;
* conclusiones sin evidencia.

Cuando dos agentes reporten el mismo problema:

combinar evidencia.

---

# 36. CONFLICTO ENTRE AGENTES

Si dos agentes discrepan:

NO calcular promedio.

Ejemplo:

```text
UX Agent:
Excelente

QA Agent:
Bueno
```

Investigar:

> ¿Por qué existe la diferencia?

La evidencia decide.

---

# 37. ABOGADO DEL DIABLO

Después de generar una primera puntuación provisional:

ASUME QUE FUE DEMASIADO GENEROSA.

Realiza una segunda pasada.

Pregunta:

> ¿Qué argumento legítimo podría utilizar el profesor para reducir esta nota?

Revisar:

* UX;
* móvil;
* seguridad;
* roles;
* BD;
* funcionalidades;
* creatividad.

Buscar:

* evidencia contradictoria;
* requisitos incompletos;
* funcionalidades parciales;
* bugs ignorados;
* pruebas insuficientes.

Si aparece evidencia nueva:

CORREGIR LA NOTA.

---

# 38. JUEZ INDEPENDIENTE

Crear un último subagente:

# RUBRIC JUDGE

Este agente NO debe confiar ciegamente en las conclusiones anteriores.

Solo puede utilizar:

1. rúbrica;
2. evidencia;
3. resultados Playwright;
4. código;
5. runtime;
6. BD;
7. seguridad.

Para cada criterio debe responder:

```text
NIVEL DEMOSTRADO:
EVIDENCIA:
REQUISITOS CUMPLIDOS:
REQUISITOS NO DEMOSTRADOS:
PROBLEMAS:
POR QUÉ NO MERECE EL NIVEL SUPERIOR:
PUNTUACIÓN:
CONFIANZA:
```

---

# 39. EXCELLENT GATE

Antes de otorgar Excelente:

```text
[ ] Todos los requisitos relevantes están implementados
[ ] Funcionan realmente
[ ] Existe evidencia
[ ] Playwright confirma los flujos importantes
[ ] No existen bugs críticos relacionados
[ ] No existen deficiencias importantes conocidas
[ ] Código y runtime son consistentes
[ ] La experiencia es consistente
[ ] El nivel Excelente puede defenderse ante el profesor
```

Si una condición fundamental falla:

> NO otorgar automáticamente Excelente.

Evaluar el siguiente nivel según la evidencia.

---

# 40. REGLA ANTI-INFLACIÓN

Está prohibido justificar notas con frases como:

> "Se ve bastante completo."

> "Parece profesional."

> "Está bien implementado."

> "Probablemente funciona."

> "Debería funcionar."

Toda puntuación debe responder:

> ¿DÓNDE ESTÁ LA EVIDENCIA?

Si no existe evidencia suficiente:

marcar:

```text
NO VERIFICADO
```

---

# 41. TAMPOCO REDUZCAS LA NOTA ARTIFICIALMENTE

Ser adversarial NO significa inventar defectos.

No reduzcas puntos porque:

* personalmente prefieras otra tecnología;
* usarías otra arquitectura;
* cambiarías el diseño por gusto;
* exista una solución técnicamente más sofisticada.

Toda reducción debe relacionarse con:

* rúbrica;
* fallo real;
* riesgo real;
* evidencia real;
* requisito no cumplido.

---

# 42. SEVERIDAD

Clasificar:

## 🔴 CRÍTICO

Rompe una función principal, genera riesgo grave o puede reducir considerablemente la nota.

## 🟠 ALTO

Puede impedir alcanzar Excelente.

## 🟡 MEDIO

Deficiencia relevante.

## 🟢 BAJO

Detalle menor/cosmético.

---

# 43. NO MODIFICAR DURANTE LA AUDITORÍA

No arreglar problemas durante la evaluación.

Primero:

```text
DETECTAR
↓
REPRODUCIR
↓
DOCUMENTAR
↓
EVIDENCIAR
↓
PUNTUAR
```

Después:

```text
RECOMENDAR SOLUCIÓN
```

La auditoría debe reflejar el estado REAL de la aplicación antes de modificaciones.

---

# 44. FUNCIONALIDADES NUEVAS

Después de evaluar el estado actual, proponer mejoras.

Especialmente funciones que aumenten:

> Creatividad y uso de nuevas tecnologías.

Para cada propuesta:

| Función | Problema/valor | Tecnología | Dificultad | Impacto |
| ------- | -------------- | ---------- | ---------- | ------- |

Priorizar:

```text
VALOR
×
INNOVACIÓN
×
DEMOSTRABILIDAD
÷
DIFICULTAD
```

No recomendar funciones simplemente porque sean "cool".

---

# 45. PRIORIZACIÓN DE MEJORAS

Para cada mejora calcular conceptualmente:

```text
PRIORIDAD =
IMPACTO EN RÚBRICA
×
SEVERIDAD
×
PROBABILIDAD DE SER OBSERVADO
÷
DIFICULTAD
```

Primero recomendar mejoras capaces de recuperar puntos.

---

# 46. INFORME FINAL

Generar exactamente esta estructura:

# 🔴 AUDITORÍA CREA J 2026

---

## 1. VEREDICTO EJECUTIVO

Indicar:

* estado actual;
* fortalezas;
* debilidades;
* riesgos principales;
* puntuación.

---

## 2. PUNTUACIÓN FINAL

| Criterio      |    Peso | Nivel | Puntos |
| ------------- | ------: | ----- | -----: |
| Amigabilidad  |      20 |       |        |
| Roles         |      10 |       |        |
| Seguridad     |      20 |       |        |
| BD            |      10 |       |        |
| Funcionalidad |      20 |       |        |
| Creatividad   |      20 |       |        |
| **TOTAL**     | **100** |       |        |

---

## 3. CONFIANZA

```text
CONFIANZA GLOBAL:
Alta / Media / Baja
```

Explicar por qué.

---

## 4. COBERTURA DE AUDITORÍA

Indicar:

```text
Pantallas descubiertas:
Pantallas probadas:

Rutas descubiertas:
Rutas probadas:

Funciones descubiertas:
Funciones probadas:

Roles descubiertos:
Roles probados:

Tests Playwright:
PASS:
FAIL:
NO VERIFICADOS:
```

---

## 5. EVALUACIÓN POR CRITERIO

Para cada criterio:

### REQUISITO

### EVIDENCIA

### TESTS

### RESULTADOS PLAYWRIGHT

### HALLAZGOS

### PROBLEMAS

### REQUISITOS NO DEMOSTRADOS

### NIVEL

### PUNTOS

### POR QUÉ NO OBTIENE EL SIGUIENTE NIVEL

### CAMBIO NECESARIO PARA SUBIR

---

## 6. MATRIZ DE EVIDENCIA

| Evidence ID | Criterio | Tipo | Evidencia | Resultado |
| ----------- | -------- | ---- | --------- | --------- |

---

## 7. MATRIZ DE TESTS

| Test ID | Área | Test | Resultado | Evidencia |
| ------- | ---- | ---- | --------- | --------- |

---

## 8. BUGS

Para cada bug:

```text
[SEVERIDAD] NOMBRE

Ubicación:
Test ID:
Pasos:
Resultado esperado:
Resultado real:
Evidencia:
Criterio afectado:
Impacto:
```

---

## 9. SEGURIDAD

Separar:

### CONFIRMADOS

### POTENCIALES

### NO VERIFICADOS

---

## 10. UX/UI

Listar todos los hallazgos.

---

## 11. RESPONSIVE / MÓVIL

Resultados para:

* 320px
* 375px
* 390px
* 414px

---

## 12. ROLES

Tabla:

| Rol | Acción | Permitido | Resultado | Evidencia |
| --- | ------ | --------- | --------- | --------- |

---

## 13. BASE DE DATOS

Documentar:

* persistencia;
* CRUD;
* actualización;
* inconsistencias;
* datos hardcodeados;
* errores.

---

## 14. FUNCIONALIDADES

### 🟢 COMPLETAS

### 🟡 PARCIALES

### 🔴 ROTAS

### ⚪ NO VERIFICADAS

---

## 15. FALSOS EXCELENTES

Lista de funciones que parecían completas pero cuya evidencia demostró limitaciones.

---

## 16. LO QUE REALMENTE ESTÁ MUY BIEN

No ser injustamente negativo.

Reconocer características que REALMENTE cumplen.

Incluir evidencia.

---

## 17. TOP 10 PROBLEMAS

Ordenar por impacto sobre la evaluación.

|  # | Problema | Severidad | Criterio | Puntos en riesgo |
| -: | -------- | --------- | -------- | ---------------- |

---

## 18. TOP 10 MEJORAS

Ordenar por:

> Impacto × facilidad

Para cada una:

```text
PROBLEMA:
SOLUCIÓN:
CRITERIO:
DIFICULTAD:
IMPACTO:
PRIORIDAD:
```

---

## 19. FUNCIONALIDADES NUEVAS

| Función | Valor | Tecnología | Criterio | Dificultad | Impacto |
| ------- | ----- | ---------- | -------- | ---------- | ------- |

---

## 20. ROADMAP A 100/100

### 🔴 BLOQUEANTES

Solucionar antes de presentar.

### 🟠 ALTO IMPACTO

Cambios capaces de recuperar puntos importantes.

### 🟡 PULIDO

Mejoras secundarias.

### 🟢 INNOVACIÓN

Características para destacar.

---

## 21. PUNTUACIÓN DESPUÉS DE LAS MEJORAS

Estimar prudentemente:

```text
PUNTUACIÓN ACTUAL:
XX/100

DESPUÉS DE BLOQUEANTES:
XX/100

DESPUÉS DE ALTO IMPACTO:
XX/100

POTENCIAL MÁXIMO:
XX/100
```

Estas cifras son estimaciones, no garantías.

---

## 22. VEREDICTO DEL ABOGADO DEL DIABLO

Responder:

> ¿Cuál es el argumento más fuerte que podría utilizar el profesor para bajar la puntuación?

Después indicar los tres riesgos principales.

---

## 23. VEREDICTO FINAL DEL JUEZ

Terminar exactamente con:

> **"Si yo fuera el profesor y evaluara hoy esta aplicación siguiendo estrictamente la rúbrica, le otorgaría XX/100."**

Después:

### Las 3 razones principales de esta puntuación:

1.
2.
3.

Y:

### Lo primero que arreglaría antes de presentar:

1.
2.
3.

---

# 47. ESTRATEGIA RECOMENDADA DE MODELOS

Tengo límites de uso y quiero maximizar calidad por consumo.

NO utilices automáticamente el modelo más costoso para todas las tareas.

Distribuye razonamiento de forma eficiente.

## Tareas mecánicas / reconocimiento

Utilizar un modelo eficiente/capaz para:

* explorar archivos;
* localizar rutas;
* buscar componentes;
* identificar endpoints;
* crear inventarios;
* recopilar evidencia.

Esfuerzo:

> MEDIO

---

## QA + Playwright

Utilizar un modelo de coding fuerte.

Esfuerzo:

> MEDIO o ALTO

El objetivo es cobertura, no escribir ensayos.

---

## Seguridad

Utilizar razonamiento superior.

Esfuerzo:

> ALTO

---

## UX

Modelo eficiente.

Esfuerzo:

> MEDIO

---

## Base de datos

Modelo fuerte de coding.

Esfuerzo:

> MEDIO-ALTO

---

## Abogado del Diablo

Utilizar el modelo más capaz disponible si la cuota lo permite.

Esfuerzo:

> ALTO

---

## Juez final

Utilizar el modelo más capaz disponible si la cuota lo permite.

Esfuerzo:

> ALTO

---

# 48. ESTRATEGIA PARA PLAN CON CUOTA LIMITADA

Priorizar el consumo en este orden:

```text
1. Playwright
2. Funcionalidad
3. Seguridad
4. Evidencia
5. Rúbrica
6. Abogado del Diablo
7. Juez
8. UX
9. Exploración adicional
```

Evitar gastar contexto en:

* explicaciones durante la auditoría;
* resúmenes repetidos;
* comentarios innecesarios;
* agentes duplicados.

Los subagentes deben reportar principalmente:

```text
HALLAZGO
EVIDENCIA
SEVERIDAD
IMPACTO
```

---

# 49. RECOMENDACIÓN OPERATIVA PARA CLAUDE CODE

Si están disponibles Sonnet y Opus:

## SONNET

Usarlo principalmente para:

* reconocimiento;
* exploración;
* Playwright;
* inventario;
* UX;
* BD;
* QA.

Esfuerzo recomendado:

> MEDIO → ALTO según la fase.

## OPUS

Reservarlo principalmente para:

* seguridad compleja;
* correlación final;
* abogado del diablo;
* Rubric Judge.

Esfuerzo:

> ALTO.

No utilizar Opus indiscriminadamente para leer cada archivo si existe una opción más eficiente.

---

# 50. PRESUPUESTO DE AGENTES

NO lanzar todos los agentes simultáneamente.

Utilizar este orden:

```text
ORQUESTADOR
     ↓
MAPA
     ↓
QA ────────┐
UX         │
SECURITY   │
DATABASE   ├── EVIDENCIA
FUNCTIONAL │
TECH       │
NOVICE ────┘
     ↓
CORRELACIÓN
     ↓
PROFESOR HOSTIL
     ↓
ABOGADO DEL DIABLO
     ↓
RUBRIC JUDGE
```

Los agentes pueden trabajar en paralelo únicamente cuando:

* no duplican trabajo;
* tienen objetivos independientes;
* el ahorro de tiempo justifica el contexto adicional.

---

# 51. STOP CONDITIONS

No sigas consumiendo cuota indefinidamente.

Una fase puede terminar cuando:

```text
[ ] principales pantallas probadas
[ ] principales flujos probados
[ ] roles probados
[ ] registro probado
[ ] autenticación probada
[ ] CRUD relevante probado
[ ] móvil probado
[ ] principales botones probados
[ ] seguridad básica revisada
[ ] evidencia suficiente para cada criterio
```

Si queda algo sin probar:

marcar:

> NO VERIFICADO

Es preferible reconocer una limitación que desperdiciar cuota o inventar evidencia.

---

# 52. CHECKPOINT ANTES DEL JUEZ

Antes de gastar recursos en el modelo final, el Orquestador debe comprobar:

```text
[ ] Existe Application Map
[ ] Existe inventario funcional
[ ] Existe matriz Playwright
[ ] Existe matriz de evidencia
[ ] Existen resultados de seguridad
[ ] Existen resultados BD
[ ] Existen resultados responsive
[ ] Existen resultados roles
[ ] Los bugs tienen evidencia
[ ] Los duplicados fueron eliminados
```

Solo entonces ejecutar:

> ABOGADO DEL DIABLO

y posteriormente:

> RUBRIC JUDGE

---

# 53. NO DESPERDICIAR CONTEXTO

Los subagentes no deben copiar grandes cantidades de código en sus respuestas.

Preferir:

```text
archivo:rango
función
hallazgo
evidencia
```

Ejemplo:

```text
src/auth/register.ts:45-72
Validación de contraseña únicamente frontend.
SECURITY-HIGH
```

No copiar 100 líneas cuando bastan referencias.

---

# 54. RECOMENDACIONES DE FUNCIONES

Al proponer nuevas funcionalidades, distinguir:

## A. FUNCIONES PARA RECUPERAR PUNTOS

Solucionan requisitos de la rúbrica.

## B. FUNCIONES PARA ALCANZAR EXCELENTE

Perfeccionan características existentes.

## C. FUNCIONES PARA DESTACAR

Innovaciones adicionales.

Nunca recomendar C antes de resolver A.

---

# 55. ORDEN DE PRIORIDAD SEGÚN LA RÚBRICA

Prestar especial atención a los criterios de 20 puntos:

```text
Amigabilidad              20
Seguridad                  20
Funcionalidad              20
Creatividad                20
```

Sin descuidar:

```text
Roles                      10
BD                         10
```

No sacrificar criterios completos de 10 puntos únicamente para añadir una función innovadora.

---

# 56. PRINCIPIO DE MAXIMIZACIÓN

El objetivo NO es crear la aplicación técnicamente más compleja.

El objetivo es:

> **MAXIMIZAR LA PUNTUACIÓN REAL Y DEFENDIBLE SEGÚN LA RÚBRICA.**

Por ello:

una mejora simple que recupera 5 puntos

es más importante que:

una función compleja que impresiona pero no modifica la evaluación.

---

# 57. REGLAS FINALES

Estas reglas son OBLIGATORIAS.

1. Sé extremadamente estricto.
2. Sé objetivo.
3. No seas complaciente.
4. No inventes defectos.
5. No asumas que algo funciona.
6. Usa Playwright.
7. Inspecciona código.
8. Compara código vs runtime.
9. Busca fallos activamente.
10. Prueba casos límite.
11. Evalúa móvil.
12. Audita seguridad.
13. Audita roles.
14. Audita BD.
15. Audita funcionalidades.
16. Audita botones.
17. Busca datos hardcodeados.
18. Busca funciones incompletas.
19. Busca falsos excelentes.
20. Registra evidencia.
21. No inventes evidencia.
22. Marca NO VERIFICADO cuando corresponda.
23. No otorgues puntos por intención.
24. No infles la nota.
25. No reduzcas la nota artificialmente.
26. Realiza revisión del Abogado del Diablo.
27. Utiliza un Juez independiente.
28. Calcula la puntuación sobre 100.
29. Explica exactamente por qué no obtiene el siguiente nivel.
30. Propón mejoras concretas.
31. Prioriza mejoras por impacto.
32. Propón innovación después de corregir problemas.
33. Controla el consumo de contexto/cuota.
34. No dupliques trabajo entre agentes.
35. Comprueba disponibilidad de Graphyfi.
36. Comprueba disponibilidad de Superpowers.
37. Si una herramienta no existe, no inventes resultados.
38. No modifiques el proyecto durante la auditoría.
39. Evidencia antes de conclusión.
40. La rúbrica es la fuente final de puntuación.

---

# 58. ECUACIÓN DE LA AUDITORÍA

Toda conclusión debe seguir:

```text
EVIDENCIA
   ↓
HALLAZGO
   ↓
SEVERIDAD
   ↓
CRITERIO DE RÚBRICA
   ↓
NIVEL
   ↓
PUNTUACIÓN
```

Nunca:

```text
IMPRESIÓN
   ↓
PUNTUACIÓN
```

---

# 59. OBJETIVO FINAL

Cuando termines debo poder responder con confianza:

> **"Si mañana el profesor evalúa mi aplicación, ¿qué nota probablemente obtendré?"**

> **"¿Qué evidencia respalda esa nota?"**

> **"¿Dónde perdería puntos?"**

> **"¿Qué tengo que arreglar primero?"**

> **"¿Qué funcionalidades me acercarían a 100/100?"**

> **"¿Qué podría descubrir el profesor que todavía no he considerado?"**

Tu trabajo consiste en descubrir esos problemas:

# ANTES QUE EL PROFESOR.

---

# 60. COMANDO DE INICIO

Comienza ahora.

NO empieces asignando puntuaciones.

Primero realiza únicamente:

1. reconocimiento del repositorio;
2. detección de herramientas disponibles;
3. detección de Graphyfi;
4. detección de Superpowers;
5. identificación de cómo ejecutar la aplicación;
6. identificación de arquitectura;
7. identificación de rutas;
8. identificación de roles;
9. identificación de funcionalidades;
10. creación del Application Map;
11. propuesta del plan de auditoría;
12. estimación de qué tareas delegarás a cada subagente.

Después comienza las pruebas.

Recuerda durante toda la auditoría:

> **SI NO PUEDES DEMOSTRARLO, NO LO DES POR CUMPLIDO.**

```
```
