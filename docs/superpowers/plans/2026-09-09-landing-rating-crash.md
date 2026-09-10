# Landing Rating Crash Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restaurar la landing de AutoDoc convirtiendo correctamente las calificaciones serializadas por Firestore REST y retirar Vercel Analytics del export alojado en Firebase.

**Architecture:** La conversión se concentra en una función pura junto al componente que consume la respuesta REST, de modo que `Workshop.rating` siempre sea un `number`. La prueba E2E usa la misma forma serializada que producción y observa el resultado real en el navegador. La integración de Vercel se elimina por completo porque Firebase Hosting no sirve su endpoint.

**Tech Stack:** Next.js 16, React 19, TypeScript, Playwright, Firebase Hosting, pnpm.

## Global Constraints

- No cambiar estilos, textos, formularios, consultas, reglas ni datos de producción.
- No desplegar a producción desde la sesión del agente.
- Mantener la rama basada en `integracion/ola-1`.
- Ejecutar la suite de landing solamente contra emuladores y fixtures.

---

### Task 1: Normalizar calificaciones Firestore REST

**Files:**
- Modify: `e2e/tests-landing/helpers.js`
- Modify: `e2e/tests-landing/enlaces.spec.js`
- Modify: `landing-web/src/components/ui/WorkshopsSection.tsx`

**Interfaces:**
- Consumes: objetos Firestore REST con `doubleValue?: string | number` o `integerValue?: string | number`.
- Produces: `normalizarCalificacion(campo): number`, con fallback `5` para valores ausentes, no numéricos o no finitos.

- [ ] **Step 1: Hacer que el fixture imite la respuesta real y escribir la regresión**

Cambiar en `stubDirectorio`:

```js
calificacion_promedio: { doubleValue: '4.5' },
```

Añadir en `e2e/tests-landing/enlaces.spec.js`:

```js
test.describe('directorio publico', () => {
  test('renderiza una calificacion serializada por Firestore REST sin tumbar la pagina', async ({ page }) => {
    const errores = [];
    page.on('pageerror', (error) => errores.push(error.message));

    await page.goto('/es');

    await expect(page.getByText('Taller Demo E2E')).toBeVisible();
    await expect(page.getByText('4.5', { exact: true })).toBeVisible();
    expect(errores).toEqual([]);
  });
});
```

La mutación que debe detectar es volver a asignar el valor REST sin convertirlo a `number`.

- [ ] **Step 2: Construir la landing actual para ejecutar exactamente el código roto**

Run: `cd e2e && npm ci && npm run build:landing`

Expected: build exitoso; todavía contiene la asignación directa del valor REST.

- [ ] **Step 3: Ejecutar la prueba y verificar el rojo correcto**

Run: `cd e2e && npx playwright test --config playwright.landing.config.js enlaces.spec.js --grep "serializada por Firestore REST"`

Expected: FAIL porque `rating.toFixed is not a function` impide que aparezca `Taller Demo E2E`.

- [ ] **Step 4: Implementar la normalización mínima**

Añadir antes del componente en `WorkshopsSection.tsx`:

```ts
type FirestoreNumberValue = {
  doubleValue?: string | number;
  integerValue?: string | number;
};

export function normalizarCalificacion(
  campo: FirestoreNumberValue | undefined,
): number {
  const valor = Number(campo?.doubleValue ?? campo?.integerValue);
  return Number.isFinite(valor) ? valor : 5;
}
```

Reemplazar la asignación de `rating` por:

```ts
rating: normalizarCalificacion(fields?.calificacion_promedio),
```

- [ ] **Step 5: Reconstruir y comprobar el verde enfocado**

Run: `cd e2e && npm run build:landing`

Run: `cd e2e && npx playwright test --config playwright.landing.config.js enlaces.spec.js --grep "serializada por Firestore REST"`

Expected: PASS; la tarjeta muestra `Taller Demo E2E` y `4.5`, sin `pageerror`.

- [ ] **Step 6: Commit del arreglo funcional**

```bash
git add e2e/tests-landing/helpers.js e2e/tests-landing/enlaces.spec.js landing-web/src/components/ui/WorkshopsSection.tsx
git commit -m "fix(landing): normalizar calificaciones de Firestore REST"
```

---

### Task 2: Retirar Vercel Analytics del alojamiento Firebase

**Files:**
- Modify: `e2e/tests-landing/enlaces.spec.js`
- Modify: `landing-web/src/app/[locale]/layout.tsx`
- Modify: `landing-web/package.json`
- Modify: `landing-web/pnpm-lock.yaml`

**Interfaces:**
- Consumes: export estático servido por Firebase Hosting.
- Produces: página que no solicita rutas bajo `/_vercel/insights/`.

- [ ] **Step 1: Escribir la regresión observable para Analytics**

Añadir en el mismo `describe('directorio publico')`:

```js
test('no solicita el endpoint de Vercel Analytics en Firebase Hosting', async ({ page }) => {
  const solicitudesVercel = [];
  page.on('request', (request) => {
    if (request.url().includes('/_vercel/insights/')) {
      solicitudesVercel.push(request.url());
    }
  });

  await page.goto('/es');
  await expect(page.getByText('Taller Demo E2E')).toBeVisible();

  expect(solicitudesVercel).toEqual([]);
});
```

La mutación que debe detectar es reinsertar `<Analytics />` en el layout.

- [ ] **Step 2: Ejecutar la prueba y verificar el rojo correcto**

Run: `cd e2e && npx playwright test --config playwright.landing.config.js enlaces.spec.js --grep "Vercel Analytics"`

Expected: FAIL mostrando una solicitud a `/_vercel/insights/script.js`.

- [ ] **Step 3: Eliminar Analytics y actualizar dependencias**

Quitar de `landing-web/src/app/[locale]/layout.tsx`:

```ts
import { Analytics } from "@vercel/analytics/react";
```

y:

```tsx
<Analytics />
```

Run: `cd landing-web && pnpm remove @vercel/analytics`

Expected: `package.json` y `pnpm-lock.yaml` dejan de contener la dependencia.

- [ ] **Step 4: Reconstruir y comprobar el verde enfocado**

Run: `cd e2e && npm run build:landing`

Run: `cd e2e && npx playwright test --config playwright.landing.config.js enlaces.spec.js --grep "Vercel Analytics"`

Expected: PASS; no se observa ninguna solicitud a `/_vercel/insights/`.

- [ ] **Step 5: Ejecutar los gates completos de la landing**

Run: `cd landing-web && pnpm lint`

Expected: exit 0.

Run: `cd e2e && npm run test:landing`

Expected: todas las pruebas pasan contra emuladores; exit 0.

Run: `git diff --check`

Expected: sin errores de espacios ni finales de línea.

- [ ] **Step 6: Commit de la retirada y verificación**

```bash
git add e2e/tests-landing/enlaces.spec.js landing-web/src/app/[locale]/layout.tsx landing-web/package.json landing-web/pnpm-lock.yaml
git commit -m "fix(landing): retirar Vercel Analytics de Firebase Hosting"
```

---

### Task 3: Preparar la entrega sin desplegar producción

**Files:**
- Verify only: `landing-web/out/`

**Interfaces:**
- Consumes: build estático verificado de las tareas anteriores.
- Produces: rama lista para integrar y desplegar exclusivamente al target `landing`.

- [ ] **Step 1: Confirmar rama, commits y árbol limpio**

Run: `git status --short --branch && git log -3 --oneline`

Expected: rama `fix/landing-crash`, tres commits de esta tarea y ningún cambio rastreado pendiente.

- [ ] **Step 2: Documentar el comando manual limitado al target correcto**

No ejecutar. Entregar al propietario:

```powershell
firebase deploy --only hosting:landing --project production
```

Antes de ejecutarlo, la rama debe estar integrada en `integracion/ola-1` y `landing-web/out`
debe proceder del build verificado. El target `landing` publica `landing-web/out`; no toca la
app Flutter, Firestore, Storage ni Functions.
