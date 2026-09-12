# GAPS-03 — contraste, encabezados e imagenes decorativas

Fecha: 2026-09-12. Rama: `fix/gaps-03`.

## Contraste

Antes: ratios verificadas aportadas en la tarea, sin sustituir su evidencia.
Despues: `getComputedStyle` en Chromium, conversion de OKLCH a sRGB con canvas,
composicion de fondos transparentes y opacidades, y luminancia relativa WCAG.
Tailwind 4.3.2 usa OKLCH: sus colores computados no son exactamente los hex de
Tailwind 3 citados en el enunciado. Todas las comprobaciones exigen **4.5:1**.

| Caso | Antes (tema defectuoso) | Despues claro | Despues oscuro |
|---|---:|---:|---:|
| FeaturesGrid: descripciones inactivas | 3.728 oscuro | 4.595 | 6.745 |
| FeaturesGrid: rotulo TALLER | 3.728 oscuro | 4.764 | 6.745 |
| FeaturesGrid: descripcion de alerta | ~2.05 claro, con opacity-80 | 5.469 | 8.193 |
| WorkshopsSection: calificacion | 2.05 claro | 4.808 | 6.846 |
| Footer: copyright y enlaces inferiores | 4.012 oscuro | 4.553 | 7.259 |

- `dark:text-slate-400` conserva los colores claros de FeaturesGrid y Footer.
  En esta version produce sRGB `(144,161,185)`.
- La alerta usa `#C53030` sin `opacity-80`; mantiene `dark:text-inherit`.
- `amber-600` sigue fallando: **3.058:1** sobre slate-50, medido con su valor
  `oklch(66.6% 0.179 58.318)` del tema instalado. Se usa `amber-700`, sRGB
  `(187,77,0)`, y `dark:text-amber-500` conserva el ambar oscuro.

## Semantica y aspecto

- FeaturesGrid incorpora un `h2.sr-only` con `navPlatform` (ya existe en ES/EN).
- Los autores de TestimonialsSection pasan de h4 a h3; las dos columnas del
  footer, de h4 a h2. `text-base` mantiene el tamano y el interlineado anteriores.
- Las cuatro imagenes CSS permanecen intactas. Cada sitio explica en una linea
  que es decorativo y donde se expresa su contenido mediante texto.
- No se incorporan claves de traduccion.

## Centinela y gates

`e2e/tests-landing/contraste-encabezados.spec.js` incorpora dos tests:
un h1 y secuencia sin saltos en las cuatro rutas ES; contraste en ambos temas,
abriendo los paneles de alerta y sincronizacion por la UI. Incluye las tres
descripciones inactivas y los cuatro textos inferiores del footer. Espera el
fundido de los ancestros, pero conserva la opacidad del texto en el calculo.
Los resultados numericos se adjuntan al reporte como `ratios-contraste`.

Los dos tests fallaron sobre el export original por los defectos esperados y
pasaron sobre el export corregido. La comprobacion inicial aislada uso una
config temporal sin emuladores; el gate completo usa la config original.

| Gate | Resultado |
|---|---|
| `cd landing-web && npx tsc --noEmit` | exit 0, sin diagnosticos TypeScript |
| `cd landing-web && npm run lint` | exit 0, sin errores ni warnings de ESLint |
| `cd e2e && npm ci && npm run build:landing && npm run test:landing` | Todos exit 0; `42 passed (1.4m)`; `Script exited successfully (code 0)` |

El lint original tenia 8 errores y 3 warnings. Se corrigen los tipos `any`,
las comillas JSX, imports sin uso y la guarda de hidratacion del header
(`useSyncExternalStore` con snapshots servidor/cliente). No se desactivan reglas.

## Entorno y trazabilidad

Se instalo pnpm con Corepack 10.34.5 (pnpm no estaba en PATH) y se ejecuto
`pnpm install`; tambien `npm ci` en e2e. Los comandos npm/npx usan sus wrappers
`.cmd` porque PowerShell no permite ejecutar los wrappers `.ps1`.

El worktree no tiene dependencias de Functions. Para no modificar `functions/`,
se preparo una copia temporal bajo `landing-web/node_modules/gaps03-qa`:
19 archivos de fuente/package identicos por SHA-256 al worktree, con un enlace
a dependencias ya instaladas. Firebase CLI se instalo en otro directorio
ignorado bajo landing-web. Configuracion de QA con los puertos canonicos y
proyecto `autodoc-e2e`; salt ficticia y sin cuentas reales.

La primera suite completa dio **41 passed, 1 failed (20.2m)**: el test de
enlaces legales llego a `chrome-error://chromewebdata/` tras 17.8 minutos,
aunque su timeout es 60 segundos. No hay evidencia suficiente para asignar
la causa. La segunda se interrumpio al perder los emuladores (`ECONNREFUSED`);
un intento posterior de arranque encontro 8080 ocupado. No se cambiaron puertos,
timeouts, tests existentes ni codigo para ocultar esos fallos.

La corrida final completa, con emuladores nuevos y su ciclo bajo
`emulators:exec`, termino con **42 passed (1.4m)** y **exit 0**: los 40 casos
existentes y los 2 centinelas. El test de enlaces legales paso en 1.5 segundos.
El controlador cerro los emuladores al terminar.

## Commits pendientes por restriccion del sandbox

`git add -- landing-web/src` fue rechazado al crear
`.git/worktrees/gaps03/index.lock`: **Permission denied**. No se crearon commits.
La separacion prevista es:

1. `landing-web/src`: **Corrige contraste y encabezados de la landing sin alterar su aspecto**.
   Las variantes por tema evitan tocar colores que pasan; el rojo opaco y amber-700
   alcanzan 4.5:1; h2/h3 recuperan la estructura semantica. Incluye comentarios
   decorativos y correcciones necesarias para superar el lint preexistente.
2. El nuevo spec y esta evidencia: **Fija el contraste y la jerarquia con centinelas de navegador**.
   Comprueba el DOM y los colores computados en vez de afirmar clases CSS;
   cubre ambas paletas y los paneles que no aparecen al cargar la pagina.
