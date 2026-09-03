# Graph Report - c:/Users/User/Documents/creaj/autodoc  (2026-09-02)

## Corpus Check
- Large corpus: 785 files · ~1,161,198 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 215 nodes · 213 edges · 42 communities (14 shown, 28 thin omitted)
- Extraction: 87% EXTRACTED · 11% INFERRED · 1% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 35
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41

## God Nodes (most connected - your core abstractions)
1. `AutoDoc Product Spec` - 17 edges
2. `Auditoría Production Readiness 2026-08-04` - 13 edges
3. `AutoDoc UI/UX Overhaul Master Plan` - 10 edges
4. `Firebase Cloud Functions Documentation` - 9 edges
5. `QA Punch List Fixes Implementation Plan` - 8 edges
6. `TestSprite Aug 7 2026 Testing Report` - 7 edges
7. `Fase 1 - Foundation Implementation Plan` - 7 edges
8. `Panel de Administracion al 100% Plan` - 5 edges
9. `Security Findings Fix Implementation Plan` - 5 edges
10. `QA E2E Punch List 10 Reported Flows Plan` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Invalid credentials still reach dashboard` --semantically_similar_to--> `auth_screen.dart lacks Form/TextFormField/validator`  [INFERRED] [semantically similar]
  TestSprite.md → docs/AUDITORIA_PRODUCTION_READINESS_2026-08-04.md
- `AutoDoc Product Spec` --references--> `go_router dependency (routing)`  [EXTRACTED]
  PRODUCT_SPEC.md → pubspec.yaml
- `Garaje/Kanban route returns 404 in production` --references--> `garage_screen.dart`  [AMBIGUOUS]
  TestSprite.md → PRODUCT_SPEC.md
- `TestSprite Aug 7 2026 Testing Report` --references--> `Auditoría Production Readiness 2026-08-04`  [INFERRED]
  TestSprite.md → docs/AUDITORIA_PRODUCTION_READINESS_2026-08-04.md
- `Historial de Servicios del Taller - failed flow` --conceptually_related_to--> `_buildServiceCard onTap + _mostrarDetalleServicio dialog`  [AMBIGUOUS]
  e2e/reporte_playwright.md → docs/superpowers/plans/2026-08-07-qa-e2e-fixes.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Production SPA routing 404 bug discovered by TestSprite, missed by static-only audit** — testsprite, testsprite_404_directorio, testsprite_404_chat, testsprite_404_garaje, docs_auditoria_production_readiness_2026_08_04 [INFERRED 0.75]
- **Mechanic Panel Feature Subsystems (Kanban, Employees, Catalog)** — docs_superpowers_plans_2026_07_31_mechanic_panel_100_reparacionmodel, docs_superpowers_plans_2026_07_31_mechanic_panel_100_empleadomodel, docs_superpowers_plans_2026_07_31_mechanic_panel_100_catalogoitemmodel [EXTRACTED 1.00]
- **Firestore Rules Field-Scoping Security Fix Pattern** — docs_superpowers_plans_2026_08_01_security_findings_fix_cotizaciones_field_scoping, docs_superpowers_plans_2026_08_01_security_findings_fix_reservas_field_scoping, docs_superpowers_plans_2026_08_01_security_findings_fix_aggregateratings_incremental [INFERRED 0.85]
- **UI/UX Overhaul: Master Plan + Foundation + Shell/Navigation Phase Dependency** — docs_superpowers_plans_2026_08_10_ui_ux_overhaul_00_master, docs_superpowers_plans_2026_08_10_ui_ux_overhaul_01_foundation, docs_superpowers_plans_2026_08_10_ui_ux_overhaul_02_shell_navigation, docs_superpowers_plans_2026_08_10_ui_ux_overhaul_03_shared_components [EXTRACTED 1.00]

## Communities (42 total, 28 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.08
Nodes (33): auth_screen.dart lacks Form/TextFormField/validator, Firebase Cloud Functions Documentation, checkAlertsDaily (Cloud Function), checkMileageOnVehicleUpdate (Cloud Function), notifyOnNewChatMessage (Cloud Function), notifyOnNewReservation (Cloud Function), notifyOnReservationStatusChange (Cloud Function), onUserDelete (Cloud Function) (+25 more)

### Community 1 - "Community 1"
Cohesion: 0.10
Nodes (26): AutoDoc UI/UX Overhaul Master Plan, Rejection of ui-ux-pro-max palette/typography recommendation to preserve brand, WindowClass window size classes (compact/medium/expanded/large), Fase 1 - Foundation Implementation Plan, AppBreakpoints / WindowClass implementation, AppMotion curves/durations/reduced-motion tokens, AppPageBody + AppGrid adaptive layout primitives, AppShadows.lightHover/darkHover variants (+18 more)

### Community 2 - "Community 2"
Cohesion: 0.10
Nodes (21): aprobarTodosTalleres.js unsafe bulk-approve script, UI calls Firebase directly in 12+ files (layering violation), Hardcoded shared Superuser temp password, Owner email enumeration oracle unmitigated, Firestore backup fails silently, unverified, Insufficient WCAG contrast on error/warning/success colors, Almost no Semantics/semanticLabel usage (accessibility 28/100), Integration tests pass without executing real flow (+13 more)

### Community 3 - "Community 3"
Cohesion: 0.11
Nodes (20): Panel del Mecanico/Talleres al 100% Plan, CatalogoItemModel + CatalogoRepository (service/parts catalog), CatalogoProvider + CatalogoServiciosScreen + invoice integration, crearEmpleadoTaller callable (Admin SDK createUser), EmpleadoModel + EmpleadoRepository (workshop sub-accounts), EmpleadoProvider + EmpleadosScreen, notifyOnReparacionStatusChange Cloud Function, ReparacionesKanbanScreen + ReparacionCard (+12 more)

### Community 4 - "Community 4"
Cohesion: 0.13
Nodes (16): Panel de Administracion al 100% Plan, AdminService monthly growth aggregation + UserGrowthChart/WorkshopsGrowthChart, csv_export_util (buildCsv/downloadCsv), Reuse of estado field for account suspension/reactivation, filtrarTalleres pure filter function, WorkshopModel.departamento field, Cloud Functions & Backend al 100% Plan, checkVehicleExpirationsAt8am cron function (+8 more)

### Community 5 - "Community 5"
Cohesion: 0.14
Nodes (15): Chat y Mensajeria al 100% Plan, notifyOnNewChatMessage audio branch push text, marcarComoLeidos trigger fix on chat open, Voice notes feature (MensajeModel.duracionSegundos, subirAudioChat, VoiceRecordButton, AudioChatCard), QA Punch List Fixes Implementation Plan, ChatProvider.enviarCotizacion (null-guard blank quote bug), especialidadesTaller fixed dropdown list, PlateFormatter + validarPlacaElSalvador (P###-### format) (+7 more)

### Community 6 - "Community 6"
Cohesion: 0.15
Nodes (14): ReviewModel.fotos + respuestaTaller fields, subirFotosResenia photo upload, Security Findings Fix Implementation Plan, aggregateRatings incremental counters (hallazgo M2, suma_estrellas), CotizacionItem.beneficio moved to private subcollection (hallazgo H2), cotizaciones update field-scoping (hallazgo H1), reservas update field-scoping (hallazgo M1), reservas dead 'aprobada' state + N+1 read fix (notifyOnReservationStatusChange/sendReservationReminders) (+6 more)

### Community 7 - "Community 7"
Cohesion: 0.17
Nodes (12): Resenias y Calificaciones al 100% Plan, admin_resenias_screen reported-reviews filter/badge, ReviewSortOrder + ordenarResenias pure sort function, ReviewService.responderResenia (workshop reply), firestore.rules resenias update rule fix (author/taller/report branches), actuaPorTaller employee-reply rule fix for resenias, dashboard_screen didChangeDependencies vehicle-fetch race fix, TestSprite Production Report Fix Real Failures Plan (+4 more)

### Community 8 - "Community 8"
Cohesion: 0.25
Nodes (8): checkAlertsDaily N+1 query fix (commit 18706e9), firestore-rules-reviewer subagent, functions-perf-reviewer subagent, /test slash command, firebase-deploy-check skill, firestore.rules, functions/index.js (Cloud Functions), Firestore rules IDOR fix (commit 1c24da0)

### Community 9 - "Community 9"
Cohesion: 0.32
Nodes (8): AppBottomNav (Material 3 NavigationBar, replaces InstagramBottomNavBar/AppBottomNavBar), AppNavDestinations single source of nav destinations, AppNavRail for medium/expanded window classes, MainScaffold adaptive shell (WindowClass x rol matrix), Fase 5 - Modulo Mechanic Plan, FakeUserProfileProvider implements-not-extends fix for Phase 2 test double, MechanicScaffold unified shell (replaces 8 copied shells + 700px breakpoint), no_hardcoded_colors_test regex gap for Colors.white10/black12 etc.

### Community 10 - "Community 10"
Cohesion: 0.50
Nodes (4): Plan de Mejora UI/UX de AutoDoc en Flutter usando Kombai, Kombai Design Tokens (.kombai/design-systems/autodoc-m3-theme.json), ReviewSheet Star Animation, VehicleCard Redesign (SOAT/circulacion status)

### Community 11 - "Community 11"
Cohesion: 0.67
Nodes (3): autodoc Binary Name, flutter_assemble Target, autodoc Executable Target

### Community 12 - "Community 12"
Cohesion: 0.67
Nodes (3): AuthService Web Login Flow, Google Sign-In Client ID, google_sign_in_web Plugin

### Community 13 - "Community 13"
Cohesion: 0.67
Nodes (3): flutter_assemble Target (Windows), flutter_wrapper_app, autodoc Executable Target (Windows)

## Ambiguous Edges - Review These
- `garage_screen.dart` → `Garaje/Kanban route returns 404 in production`  [AMBIGUOUS]
  TestSprite.md · relation: references
- `_buildServiceCard onTap + _mostrarDetalleServicio dialog` → `Historial de Servicios del Taller - failed flow`  [AMBIGUOUS]
  e2e/reporte_playwright.md · relation: conceptually_related_to
- `Fase 8 - Modulo Admin Plan` → `Rol Superusuario Implementation Plan`  [AMBIGUOUS]
  docs/superpowers/plans/2026-08-10-ui-ux-overhaul-08-admin.md · relation: conceptually_related_to

## Knowledge Gaps
- **86 isolated node(s):** `ContactPage`, `generateStaticParams`, `generateMetadata`, `RootLayout`, `Home` (+81 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **28 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `garage_screen.dart` and `Garaje/Kanban route returns 404 in production`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `_buildServiceCard onTap + _mostrarDetalleServicio dialog` and `Historial de Servicios del Taller - failed flow`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Fase 8 - Modulo Admin Plan` and `Rol Superusuario Implementation Plan`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `AutoDoc UI/UX Overhaul Master Plan` connect `Community 1` to `Community 9`, `Community 5`?**
  _High betweenness centrality (0.162) - this node is a cross-community bridge._
- **Why does `Fase 6 - Modulo Chat y Reservas Plan` connect `Community 5` to `Community 1`?**
  _High betweenness centrality (0.104) - this node is a cross-community bridge._
- **What connects `ContactPage`, `generateStaticParams`, `generateMetadata` to the rest of the system?**
  _86 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.07575757575757576 - nodes in this community are weakly interconnected._