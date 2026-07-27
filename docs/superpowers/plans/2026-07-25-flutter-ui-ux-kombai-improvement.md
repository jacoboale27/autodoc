# Plan de Mejora UI/UX de AutoDoc en Flutter usando Kombai

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar y elevar la experiencia e interfaz de usuario (UI/UX) de la aplicación Flutter de AutoDoc utilizando la metodología y configuración de Kombai, integrando Material 3, animaciones fluidas y un diseño visual premium.

**Architecture:** Refactorización modular dividida en 3 capas: (1) Sistema de Tema y Tokens de Diseño (`lib/core/theme/`), (2) Componentes Atomizados Core (`lib/core/widgets/`), (3) Rediseño de Pantallas por Módulo (`lib/features/`). Cada capa utiliza archivos de configuración en `.kombai/` para mantener consistencia de diseño.

**Tech Stack:** Flutter (Dart), Material Design 3, Google Fonts, Kombai CLI/Spec, Provider / Riverpod state management.

## Global Constraints

- Todos los colores e identidades visuales deben ser configurables mediante `AppTheme` y `AppColors`.
- Mantener compatibilidad total con la lógica de negocio y reglas de tablas Firebase (`tablas-firebase.md`).
- Asegurar comportamiento responsivo en móviles Android/iOS y Web Wrapper.

---

### Task 1: Configuración de Sistema de Diseño Kombai y Tokens en Flutter

**Files:**
- Create: `.kombai/design-systems/autodoc-m3-theme.json`
- Modify: `lib/core/theme/app_colors.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Modify: `lib/core/theme/app_shadows.dart`
- Modify: `lib/core/theme/app_text_styles.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: Flutter `ThemeData`, Google Fonts `Outfit`/`Inter`
- Produces: `AppTheme.darkTheme`, `AppTheme.lightTheme`, `AppColors.primary`, `AppShadows.cardShadow`

- [ ] **Step 1: Crear archivo de tokens de diseño Kombai**
  Crear `.kombai/design-systems/autodoc-m3-theme.json` definiendo paleta HSL, radiuses y elevaciones.

- [ ] **Step 2: Actualizar `AppColors` y `AppTheme`**
  Actualizar `app_colors.dart` y `app_theme.dart` para soportar Material 3, gradientes y esquema para modo oscuro/claro.

- [ ] **Step 3: Ejecutar pruebas sintácticas del tema**
  Ejecutar `flutter test test/core/theme/app_theme_test.dart` o `flutter analyze`.

---

### Task 2: Refactorización Visual de Componentes Core en Kombai

**Files:**
- Modify: `lib/core/widgets/app_button.dart`
- Modify: `lib/core/widgets/app_card.dart`
- Modify: `lib/core/widgets/app_text_field.dart`
- Modify: `lib/core/widgets/app_bottom_nav_bar.dart`
- Modify: `lib/core/widgets/app_status_badge.dart`
- Test: `test/core/widgets/widgets_ui_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppTheme`, Kombai Widget Specs
- Produces: Components reutilizables con soporte de micro-interacciones, retroalimentación táctil y diseño adaptable.

- [ ] **Step 1: Refactorizar `AppButton` y `AppTextField`**
  Implementar estilos de estados (activo, presionado, deshabilitado) con animaciones de transición.

- [ ] **Step 2: Refactorizar `AppCard` y `AppBottomNavBar`**
  Agregar glassmorphism a las tarjetas y barra flotante de navegación con indicador animado.

- [ ] **Step 3: Verificar renderizado de widgets**
  Ejecutar `flutter test` en los componentes modificados.

---

### Task 3: Rediseño Kombai de Pantallas Dashboard y Garaje Virtual

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- Modify: `lib/features/dashboard/presentation/widgets/vehicle_card.dart`
- Modify: `lib/features/dashboard/presentation/widgets/quick_actions_bar.dart`
- Test: `test/features/dashboard/dashboard_ui_test.dart`

**Interfaces:**
- Consumes: `Vehiculos` collection, `Alertas` status (Verde/Amarillo/Rojo por kilometraje y vencimientos)
- Produces: Interfaz de Dashboard mejorada visualmente con tarjetas 3D y resúmenes de alertas.

- [ ] **Step 1: Aplicar Kombai Spec a `VehicleCard`**
  Diseñar tarjetas de vehículos con indicadores de estado de SOAT y tarjeta de circulación.

- [ ] **Step 2: Rediseñar carrusel y resumen de acciones**
  Integrar carrusel fluido de vehículos y botones de acceso rápido a servicios y alertas.

- [ ] **Step 3: Validar en emulador / tests**
  Ejecutar `flutter analyze` y verificación manual en app.

---

### Task 4: Rediseño Kombai de Pantallas de Talleres y Reseñas

**Files:**
- Modify: `lib/features/mechanic/presentation/screens/workshop_list_screen.dart`
- Modify: `lib/features/mechanic/presentation/screens/workshop_detail_screen.dart`
- Modify: `lib/core/widgets/review_sheet.dart`
- Test: `test/features/mechanic/mechanic_ui_test.dart`

**Interfaces:**
- Consumes: `Talleres` collection, `Resenias` collection (`AVG(estrellas)`)
- Produces: Pantallas de directorio de talleres con filtros animados y sheet de reseñas interactivo.

- [ ] **Step 1: Rediseñar tarjetas de talleres con calificación de estrellas**
  Optimizar lista de búsqueda de talleres con insignias de especialidad e información de municipio.

- [ ] **Step 2: Rediseñar `ReviewSheet` con animaciones de estrellas**
  Implementar selector de estrellas con animación al presionar y campo de texto estilizado.

- [ ] **Step 3: Verificar funcionamiento y tests**
  Ejecutar `flutter analyze`.

---

## Plan Handoff

Plan completo guardado en `docs/superpowers/plans/2026-07-25-flutter-ui-ux-kombai-improvement.md`.
